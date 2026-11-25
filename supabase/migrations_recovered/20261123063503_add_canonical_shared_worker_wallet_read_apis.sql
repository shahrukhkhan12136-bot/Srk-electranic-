
create or replace function public.srk_worker_get_my_wallet_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_worker uuid;
  v_ledger numeric(14,2);
  v_reserved numeric(14,2);
  v_held integer;
  v_cash_due numeric(14,2);
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  select id into v_worker
  from public.srk_worker_profiles
  where user_id = auth.uid()
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

  select greatest(0,-coalesce(sum(balance_effect),0))::numeric(14,2)
    into v_cash_due
  from public.srk_worker_wallet_ledger
  where worker_id=v_worker
    and entry_type in ('cash_commission_due','cash_commission_collected');

  return jsonb_build_object(
    'worker_id',v_worker,
    'currency','INR',
    'ledger_balance',v_ledger,
    'reserved_payout_amount',v_reserved,
    'available_for_payout',greatest(0,v_ledger-v_reserved),
    'net_balance_after_reservations',v_ledger-v_reserved,
    'cash_commission_outstanding',v_cash_due,
    'held_earning_count',v_held,
    'payout_blocked',v_held>0
  );
end;
$$;

create or replace function public.srk_worker_get_my_earnings()
returns table (
  earning_id uuid,
  booking_id uuid,
  service_type text,
  booking_created_at timestamptz,
  booking_status text,
  payment_status text,
  worker_role text,
  billable_seconds bigint,
  gross_service_earning numeric,
  company_commission_rate numeric,
  company_commission numeric,
  net_earning numeric,
  payout_status text,
  settlement_status text,
  ledger_credited_amount numeric
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_worker uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  select id into v_worker
  from public.srk_worker_profiles
  where user_id=auth.uid()
  limit 1;

  if v_worker is null then
    raise exception 'Worker profile not found' using errcode='P0002';
  end if;

  return query
  select e.id, e.booking_id, b.service_type, b.created_at, b.status,
         b.payment_status, e.worker_role, e.billable_seconds,
         e.gross_service_earning, e.company_commission_rate,
         e.company_commission, e.net_earning, e.payout_status,
         e.settlement_status,
         coalesce((select sum(l.balance_effect)
                   from public.srk_worker_wallet_ledger l
                   where l.earning_id=e.id
                     and l.entry_type in ('earning_credit','refund_adjustment')),0)::numeric
  from public.srk_worker_earnings e
  join public.service_bookings b on b.id=e.booking_id
  where e.worker_id=v_worker
  order by e.created_at desc
  limit 500;
end;
$$;

revoke all on function public.srk_worker_get_my_wallet_summary() from public, anon;
revoke all on function public.srk_worker_get_my_earnings() from public, anon;
grant execute on function public.srk_worker_get_my_wallet_summary() to authenticated;
grant execute on function public.srk_worker_get_my_earnings() to authenticated;
