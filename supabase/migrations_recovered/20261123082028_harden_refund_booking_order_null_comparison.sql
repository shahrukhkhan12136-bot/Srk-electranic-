
create or replace function public.srk_admin_prepare_booking_refund(p_request_id uuid)
returns table(
 refund_record_id uuid, booking_id uuid, payment_id text,
 amount_paise bigint, idempotency_key text, status text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
 v_request public.srk_booking_refund_requests%rowtype;
 v_booking public.service_bookings%rowtype;
 v_order public.srk_razorpay_payment_orders%rowtype;
 v_bill public.srk_booking_final_bills%rowtype;
 v_refund public.srk_razorpay_refunds%rowtype;
 v_payout public.srk_electrician_payouts%rowtype;
 v_amount numeric(12,2);
 v_has_legacy_payout boolean := false;
begin
 if auth.uid() is null or not public.is_srk_admin() then
  raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
 end if;
 select * into v_request from public.srk_booking_refund_requests
 where id=p_request_id for update;
 if not found then raise exception 'REFUND_REQUEST_NOT_FOUND'; end if;
 if v_request.status not in ('approved','processing','unknown') then
  raise exception 'REFUND_REQUEST_MUST_BE_APPROVED_FIRST' using errcode='55000';
 end if;
 select * into v_booking from public.service_bookings where id=v_request.booking_id;
 if not found or v_booking.razorpay_order_id is null then
  raise exception 'VERIFIED_RAZORPAY_PAYMENT_ORDER_REQUIRED' using errcode='55000';
 end if;
 select * into v_order from public.srk_razorpay_payment_orders
 where booking_id=v_booking.id and razorpay_order_id=v_booking.razorpay_order_id for update;
 if not found or v_order.status<>'paid' or v_order.currency<>'INR' then
  raise exception 'PAID_RAZORPAY_ORDER_SNAPSHOT_REQUIRED' using errcode='55000';
 end if;
 select * into v_booking from public.service_bookings where id=v_request.booking_id for update;
 if not found or v_booking.razorpay_order_id is distinct from v_order.razorpay_order_id then
  raise exception 'BOOKING_PAYMENT_ORDER_CHANGED';
 end if;
 if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null
  or v_booking.razorpay_payment_id is null
  or v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$'
  or coalesce(v_booking.amount_paid,0)<=0 then
  raise exception 'VERIFIED_RAZORPAY_PAYMENT_REQUIRED' using errcode='55000';
 end if;
 select * into v_bill from public.srk_booking_final_bills
 where id=v_order.final_bill_id and booking_id=v_booking.id for update;
 if not found or v_order.final_bill_revision is null
  or v_bill.revision_no is distinct from v_order.final_bill_revision
  or v_bill.status not in ('issued','approved') or v_bill.total_amount is null
  or round(v_bill.total_amount*100)::bigint<>v_order.amount_paise
  or round(v_booking.amount_paid*100)::bigint<>v_order.amount_paise then
  raise exception 'PAID_AMOUNT_DOES_NOT_MATCH_FINAL_BILL_SNAPSHOT' using errcode='55000';
 end if;
 v_amount:=round(v_booking.amount_paid,2);
 if round(v_request.amount,2)<>v_amount then
  raise exception 'REFUND_AMOUNT_MUST_EQUAL_FULL_PAID_BOOKING_AMOUNT' using errcode='55000';
 end if;
 if exists(
  select 1 from public.srk_worker_payout_earning_allocations a
  join public.srk_worker_payout_requests p on p.id=a.payout_request_id
  where a.booking_id=v_booking.id and p.status='paid'
 ) or exists(
  select 1 from public.srk_worker_earnings e
  join public.srk_worker_payout_requests p on p.worker_id=e.worker_id and p.status='paid'
  where e.booking_id=v_booking.id and not exists(
   select 1 from public.srk_worker_payout_earning_allocations a
   where a.payout_request_id=p.id
  )
 ) then raise exception 'BOOKING_WORKER_PAYOUT_ALREADY_PAID_RECONCILIATION_REQUIRED';
 end if;
 select * into v_refund from public.srk_razorpay_refunds rr
 where rr.booking_id=v_booking.id for update;
 if found then
  if v_refund.status='failed' then raise exception 'PREVIOUS_REFUND_FAILED_RECONCILE_FIRST'; end if;
  if v_refund.payment_id is distinct from v_booking.razorpay_payment_id
   or v_refund.amount_paise<>round(v_amount*100)::bigint then
   raise exception 'EXISTING_REFUND_DOES_NOT_MATCH_PAID_FINAL_BILL';
  end if;
  update public.srk_booking_refund_requests
  set status=case when v_refund.status='processed' then 'processed' else 'processing' end,
   refund_record_id=v_refund.id,updated_at=clock_timestamp(),
   processed_at=case when v_refund.status='processed' then coalesce(v_refund.processed_at,clock_timestamp()) else null end
  where id=v_request.id;
  return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,
   v_refund.amount_paise,v_refund.idempotency_key,v_refund.status;
  return;
 end if;
 select * into v_payout from public.srk_electrician_payouts
 where booking_id=v_booking.id for update;
 if found then
  v_has_legacy_payout:=true;
  if v_payout.payout_status='paid' then raise exception 'LEGACY_WORKER_PAYOUT_ALREADY_PAID_RECONCILIATION_REQUIRED'; end if;
  if v_payout.payout_status not in ('pending','blocked') then raise exception 'LEGACY_WORKER_PAYOUT_STATE_REQUIRES_RECONCILIATION'; end if;
  update public.srk_electrician_payouts
  set payout_status='blocked',payout_note='Customer refund in progress',updated_at=clock_timestamp()
  where id=v_payout.id;
 end if;
 insert into public.srk_razorpay_refunds
  (booking_id,payment_id,amount,amount_paise,idempotency_key,status,reason,admin_user_id,previous_payout_note)
 values
  (v_booking.id,v_booking.razorpay_payment_id,v_amount,round(v_amount*100)::bigint,
   replace(gen_random_uuid()::text,'-',''),'requested',
   left('Customer refund request: '||v_request.reason,250),auth.uid(),
   case when v_has_legacy_payout then v_payout.payout_note else null end)
 returning * into v_refund;
 update public.srk_booking_refund_requests
 set status='processing',refund_record_id=v_refund.id,decided_by=auth.uid(),updated_at=clock_timestamp()
 where id=v_request.id;
 return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,
  v_refund.amount_paise,v_refund.idempotency_key,v_refund.status;
end
$function$;
