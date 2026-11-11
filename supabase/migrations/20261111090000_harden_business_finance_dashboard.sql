-- Harden and complete Admin Business Expense & Profit reporting.
-- Actual costs and estimates remain separate; replacing an estimate preserves history
-- while preventing it from being counted together with the actual invoice.
ALTER TABLE private.srk_business_expenses
  ADD COLUMN IF NOT EXISTS entry_type text NOT NULL DEFAULT 'actual';
ALTER TABLE private.srk_business_expenses
  ADD COLUMN IF NOT EXISTS superseded_at timestamptz;
ALTER TABLE private.srk_business_expenses
  ADD COLUMN IF NOT EXISTS superseded_by uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid='private.srk_business_expenses'::regclass
      AND conname='srk_business_expenses_entry_type_check'
  ) THEN
    ALTER TABLE private.srk_business_expenses
      ADD CONSTRAINT srk_business_expenses_entry_type_check
      CHECK (entry_type IN ('actual','estimate'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid='private.srk_business_expenses'::regclass
      AND conname='srk_business_expenses_superseded_by_fkey'
  ) THEN
    ALTER TABLE private.srk_business_expenses
      ADD CONSTRAINT srk_business_expenses_superseded_by_fkey
      FOREIGN KEY (superseded_by)
      REFERENCES private.srk_business_expenses(id)
      ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid='private.srk_business_expenses'::regclass
      AND conname='srk_business_expenses_superseded_pair_check'
  ) THEN
    ALTER TABLE private.srk_business_expenses
      ADD CONSTRAINT srk_business_expenses_superseded_pair_check
      CHECK ((superseded_at IS NULL) = (superseded_by IS NULL));
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS srk_business_expenses_recorded_by_idx
  ON private.srk_business_expenses(recorded_by);
CREATE INDEX IF NOT EXISTS srk_business_expenses_period_idx
  ON private.srk_business_expenses(expense_date,entry_type,superseded_at);
CREATE INDEX IF NOT EXISTS srk_business_expenses_superseded_by_idx
  ON private.srk_business_expenses(superseded_by);
