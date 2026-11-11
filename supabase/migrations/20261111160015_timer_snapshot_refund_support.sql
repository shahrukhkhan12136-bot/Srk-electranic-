-- Extend Admin Razorpay refund preparation to immutable timer payable snapshots.
-- Apply only after the 20261111160000..160014 timer release migrations.
begin;
create or replace function public.srk_admin_prepare_booking_refund(p_request_id uuid)
returns table(refund_record_id uuid,booking_id uuid,payment_id text,amount_paise bigint,idempotency_key text,status text)
language plpgsql security definer set search_path='' as $function$
declare
 v_request public.srk_booking_refund_requests%rowtype;
 v_booking public.service_bookings%rowtype;
 v_refund public.srk_razorpay_refunds%rowtype;
 v_payout public.srk_electrician_payouts%rowtype;
 v_snapshot public.srk_booking_payable_snapshots%rowtype;
 v_payment public.srk_razorpay_payments%rowtype;
 v_amount numeric(12,2);
 v_paise bigint;
 v_has_payout boolean:=false;
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 select * into v_request from public.srk_booking_refund_requests where id=p_request_id for update;
 if not found then raise exception 'REFUND_REQUEST_NOT_FOUND'; end if;
 if v_request.status not in ('approved','processing','unknown') then raise exception 'REFUND_REQUEST_MUST_BE_APPROVED_FIRST' using errcode='55000'; end if;
 select * into v_booking from public.service_bookings where id=v_request.booking_id for update;
 if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
 if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null or v_booking.razorpay_payment_id is null or v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$' or coalesce(v_booking.amount_paid,0)<=0 then raise exception 'VERIFIED_RAZORPAY_PAYMENT_REQUIRED' using errcode='55000'; end if;
 v_amount:=round(v_booking.amount_paid,2);
 if v_amount<>v_request.amount then raise exception 'REFUND_AMOUNT_CHANGED_SINCE_REQUEST' using errcode='55000'; end if;
 if v_booking.service_category_code is not null then
   select * into v_snapshot from public.srk_booking_payable_snapshots
   where booking_id=v_booking.id order by created_at desc limit 1 for update;
   if not found then raise exception 'IMMUTABLE_TIMER_PAYABLE_SNAPSHOT_REQUIRED' using errcode='55000'; end if;
   v_paise:=v_snapshot.amount_paise;
   if v_snapshot.currency<>'INR' or v_snapshot.total_amount<>v_amount
      or v_paise<>round(v_amount*100)::bigint then
     raise exception 'TIMER_REFUND_AMOUNT_DOES_NOT_MATCH_PAYABLE_SNAPSHOT' using errcode='55000';
   end if;
   select * into v_payment from public.srk_razorpay_payments
   where booking_id=v_booking.id and snapshot_id=v_snapshot.id
     and provider_payment_id=v_booking.razorpay_payment_id
     and amount_paise=v_paise and currency='INR'
   for update;
   if not found then raise exception 'CAPTURED_RAZORPAY_PAYMENT_LEDGER_REQUIRED' using errcode='55000'; end if;
 else
   if v_booking.quote_status<>'approved' then raise exception 'APPROVED_QUOTE_REQUIRED' using errcode='55000'; end if;
   if v_booking.quoted_amount is null or v_booking.service_charge is null or v_booking.materials_amount is null
      or v_amount<>round(v_booking.quoted_amount,2)
      or v_amount<>round(v_booking.service_charge+v_booking.materials_amount,2) then
     raise exception 'PAID_AMOUNT_DOES_NOT_MATCH_APPROVED_QUOTE' using errcode='55000';
   end if;
   v_paise:=round(v_amount*100)::bigint;
 end if;
 select * into v_refund from public.srk_razorpay_refunds where booking_id=v_booking.id for update;
 if found then
   if v_refund.status='failed' then raise exception 'PREVIOUS_REFUND_FAILED_RECONCILE_FIRST'; end if;
   update public.srk_booking_refund_requests
   set status=case when v_refund.status='processed' then 'processed' else 'processing' end,
       refund_record_id=v_refund.id,updated_at=clock_timestamp(),
       processed_at=case when v_refund.status='processed' then coalesce(v_refund.processed_at,clock_timestamp()) else null end
   where id=v_request.id;
   return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status;
   return;
 end if;
 select * into v_payout from public.srk_electrician_payouts where booking_id=v_booking.id for update;
 v_has_payout:=found;
 if v_has_payout then
   if v_payout.payout_status='paid' then raise exception 'ELECTRICIAN_PAYOUT_ALREADY_PAID_RECONCILIATION_REQUIRED'; end if;
   if v_payout.payout_status not in ('pending','blocked') then raise exception 'ELECTRICIAN_PAYOUT_STATE_REQUIRES_RECONCILIATION'; end if;
   update public.srk_electrician_payouts set payout_status='blocked',payout_note='Customer refund in progress',updated_at=clock_timestamp() where id=v_payout.id;
 end if;
 insert into public.srk_razorpay_refunds(
   booking_id,payment_id,amount,amount_paise,idempotency_key,status,reason,admin_user_id,previous_payout_note
 ) values (
   v_booking.id,v_booking.razorpay_payment_id,v_amount,v_paise,
   replace(gen_random_uuid()::text,'-',''),'requested',
   left('Customer refund request: '||v_request.reason,250),auth.uid(),
   case when v_has_payout then v_payout.payout_note else null end
 ) returning * into v_refund;
 update public.srk_booking_refund_requests
 set status='processing',refund_record_id=v_refund.id,decided_by=auth.uid(),updated_at=clock_timestamp()
 where id=v_request.id;
 return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status;
end $function$;
commit;
