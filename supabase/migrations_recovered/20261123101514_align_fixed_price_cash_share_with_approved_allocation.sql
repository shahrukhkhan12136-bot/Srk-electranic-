CREATE OR REPLACE FUNCTION public.srk_admin_settle_cash_worker_share(
  p_earning_id uuid,
  p_actual_cash_share numeric,
  p_reason text
)
RETURNS public.srk_worker_earnings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
DECLARE
  v public.srk_worker_earnings%ROWTYPE;
  v_booking public.service_bookings%ROWTYPE;
  v_worker_id uuid;
  v_service_total numeric(12,2);
  v_already_allocated numeric(12,2);
  v_commission numeric(12,2);
  v_existing_due numeric(12,2);
  v_fixed_allocation numeric(12,2);
BEGIN
  IF auth.uid() IS NULL OR NOT public.srk_has_admin_permission('payouts.manage') THEN
    RAISE EXCEPTION 'Payout management permission required' USING errcode='42501';
  END IF;
  IF p_earning_id IS NULL OR p_actual_cash_share IS NULL
     OR p_actual_cash_share < 0 OR p_actual_cash_share <> round(p_actual_cash_share,2)
     OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 10 AND 2000 THEN
    RAISE EXCEPTION 'Valid earning, non-negative two-decimal cash share and 10-2000 character reason are required'
      USING errcode='22023';
  END IF;

  SELECT worker_id INTO v_worker_id
  FROM public.srk_worker_earnings WHERE id=p_earning_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Worker earning not found'; END IF;

  PERFORM 1 FROM public.srk_worker_profiles WHERE id=v_worker_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Worker profile not found'; END IF;

  SELECT * INTO v FROM public.srk_worker_earnings
  WHERE id=p_earning_id FOR UPDATE;
  IF NOT FOUND OR v.worker_id<>v_worker_id OR v.payment_method<>'cash'
     OR v.settlement_status<>'cash_split_pending' THEN
    RAISE EXCEPTION 'Cash earning is not awaiting split settlement';
  END IF;

  SELECT * INTO v_booking FROM public.service_bookings
  WHERE id=v.booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
  IF v_booking.payment_status<>'paid' THEN
    RAISE EXCEPTION 'Cash payment must be confirmed before settlement';
  END IF;

  SELECT f.service_amount INTO v_service_total
  FROM public.srk_booking_final_bills f
  WHERE f.id=v.bill_id AND f.booking_id=v.booking_id;
  IF v_service_total IS NULL THEN
    RAISE EXCEPTION 'Final bill labour amount not found';
  END IF;

  -- Fixed-price allocations are the authoritative per-worker gross split.
  -- Cash settlement must not create a second, conflicting split.
  IF v_booking.pricing_unit_snapshot='per_item' THEN
    SELECT a.gross_service_earning INTO v_fixed_allocation
    FROM public.srk_fixed_price_worker_allocations a
    WHERE a.booking_id=v.booking_id
      AND a.booking_worker_id=v.booking_worker_id
      AND a.worker_id=v.worker_id
    FOR SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Approved fixed-price worker allocation is missing';
    END IF;
    IF p_actual_cash_share IS DISTINCT FROM v_fixed_allocation THEN
      RAISE EXCEPTION 'Cash share must match the approved fixed-price worker allocation';
    END IF;
  END IF;

  -- Count every previously settled cash share even if a later refund changed
  -- its settlement_status to reversed/held. The immutable ledger entry is the
  -- settlement evidence; status alone must not free the labour cap.
  SELECT coalesce(sum(e.gross_service_earning),0)
    INTO v_already_allocated
  FROM public.srk_worker_earnings e
  WHERE e.booking_id=v.booking_id
    AND e.payment_method='cash'
    AND e.id<>v.id
    AND EXISTS (
      SELECT 1 FROM public.srk_worker_wallet_ledger l
      WHERE l.earning_id=e.id AND l.entry_type='cash_commission_due'
    );

  IF v_already_allocated+p_actual_cash_share>v_service_total THEN
    RAISE EXCEPTION 'Cash shares exceed total labour amount';
  END IF;
  IF v.company_commission_rate IS NULL
     OR v.company_commission_rate<0 OR v.company_commission_rate>100 THEN
    RAISE EXCEPTION 'Earning commission snapshot is invalid';
  END IF;

  v_commission:=round(p_actual_cash_share*v.company_commission_rate/100,2);

  -- Refuse an idempotency-key collision if a prior ledger row has different
  -- financial content; do not silently accept a stale commission amount.
  SELECT amount INTO v_existing_due
  FROM public.srk_worker_wallet_ledger
  WHERE idempotency_key='cash-share-commission:'||v.id::text;
  IF FOUND AND v_existing_due<>v_commission THEN
    RAISE EXCEPTION 'Existing cash commission ledger amount differs; reconciliation required';
  END IF;

  UPDATE public.srk_worker_earnings
  SET gross_service_earning=p_actual_cash_share,
      company_commission=v_commission,
      net_earning=p_actual_cash_share-v_commission,
      settlement_status='cash_commission_due',
      payout_status='pending',
      admin_note=btrim(p_reason),
      updated_at=clock_timestamp()
  WHERE id=p_earning_id
  RETURNING * INTO v;

  INSERT INTO public.srk_worker_wallet_ledger(
    worker_id,booking_id,earning_id,entry_type,amount,balance_effect,
    description,idempotency_key
  )
  VALUES(
    v.worker_id,v.booking_id,v.id,'cash_commission_due',
    v_commission,-v_commission,
    'Admin-settled cash share commission: '||btrim(p_reason),
    'cash-share-commission:'||v.id::text
  )
  ON CONFLICT(idempotency_key) DO NOTHING;

  RETURN v;
END
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_settle_cash_worker_share(uuid,numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_settle_cash_worker_share(uuid,numeric,text) TO authenticated;