
create or replace function public.srk_admin_finance_dashboard(
  p_period text default 'monthly',
  p_anchor_date date default ((now() at time zone 'Asia/Kolkata')::date)
) returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  v_start date;
  v_end date;
  v_anchor date:=coalesce(p_anchor_date,(now() at time zone 'Asia/Kolkata')::date);
  v_result jsonb;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('payments.read') then
    raise exception 'Payment dashboard permission required' using errcode='42501';
  end if;
  if p_period not in ('daily','monthly','yearly') then raise exception 'Period must be daily, monthly or yearly'; end if;

  if p_period='daily' then v_start:=v_anchor; v_end:=v_anchor;
  elsif p_period='monthly' then v_start:=date_trunc('month',v_anchor)::date; v_end:=(v_start+interval '1 month - 1 day')::date;
  else v_start:=make_date(extract(year from v_anchor)::int,1,1); v_end:=make_date(extract(year from v_anchor)::int,12,31);
  end if;

  with paid_jobs as (
    select b.id,coalesce(b.amount_paid,0)::numeric gross,
      case when exists(select 1 from public.srk_worker_earnings e where e.booking_id=b.id)
        then (select coalesce(sum(e.company_commission),0) from public.srk_worker_earnings e where e.booking_id=b.id)
        else coalesce(b.commission_amount,round(coalesce(b.service_charge,0)*coalesce(b.commission_rate,15)/100,2))
      end::numeric commission
    from public.service_bookings b
    where b.payment_status='paid' and b.status='completed'
      and (coalesce(b.payment_verified_at,b.created_at) at time zone 'Asia/Kolkata')::date between v_start and v_end
  ),
  bookings as (
    select count(*)::int created from public.service_bookings
    where (created_at at time zone 'Asia/Kolkata')::date between v_start and v_end
  ),
  earnings as (
    select coalesce(sum(company_commission),0)::numeric(14,2) commission,
      coalesce(sum(net_earning),0)::numeric(14,2) worker_net
    from public.srk_worker_earnings e
    join public.service_bookings b on b.id=e.booking_id
    where b.payment_status='paid' and b.status='completed'
      and (coalesce(b.payment_verified_at,b.created_at) at time zone 'Asia/Kolkata')::date between v_start and v_end
  ),
  legacy as (
    select coalesce(sum(p.electrician_payable) filter(where p.payout_status='paid' and (p.paid_at at time zone 'Asia/Kolkata')::date between v_start and v_end),0)::numeric(14,2) paid,
      coalesce(sum(p.electrician_payable) filter(where p.payout_status='pending' and (p.created_at at time zone 'Asia/Kolkata')::date between v_start and v_end),0)::numeric(14,2) pending
    from public.srk_electrician_payouts p
  ),
  new_payouts as (
    select coalesce(sum(approved_amount) filter(where status='paid' and (paid_at at time zone 'Asia/Kolkata')::date between v_start and v_end),0)::numeric(14,2) paid,
      coalesce(sum(coalesce(approved_amount,requested_amount)) filter(where status in ('requested','under_review','approved') and (requested_at at time zone 'Asia/Kolkata')::date between v_start and v_end),0)::numeric(14,2) pending
    from public.srk_worker_payout_requests
  ),
  cash_dues as (
    select coalesce(sum(amount),0)::numeric(14,2) due
    from public.srk_worker_wallet_ledger
    where entry_type='cash_commission_due' and (created_at at time zone 'Asia/Kolkata')::date between v_start and v_end
  )
  select jsonb_build_object(
    'period',p_period,'start_date',v_start,'end_date',v_end,
    'bookings_created',b.created,
    'paid_completed_bookings',(select count(*)::int from paid_jobs),
    'customer_payments',(select coalesce(sum(gross),0)::numeric(14,2) from paid_jobs),
    'platform_commission',(select coalesce(sum(commission),0)::numeric(14,2) from paid_jobs),
    'worker_net_earnings',e.worker_net,
    'worker_payout_paid',l.paid+n.paid,
    'worker_payout_pending',l.pending+n.pending,
    'cash_commission_due',c.due
  ) into v_result
  from bookings b cross join earnings e cross join legacy l cross join new_payouts n cross join cash_dues c;

  return v_result;
end $$;

drop function if exists public.srk_admin_finance_add_expense(date,text,text,text,numeric,text,text);
drop function if exists public.srk_admin_finance_list_expenses(date,date,integer);
drop table if exists private.srk_business_expenses;

revoke all on function public.srk_admin_finance_dashboard(text,date) from public,anon;
grant execute on function public.srk_admin_finance_dashboard(text,date) to authenticated,service_role;
