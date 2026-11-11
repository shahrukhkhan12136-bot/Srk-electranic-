-- Extend Admin Razorpay refund preparation to immutable timer payable snapshots.
-- Apply only after the 20261111160000..160014 timer release migrations.
begin;
create table if not exists public.srk_timer_cash_refund_entries (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
 cash_receipt_id uuid not null unique references public.srk_cash_receipts(id) on delete restrict,
 amount numeric(12,2) not null check(amount>0 and amount<=10000000),
 refund_reference text not null check(length(btrim(refund_reference)) between 4 and 120),
 note text check(note is null or length(note)<=250),
 recorded_by uuid not null references auth.users(id) on delete restrict,
 recorded_at timestamptz not null default clock_timestamp()
);
alter table public.srk_timer_cash_refund_entries enable row level security;
revoke all on public.srk_timer_cash_refund_entries from public,anon,authenticated;
grant select,insert,update,delete on public.srk_timer_cash_refund_entries to service_role;

drop function public.srk_admin_list_booking_refund_requests(integer);
create function public.srk_admin_list_booking_refund_requests(p_limit integer default 200)
returns table(
 id uuid,booking_id uuid,customer_user_id uuid,customer_name text,customer_phone text,
 amount numeric,reason text,status text,admin_note text,created_at timestamptz,updated_at timestamptz,
 payment_status text,payment_method text,razorpay_payment_id text,has_manual_payment boolean,
 refund_record_id uuid,refund_id text,provider_status text,is_timer_booking boolean
)
language plpgsql stable security definer set search_path='' as $function$
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 return query
 select r.id,r.booking_id,r.customer_user_id,b.customer_name,b.phone,r.amount,r.reason,r.status,
  r.admin_note,r.created_at,r.updated_at,b.payment_status,b.payment_method,b.razorpay_payment_id,
  (exists(select 1 from public.srk_manual_payment_entries m where m.booking_id=b.id)
   or exists(select 1 from public.srk_cash_receipts cr where cr.booking_id=b.id)),
  r.refund_record_id,rr.refund_id,rr.provider_status,(b.service_category_code is not null)
 from public.srk_booking_refund_requests r
 join public.service_bookings b on b.id=r.booking_id
 left join public.srk_razorpay_refunds rr on rr.id=r.refund_record_id
 order by r.created_at desc limit greatest(1,least(coalesce(p_limit,200),300));
end $function$;
revoke all on function public.srk_admin_list_booking_refund_requests(integer) from public,anon;
grant execute on function public.srk_admin_list_booking_refund_requests(integer) to authenticated;

create or replace function public.srk_admin_finalize_timer_cash_refund(
 p_request_id uuid,p_reference text,p_note text default null
)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare
 v_request public.srk_booking_refund_requests%rowtype;
 v_booking public.service_bookings%rowtype;
 v_receipt public.srk_cash_receipts%rowtype;
 v_payout public.srk_electrician_payouts%rowtype;
 v_reference text:=btrim(coalesce(p_reference,''));
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 if p_request_id is null or length(v_reference) not between 4 and 120 or (p_note is not null and length(p_note)>250) then raise exception 'VALID_REFUND_REQUEST_AND_UTR_REQUIRED' using errcode='22023'; end if;
 select * into v_request from public.srk_booking_refund_requests where id=p_request_id for update;
 if not found then raise exception 'REFUND_REQUEST_NOT_FOUND'; end if;
 if v_request.status<>'approved' then raise exception 'REFUND_REQUEST_MUST_BE_APPROVED_FIRST'; end if;
 select * into v_booking from public.service_bookings where id=v_request.booking_id for update;
 if not found or v_booking.service_category_code is null then raise exception 'TIMER_BOOKING_REQUIRED'; end if;
 if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null or v_booking.razorpay_payment_id is not null then raise exception 'VERIFIED_TIMER_CASH_PAYMENT_REQUIRED'; end if;
 select * into v_receipt from public.srk_cash_receipts where booking_id=v_booking.id for update;
 if not found then raise exception 'CONFIRMED_CASH_RECEIPT_REQUIRED'; end if;
 if v_receipt.currency<>'INR' or round(v_receipt.amount_paise::numeric/100,2)<>v_request.amount or round(coalesce(v_booking.amount_paid,0),2)<>v_request.amount then raise exception 'CASH_RECEIPT_AMOUNT_MISMATCH'; end if;
 if exists(select 1 from public.srk_timer_cash_refund_entries where booking_id=v_booking.id) then raise exception 'TIMER_CASH_REFUND_ALREADY_RECORDED'; end if;
 select ep.* into v_payout from public.srk_electrician_payouts ep where ep.booking_id=v_booking.id for update;
 if found then
   if v_payout.payout_status='paid' or v_payout.commission_collection_status='received' then raise exception 'CASH_COMMISSION_ALREADY_SETTLED_RECOVERY_REQUIRED'; end if;
 end if;
 insert into public.srk_timer_cash_refund_entries(booking_id,cash_receipt_id,amount,refund_reference,note,recorded_by)
 values(v_booking.id,v_receipt.id,v_request.amount,v_reference,nullif(btrim(coalesce(p_note,'')),''),auth.uid());
 update public.service_bookings set payment_status='refunded' where id=v_booking.id and payment_status='paid';
 update public.srk_booking_refund_requests set status='processed',admin_note=coalesce(nullif(btrim(coalesce(p_note,'')),''),admin_note),decided_by=auth.uid(),processed_at=clock_timestamp(),updated_at=clock_timestamp() where id=p_request_id;
 return jsonb_build_object('success',true,'booking_id',v_booking.id,'amount',v_request.amount,'refund_reference',v_reference,'status','processed');
end $function$;
revoke all on function public.srk_admin_finalize_timer_cash_refund(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_finalize_timer_cash_refund(uuid,text,text) to authenticated;

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
   select ps.* into v_snapshot from public.srk_booking_payable_snapshots ps
   where ps.booking_id=v_booking.id order by ps.created_at desc limit 1 for update;
   if not found then raise exception 'IMMUTABLE_TIMER_PAYABLE_SNAPSHOT_REQUIRED' using errcode='55000'; end if;
   v_paise:=v_snapshot.amount_paise;
   if v_snapshot.currency<>'INR' or v_snapshot.total_amount<>v_amount
      or v_paise<>round(v_amount*100)::bigint then
     raise exception 'TIMER_REFUND_AMOUNT_DOES_NOT_MATCH_PAYABLE_SNAPSHOT' using errcode='55000';
   end if;
   select rp.* into v_payment from public.srk_razorpay_payments rp
   where rp.booking_id=v_booking.id and rp.snapshot_id=v_snapshot.id
     and rp.provider_payment_id=v_booking.razorpay_payment_id
     and rp.amount_paise=v_paise and rp.currency='INR'
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
 select rr.* into v_refund from public.srk_razorpay_refunds rr where rr.booking_id=v_booking.id for update;
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
