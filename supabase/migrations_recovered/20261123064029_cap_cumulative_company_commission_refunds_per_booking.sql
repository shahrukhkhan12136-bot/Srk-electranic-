
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
  v_booking public.service_bookings%rowtype;
  v_total_commission numeric(14,2);
  v_prior_company_refunds numeric(14,2);
  v_worker_allocations numeric(14,2);
  v_existing public.srk_company_commission_refund_reconciliations%rowtype;
  v_result public.srk_company_commission_refund_reconciliations%rowtype;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('refunds.manage') then
    raise exception 'Refund management permission required' using errcode='42501';
  end if;
  if p_refund_request_id is null or p_commission_refund_amount is null
     or p_commission_refund_amount < 0
     or p_commission_refund_amount <> round(p_commission_refund_amount,2)
     or p_note is null or length(btrim(p_note)) not between 10 and 2000 then
    raise exception 'Valid refund, non-negative amount with at most 2 decimals and 10-2000 character note required'
      using errcode='22023';
  end if;

  select * into v_refund
  from public.srk_booking_refund_requests
  where id=p_refund_request_id and status='processed'
  for update;
  if not found then
    raise exception 'Refund must be processed before company commission reconciliation' using errcode='55000';
  end if;

  -- Serialize all company-commission refund reconciliations for this booking.
  select * into v_booking
  from public.service_bookings
  where id=v_refund.booking_id
  for update;
  if not found then raise exception 'Refund booking not found'; end if;

  select coalesce(sum(company_commission),0)::numeric(14,2)
    into v_total_commission
  from public.srk_worker_earnings
  where booking_id=v_refund.booking_id;

  select coalesce(sum(commission_refund_amount),0)::numeric(14,2)
    into v_prior_company_refunds
  from public.srk_company_commission_refund_reconciliations
  where booking_id=v_refund.booking_id
    and refund_request_id<>p_refund_request_id;

  if v_prior_company_refunds + p_commission_refund_amount > v_total_commission then
    raise exception 'Cumulative company commission refunds cannot exceed total commission recorded for this booking';
  end if;

  select coalesce(sum(worker_refund_amount),0)::numeric(14,2)
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
