
create or replace function public.srk_worker_wallet_balance()
returns table(available_balance numeric,total_credits numeric,total_debits numeric)
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_worker uuid;
  v_held numeric(12,2);
  v_reserved numeric(12,2);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if not found then raise exception 'Worker profile not found'; end if;

  select coalesce(sum(net_earning),0) into v_held
  from public.srk_worker_earnings
  where worker_id=v_worker and payout_status='held'
    and payment_method in ('online','upi','card');

  select coalesce(sum(coalesce(approved_amount,requested_amount)),0) into v_reserved
  from public.srk_worker_payout_requests
  where worker_id=v_worker and status in ('requested','under_review','approved');

  return query
  select (coalesce(sum(balance_effect),0)-v_held-v_reserved)::numeric(12,2),
    coalesce(sum(balance_effect) filter(where balance_effect>0),0)::numeric(12,2),
    coalesce(-sum(balance_effect) filter(where balance_effect<0),0)::numeric(12,2)
  from public.srk_worker_wallet_ledger where worker_id=v_worker;
end
$function$;

create or replace function public.srk_worker_wallet_summary()
returns table(available_balance numeric,held_earnings numeric,total_credits numeric,total_debits numeric)
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_worker uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if not found then raise exception 'Worker profile not found'; end if;

  return query
  with ledger as (
    select coalesce(sum(balance_effect),0)::numeric(12,2) balance,
      coalesce(sum(balance_effect) filter(where balance_effect>0),0)::numeric(12,2) credits,
      coalesce(-sum(balance_effect) filter(where balance_effect<0),0)::numeric(12,2) debits
    from public.srk_worker_wallet_ledger where worker_id=v_worker
  ), holds as (
    select coalesce(sum(net_earning),0)::numeric(12,2) held
    from public.srk_worker_earnings
    where worker_id=v_worker and payout_status='held'
      and payment_method in ('online','upi','card')
  ), reservations as (
    select coalesce(sum(coalesce(approved_amount,requested_amount)),0)::numeric(12,2) reserved
    from public.srk_worker_payout_requests
    where worker_id=v_worker and status in ('requested','under_review','approved')
  )
  select (ledger.balance-holds.held-reservations.reserved)::numeric(12,2),
    holds.held,ledger.credits,ledger.debits
  from ledger cross join holds cross join reservations;
end
$function$;
