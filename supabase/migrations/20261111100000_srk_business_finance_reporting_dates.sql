-- SRK ELECTRONIC finance reporting: India-local date boundaries and payout settlement dates.
-- Existing architecture and ledger remain unchanged; this only corrects reporting dates and adds supporting indexes.

create index if not exists srk_business_expenses_expense_date_idx
  on private.srk_business_expenses (expense_date desc);

create index if not exists srk_business_expenses_recorded_by_idx
  on private.srk_business_expenses (recorded_by);

create index if not exists srk_electrician_payouts_paid_at_idx
  on public.srk_electrician_payouts (paid_at desc)
  where payout_status = 'paid' and paid_at is not null;

create or replace function public.srk_admin_finance_add_expense(
  p_expense_date date default ((now() at time zone 'Asia/Kolkata')::date),
  p_category text default null,
  p_provider text default '',
  p_description text default null,
  p_amount numeric default null,
  p_reference text default null,
  p_notes text default null
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth, pg_temp
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;

  if p_category is null or p_category not in
    ('sms_otp','razorpay_fee','supabase','netlify','advertising','staff','other') then
    raise exception 'Invalid expense category' using errcode='22023';
  end if;

  if p_amount is null or p_amount <= 0 or p_amount > 100000000 then
    raise exception 'Expense amount must be greater than zero' using errcode='22023';
  end if;

  if p_description is null or length(btrim(p_description)) not between 2 and 300 then
    raise exception 'Description must contain 2 to 300 characters' using errcode='22023';
  end if;

  if length(coalesce(p_provider,'')) > 100 then
    raise exception 'Provider name must not exceed 100 characters' using errcode='22023';
  end if;

  if p_reference is not null and length(btrim(p_reference)) > 120 then
    raise exception 'Reference must not exceed 120 characters' using errcode='22023';
  end if;

  if p_notes is not null and length(btrim(p_notes)) > 500 then
    raise exception 'Notes must not exceed 500 characters' using errcode='22023';
  end if;

  insert into private.srk_business_expenses
    (expense_date,category,provider,description,amount,reference,notes,recorded_by)
  values
    (coalesce(p_expense_date,(now() at time zone 'Asia/Kolkata')::date),
     p_category,coalesce(btrim(p_provider),''),btrim(p_description),p_amount,
     nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),auth.uid())
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.srk_admin_finance_dashboard(
  p_period text default 'monthly',
  p_anchor_date date default ((now() at time zone 'Asia/Kolkata')::date)
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth, pg_temp
as $$
declare
  v_start date;
  v_end date;
  v_anchor date := coalesce(p_anchor_date,(now() at time zone 'Asia/Kolkata')::date);
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;

  if p_period is null or p_period not in ('daily','monthly','yearly') then
    raise exception 'Period must be daily, monthly, or yearly' using errcode='22023';
  end if;

  if p_period='daily' then
    v_start := v_anchor;
    v_end := v_anchor;
  elsif p_period='monthly' then
    v_start := date_trunc('month',v_anchor)::date;
    v_end := (v_start + interval '1 month - 1 day')::date;
  else
    v_start := make_date(extract(year from v_anchor)::int,1,1);
    v_end := make_date(extract(year from v_anchor)::int,12,31);
  end if;

  with paid_jobs as (
    select
      coalesce(amount_paid,0)::numeric as gross,
      coalesce(
        commission_amount,
        round(coalesce(service_charge,0)*coalesce(commission_rate,15)/100,2)
      )::numeric as commission
    from public.service_bookings
    where payment_status='paid'
      and status='completed'
      and coalesce(payment_verified_at,created_at) is not null
      and (coalesce(payment_verified_at,created_at) at time zone 'Asia/Kolkata')::date
          between v_start and v_end
  ),
  job_totals as (
    select
      count(*)::int as paid_completed_bookings,
      coalesce(sum(gross),0)::numeric(14,2) as customer_payments,
      coalesce(sum(commission),0)::numeric(14,2) as platform_commission,
      coalesce(sum(gross-commission),0)::numeric(14,2) as electrician_share
    from paid_jobs
  ),
  booking_totals as (
    select count(*)::int as bookings_created
    from public.service_bookings
    where created_at is not null
      and (created_at at time zone 'Asia/Kolkata')::date between v_start and v_end
  ),
  payout_totals as (
    select
      coalesce(sum(electrician_payable) filter (
        where payout_status='paid'
          and paid_at is not null
          and (paid_at at time zone 'Asia/Kolkata')::date between v_start and v_end
      ),0)::numeric(14,2) as payout_paid,
      coalesce(sum(electrician_payable) filter (
        where payout_status='pending'
          and (created_at at time zone 'Asia/Kolkata')::date between v_start and v_end
      ),0)::numeric(14,2) as payout_pending
    from public.srk_electrician_payouts
  ),
  expense_totals as (
    select
      coalesce(sum(amount),0)::numeric(14,2) as total_expenses,
      coalesce(sum(amount) filter(where category='sms_otp'),0)::numeric(14,2) as sms_otp_cost,
      coalesce(sum(amount) filter(where category='razorpay_fee'),0)::numeric(14,2) as razorpay_fees,
      coalesce(sum(amount) filter(where category='supabase'),0)::numeric(14,2) as supabase_cost,
      coalesce(sum(amount) filter(where category='netlify'),0)::numeric(14,2) as netlify_cost,
      coalesce(sum(amount) filter(where category='advertising'),0)::numeric(14,2) as advertising_cost,
      coalesce(sum(amount) filter(where category='staff'),0)::numeric(14,2) as staff_cost,
      coalesce(sum(amount) filter(where category='other'),0)::numeric(14,2) as other_cost
    from private.srk_business_expenses
    where expense_date between v_start and v_end
  )
  select jsonb_build_object(
    'period',p_period,
    'start_date',v_start,
    'end_date',v_end,
    'bookings_created',b.bookings_created,
    'paid_completed_bookings',j.paid_completed_bookings,
    'customer_payments',j.customer_payments,
    'platform_commission',j.platform_commission,
    'electrician_share',j.electrician_share,
    'electrician_payout_paid',p.payout_paid,
    'electrician_payout_pending',p.payout_pending,
    'total_expenses',e.total_expenses,
    'sms_otp_cost',e.sms_otp_cost,
    'razorpay_fees',e.razorpay_fees,
    'supabase_cost',e.supabase_cost,
    'netlify_cost',e.netlify_cost,
    'advertising_cost',e.advertising_cost,
    'staff_cost',e.staff_cost,
    'other_cost',e.other_cost,
    'net_profit',j.platform_commission-e.total_expenses
  ) into v_result
  from job_totals j
  cross join booking_totals b
  cross join payout_totals p
  cross join expense_totals e;

  return v_result;
end;
$$;

revoke all on function public.srk_admin_finance_add_expense(date,text,text,text,numeric,text,text) from public, anon;
revoke all on function public.srk_admin_finance_dashboard(text,date) from public, anon;
grant execute on function public.srk_admin_finance_add_expense(date,text,text,text,numeric,text,text) to authenticated;
grant execute on function public.srk_admin_finance_dashboard(text,date) to authenticated;
