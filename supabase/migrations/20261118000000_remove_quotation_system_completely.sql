-- Retire the quotation system end-to-end.
-- Historical price data is first archived by 20261115210000; it remains read-only
-- evidence for old receipts/refunds/reconciliation and is never used by new bookings.

-- Remove all live quotation and legacy quote-based payment/inspection RPCs.
DROP FUNCTION IF EXISTS public.srk_submit_booking_quote(uuid,numeric,numeric,text);
DROP FUNCTION IF EXISTS public.srk_customer_respond_booking_quote(uuid,text);
DROP FUNCTION IF EXISTS public.srk_update_booking_work_status(uuid,text);
DROP FUNCTION IF EXISTS public.srk_get_my_assigned_booking_quote_details();
DROP FUNCTION IF EXISTS public.srk_get_my_offer_price_details();
DROP FUNCTION IF EXISTS public.srk_electrician_confirm_cash_payment(uuid);
DROP FUNCTION IF EXISTS public.srk_get_my_assigned_cash_payment(uuid);
DROP FUNCTION IF EXISTS public.srk_admin_record_manual_payment(uuid,text,text,text);

-- Retire the old amount-paid commission trigger. New commission is based only
-- on the immutable server-timed labour bill.
DROP TRIGGER IF EXISTS srk_calculate_booking_commission ON public.service_bookings;
DROP FUNCTION IF EXISTS public.srk_calculate_booking_commission();

-- New-category payout rows are generated only from the immutable labour bill.
-- Legacy rows are never re-priced; their existing payout ledger remains intact.
CREATE OR REPLACE FUNCTION public.srk_create_electrician_payable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_bill public.srk_booking_labour_bills%rowtype;
  v_service numeric(12,2);
  v_commission numeric(12,2);
  v_rate numeric(7,2);
BEGIN
  IF NEW.payment_status='paid'
     AND NEW.status='completed'
     AND NEW.selected_category IS NOT NULL
     AND NEW.assigned_electrician_id IS NOT NULL
     AND NEW.payment_verified_at IS NOT NULL
     AND (
       NEW.razorpay_payment_id IS NOT NULL
       OR EXISTS (
         SELECT 1 FROM public.srk_manual_payment_entries e
         WHERE e.booking_id=NEW.id
           AND round(coalesce(e.amount,0),2)=round(coalesce(NEW.amount_paid,0),2)
           AND lower(btrim(coalesce(e.payment_method,'')))=lower(btrim(coalesce(NEW.payment_method,'')))
       )
     ) THEN
    SELECT * INTO v_bill
      FROM public.srk_booking_labour_bills
     WHERE booking_id=NEW.id;

    IF NOT FOUND
       OR v_bill.electrician_profile_id IS DISTINCT FROM NEW.assigned_electrician_id
       OR v_bill.labour_amount_paise IS NULL
       OR v_bill.labour_amount_paise<=0 THEN
      RAISE EXCEPTION 'IMMUTABLE_LABOUR_BILL_REQUIRED_FOR_PAYOUT';
    END IF;

    v_service:=round(v_bill.labour_amount_paise/100.0,2);
    v_rate:=NEW.commission_rate;
    IF v_rate IS NULL OR v_rate<0 OR v_rate>100 THEN
      RAISE EXCEPTION 'COMMISSION_RATE_MUST_BE_BETWEEN_0_AND_100';
    END IF;
    v_commission:=round(v_service*v_rate/100,2);

    INSERT INTO public.srk_electrician_payouts(
      booking_id,electrician_profile_id,razorpay_payment_id,
      gross_service_amount,materials_amount,platform_commission,
      electrician_payable,payout_status
    ) VALUES(
      NEW.id,NEW.assigned_electrician_id,NEW.razorpay_payment_id,
      v_service,0,v_commission,round(v_service-v_commission,2),'pending'
    )
    ON CONFLICT(booking_id) DO UPDATE SET
      electrician_profile_id=excluded.electrician_profile_id,
      razorpay_payment_id=excluded.razorpay_payment_id,
      gross_service_amount=excluded.gross_service_amount,
      materials_amount=0,
      platform_commission=excluded.platform_commission,
      electrician_payable=excluded.electrician_payable,
      updated_at=clock_timestamp()
    WHERE public.srk_electrician_payouts.payout_status='pending';
  ELSIF NEW.payment_status='refunded' THEN
    UPDATE public.srk_electrician_payouts
       SET payout_status='refunded',updated_at=clock_timestamp()
     WHERE booking_id=NEW.id AND payout_status='pending';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_create_electrician_payable() FROM PUBLIC,anon,authenticated;

