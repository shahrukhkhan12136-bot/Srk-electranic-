-- SRK ELECTRONIC business finance ledger and admin-only reporting
-- Expense records are append-only and stored in a non-exposed schema.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.srk_business_expenses (
  id uuid primary key default gen_random_uuid(),
  expense_date date not null default current_date,
  category text not null check (category in ('sms_otp','razorpay_fee','supabase','netlify','advertising','staff','other')),
  provider text not null default '',
  description text not null check (length(btrim(description)) between 2 and 300),
  amount numeric(12,2) not null check (amount > 0 and amount <= 100000000),
  reference text,
  notes text,
  recorded_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
alter table private.srk_business_expenses enable row level security;
revoke all on private.srk_business_expenses from public, anon, authenticated;

create or replace function public.srk_admin_finance_add_expense(
  p_expense_date date, p_category text, p_provider text, p_description text,
  p_amount numeric, p_reference text default null, p_notes text default null
) returns uuid
language plpgsql security definer
set search_path = pg_catalog, public, private, auth, pg_temp
as $$
declare v_id uuid;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;
  if p_category not in ('sms_otp','razorpay_fee','supabase','netlify','advertising','staff','other') then
    raise exception 'Invalid expense category' using errcode='22023';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount > 100000000 then
    raise exception 'Expense amount must be greater than zero' using errcode='22023';
  end if;
  if p_description is null or length(btrim(p_description)) not between 2 and 300 then
    raise exception 'Description must contain 2 to 300 characters' using errcode='22023';
  end if;
  insert into private.srk_business_expenses(expense_date,category,provider,description,amount,reference,notes,recorded_by)
  values(coalesce(p_expense_date,current_date),p_category,coalesce(p_provider,''),btrim(p_description),p_amount,
         nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.srk_admin_finance_list_expenses(
  p_start_date date default null, p_end_date date default null, p_limit integer default 200
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, private, auth, pg_temp
as $$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.expense_date desc, x.created_at desc),'[]'::jsonb)
  into v_result
  from (
    select id,expense_date,category,provider,description,amount,reference,notes,created_at
    from private.srk_business_expenses
    where (p_start_date is null or expense_date >= p_start_date)
      and (p_end_date is null or expense_date <= p_end_date)
    order by expense_date desc,created_at desc
    limit greatest(1,least(coalesce(p_limit,200),500))
  ) x;
  return v_result;
end;
$$;

create or replace function public.srk_admin_finance_dashboard(
  p_period text default 'monthly', p_anchor_date date default current_date
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, private, auth, pg_temp
as $$
declare v_start date; v_end date; v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode='42501';
  end if;
  if p_period not in ('daily','monthly','yearly') then
    raise exception 'Period must be daily, monthly, or yearly' using errcode='22023';
  end if;
  if p_period='daily' then
    v_start := coalesce(p_anchor_date,current_date); v_end := v_start;
  elsif p_period='monthly' then
    v_start := date_trunc('month',coalesce(p_anchor_date,current_date))::date;
    v_end := (v_start + interval '1 month - 1 day')::date;
  else
    v_start := make_date(extract(year from coalesce(p_anchor_date,current_date))::int,1,1);
    v_end := make_date(extract(year from coalesce(p_anchor_date,current_date))::int,12,31);
  end if;
  with paid_jobs as (
    select coalesce(amount_paid,0)::numeric as gross,
      coalesce(commission_amount,round(coalesce(service_charge,0)*coalesce(commission_rate,15)/100,2))::numeric as commission
    from public.service_bookings
    where payment_status='paid' and status='completed'
      and coalesce(payment_verified_at,created_at)::date between v_start and v_end
  ),
  job_totals as (
    select count(*)::int as paid_completed_bookings,
      coalesce(sum(gross),0)::numeric(14,2) as customer_payments,
      coalesce(sum(commission),0)::numeric(14,2) as platform_commission,
      coalesce(sum(gross-commission),0)::numeric(14,2) as electrician_share
    from paid_jobs
  ),
  payout_totals as (
    select coalesce(sum(electrician_payable) filter(where payout_status='paid'),0)::numeric(14,2) as payout_paid,
      coalesce(sum(electrician_payable) filter(where payout_status='pending'),0)::numeric(14,2) as payout_pending
    from public.srk_electrician_payouts where created_at::date between v_start and v_end
  ),
  expense_totals as (
    select coalesce(sum(amount),0)::numeric(14,2) as total_expenses,
      coalesce(sum(amount) filter(where category='sms_otp'),0)::numeric(14,2) as sms_otp_cost,
      coalesce(sum(amount) filter(where category='razorpay_fee'),0)::numeric(14,2) as razorpay_fees,
      coalesce(sum(amount) filter(where category='supabase'),0)::numeric(14,2) as supabase_cost,
      coalesce(sum(amount) filter(where category='netlify'),0)::numeric(14,2) as netlify_cost,
      coalesce(sum(amount) filter(where category='advertising'),0)::numeric(14,2) as advertising_cost,
      coalesce(sum(amount) filter(where category='staff'),0)::numeric(14,2) as staff_cost,
      coalesce(sum(amount) filter(where category='other'),0)::numeric(14,2) as other_cost
    from private.srk_business_expenses where expense_date between v_start and v_end
  )
  select jsonb_build_object(
    'period',p_period,'start_date',v_start,'end_date',v_end,
    'paid_completed_bookings',j.paid_completed_bookings,'customer_payments',j.customer_payments,
    'platform_commission',j.platform_commission,'electrician_share',j.electrician_share,
    'electrician_payout_paid',p.payout_paid,'electrician_payout_pending',p.payout_pending,
    'total_expenses',e.total_expenses,'sms_otp_cost',e.sms_otp_cost,'razorpay_fees',e.razorpay_fees,
    'supabase_cost',e.supabase_cost,'netlify_cost',e.netlify_cost,'advertising_cost',e.advertising_cost,
    'staff_cost',e.staff_cost,'other_cost',e.other_cost,'net_profit',j.platform_commission-e.total_expenses
  ) into v_result from job_totals j cross join payout_totals p cross join expense_totals e;
  return v_result;
end;
$$;

revoke all on function public.srk_admin_finance_add_expense(date,text,text,text,numeric,text,text) from public, anon;
revoke all on function public.srk_admin_finance_list_expenses(date,date,integer) from public, anon;
revoke all on function public.srk_admin_finance_dashboard(text,date) from public, anon;
grant execute on function public.srk_admin_finance_add_expense(date,text,text,text,numeric,text,text) to authenticated;
grant execute on function public.srk_admin_finance_list_expenses(date,date,integer) to authenticated;
grant execute on function public.srk_admin_finance_dashboard(text,date) to authenticated;
