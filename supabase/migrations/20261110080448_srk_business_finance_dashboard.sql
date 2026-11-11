-- Source-of-truth baseline for the Admin Business Expense & Profit Dashboard.
-- This migration was already applied to the primary project; the file is added here
-- so the working branch retains a reproducible migration history.
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.srk_business_expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_date date NOT NULL DEFAULT CURRENT_DATE,
  category text NOT NULL CHECK (category IN ('sms_otp','razorpay_fee','supabase','netlify','advertising','staff','other')),
  provider text NOT NULL DEFAULT '',
  description text NOT NULL CHECK (length(btrim(description)) BETWEEN 2 AND 300),
  amount numeric(12,2) NOT NULL CHECK (amount > 0 AND amount <= 100000000),
  reference text,
  notes text,
  recorded_by uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE private.srk_business_expenses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.srk_business_expenses FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_finance_add_expense(
  p_expense_date date,
  p_category text,
  p_provider text,
  p_description text,
  p_amount numeric,
  p_reference text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, private, auth, pg_temp
AS $function$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  IF p_category IS NULL OR p_category NOT IN ('sms_otp','razorpay_fee','supabase','netlify','advertising','staff','other') THEN
    RAISE EXCEPTION 'Invalid expense category' USING ERRCODE='22023';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 100000000 THEN
    RAISE EXCEPTION 'Expense amount must be greater than zero' USING ERRCODE='22023';
  END IF;
  IF p_description IS NULL OR length(btrim(p_description)) NOT BETWEEN 2 AND 300 THEN
    RAISE EXCEPTION 'Description must contain 2 to 300 characters' USING ERRCODE='22023';
  END IF;
  INSERT INTO private.srk_business_expenses
    (expense_date,category,provider,description,amount,reference,notes,recorded_by)
  VALUES
    (coalesce(p_expense_date,current_date),p_category,coalesce(p_provider,''),btrim(p_description),p_amount,
     nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_finance_list_expenses(
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_limit integer DEFAULT 200
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, private, auth, pg_temp
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.expense_date DESC,x.created_at DESC),'[]'::jsonb)
    INTO v_result
  FROM (
    SELECT id,expense_date,category,provider,description,amount,reference,notes,created_at
    FROM private.srk_business_expenses
    WHERE (p_start_date IS NULL OR expense_date >= p_start_date)
      AND (p_end_date IS NULL OR expense_date <= p_end_date)
    ORDER BY expense_date DESC,created_at DESC
    LIMIT greatest(1,least(coalesce(p_limit,200),500))
  ) x;
  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_finance_dashboard(
  p_period text DEFAULT 'monthly',
  p_anchor_date date DEFAULT CURRENT_DATE
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, private, auth, pg_temp
AS $function$
DECLARE
  v_start date;
  v_end date;
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  IF p_period NOT IN ('daily','monthly','yearly') THEN
    RAISE EXCEPTION 'Period must be daily, monthly, or yearly' USING ERRCODE='22023';
  END IF;
  IF p_period='daily' THEN
    v_start := coalesce(p_anchor_date,current_date);
    v_end := v_start;
  ELSIF p_period='monthly' THEN
    v_start := date_trunc('month',coalesce(p_anchor_date,current_date))::date;
    v_end := (v_start + interval '1 month - 1 day')::date;
  ELSE
    v_start := make_date(extract(year FROM coalesce(p_anchor_date,current_date))::int,1,1);
    v_end := make_date(extract(year FROM coalesce(p_anchor_date,current_date))::int,12,31);
  END IF;

  WITH paid_jobs AS (
    SELECT coalesce(amount_paid,0)::numeric AS gross,
           coalesce(commission_amount,round(coalesce(service_charge,0)*coalesce(commission_rate,15)/100,2))::numeric AS commission
    FROM public.service_bookings
    WHERE payment_status='paid' AND status='completed'
      AND coalesce(payment_verified_at,created_at)::date BETWEEN v_start AND v_end
  ),
  job_totals AS (
    SELECT count(*)::int AS paid_completed_bookings,
           coalesce(sum(gross),0)::numeric(14,2) AS customer_payments,
           coalesce(sum(commission),0)::numeric(14,2) AS platform_commission,
           coalesce(sum(gross-commission),0)::numeric(14,2) AS electrician_share
    FROM paid_jobs
  ),
  payout_totals AS (
    SELECT coalesce(sum(electrician_payable) FILTER (WHERE payout_status='paid'),0)::numeric(14,2) AS payout_paid,
           coalesce(sum(electrician_payable) FILTER (WHERE payout_status='pending'),0)::numeric(14,2) AS payout_pending
    FROM public.srk_electrician_payouts
    WHERE created_at::date BETWEEN v_start AND v_end
  ),
  expense_totals AS (
    SELECT coalesce(sum(amount),0)::numeric(14,2) AS total_expenses,
           coalesce(sum(amount) FILTER (WHERE category='sms_otp'),0)::numeric(14,2) AS sms_otp_cost,
           coalesce(sum(amount) FILTER (WHERE category='razorpay_fee'),0)::numeric(14,2) AS razorpay_fees,
           coalesce(sum(amount) FILTER (WHERE category='supabase'),0)::numeric(14,2) AS supabase_cost,
           coalesce(sum(amount) FILTER (WHERE category='netlify'),0)::numeric(14,2) AS netlify_cost,
           coalesce(sum(amount) FILTER (WHERE category='advertising'),0)::numeric(14,2) AS advertising_cost,
           coalesce(sum(amount) FILTER (WHERE category='staff'),0)::numeric(14,2) AS staff_cost,
           coalesce(sum(amount) FILTER (WHERE category='other'),0)::numeric(14,2) AS other_cost
    FROM private.srk_business_expenses
    WHERE expense_date BETWEEN v_start AND v_end
  )
  SELECT jsonb_build_object(
    'period',p_period,'start_date',v_start,'end_date',v_end,
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
  ) INTO v_result
  FROM job_totals j CROSS JOIN payout_totals p CROSS JOIN expense_totals e;
  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_finance_add_expense(date,text,text,text,numeric,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finance_add_expense(date,text,text,text,numeric,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_finance_list_expenses(date,date,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finance_list_expenses(date,date,integer) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_finance_dashboard(text,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finance_dashboard(text,date) TO authenticated;