-- Main Admin payout settlement validates either the immutable new labour bill
-- or archived historical financial evidence. No live quote status is consulted.
CREATE OR REPLACE FUNCTION public.srk_admin_mark_electrician_payout_paid(
  p_payout_id uuid,p_method text,p_reference text,p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_row public.srk_electrician_payouts%rowtype;
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_labour_bills%rowtype;
  v_legacy srk_private.legacy_booking_financial_evidence%rowtype;
  v_booking_id uuid;
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_commission numeric(12,2);
  v_payable numeric(12,2);
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING errcode='42501';
  END IF;
  IF p_payout_id IS NULL THEN RAISE EXCEPTION 'Payout ID is required'; END IF;
  IF p_method IS NULL OR p_method NOT IN ('upi','bank') THEN
    RAISE EXCEPTION 'Payout method must be upi or bank';
  END IF;
  IF p_reference IS NULL OR length(btrim(p_reference)) NOT BETWEEN 4 AND 120 THEN
    RAISE EXCEPTION 'Valid UTR / UPI reference is required';
  END IF;
  IF p_note IS NOT NULL AND length(p_note)>250 THEN
    RAISE EXCEPTION 'Payout note is too long';
  END IF;

  SELECT booking_id INTO v_booking_id
    FROM public.srk_electrician_payouts WHERE id=p_payout_id;
  IF NOT FOUND OR v_booking_id IS NULL THEN
    RAISE EXCEPTION 'Payout record not found or has no booking';
  END IF;

  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=v_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Payout booking not found'; END IF;

  SELECT * INTO v_row FROM public.srk_electrician_payouts
   WHERE id=p_payout_id FOR UPDATE;
  IF NOT FOUND OR v_row.booking_id IS DISTINCT FROM v_booking_id THEN
    RAISE EXCEPTION 'Payout record changed; retry the operation';
  END IF;
  IF v_row.payout_status<>'pending' THEN
    RAISE EXCEPTION 'Only pending payouts can be marked paid';
  END IF;
  IF v_booking.status<>'completed'
     OR v_booking.payment_status<>'paid'
     OR v_booking.payment_verified_at IS NULL
     OR v_booking.assigned_electrician_id IS DISTINCT FROM v_row.electrician_profile_id THEN
    RAISE EXCEPTION 'Completed verified booking and payout assignment are required';
  END IF;
  IF NOT (
    (v_row.razorpay_payment_id IS NOT NULL
      AND v_booking.razorpay_payment_id=v_row.razorpay_payment_id)
    OR
    (v_row.razorpay_payment_id IS NULL
      AND v_booking.razorpay_payment_id IS NULL
      AND EXISTS (
        SELECT 1 FROM public.srk_manual_payment_entries e
         WHERE e.booking_id=v_booking.id
           AND round(e.amount,2)=round(v_booking.amount_paid,2)
           AND lower(btrim(coalesce(e.payment_method,'')))=lower(btrim(coalesce(v_booking.payment_method,'')))
      ))
  ) THEN
    RAISE EXCEPTION 'Verified payment evidence does not match booking';
  END IF;

  IF v_booking.selected_category IS NOT NULL THEN
    SELECT * INTO v_bill FROM public.srk_booking_labour_bills
     WHERE booking_id=v_booking.id;
    IF NOT FOUND OR v_bill.electrician_profile_id IS DISTINCT FROM v_booking.assigned_electrician_id
       OR v_bill.labour_amount_paise IS NULL OR v_bill.labour_amount_paise<=0 THEN
      RAISE EXCEPTION 'Immutable labour bill is missing or mismatched';
    END IF;
    v_service:=round(v_bill.labour_amount_paise/100.0,2);
    v_materials:=0;
  ELSE
    SELECT * INTO v_legacy FROM srk_private.legacy_booking_financial_evidence
     WHERE booking_id=v_booking.id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Archived historical financial evidence is missing'; END IF;
    v_service:=round(coalesce(v_legacy.service_charge,0),2);
    v_materials:=round(coalesce(v_legacy.materials_amount,0),2);
    IF v_service<=0 OR round(v_booking.amount_paid,2)<>round(v_service+v_materials,2)
       OR (v_legacy.quoted_amount IS NOT NULL
           AND round(v_legacy.quoted_amount,2)<>round(v_service+v_materials,2)) THEN
      RAISE EXCEPTION 'Historical payment does not match archived financial evidence';
    END IF;
  END IF;

  IF v_booking.commission_rate IS NULL OR v_booking.commission_rate<0 OR v_booking.commission_rate>100 THEN
    RAISE EXCEPTION 'Commission rate must be between 0 and 100';
  END IF;
  v_commission:=round(v_service*v_booking.commission_rate/100,2);
  v_payable:=round(v_service+v_materials-v_commission,2);

  IF round(coalesce(v_row.gross_service_amount,0),2) IS DISTINCT FROM v_service
     OR round(coalesce(v_row.materials_amount,0),2) IS DISTINCT FROM v_materials
     OR round(coalesce(v_row.platform_commission,0),2) IS DISTINCT FROM v_commission
     OR round(coalesce(v_row.electrician_payable,0),2) IS DISTINCT FROM v_payable
     OR v_row.razorpay_payment_id IS DISTINCT FROM v_booking.razorpay_payment_id THEN
    RAISE EXCEPTION 'Booking payment or payout ledger does not match verified financial evidence; payout blocked';
  END IF;

  UPDATE public.srk_electrician_payouts
     SET payout_status='paid',payout_method=p_method,payout_reference=btrim(p_reference),
         payout_note=nullif(btrim(p_note),''),paid_by=auth.uid(),
         paid_at=clock_timestamp(),updated_at=clock_timestamp()
   WHERE id=p_payout_id AND payout_status='pending';
  IF NOT FOUND THEN RAISE EXCEPTION 'Payout state changed; retry'; END IF;
  RETURN jsonb_build_object('success',true,'payout_id',p_payout_id,'status','paid');
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text) TO authenticated;

