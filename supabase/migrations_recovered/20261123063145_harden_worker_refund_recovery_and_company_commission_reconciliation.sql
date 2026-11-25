
create table if not exists public.srk_company_commission_refund_reconciliations (
  id uuid primary key default gen_random_uuid(),
  refund_request_id uuid not null unique references public.srk_booking_refund_requests(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  commission_refund_amount numeric(12,2) not null check (commission_refund_amount >= 0),
  admin_note text not null check (length(btrim(admin_note)) between 10 and 2000),
  recorded_by uuid not null,
  recorded_at timestamptz not null default clock_timestamp()
);

alter table public.srk_company_commission_refund_reconciliations enable row level security;
drop policy if exists srk_company_commission_refund_admin_read on public.srk_company_commission_refund_reconciliations;
create policy srk_company_commission_refund_admin_read
on public.srk_company_commission_refund_reconciliations
for select to authenticated
using (public.srk_has_admin_permission('refunds.manage'));

revoke insert,update,delete,truncate,references,trigger
on public.srk_company_commission_refund_reconciliations from public,anon,authenticated;
grant select on public.srk_company_commission_refund_reconciliations to authenticated;

create or replace function public.srk_admin_record_company_commission_refund(
  p_refund_request_id uuid,
  p_commission_refund_amount numeric,
  p_note text
)
returns public.srk_company_commission_refund_reconciliations
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_refund public.srk_booking_refund_requests%rowtype;
  v_total_commission numeric(12,2);
  v_worker_allocations numeric(12,2);
  v_existing public.srk_company_commission_refund_reconciliations%rowtype;
  v_result public.srk_company_commission_refund_reconciliations%rowtype;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('refunds.manage') then
    raise exception 'Refund management permission required' using errcode='42501';
  end if;
  if p_refund_request_id is null or p_commission_refund_amount is null
     or p_commission_refund_amount < 0
     or p_note is null or length(btrim(p_note)) not between 10 and 2000 then
    raise exception 'Valid refund, non-negative commission amount and 10-2000 character note required'
      using errcode='22023';
  end if;

  select * into v_refund
  from public.srk_booking_refund_requests
  where id=p_refund_request_id and status='processed'
  for update;
  if not found then
    raise exception 'Refund must be processed before company commission reconciliation' using errcode='55000';
  end if;

  select coalesce(sum(company_commission),0)
    into v_total_commission
  from public.srk_worker_earnings
  where booking_id=v_refund.booking_id;

  if p_commission_refund_amount > v_total_commission then
    raise exception 'Commission refund cannot exceed commission recorded for this booking';
  end if;

  select coalesce(sum(worker_refund_amount),0)
    into v_worker_allocations
  from public.srk_worker_refund_allocations
  where refund_request_id=p_refund_request_id;

  if v_worker_allocations + p_commission_refund_amount > v_refund.amount then
    raise exception 'Worker allocations plus company commission refund cannot exceed customer refund amount';
  end if;

  select * into v_existing
  from public.srk_company_commission_refund_reconciliations
  where refund_request_id=p_refund_request_id
  for update;

  if found then
    update public.srk_company_commission_refund_reconciliations
    set commission_refund_amount=p_commission_refund_amount,
        admin_note=btrim(p_note),recorded_by=auth.uid(),recorded_at=clock_timestamp()
    where id=v_existing.id returning * into v_result;
  else
    insert into public.srk_company_commission_refund_reconciliations
      (refund_request_id,booking_id,commission_refund_amount,admin_note,recorded_by)
    values
      (p_refund_request_id,v_refund.booking_id,p_commission_refund_amount,btrim(p_note),auth.uid())
    returning * into v_result;
  end if;
  return v_result;
end
$function$;

revoke all on function public.srk_admin_record_company_commission_refund(uuid,numeric,text) from public,anon;
grant execute on function public.srk_admin_record_company_commission_refund(uuid,numeric,text) to authenticated;

create or replace function public.srk_admin_resolve_worker_refund_allocation(
  p_refund_request_id uuid,
  p_earning_id uuid,
  p_worker_refund_amount numeric,
  p_note text
)
returns public.srk_worker_refund_allocations
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_refund public.srk_booking_refund_requests%rowtype;
  v_earning public.srk_worker_earnings%rowtype;
  v_worker_id uuid;
  v_alloc public.srk_worker_refund_allocations%rowtype;
  v_refund_allocated numeric(12,2);
  v_earning_allocated numeric(12,2);
  v_company_refund numeric(12,2);
begin
  if auth.uid() is null or not public.srk_has_admin_permission('refunds.manage') then
    raise exception 'Refund management permission required' using errcode='42501';
  end if;
  if p_refund_request_id is null or p_earning_id is null
     or p_worker_refund_amount is null or p_worker_refund_amount < 0
     or p_note is null or length(btrim(p_note)) not between 10 and 2000 then
    raise exception 'Valid refund, earning, non-negative amount and 10-2000 character note required'
      using errcode='22023';
  end if;

  select * into v_refund
  from public.srk_booking_refund_requests
  where id=p_refund_request_id and status='processed'
  for update;
  if not found then
    raise exception 'Refund must be processed before worker allocation' using errcode='55000';
  end if;

  select worker_id into v_worker_id
  from public.srk_worker_earnings
  where id=p_earning_id and booking_id=v_refund.booking_id;
  if not found then raise exception 'Worker earning not found for this booking'; end if;

  -- Match the worker-profile lock used by payout requests and payout settlement.
  perform 1 from public.srk_worker_profiles
  where id=v_worker_id
  for update;

  select * into v_earning
  from public.srk_worker_earnings
  where id=p_earning_id and booking_id=v_refund.booking_id
  for update;
  if not found then raise exception 'Worker earning not found for this booking'; end if;

  select coalesce(sum(worker_refund_amount),0)
    into v_refund_allocated
  from public.srk_worker_refund_allocations
  where refund_request_id=p_refund_request_id;

  select coalesce(sum(worker_refund_amount),0)
    into v_earning_allocated
  from public.srk_worker_refund_allocations
  where earning_id=p_earning_id;

  select coalesce(commission_refund_amount,0)
    into v_company_refund
  from public.srk_company_commission_refund_reconciliations
  where refund_request_id=p_refund_request_id;

  if v_earning_allocated + p_worker_refund_amount > v_earning.net_earning then
    raise exception 'Cumulative worker refund allocations cannot exceed this earning net amount';
  end if;
  if v_refund_allocated + p_worker_refund_amount + v_company_refund > v_refund.amount then
    raise exception 'Worker allocations plus company commission refund cannot exceed customer refund amount';
  end if;

  insert into public.srk_worker_refund_allocations
    (refund_request_id,earning_id,worker_refund_amount,admin_note,created_by)
  values
    (p_refund_request_id,p_earning_id,p_worker_refund_amount,btrim(p_note),auth.uid())
  returning * into v_alloc;

  if p_worker_refund_amount > 0 then
    insert into public.srk_worker_wallet_ledger
      (worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
    values
      (v_earning.worker_id,v_earning.booking_id,v_earning.id,'refund_adjustment',
       p_worker_refund_amount,-p_worker_refund_amount,
       'Admin refund allocation; negative balance is recovered from future worker earnings. '||btrim(p_note),
       'worker-refund:'||p_refund_request_id::text||':'||p_earning_id::text)
    on conflict(idempotency_key) do nothing;
  end if;

  update public.srk_worker_earnings
  set payout_status='pending',
      settlement_status=case
        when v_earning_allocated + p_worker_refund_amount >= v_earning.net_earning then 'reversed'
        when payment_method='cash' and worker_role='technician' then 'cash_commission_due'
        when payment_method='cash' and worker_role='helper' then 'cash_split_pending'
        else 'available'
      end,
      updated_at=clock_timestamp()
  where id=p_earning_id;

  return v_alloc;
end
$function$;

revoke all on function public.srk_admin_resolve_worker_refund_allocation(uuid,uuid,numeric,text) from public,anon;
grant execute on function public.srk_admin_resolve_worker_refund_allocation(uuid,uuid,numeric,text) to authenticated;
