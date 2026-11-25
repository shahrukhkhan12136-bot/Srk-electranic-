
create unique index if not exists srk_worker_paid_payout_reference_uidx
on public.srk_worker_payout_requests (lower(btrim(payment_reference)))
where status='paid' and payment_reference is not null;

create or replace function public.srk_worker_request_payout(p_amount numeric)
returns public.srk_worker_payout_requests
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_worker uuid;
  v_available numeric(12,2);
  v_reserved numeric(12,2);
  v_payout public.srk_worker_payout_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;
  if p_amount is null or p_amount<=0 or p_amount<>round(p_amount,2) then
    raise exception 'Payout amount must be positive and limited to two decimal places' using errcode='22023';
  end if;

  select id into v_worker
  from public.srk_worker_profiles
  where user_id=auth.uid()
  for update;
  if not found then raise exception 'Worker profile not found'; end if;

  if exists(select 1 from public.srk_worker_earnings
            where worker_id=v_worker and settlement_status='held') then
    raise exception 'Payout is temporarily held while a refund/dispute is reviewed';
  end if;

  select coalesce(sum(balance_effect),0)
    into v_available
  from public.srk_worker_wallet_ledger
  where worker_id=v_worker;

  select coalesce(sum(coalesce(approved_amount,requested_amount)),0)
    into v_reserved
  from public.srk_worker_payout_requests
  where worker_id=v_worker
    and status in ('requested','under_review','approved');

  if p_amount>v_available-v_reserved then
    raise exception 'Payout exceeds unreserved available balance';
  end if;

  insert into public.srk_worker_payout_requests(worker_id,requested_amount,status)
  values(v_worker,p_amount,'requested')
  returning * into v_payout;
  return v_payout;
end;
$$;

create or replace function public.srk_admin_review_worker_payout(
  p_payout_id uuid,
  p_approve boolean,
  p_approved_amount numeric default null,
  p_note text default null
)
returns public.srk_worker_payout_requests
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_payout public.srk_worker_payout_requests%rowtype;
  v_available numeric(12,2);
  v_reserved numeric(12,2);
  v_amount numeric(12,2);
begin
  if auth.uid() is null or not public.srk_has_admin_permission('payouts.manage') then
    raise exception 'Payout management permission required' using errcode='42501';
  end if;
  if p_approve is null then
    raise exception 'Approval decision is required' using errcode='22023';
  end if;
  if p_approved_amount is not null and
     (p_approved_amount<=0 or p_approved_amount<>round(p_approved_amount,2)) then
    raise exception 'Approved amount must be positive and limited to two decimal places' using errcode='22023';
  end if;

  select * into v_payout
  from public.srk_worker_payout_requests
  where id=p_payout_id
  for update;
  if not found or v_payout.status not in ('requested','under_review') then
    raise exception 'Payout request not reviewable';
  end if;

  perform 1 from public.srk_worker_profiles where id=v_payout.worker_id for update;

  if exists(select 1 from public.srk_worker_earnings
            where worker_id=v_payout.worker_id and settlement_status='held') then
    raise exception 'Worker payout is held due to refund/dispute review';
  end if;

  if not p_approve then
    update public.srk_worker_payout_requests
    set status='rejected',reviewed_at=clock_timestamp(),
        reviewed_by=auth.uid(),admin_note=p_note
    where id=p_payout_id returning * into v_payout;
    return v_payout;
  end if;

  v_amount:=coalesce(p_approved_amount,v_payout.requested_amount);

  select coalesce(sum(balance_effect),0)
    into v_available
  from public.srk_worker_wallet_ledger
  where worker_id=v_payout.worker_id;

  select coalesce(sum(coalesce(approved_amount,requested_amount)),0)
    into v_reserved
  from public.srk_worker_payout_requests
  where worker_id=v_payout.worker_id
    and id<>p_payout_id
    and status in ('requested','under_review','approved');

  if v_amount<=0 or v_amount>v_payout.requested_amount or v_amount>v_available-v_reserved then
    raise exception 'Approved amount exceeds unreserved available balance';
  end if;

  update public.srk_worker_payout_requests
  set status='approved',approved_amount=v_amount,
      reviewed_at=clock_timestamp(),reviewed_by=auth.uid(),admin_note=p_note
  where id=p_payout_id returning * into v_payout;
  return v_payout;
end;
$$;

revoke all on function public.srk_worker_request_payout(numeric) from public, anon;
grant execute on function public.srk_worker_request_payout(numeric) to authenticated;
revoke all on function public.srk_admin_review_worker_payout(uuid,boolean,numeric,text) from public, anon;
grant execute on function public.srk_admin_review_worker_payout(uuid,boolean,numeric,text) to authenticated;