-- Customer refund requests reconcile to immutable new bills or archived old
-- financial evidence. The old quote approval state is never consulted.
CREATE OR REPLACE FUNCTION public.srk_admin_prepare_booking_refund(p_request_id uuid)
RETURNS TABLE(refund_record_id uuid,booking_id uuid,payment_id text,amount_paise bigint,idempotency_key text,status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_request public.srk_booking_refund_requests%rowtype;
  v_booking public.service_bookings%rowtype;
  v_refund public.srk_razorpay_refunds%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_bill public.srk_booking_labour_bills%rowtype;
  v_legacy srk_private.legacy_booking_financial_evidence%rowtype;
  v_amount numeric(12,2);
  v_expected_paise bigint;
  v_fee_paise bigint:=0;
  v_previous_payout_note text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING errcode='42501';
  END IF;
  SELECT * INTO v_request FROM public.srk_booking_refund_requests
   WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'REFUND_REQUEST_NOT_FOUND'; END IF;
  IF v_request.status NOT IN ('approved','processing','unknown') THEN
    RAISE EXCEPTION 'REFUND_REQUEST_MUST_BE_APPROVED_FIRST' USING errcode='55000';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=v_request.booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND'; END IF;
  IF v_booking.payment_status<>'paid' OR v_booking.payment_verified_at IS NULL
     OR v_booking.razorpay_payment_id IS NULL
     OR v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$'
     OR coalesce(v_booking.amount_paid,0)<=0 THEN
    RAISE EXCEPTION 'VERIFIED_RAZORPAY_PAYMENT_REQUIRED' USING errcode='55000';
  END IF;
  v_amount:=round(v_booking.amount_paid,2);
  IF v_amount<>v_request.amount THEN
    RAISE EXCEPTION 'REFUND_AMOUNT_CHANGED_SINCE_REQUEST' USING errcode='55000';
  END IF;

  IF v_booking.selected_category IS NOT NULL THEN
    IF v_booking.status<>'completed' THEN RAISE EXCEPTION 'NEW_CATEGORY_REFUND_REQUIRES_COMPLETED_BOOKING'; END IF;
    SELECT * INTO v_bill FROM public.srk_booking_labour_bills
     WHERE booking_id=v_booking.id AND customer_user_id=v_booking.customer_user_id;
    IF NOT FOUND OR v_bill.labour_amount_paise IS NULL OR v_bill.labour_amount_paise<=0
       OR v_bill.electrician_profile_id IS DISTINCT FROM v_booking.assigned_electrician_id THEN
      RAISE EXCEPTION 'IMMUTABLE_LABOUR_BILL_MISSING_OR_MISMATCHED';
    END IF;
    SELECT coalesce(sum(amount_paise),0)::bigint INTO v_fee_paise
      FROM public.srk_booking_cancellation_fee_items
     WHERE booking_id=v_booking.id AND status='settled';
    v_expected_paise:=v_bill.labour_amount_paise+v_fee_paise;
  ELSE
    SELECT * INTO v_legacy FROM srk_private.legacy_booking_financial_evidence
     WHERE booking_id=v_booking.id;
    IF NOT FOUND THEN RAISE EXCEPTION 'ARCHIVED_HISTORICAL_FINANCIAL_EVIDENCE_MISSING'; END IF;
    v_expected_paise:=round((coalesce(v_legacy.service_charge,0)+coalesce(v_legacy.materials_amount,0))*100)::bigint;
    IF v_legacy.quoted_amount IS NOT NULL
       AND round(v_legacy.quoted_amount*100)::bigint IS DISTINCT FROM v_expected_paise THEN
      RAISE EXCEPTION 'ARCHIVED_HISTORICAL_FINANCIAL_EVIDENCE_MISMATCH';
    END IF;
  END IF;
  IF v_expected_paise IS NULL OR v_expected_paise<=0
     OR round(v_amount*100)::bigint IS DISTINCT FROM v_expected_paise THEN
    RAISE EXCEPTION 'PAID_AMOUNT_DOES_NOT_MATCH_VERIFIED_FINANCIAL_EVIDENCE' USING errcode='55000';
  END IF;

  SELECT * INTO v_refund FROM public.srk_razorpay_refunds
   WHERE booking_id=v_booking.id FOR UPDATE;
  IF FOUND THEN
    IF v_refund.status='failed' THEN RAISE EXCEPTION 'PREVIOUS_REFUND_FAILED_RECONCILE_FIRST'; END IF;
    UPDATE public.srk_booking_refund_requests
       SET status=case when v_refund.status='processed' then 'processed' else 'processing' end,
           refund_record_id=v_refund.id,updated_at=clock_timestamp(),
           processed_at=case when v_refund.status='processed' then coalesce(v_refund.processed_at,clock_timestamp()) else null end
     WHERE id=v_request.id;
    RETURN QUERY SELECT v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status;
    RETURN;
  END IF;

  SELECT * INTO v_payout FROM public.srk_electrician_payouts
   WHERE booking_id=v_booking.id FOR UPDATE;
  IF FOUND THEN
    v_previous_payout_note:=v_payout.payout_note;
    IF v_payout.payout_status='paid' THEN RAISE EXCEPTION 'ELECTRICIAN_PAYOUT_ALREADY_PAID_RECONCILIATION_REQUIRED'; END IF;
    IF v_payout.payout_status NOT IN ('pending','blocked') THEN RAISE EXCEPTION 'ELECTRICIAN_PAYOUT_STATE_REQUIRES_RECONCILIATION'; END IF;
    UPDATE public.srk_electrician_payouts
       SET payout_status='blocked',payout_note='Customer refund in progress',updated_at=clock_timestamp()
     WHERE id=v_payout.id;
  END IF;

  INSERT INTO public.srk_razorpay_refunds(
    booking_id,payment_id,amount,amount_paise,idempotency_key,status,reason,admin_user_id,previous_payout_note
  ) VALUES (
    v_booking.id,v_booking.razorpay_payment_id,v_amount,v_expected_paise,
    replace(gen_random_uuid()::text,'-',''),'requested',
    left('Customer refund request: '||v_request.reason,250),auth.uid(),v_previous_payout_note
  ) RETURNING * INTO v_refund;

  UPDATE public.srk_booking_refund_requests
     SET status='processing',refund_record_id=v_refund.id,decided_by=auth.uid(),updated_at=clock_timestamp()
   WHERE id=v_request.id;
  RETURN QUERY SELECT v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_prepare_booking_refund(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_prepare_booking_refund(uuid) TO authenticated;

-- Direct Main Admin refund preparation uses the same immutable/archived evidence.
CREATE OR REPLACE FUNCTION public.srk_admin_prepare_razorpay_refund(p_booking_id uuid,p_reason text)
RETURNS TABLE(refund_record_id uuid,booking_id uuid,payment_id text,amount_paise bigint,idempotency_key text,status text,previous_payout_note text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%rowtype;
  v_refund public.srk_razorpay_refunds%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_bill public.srk_booking_labour_bills%rowtype;
  v_legacy srk_private.legacy_booking_financial_evidence%rowtype;
  v_total numeric(12,2);
  v_expected_paise bigint;
  v_fee_paise bigint:=0;
  v_previous_payout_note text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING errcode='42501';
  END IF;
  IF p_booking_id IS NULL OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 20 AND 250 THEN
    RAISE EXCEPTION 'Refund reason must be 20 to 250 characters';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
  IF v_booking.payment_status<>'paid' OR v_booking.payment_verified_at IS NULL
     OR v_booking.razorpay_payment_id IS NULL OR v_booking.amount_paid IS NULL OR v_booking.amount_paid<=0
     OR v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$' THEN
    RAISE EXCEPTION 'Only verified Razorpay-paid bookings can be refunded';
  END IF;
  v_total:=round(v_booking.amount_paid,2);

  IF v_booking.selected_category IS NOT NULL THEN
    IF v_booking.status<>'completed' THEN RAISE EXCEPTION 'NEW_CATEGORY_REFUND_REQUIRES_COMPLETED_BOOKING'; END IF;
    SELECT * INTO v_bill FROM public.srk_booking_labour_bills
     WHERE booking_id=v_booking.id AND customer_user_id=v_booking.customer_user_id;
    IF NOT FOUND OR v_bill.labour_amount_paise IS NULL OR v_bill.labour_amount_paise<=0
       OR v_bill.electrician_profile_id IS DISTINCT FROM v_booking.assigned_electrician_id THEN
      RAISE EXCEPTION 'IMMUTABLE_LABOUR_BILL_MISSING_OR_MISMATCHED';
    END IF;
    SELECT coalesce(sum(amount_paise),0)::bigint INTO v_fee_paise
      FROM public.srk_booking_cancellation_fee_items
     WHERE booking_id=v_booking.id AND status='settled';
    v_expected_paise:=v_bill.labour_amount_paise+v_fee_paise;
  ELSE
    SELECT * INTO v_legacy FROM srk_private.legacy_booking_financial_evidence
     WHERE booking_id=v_booking.id;
    IF NOT FOUND THEN RAISE EXCEPTION 'ARCHIVED_HISTORICAL_FINANCIAL_EVIDENCE_MISSING'; END IF;
    v_expected_paise:=round((coalesce(v_legacy.service_charge,0)+coalesce(v_legacy.materials_amount,0))*100)::bigint;
    IF v_legacy.quoted_amount IS NOT NULL
       AND round(v_legacy.quoted_amount*100)::bigint IS DISTINCT FROM v_expected_paise THEN
      RAISE EXCEPTION 'ARCHIVED_HISTORICAL_FINANCIAL_EVIDENCE_MISMATCH';
    END IF;
  END IF;
  IF v_expected_paise IS NULL OR v_expected_paise<=0
     OR round(v_total*100)::bigint IS DISTINCT FROM v_expected_paise THEN
    RAISE EXCEPTION 'PAID_AMOUNT_DOES_NOT_MATCH_VERIFIED_FINANCIAL_EVIDENCE';
  END IF;

  SELECT * INTO v_refund FROM public.srk_razorpay_refunds WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND THEN
    IF v_refund.status='failed' THEN RAISE EXCEPTION 'Previous Razorpay refund failed; reconcile before creating another request'; END IF;
    RETURN QUERY SELECT v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
    RETURN;
  END IF;

  SELECT * INTO v_payout FROM public.srk_electrician_payouts WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND THEN
    v_previous_payout_note:=v_payout.payout_note;
    IF v_payout.payout_status='paid' THEN
      RAISE EXCEPTION 'Electrician payout is already paid; recovery requires separate Admin reconciliation';
    END IF;
    IF v_payout.payout_status NOT IN ('pending','blocked') THEN
      RAISE EXCEPTION 'Electrician payout is not pending; reconcile payout before refund';
    END IF;
    UPDATE public.srk_electrician_payouts
       SET payout_status='blocked',payout_note='Razorpay refund pending',updated_at=clock_timestamp()
     WHERE id=v_payout.id;
  END IF;

  INSERT INTO public.srk_razorpay_refunds
    (booking_id,payment_id,amount,amount_paise,idempotency_key,status,reason,admin_user_id,previous_payout_note)
  VALUES
    (p_booking_id,v_booking.razorpay_payment_id,v_total,v_expected_paise,
     replace(gen_random_uuid()::text,'-',''),'requested',btrim(p_reason),auth.uid(),v_previous_payout_note)
  RETURNING * INTO v_refund;
  RETURN QUERY SELECT v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_prepare_razorpay_refund(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_prepare_razorpay_refund(uuid,text) TO authenticated;

-- Finance dashboard reads immutable bills for new work and archived amounts for
-- old paid bookings. No active booking price or quote columns are required.
CREATE OR REPLACE FUNCTION public.srk_admin_finance_dashboard(
  p_period text DEFAULT 'monthly',
  p_anchor_date date DEFAULT ((now() AT TIME ZONE 'Asia/Kolkata'))::date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','private','auth','pg_temp'
AS $function$
DECLARE
  v_start date;
  v_end date;
  v_anchor date:=coalesce(p_anchor_date,(now() at time zone 'Asia/Kolkata')::date);
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING errcode='42501';
  END IF;
  IF p_period IS NULL OR p_period NOT IN ('daily','monthly','yearly') THEN
    RAISE EXCEPTION 'Period must be daily, monthly, or yearly' USING errcode='22023';
  END IF;
  IF p_period='daily' THEN
    v_start:=v_anchor; v_end:=v_anchor;
  ELSIF p_period='monthly' THEN
    v_start:=date_trunc('month',v_anchor)::date;
    v_end:=(v_start+interval '1 month - 1 day')::date;
  ELSE
    v_start:=make_date(extract(year from v_anchor)::int,1,1);
    v_end:=make_date(extract(year from v_anchor)::int,12,31);
  END IF;

  WITH paid_jobs AS (
    SELECT coalesce(b.amount_paid,0)::numeric AS gross,
      coalesce(b.commission_amount,
        round(coalesce(lb.labour_amount,le.service_charge,0)*coalesce(b.commission_rate,15)/100,2)
      )::numeric AS commission
    FROM public.service_bookings b
    LEFT JOIN public.srk_booking_labour_bills lb ON lb.booking_id=b.id
    LEFT JOIN srk_private.legacy_booking_financial_evidence le ON le.booking_id=b.id
    WHERE b.payment_status='paid' AND b.status='completed'
      AND coalesce(b.payment_verified_at,b.created_at) IS NOT NULL
      AND (coalesce(b.payment_verified_at,b.created_at) AT TIME ZONE 'Asia/Kolkata')::date BETWEEN v_start AND v_end
  ),
  job_totals AS (
    SELECT count(*)::int AS paid_completed_bookings,
      coalesce(sum(gross),0)::numeric(14,2) AS customer_payments,
      coalesce(sum(commission),0)::numeric(14,2) AS platform_commission,
      coalesce(sum(gross-commission),0)::numeric(14,2) AS electrician_share
    FROM paid_jobs
  ),
  booking_totals AS (
    SELECT count(*)::int AS bookings_created FROM public.service_bookings
    WHERE created_at IS NOT NULL AND (created_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN v_start AND v_end
  ),
  payout_totals AS (
    SELECT
      coalesce(sum(electrician_payable) FILTER (WHERE payout_status='paid' AND paid_at IS NOT NULL
        AND (paid_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN v_start AND v_end),0)::numeric(14,2) AS payout_paid,
      coalesce(sum(electrician_payable) FILTER (WHERE payout_status='pending'
        AND (created_at AT TIME ZONE 'Asia/Kolkata')::date BETWEEN v_start AND v_end),0)::numeric(14,2) AS payout_pending
    FROM public.srk_electrician_payouts
  ),
  expense_totals AS (
    SELECT
      coalesce(sum(amount),0)::numeric(14,2) AS total_expenses,
      coalesce(sum(amount) FILTER(WHERE category='sms_otp'),0)::numeric(14,2) AS sms_otp_cost,
      coalesce(sum(amount) FILTER(WHERE category='razorpay_fee'),0)::numeric(14,2) AS razorpay_fees,
      coalesce(sum(amount) FILTER(WHERE category='supabase'),0)::numeric(14,2) AS supabase_cost,
      coalesce(sum(amount) FILTER(WHERE category='netlify'),0)::numeric(14,2) AS netlify_cost,
      coalesce(sum(amount) FILTER(WHERE category='advertising'),0)::numeric(14,2) AS advertising_cost,
      coalesce(sum(amount) FILTER(WHERE category='staff'),0)::numeric(14,2) AS staff_cost,
      coalesce(sum(amount) FILTER(WHERE category='other'),0)::numeric(14,2) AS other_cost
    FROM private.srk_business_expenses WHERE expense_date BETWEEN v_start AND v_end
  )
  SELECT jsonb_build_object(
    'period',p_period,'start_date',v_start,'end_date',v_end,
    'bookings_created',b.bookings_created,'paid_completed_bookings',j.paid_completed_bookings,
    'customer_payments',j.customer_payments,'platform_commission',j.platform_commission,
    'electrician_share',j.electrician_share,'electrician_payout_paid',p.payout_paid,
    'electrician_payout_pending',p.payout_pending,'total_expenses',e.total_expenses,
    'sms_otp_cost',e.sms_otp_cost,'razorpay_fees',e.razorpay_fees,
    'supabase_cost',e.supabase_cost,'netlify_cost',e.netlify_cost,
    'advertising_cost',e.advertising_cost,'staff_cost',e.staff_cost,
    'other_cost',e.other_cost,'net_profit',j.platform_commission-e.total_expenses
  ) INTO v_result
  FROM job_totals j CROSS JOIN booking_totals b CROSS JOIN payout_totals p CROSS JOIN expense_totals e;
  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_finance_dashboard(text,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finance_dashboard(text,date) TO authenticated;

-- Rebind the payable trigger without references to retired booking columns.
DROP TRIGGER IF EXISTS trg_srk_create_electrician_payable ON public.service_bookings;
CREATE TRIGGER trg_srk_create_electrician_payable
AFTER INSERT OR UPDATE OF
  payment_status,status,assigned_electrician_id,payment_verified_at,
  razorpay_payment_id,amount_paid
ON public.service_bookings
FOR EACH ROW EXECUTE FUNCTION public.srk_create_electrician_payable();

-- The archive is the only surviving home for legacy price/quotation fields.
-- Remove those fields from the active booking table after all dependent RPCs
-- have been switched to immutable bills or the read-only archive.
ALTER TABLE public.service_bookings
  DROP COLUMN IF EXISTS quoted_amount,
  DROP COLUMN IF EXISTS quote_status,
  DROP COLUMN IF EXISTS quote_note,
  DROP COLUMN IF EXISTS quote_submitted_at,
  DROP COLUMN IF EXISTS quote_responded_at,
  DROP COLUMN IF EXISTS customer_suggested_amount,
  DROP COLUMN IF EXISTS electrician_quote_kind,
  DROP COLUMN IF EXISTS service_charge,
  DROP COLUMN IF EXISTS materials_amount;

NOTIFY pgrst,'reload schema';
