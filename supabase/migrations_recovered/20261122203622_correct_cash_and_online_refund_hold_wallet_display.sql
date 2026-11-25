
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
  with ledger as (
    select coalesce(sum(balance_effect),0)::numeric(12,2) balance,
      coalesce(sum(balance_effect) filter(where balance_effect>0),0)::numeric(12,2) credits,
      coalesce(-sum(balance_effect) filter(where balance_effect<0),0)::numeric(12,2) debits
    from public.srk_worker_wallet_ledger where worker_id=v_worker
  ), holds as (
    select coalesce(sum(net_earning),0)::numeric(12,2) held
    from public.srk_worker_earnings
    where worker_id=v_worker and payout_status='held' and payment_method in ('online','upi','card')
  )
  select (ledger.balance-holds.held)::numeric(12,2),holds.held,ledger.credits,ledger.debits
  from ledger cross join holds;
end $$;

create or replace function public.srk_worker_wallet_balance()
returns table(available_balance numeric(12,2),total_credits numeric(12,2),total_debits numeric(12,2))
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_worker uuid; v_held numeric(12,2);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select id into v_worker from public.srk_worker_profiles where user_id=auth.uid();
  if not found then raise exception 'Worker profile not found'; end if;
  select coalesce(sum(net_earning),0) into v_held from public.srk_worker_earnings
    where worker_id=v_worker and payout_status='held' and payment_method in ('online','upi','card');
  return query select (coalesce(sum(balance_effect),0)-v_held)::numeric(12,2),
    coalesce(sum(balance_effect) filter(where balance_effect>0),0)::numeric(12,2),
    coalesce(-sum(balance_effect) filter(where balance_effect<0),0)::numeric(12,2)
  from public.srk_worker_wallet_ledger where worker_id=v_worker;
end $$;