CREATE UNIQUE INDEX IF NOT EXISTS srk_business_expenses_actual_reference_uq
  ON private.srk_business_expenses(category,lower(provider),lower(reference))
  WHERE entry_type='actual'
    AND superseded_at IS NULL
    AND reference IS NOT NULL
    AND btrim(reference) <> '';

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
  IF coalesce(length(p_provider),0)>120 OR coalesce(length(p_reference),0)>180 OR coalesce(length(p_notes),0)>1000 THEN
    RAISE EXCEPTION 'Provider, reference or notes are too long' USING ERRCODE='22023';
  END IF;
  INSERT INTO private.srk_business_expenses
    (expense_date,category,provider,description,amount,reference,notes,recorded_by,entry_type)
  VALUES
    (coalesce(p_expense_date,(now() AT TIME ZONE 'Asia/Kolkata')::date),p_category,coalesce(btrim(p_provider),''),btrim(p_description),p_amount,
     nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),auth.uid(),'actual')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_finance_add_expense_estimate(
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
    RAISE EXCEPTION 'Estimate amount must be greater than zero' USING ERRCODE='22023';
  END IF;
  IF p_description IS NULL OR length(btrim(p_description)) NOT BETWEEN 2 AND 300 THEN
    RAISE EXCEPTION 'Description must contain 2 to 300 characters' USING ERRCODE='22023';
  END IF;
  IF coalesce(length(p_provider),0)>120 OR coalesce(length(p_reference),0)>180 OR coalesce(length(p_notes),0)>1000 THEN
    RAISE EXCEPTION 'Provider, reference or notes are too long' USING ERRCODE='22023';
  END IF;
  INSERT INTO private.srk_business_expenses
    (expense_date,category,provider,description,amount,reference,notes,recorded_by,entry_type)
  VALUES
    (coalesce(p_expense_date,(now() AT TIME ZONE 'Asia/Kolkata')::date),p_category,coalesce(btrim(p_provider),''),btrim(p_description),p_amount,
     nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),auth.uid(),'estimate')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_finance_replace_estimate(
  p_estimate_id uuid,
  p_expense_date date,
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
  v_estimate private.srk_business_expenses%ROWTYPE;
  v_actual_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  IF p_estimate_id IS NULL OR p_amount IS NULL OR p_amount<=0 OR p_amount>100000000 THEN
    RAISE EXCEPTION 'A valid estimate and actual amount are required' USING ERRCODE='22023';
  END IF;
  IF p_description IS NULL OR length(btrim(p_description)) NOT BETWEEN 2 AND 300 THEN
    RAISE EXCEPTION 'Description must contain 2 to 300 characters' USING ERRCODE='22023';
  END IF;
  IF coalesce(length(p_provider),0)>120 OR coalesce(length(p_reference),0)>180 OR coalesce(length(p_notes),0)>1000 THEN
    RAISE EXCEPTION 'Provider, reference or notes are too long' USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_estimate
  FROM private.srk_business_expenses
  WHERE id=p_estimate_id AND entry_type='estimate' AND superseded_at IS NULL
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active estimate not found';
  END IF;

  INSERT INTO private.srk_business_expenses
    (expense_date,category,provider,description,amount,reference,notes,recorded_by,entry_type)
  VALUES
    (coalesce(p_expense_date,(now() AT TIME ZONE 'Asia/Kolkata')::date),v_estimate.category,coalesce(btrim(p_provider),v_estimate.provider),
     btrim(p_description),p_amount,nullif(btrim(p_reference),''),nullif(btrim(p_notes),''),auth.uid(),'actual')
  RETURNING id INTO v_actual_id;

  UPDATE private.srk_business_expenses
  SET superseded_at=now(),superseded_by=v_actual_id
  WHERE id=p_estimate_id AND superseded_at IS NULL;
  RETURN v_actual_id;
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
  IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL AND p_start_date>p_end_date THEN
    RAISE EXCEPTION 'Start date must be on or before end date' USING ERRCODE='22023';
  END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.expense_date DESC,x.created_at DESC),'[]'::jsonb)
    INTO v_result
  FROM (
    SELECT id,expense_date,category,provider,description,amount,entry_type,
           reference,notes,created_at,superseded_at,superseded_by
    FROM private.srk_business_expenses
    WHERE (p_start_date IS NULL OR expense_date>=p_start_date)
      AND (p_end_date IS NULL OR expense_date<=p_end_date)
    ORDER BY expense_date DESC,created_at DESC
    LIMIT greatest(1,least(coalesce(p_limit,200),500))
  ) x;
  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_finance_dashboard(
  p_period text DEFAULT 'monthly',
  p_anchor_date date DEFAULT ((now() AT TIME ZONE 'Asia/Kolkata')::date)
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
  IF p_period IS NULL OR p_period NOT IN ('daily','monthly','yearly') THEN
    RAISE EXCEPTION 'Period must be daily, monthly, or yearly' USING ERRCODE='22023';
  END IF;

  IF p_period='daily' THEN
    v_start:=coalesce(p_anchor_date,(now() AT TIME ZONE 'Asia/Kolkata')::date);
    v_end:=v_start;
  ELSIF p_period='monthly' THEN
    v_start:=date_trunc('month',coalesce(p_anchor_date,(now() AT TIME ZONE 'Asia/Kolkata')::date))::date;
    v_end:=(v_start+interval '1 month - 1 day')::date;
  ELSE
    v_start:=make_date(extract(year FROM coalesce(p_anchor_date,(now() AT TIME ZONE 'Asia/Kolkata')::date))::int,1,1);
    v_end:=make_date(extract(year FROM coalesce(p_anchor_date,(now() AT TIME ZONE 'Asia/Kolkata')::date))::int,12,31);
  END IF;

  WITH completion_dates AS (
    SELECT booking_id,max(changed_at) AS completed_at
    FROM public.service_booking_status_history
    WHERE new_status='completed'
    GROUP BY booking_id
  ),
  completed_totals AS (
    SELECT count(*)::int AS completed_bookings
    FROM public.service_bookings b
    LEFT JOIN completion_dates h ON h.booking_id=b.id
    WHERE b.status='completed'
      AND (coalesce(h.completed_at,b.created_at) AT TIME ZONE 'Asia/Kolkata')::date BETWEEN v_start AND v_end
  ),
  paid_jobs AS (
    -- One payout row per booking is the authoritative, already verified commission source.
    -- This avoids re-counting payment rows and excludes refunded/unsettled ledger states.
    SELECT b.id,b.amount_paid,p.platform_commission,p.electrician_payable,p.materials_amount
    FROM public.service_bookings b
    JOIN public.srk_electrician_payouts p ON p.booking_id=b.id
    WHERE b.status='completed'
      AND b.payment_status='paid'
      AND b.payment_verified_at IS NOT NULL
      AND p.payout_status IN ('pending','paid')
      AND (b.payment_verified_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN v_start AND v_end
  ),
  job_totals AS (
    SELECT count(*)::int AS paid_completed_bookings,
           coalesce(sum(amount_paid),0)::numeric(14,2) AS customer_payments,
           coalesce(sum(platform_commission),0)::numeric(14,2) AS platform_commission,
           coalesce(sum(electrician_payable),0)::numeric(14,2) AS electrician_share,
           coalesce(sum(materials_amount),0)::numeric(14,2) AS materials_amount
    FROM paid_jobs
  ),
  unmatched_totals AS (
    SELECT count(*)::int AS unmatched_paid_completed_bookings
    FROM public.service_bookings b
    WHERE b.status='completed'
      AND b.payment_status='paid'
      AND b.payment_verified_at IS NOT NULL
      AND (b.payment_verified_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN v_start AND v_end
      AND NOT EXISTS (
        SELECT 1 FROM public.srk_electrician_payouts p
        WHERE p.booking_id=b.id AND p.payout_status IN ('pending','paid')
      )
  ),
  payout_totals AS (
    SELECT coalesce(sum(electrician_payable) FILTER (
             WHERE payout_status='paid' AND (paid_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN v_start AND v_end
           ),0)::numeric(14,2) AS payout_paid,
           coalesce(sum(electrician_payable) FILTER (
             WHERE payout_status='pending' AND (created_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN v_start AND v_end
           ),0)::numeric(14,2) AS payout_pending
    FROM public.srk_electrician_payouts
  ),
  expense_totals AS (
    SELECT coalesce(sum(amount) FILTER (WHERE entry_type='actual'),0)::numeric(14,2) AS actual_expenses,
           coalesce(sum(amount) FILTER (WHERE entry_type='estimate'),0)::numeric(14,2) AS estimated_expenses,
           coalesce(sum(amount) FILTER (WHERE entry_type='actual' AND category='sms_otp'),0)::numeric(14,2) AS sms_otp_cost,
           coalesce(sum(amount) FILTER (WHERE entry_type='actual' AND category='razorpay_fee'),0)::numeric(14,2) AS razorpay_fees,
           coalesce(sum(amount) FILTER (WHERE entry_type='actual' AND category='supabase'),0)::numeric(14,2) AS supabase_cost,
           coalesce(sum(amount) FILTER (WHERE entry_type='actual' AND category='netlify'),0)::numeric(14,2) AS netlify_cost,
           coalesce(sum(amount) FILTER (WHERE entry_type='actual' AND category='advertising'),0)::numeric(14,2) AS advertising_cost,
           coalesce(sum(amount) FILTER (WHERE entry_type='actual' AND category='staff'),0)::numeric(14,2) AS staff_cost,
           coalesce(sum(amount) FILTER (WHERE entry_type='actual' AND category='other'),0)::numeric(14,2) AS other_cost
    FROM private.srk_business_expenses
    WHERE expense_date BETWEEN v_start AND v_end
      AND superseded_at IS NULL
  ),
  category_totals AS (
    SELECT category,
           coalesce(sum(amount) FILTER (WHERE entry_type='actual'),0)::numeric(14,2) AS actual_amount,
           coalesce(sum(amount) FILTER (WHERE entry_type='estimate'),0)::numeric(14,2) AS estimated_amount
    FROM private.srk_business_expenses
    WHERE expense_date BETWEEN v_start AND v_end
      AND superseded_at IS NULL
    GROUP BY category
  )
  SELECT jsonb_build_object(
    'period',p_period,
    'start_date',v_start,
    'end_date',v_end,
    'completed_bookings',c.completed_bookings,
    'paid_completed_bookings',j.paid_completed_bookings,
    'unmatched_paid_completed_bookings',u.unmatched_paid_completed_bookings,
    'customer_payments',j.customer_payments,
    'materials_amount',j.materials_amount,
    'platform_commission',j.platform_commission,
    'electrician_share',j.electrician_share,
    'electrician_payout_paid',p.payout_paid,
    'electrician_payout_pending',p.payout_pending,
    'total_expenses',e.actual_expenses,
    'estimated_expenses',e.estimated_expenses,
    'sms_otp_cost',e.sms_otp_cost,
    'razorpay_fees',e.razorpay_fees,
    'supabase_cost',e.supabase_cost,
    'netlify_cost',e.netlify_cost,
    'advertising_cost',e.advertising_cost,
    'staff_cost',e.staff_cost,
    'other_cost',e.other_cost,
    'expense_breakdown',coalesce((
      SELECT jsonb_object_agg(category,jsonb_build_object('actual',actual_amount,'estimate',estimated_amount))
      FROM category_totals
    ),'{}'::jsonb),
    'net_profit',j.platform_commission-e.actual_expenses,
    'projected_net_profit',j.platform_commission-e.actual_expenses-e.estimated_expenses,
    'commission_source','srk_electrician_payouts'
  ) INTO v_result
  FROM completed_totals c
  CROSS JOIN job_totals j
  CROSS JOIN unmatched_totals u
  CROSS JOIN payout_totals p
  CROSS JOIN expense_totals e;

  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_finance_add_expense(date,text,text,text,numeric,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finance_add_expense(date,text,text,text,numeric,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_finance_add_expense_estimate(date,text,text,text,numeric,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finance_add_expense_estimate(date,text,text,text,numeric,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_finance_replace_estimate(uuid,date,text,text,numeric,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finance_replace_estimate(uuid,date,text,text,numeric,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_finance_list_expenses(date,date,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finance_list_expenses(date,date,integer) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_finance_dashboard(text,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finance_dashboard(text,date) TO authenticated;
