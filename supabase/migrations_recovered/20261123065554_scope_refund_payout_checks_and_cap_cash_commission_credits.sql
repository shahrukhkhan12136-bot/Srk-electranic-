
create or replace function public.srk_admin_record_manual_refund(p_booking_id uuid,p_reference text,p_note text default null)
returns jsonb language plpgsql security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $$
declare
 v_booking public.service_bookings%rowtype;
 v_payment public.srk_manual_payment_entries%rowtype;
 v_refund_request public.srk_booking_refund_requests%rowtype;
 v_reference text;
 v_paid_payout boolean;
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'Admin access required' using errcode='42501'; end if;
 if p_booking_id is null then raise exception 'Booking ID is required'; end if;
 v_reference:=trim(coalesce(p_reference,''));
 if length(v_reference)<4 or length(v_reference)>120 then raise exception 'A valid refund UTR / provider reference is required'; end if;
 if p_note is not null and length(p_note)>250 then raise exception 'Refund note is too long'; end if;
 select * into v_refund_request from public.srk_booking_refund_requests
 where booking_id=p_booking_id and status='approved' for update;
 if not found then raise exception 'APPROVED_REFUND_REQUEST_REQUIRED'; end if;
 select * into v_booking from public.service_bookings where id=p_booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null then raise exception 'Only verified paid bookings can be refunded'; end if;
 if v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null then
  raise exception 'Razorpay-linked refunds must be completed and reconciled through Razorpay';
 end if;
 select * into v_payment from public.srk_manual_payment_entries where booking_id=p_booking_id for update;
 if not found then raise exception 'Manual payment audit record not found'; end if;
 if round(coalesce(v_booking.amount_paid,0),2)<>v_payment.amount then raise exception 'Recorded payment amount does not match booking amount'; end if;
 if exists(select 1 from public.srk_manual_refund_entries where booking_id=p_booking_id) then raise exception 'A refund has already been recorded for this booking'; end if;

 select exists(select 1 from public.srk_electrician_payouts p where p.booking_id=p_booking_id and p.payout_status='paid')
 or exists(
  select 1 from public.srk_worker_payout_earning_allocations a
  join public.srk_worker_payout_requests p on p.id=a.payout_request_id
  where a.booking_id=p_booking_id and p.status='paid'
 )
 or exists(
  select 1 from public.srk_worker_earnings e
  join public.srk_worker_payout_requests p on p.worker_id=e.worker_id and p.status='paid'
  where e.booking_id=p_booking_id
   and not exists(select 1 from public.srk_worker_payout_earning_allocations a where a.payout_request_id=p.id)
 ) into v_paid_payout;
 if v_paid_payout then raise exception 'Booking worker payout already paid; booking-specific recovery and reconciliation required'; end if;

 insert into public.srk_manual_refund_entries(booking_id,payment_entry_id,amount,refund_reference,note,recorded_by)
 values(p_booking_id,v_payment.id,v_payment.amount,v_reference,nullif(trim(coalesce(p_note,'')),''),auth.uid());
 update public.service_bookings set payment_status='refunded' where id=p_booking_id;
 return jsonb_build_object('success',true,'booking_id',p_booking_id,'amount',v_payment.amount,
  'refund_reference',v_reference,'refund_request_id',v_refund_request.id);
end
$$;

create or replace function public.srk_admin_record_cash_commission_refund_allocation(
 p_refund_request_id uuid,p_earning_id uuid,p_amount numeric,p_note text
) returns public.srk_worker_cash_commission_refund_allocations
language plpgsql security definer set search_path to 'pg_catalog','public','auth','pg_temp'
as $$
declare
 v_refund public.srk_booking_refund_requests%rowtype;
 v_earning public.srk_worker_earnings%rowtype;
 v_company_refund numeric(14,2);
 v_worker_refund numeric(14,2);
 v_prior_earning numeric(14,2);
 v_prior_refund numeric(14,2);
 v_result public.srk_worker_cash_commission_refund_allocations%rowtype;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('refunds.manage') then
  raise exception 'Refund management permission required' using errcode='42501';
 end if;
 if p_refund_request_id is null or p_earning_id is null or p_amount is null
  or p_amount<0 or p_amount<>round(p_amount,2)
  or p_note is null or length(btrim(p_note)) not between 10 and 2000 then
  raise exception 'Valid refund allocation amount and 10-2000 character note required' using errcode='22023';
 end if;
 select * into v_refund from public.srk_booking_refund_requests
 where id=p_refund_request_id and status='processed' for update;
 if not found then raise exception 'Refund must be processed first'; end if;
 perform 1 from public.service_bookings where id=v_refund.booking_id for update;
 select * into v_earning from public.srk_worker_earnings
 where id=p_earning_id and booking_id=v_refund.booking_id for update;
 if not found then raise exception 'Earning does not belong to refund booking'; end if;
 if v_earning.payment_method<>'cash' then raise exception 'Cash commission refund allocation is only for cash earnings'; end if;
 if not exists(select 1 from public.srk_worker_wallet_ledger where earning_id=v_earning.id and entry_type='cash_commission_due') then
  raise exception 'Cash commission due ledger entry not found for earning';
 end if;
 select coalesce(sum(commission_refund_amount),0) into v_company_refund
 from public.srk_company_commission_refund_reconciliations where refund_request_id=p_refund_request_id;
 if p_amount>v_company_refund then raise exception 'Worker cash commission refund allocation cannot exceed company commission refunded for this refund'; end if;
 select coalesce(sum(worker_refund_amount),0) into v_worker_refund
 from public.srk_worker_refund_allocations where refund_request_id=p_refund_request_id;
 if v_worker_refund+v_company_refund>v_refund.amount then raise exception 'Worker and company allocations exceed customer refund amount'; end if;
 select coalesce(sum(amount),0) into v_prior_earning
 from public.srk_worker_cash_commission_refund_allocations where earning_id=p_earning_id;
 if v_prior_earning+p_amount>v_earning.company_commission then raise exception 'Cumulative cash commission refund exceeds this earning commission'; end if;
 select coalesce(sum(amount),0) into v_prior_refund
 from public.srk_worker_cash_commission_refund_allocations where refund_request_id=p_refund_request_id;
 if v_prior_refund+p_amount>v_company_refund then raise exception 'Cumulative worker cash commission credits exceed company commission refund'; end if;
 insert into public.srk_worker_cash_commission_refund_allocations
 (refund_request_id,booking_id,earning_id,worker_id,amount,note,recorded_by)
 values(p_refund_request_id,v_earning.booking_id,v_earning.id,v_earning.worker_id,p_amount,btrim(p_note),auth.uid())
 returning * into v_result;
 if p_amount>0 then
  insert into public.srk_worker_wallet_ledger
  (worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
  values(v_earning.worker_id,v_earning.booking_id,v_earning.id,'cash_commission_refund_credit',
   p_amount,p_amount,'Approved cash commission refund credit: '||btrim(p_note),
   'cash-commission-refund:'||p_refund_request_id::text||':'||p_earning_id::text);
 end if;
 return v_result;
end
$$;

revoke all on function public.srk_admin_record_manual_refund(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_record_manual_refund(uuid,text,text) to authenticated;
revoke all on function public.srk_admin_record_cash_commission_refund_allocation(uuid,uuid,numeric,text) from public,anon;
grant execute on function public.srk_admin_record_cash_commission_refund_allocation(uuid,uuid,numeric,text) to authenticated;
