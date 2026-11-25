create or replace function public.srk_worker_get_my_wallet_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_worker uuid;
  v_ledger numeric(14,2);
  v_reserved numeric(14,2);
  v_net numeric(14,2);
  v_held integer;
  v_cash_due numeric(14,2);
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  select id into v_worker
  from public.srk_worker_profiles
  where user_id=auth.uid()
  limit 1;

  if v_worker is null then
    raise exception 'Approved worker profile not found' using errcode='P0002';
  end if;

  select coalesce(sum(balance_effect),0)::numeric(14,2)
    into v_ledger
  from public.srk_worker_wallet_ledger
  where worker_id=v_worker;

  select coalesce(sum(coalesce(approved_amount,requested_amount)),0)::numeric(14,2)
    into v_reserved
  from public.srk_worker_payout_requests
  where worker_id=v_worker
    and status in ('requested','under_review','approved');

  select count(*)::integer into v_held
  from public.srk_worker_earnings
  where worker_id=v_worker and settlement_status='held';

  -- Cash commission outstanding is only the unpaid company commission.
  -- Refund credits are separate worker-wallet credits and must not reduce
  -- the company's outstanding cash commission balance.
  select greatest(0,-coalesce(sum(balance_effect),0))::numeric(14,2)
    into v_cash_due
  from public.srk_worker_wallet_ledger
  where worker_id=v_worker
    and entry_type in ('cash_commission_due','cash_commission_collected');

  v_net:=v_ledger-v_reserved;

  return jsonb_build_object(
    'worker_id',v_worker,
    'currency','INR',
    'ledger_balance',v_ledger,
    'reserved_payout_amount',v_reserved,
    'available_for_payout',greatest(0,v_net),
    'recovery_debt',greatest(0,-v_net),
    'net_balance_after_reservations',v_net,
    'cash_commission_outstanding',v_cash_due,
    'held_earning_count',v_held,
    'payout_blocked',v_held>0
  );
end
$function$;

revoke all on function public.srk_worker_get_my_wallet_summary() from public,anon;
grant execute on function public.srk_worker_get_my_wallet_summary() to authenticated;