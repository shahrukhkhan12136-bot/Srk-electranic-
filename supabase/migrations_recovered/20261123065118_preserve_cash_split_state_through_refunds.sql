
create or replace function public.srk_admin_settle_cash_worker_share(
  p_earning_id uuid,
  p_actual_cash_share numeric,
  p_reason text
)
returns public.srk_worker_earnings
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v public.srk_worker_earnings%rowtype;
  v_booking public.service_bookings%rowtype;
  v_worker_id uuid;
  v_service_total numeric(12,2);
  v_already_allocated numeric(12,2);
  v_commission numeric(12,2);
  v_existing_due numeric(12,2);
begin
  if auth.uid() is null or not public.srk_has_admin_permission('payouts.manage') then
    raise exception 'Payout management permission required' using errcode='42501';
  end if;
  if p_earning_id is null or p_actual_cash_share is null
     or p_actual_cash_share<0 or p_actual_cash_share<>round(p_actual_cash_share,2)
     or p_reason is null or length(btrim(p_reason)) not between 10 and 2000 then
    raise exception 'Valid earning, non-negative two-decimal cash share and 10-2000 character reason are required'
      using errcode='22023';
  end if;

  select worker_id into v_worker_id
  from public.srk_worker_earnings where id=p_earning_id;
  if not found then raise exception 'Worker earning not found'; end if;

  perform 1 from public.srk_worker_profiles where id=v_worker_id for update;
  if not found then raise exception 'Worker profile not found'; end if;

  select * into v from public.srk_worker_earnings
  where id=p_earning_id for update;
  if not found or v.worker_id<>v_worker_id or v.payment_method<>'cash'
     or v.settlement_status<>'cash_split_pending' then
    raise exception 'Cash earning is not awaiting split settlement';
  end if;

  select * into v_booking from public.service_bookings
  where id=v.booking_id for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.payment_status<>'paid' then
    raise exception 'Cash payment must be confirmed before settlement';
  end if;

  select f.service_amount into v_service_total
  from public.srk_booking_final_bills f
  where f.id=v.bill_id and f.booking_id=v.booking_id;
  if v_service_total is null then
    raise exception 'Final bill labour amount not found';
  end if;

  -- Count every previously settled cash share even if a later refund changed
  -- its settlement_status to reversed/held. The immutable ledger entry is the
  -- settlement evidence; status alone must not free the labour cap.
  select coalesce(sum(e.gross_service_earning),0)
    into v_already_allocated
  from public.srk_worker_earnings e
  where e.booking_id=v.booking_id
    and e.payment_method='cash'
    and e.id<>v.id
    and exists (
      select 1 from public.srk_worker_wallet_ledger l
      where l.earning_id=e.id and l.entry_type='cash_commission_due'
    );

  if v_already_allocated+p_actual_cash_share>v_service_total then
    raise exception 'Cash shares exceed total labour amount';
  end if;
  if v.company_commission_rate is null
     or v.company_commission_rate<0 or v.company_commission_rate>100 then
    raise exception 'Earning commission snapshot is invalid';
  end if;

  v_commission:=round(p_actual_cash_share*v.company_commission_rate/100,2);

  -- Refuse an idempotency-key collision if a prior ledger row has different
  -- financial content; do not silently accept a stale commission amount.
  select amount into v_existing_due
  from public.srk_worker_wallet_ledger
  where idempotency_key='cash-share-commission:'||v.id::text;
  if found and v_existing_due<>v_commission then
    raise exception 'Existing cash commission ledger amount differs; reconciliation required';
  end if;

  update public.srk_worker_earnings
  set gross_service_earning=p_actual_cash_share,
      company_commission=v_commission,
      net_earning=p_actual_cash_share-v_commission,
      settlement_status='cash_commission_due',
      payout_status='pending',
      admin_note=btrim(p_reason),
      updated_at=clock_timestamp()
  where id=p_earning_id
  returning * into v;

  insert into public.srk_worker_wallet_ledger(
    worker_id,booking_id,earning_id,entry_type,amount,balance_effect,
    description,idempotency_key
  )
  values(
    v.worker_id,v.booking_id,v.id,'cash_commission_due',
    v_commission,-v_commission,
    'Admin-settled cash share commission: '||btrim(p_reason),
    'cash-share-commission:'||v.id::text
  )
  on conflict(idempotency_key) do nothing;

  return v;
end
$function$;

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
  v_unresolved_refund boolean;
  v_cash_commission_posted boolean;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('refunds.manage') then
    raise exception 'Refund management permission required' using errcode='42501';
  end if;
  if p_refund_request_id is null or p_earning_id is null
     or p_worker_refund_amount is null or p_worker_refund_amount < 0
     or p_worker_refund_amount<>round(p_worker_refund_amount,2)
     or p_note is null or length(btrim(p_note)) not between 10 and 2000 then
    raise exception 'Valid refund, non-negative two-decimal amount and 10-2000 character note required'
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

  perform 1 from public.srk_worker_profiles where id=v_worker_id for update;

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

  select exists(
    select 1
    from public.srk_booking_refund_requests r
    where r.booking_id=v_earning.booking_id
      and r.status<>'rejected'
      and not exists(
        select 1 from public.srk_worker_refund_allocations a
        where a.refund_request_id=r.id and a.earning_id=p_earning_id
      )
  ) into v_unresolved_refund;

  -- A cash earning with a posted commission ledger entry has already completed
  -- its Tech/Helper share settlement. Without that ledger evidence, it must
  -- remain in split-pending state after refund review, including Technician
  -- earnings from bookings that also had a Helper.
  select exists(
    select 1 from public.srk_worker_wallet_ledger l
    where l.earning_id=v_earning.id and l.entry_type='cash_commission_due'
  ) into v_cash_commission_posted;

  update public.srk_worker_earnings
  set payout_status=case
        when v_unresolved_refund then 'held'
        when v_earning_allocated + p_worker_refund_amount >= v_earning.net_earning then 'pending'
        when payment_method='cash' and not v_cash_commission_posted then 'held'
        else 'pending'
      end,
      settlement_status=case
        when v_unresolved_refund then 'held'
        when v_earning_allocated + p_worker_refund_amount >= v_earning.net_earning then 'reversed'
        when payment_method='cash' and v_cash_commission_posted then 'cash_commission_due'
        when payment_method='cash' then 'cash_split_pending'
        else 'available'
      end,
      updated_at=clock_timestamp()
  where id=p_earning_id;

  return v_alloc;
end
$function$;

revoke all on function public.srk_admin_settle_cash_worker_share(uuid,numeric,text) from public,anon;
grant execute on function public.srk_admin_settle_cash_worker_share(uuid,numeric,text) to authenticated;
revoke all on function public.srk_admin_resolve_worker_refund_allocation(uuid,uuid,numeric,text) from public,anon;
grant execute on function public.srk_admin_resolve_worker_refund_allocation(uuid,uuid,numeric,text) to authenticated;
