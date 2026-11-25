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
  v_held_credited numeric(14,2);
  v_net numeric(14,2);
  v_held_count integer;
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

  -- Only subtract funds actually credited to the ledger and subsequently held.
  -- A hold created before the payment/earning is posted must not create a
  -- phantom negative wallet balance.
  select coalesce(sum(greatest(0,x.credited_balance)),0)::numeric(14,2)
    into v_held_credited
  from (
    select e.id,
      coalesce(sum(l.balance_effect),0)::numeric(14,2) as credited_balance
    from public.srk_worker_earnings e
    left join public.srk_worker_wallet_ledger l
      on l.earning_id=e.id
     and l.entry_type in ('earning','refund_adjustment')
    where e.worker_id=v_worker
      and e.settlement_status='held'
      and lower(coalesce(e.payment_method,'')) in ('online','upi','card')
    group by e.id
  ) x;

  select count(*)::integer into v_held_count
  from public.srk_worker_earnings
  where worker_id=v_worker and settlement_status='held';

  select greatest(0,-coalesce(sum(balance_effect),0))::numeric(14,2)
    into v_cash_due
  from public.srk_worker_wallet_ledger
  where worker_id=v_worker
    and entry_type in ('cash_commission_due','cash_commission_collected');

  v_net:=v_ledger-v_held_credited-v_reserved;

  return jsonb_build_object(
    'worker_id',v_worker,
    'currency','INR',
    'ledger_balance',v_ledger,
    'held_earnings',v_held_credited,
    'reserved_payout_amount',v_reserved,
    'available_for_payout',greatest(0,v_net),
    'recovery_debt',greatest(0,-v_net),
    'net_balance_after_reservations',v_net,
    'cash_commission_outstanding',v_cash_due,
    'held_earning_count',v_held_count,
    'payout_blocked',v_held_count>0
  );
end
$function$;

create or replace function public.srk_worker_wallet_balance()
returns table(available_balance numeric,total_credits numeric,total_debits numeric)
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_worker uuid;
  v_held numeric(14,2);
  v_reserved numeric(14,2);
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if not found then raise exception 'Worker profile not found' using errcode='P0002'; end if;

  select coalesce(sum(greatest(0,x.credited_balance)),0)::numeric(14,2)
    into v_held
  from (
    select e.id,coalesce(sum(l.balance_effect),0)::numeric(14,2) credited_balance
    from public.srk_worker_earnings e
    left join public.srk_worker_wallet_ledger l
      on l.earning_id=e.id and l.entry_type in ('earning','refund_adjustment')
    where e.worker_id=v_worker and e.settlement_status='held'
      and lower(coalesce(e.payment_method,'')) in ('online','upi','card')
    group by e.id
  ) x;

  select coalesce(sum(coalesce(approved_amount,requested_amount)),0)::numeric(14,2)
    into v_reserved
  from public.srk_worker_payout_requests
  where worker_id=v_worker and status in ('requested','under_review','approved');

  return query
  select (coalesce(sum(l.balance_effect),0)-v_held-v_reserved)::numeric(14,2),
    coalesce(sum(l.balance_effect) filter(where l.balance_effect>0),0)::numeric(14,2),
    coalesce(-sum(l.balance_effect) filter(where l.balance_effect<0),0)::numeric(14,2)
  from public.srk_worker_wallet_ledger l where l.worker_id=v_worker;
end
$function$;

create or replace function public.srk_worker_wallet_summary()
returns table(available_balance numeric,held_earnings numeric,total_credits numeric,total_debits numeric)
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_worker uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if not found then raise exception 'Worker profile not found' using errcode='P0002'; end if;

  return query
  with ledger as (
    select coalesce(sum(balance_effect),0)::numeric(14,2) balance,
      coalesce(sum(balance_effect) filter(where balance_effect>0),0)::numeric(14,2) credits,
      coalesce(-sum(balance_effect) filter(where balance_effect<0),0)::numeric(14,2) debits
    from public.srk_worker_wallet_ledger where worker_id=v_worker
  ), holds as (
    select coalesce(sum(greatest(0,x.credited_balance)),0)::numeric(14,2) held
    from (
      select e.id,coalesce(sum(l.balance_effect),0)::numeric(14,2) credited_balance
      from public.srk_worker_earnings e
      left join public.srk_worker_wallet_ledger l
        on l.earning_id=e.id and l.entry_type in ('earning','refund_adjustment')
      where e.worker_id=v_worker and e.settlement_status='held'
        and lower(coalesce(e.payment_method,'')) in ('online','upi','card')
      group by e.id
    ) x
  ), reservations as (
    select coalesce(sum(coalesce(approved_amount,requested_amount)),0)::numeric(14,2) reserved
    from public.srk_worker_payout_requests
    where worker_id=v_worker and status in ('requested','under_review','approved')
  )
  select (ledger.balance-holds.held-reservations.reserved)::numeric(14,2),
    holds.held,ledger.credits,ledger.debits
  from ledger cross join holds cross join reservations;
end
$function$;

revoke all on function public.srk_worker_get_my_wallet_summary() from public,anon;
grant execute on function public.srk_worker_get_my_wallet_summary() to authenticated;
revoke all on function public.srk_worker_wallet_balance() from public,anon;
grant execute on function public.srk_worker_wallet_balance() to authenticated;
revoke all on function public.srk_worker_wallet_summary() from public,anon;
grant execute on function public.srk_worker_wallet_summary() to authenticated;