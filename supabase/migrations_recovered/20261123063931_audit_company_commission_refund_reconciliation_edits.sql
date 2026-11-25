
create table if not exists public.srk_company_commission_refund_reconciliation_history (
  id uuid primary key default gen_random_uuid(),
  reconciliation_id uuid not null references public.srk_company_commission_refund_reconciliations(id) on delete restrict,
  refund_request_id uuid not null,
  booking_id uuid not null,
  action text not null check (action in ('created','updated')),
  old_commission_refund_amount numeric,
  new_commission_refund_amount numeric not null,
  old_admin_note text,
  new_admin_note text not null,
  old_recorded_by uuid,
  new_recorded_by uuid not null,
  original_recorded_at timestamptz not null,
  changed_by uuid,
  changed_at timestamptz not null default clock_timestamp()
);

create index if not exists srk_company_comm_refund_history_lookup_idx
on public.srk_company_commission_refund_reconciliation_history
(refund_request_id, changed_at desc);

alter table public.srk_company_commission_refund_reconciliation_history enable row level security;
drop policy if exists srk_company_commission_refund_history_admin_read
on public.srk_company_commission_refund_reconciliation_history;
create policy srk_company_commission_refund_history_admin_read
on public.srk_company_commission_refund_reconciliation_history
for select to authenticated
using (public.srk_has_admin_permission('refunds.manage'));

revoke all on public.srk_company_commission_refund_reconciliation_history from public, anon, authenticated;
grant select on public.srk_company_commission_refund_reconciliation_history to authenticated;

create or replace function public.srk_log_company_commission_refund_reconciliation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if tg_op='INSERT' then
    insert into public.srk_company_commission_refund_reconciliation_history
      (reconciliation_id,refund_request_id,booking_id,action,
       new_commission_refund_amount,new_admin_note,new_recorded_by,
       original_recorded_at,changed_by)
    values
      (new.id,new.refund_request_id,new.booking_id,'created',
       new.commission_refund_amount,new.admin_note,new.recorded_by,
       new.recorded_at,auth.uid());
    return new;
  elsif tg_op='UPDATE' then
    if new.refund_request_id is distinct from old.refund_request_id
       or new.booking_id is distinct from old.booking_id then
      raise exception 'Refund reconciliation identity cannot be changed';
    end if;
    -- Keep the original accounting-period timestamp; edits are separately timestamped in history.
    new.recorded_at := old.recorded_at;
    insert into public.srk_company_commission_refund_reconciliation_history
      (reconciliation_id,refund_request_id,booking_id,action,
       old_commission_refund_amount,new_commission_refund_amount,
       old_admin_note,new_admin_note,old_recorded_by,new_recorded_by,
       original_recorded_at,changed_by)
    values
      (new.id,new.refund_request_id,new.booking_id,'updated',
       old.commission_refund_amount,new.commission_refund_amount,
       old.admin_note,new.admin_note,old.recorded_by,new.recorded_by,
       old.recorded_at,auth.uid());
    return new;
  end if;
  return null;
end;
$$;

drop trigger if exists srk_company_commission_refund_history_trg
on public.srk_company_commission_refund_reconciliations;
create trigger srk_company_commission_refund_history_trg
before insert or update on public.srk_company_commission_refund_reconciliations
for each row execute function public.srk_log_company_commission_refund_reconciliation();

-- Replace the Admin RPC so edits do not move the original refund accounting date.
create or replace function public.srk_admin_record_company_commission_refund(
  p_refund_request_id uuid,
  p_commission_refund_amount numeric,
  p_note text
)
returns public.srk_company_commission_refund_reconciliations
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
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
        admin_note=btrim(p_note),recorded_by=auth.uid()
    where id=v_existing.id returning * into v_result;
  else
    insert into public.srk_company_commission_refund_reconciliations
      (refund_request_id,booking_id,commission_refund_amount,admin_note,recorded_by)
    values
      (p_refund_request_id,v_refund.booking_id,p_commission_refund_amount,btrim(p_note),auth.uid())
    returning * into v_result;
  end if;
  return v_result;
end;
$$;

revoke all on function public.srk_admin_record_company_commission_refund(uuid,numeric,text) from public, anon;
grant execute on function public.srk_admin_record_company_commission_refund(uuid,numeric,text) to authenticated;
