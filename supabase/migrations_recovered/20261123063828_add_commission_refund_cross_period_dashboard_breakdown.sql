
create or replace function public.srk_admin_commission_refund_period_breakdown(
  p_period text default 'monthly',
  p_anchor_date date default ((now() at time zone 'Asia/Kolkata')::date)
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_anchor date := coalesce(p_anchor_date,(now() at time zone 'Asia/Kolkata')::date);
  v_start date;
  v_end date;
  v_result jsonb;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('payments.read') then
    raise exception 'Payment dashboard permission required' using errcode='42501';
  end if;
  if p_period not in ('daily','monthly','yearly') then
    raise exception 'Period must be daily, monthly or yearly' using errcode='22023';
  end if;

  if p_period='daily' then
    v_start:=v_anchor; v_end:=v_anchor;
  elsif p_period='monthly' then
    v_start:=date_trunc('month',v_anchor)::date;
    v_end:=(v_start+interval '1 month - 1 day')::date;
  else
    v_start:=make_date(extract(year from v_anchor)::int,1,1);
    v_end:=make_date(extract(year from v_anchor)::int,12,31);
  end if;

  with refund_period as (
    select r.id,r.booking_id,r.commission_refund_amount,
      (r.recorded_at at time zone 'Asia/Kolkata')::date refund_recorded_date,
      (coalesce(b.payment_verified_at,b.created_at) at time zone 'Asia/Kolkata')::date original_payment_date
    from public.srk_company_commission_refund_reconciliations r
    join public.service_bookings b on b.id=r.booking_id
    where (r.recorded_at at time zone 'Asia/Kolkata')::date between v_start and v_end
  )
  select jsonb_build_object(
    'period',p_period,'start_date',v_start,'end_date',v_end,
    'commission_refund_total_recorded_in_period',
      coalesce(sum(commission_refund_amount),0)::numeric(14,2),
    'refunds_against_same_period_bookings',
      coalesce(sum(commission_refund_amount) filter(where original_payment_date between v_start and v_end),0)::numeric(14,2),
    'refunds_against_prior_period_bookings',
      coalesce(sum(commission_refund_amount) filter(where original_payment_date < v_start),0)::numeric(14,2),
    'refunds_against_future_dated_bookings',
      coalesce(sum(commission_refund_amount) filter(where original_payment_date > v_end),0)::numeric(14,2),
    'reconciliation_count',count(*)::int
  ) into v_result
  from refund_period;

  return v_result;
end;
$$;
revoke all on function public.srk_admin_commission_refund_period_breakdown(text,date) from public, anon;
grant execute on function public.srk_admin_commission_refund_period_breakdown(text,date) to authenticated;
