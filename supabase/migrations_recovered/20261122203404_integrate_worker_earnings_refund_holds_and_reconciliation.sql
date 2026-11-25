
create table if not exists public.srk_worker_refund_allocations (
  id uuid primary key default gen_random_uuid(),
  refund_request_id uuid not null references public.srk_booking_refund_requests(id) on delete restrict,
  earning_id uuid not null references public.srk_worker_earnings(id) on delete restrict,
  worker_refund_amount numeric(12,2) not null default 0,
  admin_note text not null,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  constraint srk_worker_refund_allocation_amount_valid check(worker_refund_amount>=0),
  constraint srk_worker_refund_allocation_unique unique(refund_request_id,earning_id)
);
alter table public.srk_worker_refund_allocations enable row level security;
create policy srk_worker_refund_allocations_admin_read on public.srk_worker_refund_allocations
for select to authenticated using(public.srk_has_admin_permission('refunds.manage'));

create or replace function public.srk_post_one_worker_earning(p_earning_id uuid)
returns void language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v public.srk_worker_earnings%rowtype; v_paid text; v_refund_pending boolean;
begin
  select e.* into v from public.srk_worker_earnings e where e.id=p_earning_id;
  if not found then return; end if;
  select payment_status into v_paid from public.service_bookings where id=v.booking_id;
  if lower(coalesce(v_paid,'')) not in ('paid','completed') then return; end if;
  select exists(select 1 from public.srk_booking_refund_requests r
    where r.booking_id=v.booking_id and r.status<>'rejected') into v_refund_pending;
  if v_refund_pending then
    update public.srk_worker_earnings set payout_status='held',settlement_status='held' where id=v.id;
    return;
  end if;

  if v.payment_method in ('online','upi','card') then
    insert into public.srk_worker_wallet_ledger(worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
    values(v.worker_id,v.booking_id,v.id,'earning',v.net_earning,v.net_earning,
      'Paid online booking net earning after 15% commission','earning:'||v.id::text)
    on conflict(idempotency_key) do nothing;
    update public.srk_worker_earnings set settlement_status='available',payout_status='pending' where id=v.id;
  elsif v.payment_method='cash' and v.worker_role='technician' then
    insert into public.srk_worker_wallet_ledger(worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
    values(v.worker_id,v.booking_id,v.id,'cash_commission_due',v.company_commission,-v.company_commission,
      'Cash booking company commission due from technician','cash-commission:'||v.id::text)
    on conflict(idempotency_key) do nothing;
    update public.srk_worker_earnings set settlement_status='cash_commission_due',payout_status='pending' where id=v.id;
  elsif v.payment_method='cash' and v.worker_role='helper' then
    update public.srk_worker_earnings set settlement_status='cash_split_pending',payout_status='pending' where id=v.id;
  end if;
end $$;

create or replace function public.srk_hold_worker_earnings_for_refund()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_earning record;
begin
  if new.status in ('requested','in_review','approved','processing','unknown') then
    update public.srk_worker_earnings set payout_status='held',settlement_status='held'
    where booking_id=new.booking_id;
  elsif new.status='rejected' then
    update public.srk_worker_earnings set payout_status='pending',
      settlement_status=case when payment_method='cash' and worker_role='technician' then 'cash_commission_due'
        when payment_method='cash' and worker_role='helper' then 'cash_split_pending' else 'pending' end
    where booking_id=new.booking_id;
    for v_earning in select id from public.srk_worker_earnings where booking_id=new.booking_id loop
      perform public.srk_post_one_worker_earning(v_earning.id);
    end loop;
  end if;
  return new;
end $$;
drop trigger if exists srk_hold_worker_earnings_for_refund_trigger on public.srk_booking_refund_requests;
create trigger srk_hold_worker_earnings_for_refund_trigger
after insert or update of status on public.srk_booking_refund_requests
for each row execute function public.srk_hold_worker_earnings_for_refund();

create or replace function public.srk_worker_request_payout(p_amount numeric)
returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_worker uuid; v_available numeric(12,2); v_reserved numeric(12,2); v_payout public.srk_worker_payout_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid() for update;
  if not found then raise exception 'Worker profile not found'; end if;
  if exists(select 1 from public.srk_worker_earnings where worker_id=v_worker and payout_status='held') then
    raise exception 'Payout is temporarily held while a refund/dispute is reviewed';
  end if;
  if p_amount is null or p_amount<=0 then raise exception 'Payout amount must be positive'; end if;
  select coalesce(sum(balance_effect),0) into v_available from public.srk_worker_wallet_ledger where worker_id=v_worker;
  select coalesce(sum(coalesce(approved_amount,requested_amount)),0) into v_reserved from public.srk_worker_payout_requests
    where worker_id=v_worker and status in ('requested','under_review','approved');
  if p_amount>v_available-v_reserved then raise exception 'Payout exceeds unreserved available balance'; end if;
  insert into public.srk_worker_payout_requests(worker_id,requested_amount,status)
  values(v_worker,p_amount,'requested') returning * into v_payout;
  return v_payout;
end $$;

create or replace function public.srk_admin_review_worker_payout(
 p_payout_id uuid,p_approve boolean,p_approved_amount numeric default null,p_note text default null
) returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_payout public.srk_worker_payout_requests%rowtype; v_available numeric(12,2); v_reserved numeric(12,2); v_amount numeric(12,2);
begin
  if not public.srk_has_admin_permission('payouts.manage') then raise exception 'Payout management permission required'; end if;
  select * into v_payout from public.srk_worker_payout_requests where id=p_payout_id for update;
  if not found or v_payout.status not in ('requested','under_review') then raise exception 'Payout request not reviewable'; end if;
  perform 1 from public.srk_worker_profiles where id=v_payout.worker_id for update;
  if exists(select 1 from public.srk_worker_earnings where worker_id=v_payout.worker_id and payout_status='held') then
    raise exception 'Worker payout is held due to refund/dispute review';
  end if;
  if not p_approve then
    update public.srk_worker_payout_requests set status='rejected',reviewed_at=clock_timestamp(),reviewed_by=auth.uid(),admin_note=p_note
    where id=p_payout_id returning * into v_payout;
    return v_payout;
  end if;
  v_amount:=coalesce(p_approved_amount,v_payout.requested_amount);
  select coalesce(sum(balance_effect),0) into v_available from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
  select coalesce(sum(coalesce(approved_amount,requested_amount)),0) into v_reserved from public.srk_worker_payout_requests
    where worker_id=v_payout.worker_id and id<>p_payout_id and status in ('requested','under_review','approved');
  if v_amount<=0 or v_amount>v_payout.requested_amount or v_amount>v_available-v_reserved then
    raise exception 'Approved amount exceeds unreserved available balance';
  end if;
  update public.srk_worker_payout_requests set status='approved',approved_amount=v_amount,
    reviewed_at=clock_timestamp(),reviewed_by=auth.uid(),admin_note=p_note
  where id=p_payout_id returning * into v_payout;
  return v_payout;
end $$;

create or replace function public.srk_admin_mark_worker_payout_paid(
 p_payout_id uuid,p_payment_method text,p_payment_reference text,p_note text default null
) returns public.srk_worker_payout_requests
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_payout public.srk_worker_payout_requests%rowtype; v_available numeric(12,2); v_reserved numeric(12,2);
begin
  if not public.srk_has_admin_permission('payouts.manage') then raise exception 'Payout management permission required'; end if;
  if nullif(btrim(p_payment_reference),'') is null then raise exception 'UTR/transaction reference required'; end if;
  if p_payment_method not in ('upi','bank_transfer','phonepe','other') then raise exception 'Invalid payout method'; end if;
  select * into v_payout from public.srk_worker_payout_requests where id=p_payout_id for update;
  if not found or v_payout.status<>'approved' then raise exception 'Only approved payout can be marked paid'; end if;
  perform 1 from public.srk_worker_profiles where id=v_payout.worker_id for update;
  if exists(select 1 from public.srk_worker_earnings where worker_id=v_payout.worker_id and payout_status='held') then
    raise exception 'Worker payout is held due to refund/dispute review';
  end if;
  select coalesce(sum(balance_effect),0) into v_available from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
  select coalesce(sum(approved_amount),0) into v_reserved from public.srk_worker_payout_requests
    where worker_id=v_payout.worker_id and id<>p_payout_id and status='approved';
  if v_payout.approved_amount>v_available-v_reserved then raise exception 'Wallet balance changed; payout cannot be paid'; end if;
  insert into public.srk_worker_wallet_ledger(worker_id,entry_type,amount,balance_effect,description,reference_id,idempotency_key)
  values(v_payout.worker_id,'payout_paid',v_payout.approved_amount,-v_payout.approved_amount,
    'Admin verified payout',p_payment_reference,'payout-paid:'||v_payout.id::text);
  update public.srk_worker_payout_requests set status='paid',payment_method=p_payment_method,
    payment_reference=p_payment_reference,admin_note=coalesce(p_note,admin_note),paid_at=clock_timestamp()
  where id=p_payout_id returning * into v_payout;
  return v_payout;
end $$;

create or replace function public.srk_worker_wallet_summary()
returns table(available_balance numeric(12,2),held_earnings numeric(12,2),total_credits numeric(12,2),total_debits numeric(12,2))
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_worker uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if not found then raise exception 'Worker profile not found'; end if;
  return query
  select (coalesce(sum(l.balance_effect),0)-coalesce(sum(e.net_earning) filter(where e.payout_status='held'),0))::numeric(12,2),
    coalesce(sum(e.net_earning) filter(where e.payout_status='held'),0)::numeric(12,2),
    coalesce(sum(l.balance_effect) filter(where l.balance_effect>0),0)::numeric(12,2),
    coalesce(-sum(l.balance_effect) filter(where l.balance_effect<0),0)::numeric(12,2)
  from public.srk_worker_wallet_ledger l
  full join public.srk_worker_earnings e on e.worker_id=l.worker_id
  where coalesce(l.worker_id,e.worker_id)=v_worker;
end $$;

create or replace function public.srk_admin_resolve_worker_refund_allocation(
 p_refund_request_id uuid,p_earning_id uuid,p_worker_refund_amount numeric,p_note text
) returns public.srk_worker_refund_allocations
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_refund public.srk_booking_refund_requests%rowtype; v_earning public.srk_worker_earnings%rowtype;
  v_alloc public.srk_worker_refund_allocations%rowtype;
begin
  if not public.srk_has_admin_permission('refunds.manage') then raise exception 'Refund management permission required'; end if;
  if length(coalesce(p_note,''))<10 or p_worker_refund_amount<0 then raise exception 'Valid note and non-negative refund amount required'; end if;
  select * into v_refund from public.srk_booking_refund_requests where id=p_refund_request_id and status='processed' for update;
  if not found then raise exception 'Refund must be processed before worker allocation'; end if;
  select * into v_earning from public.srk_worker_earnings where id=p_earning_id and booking_id=v_refund.booking_id for update;
  if not found then raise exception 'Worker earning not found for this booking'; end if;
  if p_worker_refund_amount>v_earning.net_earning then raise exception 'Worker refund allocation exceeds net earning'; end if;

  insert into public.srk_worker_refund_allocations(refund_request_id,earning_id,worker_refund_amount,admin_note,created_by)
  values(p_refund_request_id,p_earning_id,p_worker_refund_amount,p_note,auth.uid())
  returning * into v_alloc;

  if p_worker_refund_amount>0 then
    insert into public.srk_worker_wallet_ledger(worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
    values(v_earning.worker_id,v_earning.booking_id,v_earning.id,'refund_adjustment',p_worker_refund_amount,-p_worker_refund_amount,
      'Admin refund allocation: '||p_note,'worker-refund:'||p_refund_request_id::text||':'||p_earning_id::text)
    on conflict(idempotency_key) do nothing;
  end if;

  update public.srk_worker_earnings set payout_status='pending',
    settlement_status=case when p_worker_refund_amount>=net_earning then 'reversed'
      when payment_method='cash' and worker_role='technician' then 'cash_commission_due'
      when payment_method='cash' and worker_role='helper' then 'cash_split_pending'
      else 'available' end,
    updated_at=clock_timestamp()
  where id=p_earning_id;
  return v_alloc;
end $$;

revoke all on function public.srk_admin_resolve_worker_refund_allocation(uuid,uuid,numeric,text) from public,anon;
revoke all on function public.srk_worker_wallet_summary() from public,anon;
grant execute on function public.srk_admin_resolve_worker_refund_allocation(uuid,uuid,numeric,text) to authenticated;
grant execute on function public.srk_worker_wallet_summary() to authenticated;
