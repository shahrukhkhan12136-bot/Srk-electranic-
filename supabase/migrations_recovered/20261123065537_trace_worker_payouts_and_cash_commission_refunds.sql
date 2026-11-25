
-- Per-earning payout traceability and per-earning cash commission refund credits.
create table if not exists public.srk_worker_payout_earning_allocations (
  id uuid primary key default gen_random_uuid(),
  payout_request_id uuid not null references public.srk_worker_payout_requests(id) on delete restrict,
  earning_id uuid not null references public.srk_worker_earnings(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  allocated_amount numeric(14,2) not null check (allocated_amount > 0 and allocated_amount = round(allocated_amount,2)),
  created_at timestamptz not null default clock_timestamp(),
  unique(payout_request_id, earning_id)
);
create index if not exists srk_payout_alloc_booking_idx on public.srk_worker_payout_earning_allocations(booking_id, payout_request_id);
create index if not exists srk_payout_alloc_worker_idx on public.srk_worker_payout_earning_allocations(worker_id, created_at);

create table if not exists public.srk_worker_cash_commission_refund_allocations (
  id uuid primary key default gen_random_uuid(),
  refund_request_id uuid not null references public.srk_booking_refund_requests(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  earning_id uuid not null references public.srk_worker_earnings(id) on delete restrict,
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  amount numeric(14,2) not null check (amount >= 0 and amount = round(amount,2)),
  note text not null check (length(btrim(note)) between 10 and 2000),
  recorded_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(refund_request_id, earning_id)
);
create index if not exists srk_cash_comm_refund_booking_idx on public.srk_worker_cash_commission_refund_allocations(booking_id, earning_id);

alter table public.srk_worker_wallet_ledger drop constraint if exists srk_worker_wallet_ledger_entry_type_check;
alter table public.srk_worker_wallet_ledger add constraint srk_worker_wallet_ledger_entry_type_check
 check (entry_type = any (array['earning','commission','cash_commission_due','cash_commission_collected','cash_commission_refund_credit','payout_requested','payout_paid','refund_adjustment','admin_adjustment','hold','release']));

alter table public.srk_worker_payout_earning_allocations enable row level security;
alter table public.srk_worker_cash_commission_refund_allocations enable row level security;

drop policy if exists srk_worker_payout_alloc_worker_read on public.srk_worker_payout_earning_allocations;
create policy srk_worker_payout_alloc_worker_read on public.srk_worker_payout_earning_allocations
for select to authenticated using (
 worker_id in (select wp.id from public.srk_worker_profiles wp where wp.user_id=(select auth.uid()))
 or public.srk_has_admin_permission('payouts.manage')
);
drop policy if exists srk_cash_comm_refund_worker_read on public.srk_worker_cash_commission_refund_allocations;
create policy srk_cash_comm_refund_worker_read on public.srk_worker_cash_commission_refund_allocations
for select to authenticated using (
 worker_id in (select wp.id from public.srk_worker_profiles wp where wp.user_id=(select auth.uid()))
 or public.srk_has_admin_permission('refunds.manage')
);
revoke all on public.srk_worker_payout_earning_allocations from public, anon, authenticated;
revoke all on public.srk_worker_cash_commission_refund_allocations from public, anon, authenticated;
grant select on public.srk_worker_payout_earning_allocations to authenticated;
grant select on public.srk_worker_cash_commission_refund_allocations to authenticated;

create or replace function public.srk_admin_mark_worker_payout_paid(
 p_payout_id uuid, p_payment_method text, p_payment_reference text, p_note text default null
) returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path to 'pg_catalog','public','auth'
as $$
declare
 v_payout public.srk_worker_payout_requests%rowtype;
 v_available numeric(14,2);
 v_reserved numeric(14,2);
 v_left numeric(14,2);
 v_earning record;
 v_alloc numeric(14,2);
 v_total_allocated numeric(14,2):=0;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('payouts.manage') then
  raise exception 'Payout management permission required' using errcode='42501';
 end if;
 if nullif(btrim(p_payment_reference),'') is null then raise exception 'UTR/transaction reference required'; end if;
 if p_payment_method not in ('upi','bank_transfer','phonepe','other') then raise exception 'Invalid payout method'; end if;

 select * into v_payout from public.srk_worker_payout_requests where id=p_payout_id for update;
 if not found or v_payout.status<>'approved' then raise exception 'Only approved payout can be marked paid'; end if;
 perform 1 from public.srk_worker_profiles where id=v_payout.worker_id for update;
 if exists(select 1 from public.srk_worker_earnings where worker_id=v_payout.worker_id and settlement_status='held') then
  raise exception 'Worker payout is held due to refund/dispute review';
 end if;

 select coalesce(sum(balance_effect),0) into v_available
 from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
 select coalesce(sum(coalesce(approved_amount,requested_amount)),0) into v_reserved
 from public.srk_worker_payout_requests
 where worker_id=v_payout.worker_id and id<>p_payout_id and status in ('requested','under_review','approved');
 if v_payout.approved_amount>v_available-v_reserved then
  raise exception 'Wallet balance changed; payout cannot be paid';
 end if;

 -- Allocate payout to actual positive earning balances (oldest first).
 -- Any untraceable admin credit is deliberately not eligible for payout.
 v_left:=v_payout.approved_amount;
 for v_earning in
  select e.id,e.booking_id,e.worker_id,
    (coalesce((select sum(l.balance_effect) from public.srk_worker_wallet_ledger l where l.earning_id=e.id),0)
     - coalesce((select sum(a.allocated_amount) from public.srk_worker_payout_earning_allocations a where a.earning_id=e.id),0)) as remaining
  from public.srk_worker_earnings e
  where e.worker_id=v_payout.worker_id
  order by e.created_at,e.id
  for update
 loop
  exit when v_left<=0;
  if v_earning.remaining>0 then
   v_alloc:=least(v_left,v_earning.remaining);
   insert into public.srk_worker_payout_earning_allocations
    (payout_request_id,earning_id,booking_id,worker_id,allocated_amount)
   values(p_payout_id,v_earning.id,v_earning.booking_id,v_earning.worker_id,v_alloc);
   v_left:=v_left-v_alloc;
   v_total_allocated:=v_total_allocated+v_alloc;
  end if;
 end loop;
 if v_left>0 then
  raise exception 'Payout exceeds traceable unallocated earning balance; reconcile wallet before paying';
 end if;

 insert into public.srk_worker_wallet_ledger(worker_id,entry_type,amount,balance_effect,description,reference_id,idempotency_key)
 values(v_payout.worker_id,'payout_paid',v_payout.approved_amount,-v_payout.approved_amount,
  'Admin verified payout with earning-level allocation',p_payment_reference,'payout-paid:'||v_payout.id::text)
 on conflict(idempotency_key) do nothing;

 update public.srk_worker_payout_requests
 set status='paid',payment_method=p_payment_method,payment_reference=p_payment_reference,
  admin_note=coalesce(p_note,admin_note),paid_at=clock_timestamp()
 where id=p_payout_id returning * into v_payout;
 return v_payout;
end
$$;

create or replace function public.srk_admin_record_cash_commission_refund_allocation(
 p_refund_request_id uuid, p_earning_id uuid, p_amount numeric, p_note text
) returns public.srk_worker_cash_commission_refund_allocations
language plpgsql security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $$
declare
 v_refund public.srk_booking_refund_requests%rowtype;
 v_earning public.srk_worker_earnings%rowtype;
 v_company_refund numeric(14,2);
 v_worker_refund numeric(14,2);
 v_prior numeric(14,2);
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
 select * into v_earning from public.srk_worker_earnings
 where id=p_earning_id and booking_id=v_refund.booking_id for update;
 if not found then raise exception 'Earning does not belong to refund booking'; end if;
 if v_earning.payment_method<>'cash' then raise exception 'Cash commission refund allocation is only for cash earnings'; end if;
 if not exists(select 1 from public.srk_worker_wallet_ledger
   where earning_id=v_earning.id and entry_type='cash_commission_due') then
  raise exception 'Cash commission due ledger entry not found for earning';
 end if;
 select coalesce(sum(commission_refund_amount),0) into v_company_refund
 from public.srk_company_commission_refund_reconciliations where refund_request_id=p_refund_request_id;
 if p_amount>v_company_refund then
  raise exception 'Worker cash commission refund allocation cannot exceed company commission refunded for this refund';
 end if;
 select coalesce(sum(worker_refund_amount),0) into v_worker_refund
 from public.srk_worker_refund_allocations where refund_request_id=p_refund_request_id;
 if v_worker_refund+v_company_refund>v_refund.amount then
  raise exception 'Worker and company allocations exceed customer refund amount';
 end if;
 select coalesce(sum(amount),0) into v_prior
 from public.srk_worker_cash_commission_refund_allocations where earning_id=p_earning_id;
 if v_prior+p_amount>v_earning.company_commission then
  raise exception 'Cumulative cash commission refund exceeds this earning commission';
 end if;
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

create or replace function public.srk_worker_get_my_wallet_summary()
returns jsonb language plpgsql stable security definer
set search_path to 'pg_catalog','public','auth'
as $$
declare
 v_worker uuid; v_ledger numeric(14,2); v_reserved numeric(14,2);
 v_net numeric(14,2); v_held integer; v_cash_due numeric(14,2);
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select id into v_worker from public.srk_worker_profiles where user_id=auth.uid() limit 1;
 if v_worker is null then raise exception 'Approved worker profile not found' using errcode='P0002'; end if;
 select coalesce(sum(balance_effect),0)::numeric(14,2) into v_ledger
 from public.srk_worker_wallet_ledger where worker_id=v_worker;
 select coalesce(sum(coalesce(approved_amount,requested_amount)),0)::numeric(14,2) into v_reserved
 from public.srk_worker_payout_requests where worker_id=v_worker and status in ('requested','under_review','approved');
 select count(*)::integer into v_held from public.srk_worker_earnings
 where worker_id=v_worker and settlement_status='held';
 select greatest(0,-coalesce(sum(balance_effect),0))::numeric(14,2) into v_cash_due
 from public.srk_worker_wallet_ledger where worker_id=v_worker
 and entry_type in ('cash_commission_due','cash_commission_collected','cash_commission_refund_credit');
 v_net:=v_ledger-v_reserved;
 return jsonb_build_object('worker_id',v_worker,'currency','INR','ledger_balance',v_ledger,
  'reserved_payout_amount',v_reserved,'available_for_payout',greatest(0,v_net),
  'recovery_debt',greatest(0,-v_net),'net_balance_after_reservations',v_net,
  'cash_commission_outstanding',v_cash_due,'held_earning_count',v_held,'payout_blocked',v_held>0);
end
$$;

-- A refund is blocked only by a paid payout allocated to this booking.
-- Historical paid payouts with no allocation record remain conservatively blocked.
create or replace function public.srk_admin_prepare_booking_refund(p_request_id uuid)
returns table(refund_record_id uuid, booking_id uuid, payment_id text, amount_paise bigint, idempotency_key text, status text)
language plpgsql security definer set search_path to ''
as $$
declare
 v_request public.srk_booking_refund_requests%rowtype;
 v_booking public.service_bookings%rowtype;
 v_refund public.srk_razorpay_refunds%rowtype;
 v_payout public.srk_electrician_payouts%rowtype;
 v_amount numeric(12,2);
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501'; end if;
 select * into v_request from public.srk_booking_refund_requests where id=p_request_id for update;
 if not found then raise exception 'REFUND_REQUEST_NOT_FOUND'; end if;
 if v_request.status not in ('approved','processing','unknown') then raise exception 'REFUND_REQUEST_MUST_BE_APPROVED_FIRST' using errcode='55000'; end if;
 select * into v_booking from public.service_bookings where id=v_request.booking_id for update;
 if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
 if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null
  or v_booking.razorpay_payment_id is null or v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$'
  or coalesce(v_booking.amount_paid,0)<=0 then
  raise exception 'VERIFIED_RAZORPAY_PAYMENT_REQUIRED' using errcode='55000';
 end if;
 v_amount:=round(v_booking.amount_paid,2);
 if v_amount<>v_request.amount then raise exception 'REFUND_AMOUNT_CHANGED_SINCE_REQUEST' using errcode='55000'; end if;

 if exists(select 1 from public.srk_worker_payout_earning_allocations a
   join public.srk_worker_payout_requests p on p.id=a.payout_request_id
   where a.booking_id=v_booking.id and p.status='paid')
 or exists(select 1 from public.srk_worker_earnings e
   join public.srk_worker_payout_requests p on p.worker_id=e.worker_id and p.status='paid'
   where e.booking_id=v_booking.id
   and not exists(select 1 from public.srk_worker_payout_earning_allocations a where a.payout_request_id=p.id)) then
  raise exception 'BOOKING_WORKER_PAYOUT_ALREADY_PAID_RECONCILIATION_REQUIRED' using errcode='55000';
 end if;
 if v_booking.quote_status<>'approved' then raise exception 'TIMER_OR_NON_QUOTE_REFUND_REQUIRES_SEPARATE_PAYMENT_RECONCILIATION' using errcode='55000'; end if;
 if v_booking.quoted_amount is null or v_booking.service_charge is null or v_booking.materials_amount is null
  or v_amount<>round(v_booking.quoted_amount,2)
  or v_amount<>round(v_booking.service_charge+v_booking.materials_amount,2) then
  raise exception 'PAID_AMOUNT_DOES_NOT_MATCH_APPROVED_QUOTE' using errcode='55000';
 end if;
 select * into v_refund from public.srk_razorpay_refunds rr where rr.booking_id=v_booking.id for update;
 if found then
  if v_refund.status='failed' then raise exception 'PREVIOUS_REFUND_FAILED_RECONCILE_FIRST'; end if;
  update public.srk_booking_refund_requests set status=case when v_refund.status='processed' then 'processed' else 'processing' end,
   refund_record_id=v_refund.id,updated_at=clock_timestamp(),
   processed_at=case when v_refund.status='processed' then coalesce(v_refund.processed_at,clock_timestamp()) else null end
  where id=v_request.id;
  return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status;
  return;
 end if;
 select * into v_payout from public.srk_electrician_payouts ep where ep.booking_id=v_booking.id for update;
 if found then
  if v_payout.payout_status='paid' then raise exception 'ELECTRICIAN_PAYOUT_ALREADY_PAID_RECONCILIATION_REQUIRED'; end if;
  if v_payout.payout_status not in ('pending','blocked') then raise exception 'ELECTRICIAN_PAYOUT_STATE_REQUIRES_RECONCILIATION'; end if;
  update public.srk_electrician_payouts set payout_status='blocked',payout_note='Customer refund in progress',updated_at=clock_timestamp() where id=v_payout.id;
 end if;
 insert into public.srk_razorpay_refunds(booking_id,payment_id,amount,amount_paise,idempotency_key,status,reason,admin_user_id,previous_payout_note)
 values(v_booking.id,v_booking.razorpay_payment_id,v_amount,round(v_amount*100)::bigint,
  replace(gen_random_uuid()::text,'-',''),'requested',left('Customer refund request: '||v_request.reason,250),auth.uid(),
  case when found then v_payout.payout_note else null end)
 returning * into v_refund;
 update public.srk_booking_refund_requests set status='processing',refund_record_id=v_refund.id,decided_by=auth.uid(),updated_at=clock_timestamp()
 where id=v_request.id;
 return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status;
end
$$;

revoke all on function public.srk_admin_record_cash_commission_refund_allocation(uuid,uuid,numeric,text) from public,anon;
grant execute on function public.srk_admin_record_cash_commission_refund_allocation(uuid,uuid,numeric,text) to authenticated;
revoke all on function public.srk_admin_mark_worker_payout_paid(uuid,text,text,text) from public,anon;
grant execute on function public.srk_admin_mark_worker_payout_paid(uuid,text,text,text) to authenticated;
revoke all on function public.srk_worker_get_my_wallet_summary() from public,anon;
grant execute on function public.srk_worker_get_my_wallet_summary() to authenticated;
revoke all on function public.srk_admin_prepare_booking_refund(uuid) from public,anon;
grant execute on function public.srk_admin_prepare_booking_refund(uuid) to authenticated;
