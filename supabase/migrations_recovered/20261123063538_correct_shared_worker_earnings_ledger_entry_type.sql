
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
                     and l.entry_type in ('earning','refund_adjustment')),0)::numeric
  from public.srk_worker_earnings e
  join public.service_bookings b on b.id=e.booking_id
  where e.worker_id=v_worker
  order by e.created_at desc
  limit 500;
end;
$$;
revoke all on function public.srk_worker_get_my_earnings() from public, anon;
grant execute on function public.srk_worker_get_my_earnings() to authenticated;
