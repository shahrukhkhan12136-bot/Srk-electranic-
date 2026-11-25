
create or replace function public.srk_admin_settle_cash_worker_share(
  p_earning_id uuid,
  p_actual_cash_share numeric,
  p_reason text
)
returns public.srk_worker_earnings
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v public.srk_worker_earnings%rowtype;
  v_booking public.service_bookings%rowtype;
  v_worker_id uuid;
  v_service_total numeric(12,2);
  v_already_allocated numeric(12,2);
  v_commission numeric(12,2);
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

  -- Lock Worker first, matching wallet/payout/refund operations and preventing
  -- a payout request from racing ahead of a newly posted cash-commission debt.
  select worker_id into v_worker_id
  from public.srk_worker_earnings
  where id=p_earning_id;
  if not found then raise exception 'Worker earning not found'; end if;

  perform 1 from public.srk_worker_profiles
  where id=v_worker_id
  for update;
  if not found then raise exception 'Worker profile not found'; end if;

  select * into v
  from public.srk_worker_earnings
  where id=p_earning_id
  for update;
  if not found or v.worker_id<>v_worker_id or v.payment_method<>'cash'
     or v.settlement_status<>'cash_split_pending' then
    raise exception 'Cash earning is not awaiting split settlement';
  end if;

  -- Serialize Technician/Helper shares for this booking.
  select * into v_booking
  from public.service_bookings
  where id=v.booking_id
  for update;
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

  select coalesce(sum(gross_service_earning),0)
  into v_already_allocated
  from public.srk_worker_earnings
  where booking_id=v.booking_id
    and settlement_status='cash_commission_due'
    and id<>v.id;

  if v_already_allocated+p_actual_cash_share>v_service_total then
    raise exception 'Cash shares exceed total labour amount';
  end if;
  if v.company_commission_rate is null
     or v.company_commission_rate<0 or v.company_commission_rate>100 then
    raise exception 'Earning commission snapshot is invalid';
  end if;

  v_commission:=round(p_actual_cash_share*v.company_commission_rate/100,2);

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

revoke all on function public.srk_admin_settle_cash_worker_share(uuid,numeric,text) from public, anon;
grant execute on function public.srk_admin_settle_cash_worker_share(uuid,numeric,text) to authenticated;
