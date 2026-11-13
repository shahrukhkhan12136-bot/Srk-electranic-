-- Guarded, labour-only Razorpay refund preparation. This creates a durable
-- intent only; a trusted provider executor must still submit it to Razorpay.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_admin_prepare_booking_refund(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_request public.srk_booking_refund_requests%ROWTYPE;
  v_booking public.service_bookings%ROWTYPE;
  v_bill public.srk_booking_labour_bills%ROWTYPE;
  v_payout public.srk_electrician_payouts%ROWTYPE;
  v_existing public.srk_razorpay_refunds%ROWTYPE;
  v_profile_id uuid;
  v_amount_paise bigint;
  v_idempotency_key text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_request_id IS NULL THEN
    RAISE EXCEPTION 'REFUND_REQUEST_ID_REQUIRED' USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_request
    FROM public.srk_booking_refund_requests
   WHERE id=p_request_id
   FOR UPDATE;
  IF NOT FOUND OR v_request.status NOT IN ('approved','processing','unknown') THEN
    RAISE EXCEPTION 'APPROVED_REFUND_REQUEST_REQUIRED' USING ERRCODE='55000';
  END IF;

  SELECT * INTO v_booking
    FROM public.service_bookings
   WHERE id=v_request.booking_id
   FOR UPDATE;
  IF NOT FOUND OR v_booking.customer_user_id IS DISTINCT FROM v_request.customer_user_id
     OR v_booking.status <> 'completed'
     OR v_booking.completion_approval_status <> 'approved'
     OR v_booking.payment_status <> 'paid'
     OR v_booking.payment_verified_at IS NULL
     OR v_booking.selected_category IS NULL THEN
    RAISE EXCEPTION 'COMPLETED_VERIFIED_LABOUR_BOOKING_REQUIRED' USING ERRCODE='55000';
  END IF;

  SELECT * INTO v_bill
    FROM public.srk_booking_labour_bills
   WHERE booking_id=v_booking.id;
  IF NOT FOUND OR v_bill.labour_amount_paise <= 0
     OR v_bill.labour_amount_paise <> round(v_bill.labour_amount*100)::bigint
     OR round(coalesce(v_booking.amount_paid,0)*100)::bigint <> v_bill.labour_amount_paise
     OR round(v_request.amount*100)::bigint <> v_bill.labour_amount_paise THEN
    RAISE EXCEPTION 'REFUND_AMOUNT_MUST_MATCH_VERIFIED_LABOUR_BILL' USING ERRCODE='55000';
  END IF;
  v_amount_paise := v_bill.labour_amount_paise;

  IF v_booking.razorpay_payment_id IS NULL
     OR v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$'
     OR v_booking.razorpay_order_id IS NULL THEN
    RAISE EXCEPTION 'RAZORPAY_CAPTURED_PAYMENT_REQUIRED_USE_MANUAL_RECONCILIATION' USING ERRCODE='55000';
  END IF;

  v_profile_id := v_booking.assigned_electrician_id;
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'ASSIGNED_ELECTRICIAN_REQUIRED' USING ERRCODE='55000';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_profile_id::text,0)
  );

  SELECT * INTO v_payout
    FROM public.srk_electrician_payouts
   WHERE booking_id=v_booking.id
   FOR UPDATE;
  IF FOUND AND v_payout.payout_status='paid' THEN
    RAISE EXCEPTION 'ELECTRICIAN_PAYOUT_ALREADY_PAID_ADMIN_RECONCILIATION_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF FOUND AND v_payout.payout_status NOT IN ('pending','blocked','refunded') THEN
    RAISE EXCEPTION 'PAYOUT_STATE_REQUIRES_ADMIN_RECONCILIATION' USING ERRCODE='55000';
  END IF;

  -- A cash booking whose pooled fee due has already been settled by a later
  -- online booking cannot be refunded automatically; this avoids the ledger
  -- trigger rejecting the post-provider reconciliation.
  IF EXISTS (
    SELECT 1
      FROM public.srk_platform_fee_ledger due_entry
      JOIN public.srk_platform_fee_ledger settlement
        ON settlement.electrician_profile_id=due_entry.electrician_profile_id
       AND settlement.entry_type='cash_due_settlement'
       AND settlement.created_at>due_entry.created_at
     WHERE due_entry.booking_id=v_booking.id
       AND due_entry.entry_type='cash_due'
  ) THEN
    RAISE EXCEPTION 'CASH_FEE_DUE_ALREADY_SETTLED_ADMIN_RECONCILIATION_REQUIRED' USING ERRCODE='55000';
  END IF;

  SELECT * INTO v_existing
    FROM public.srk_razorpay_refunds
   WHERE booking_id=v_booking.id
   FOR UPDATE;
  IF FOUND THEN
    IF v_existing.payment_id<>v_booking.razorpay_payment_id
       OR v_existing.amount_paise<>v_amount_paise
       OR v_existing.status IN ('processed','processing','unknown') THEN
      RETURN jsonb_build_object(
        'success',false,'requires_reconciliation',true,
        'refund_id',v_existing.id,'status',v_existing.status
      );
    END IF;
    IF v_existing.status='requested' THEN
      UPDATE public.srk_booking_refund_requests
         SET refund_record_id=v_existing.id,updated_at=clock_timestamp()
       WHERE id=v_request.id AND refund_record_id IS NULL;
      RETURN jsonb_build_object(
        'success',true,'already_prepared',true,
        'refund_id',v_existing.id,'idempotency_key',v_existing.idempotency_key,
        'amount_paise',v_existing.amount_paise
      );
    END IF;
    RAISE EXCEPTION 'EXISTING_REFUND_RECORD_REQUIRES_ADMIN_RECONCILIATION' USING ERRCODE='55000';
  END IF;

  v_idempotency_key := 'srk_'||replace(gen_random_uuid()::text,'-','');
  INSERT INTO public.srk_razorpay_refunds
    (booking_id,payment_id,amount,amount_paise,currency,idempotency_key,
     status,reason,admin_user_id)
  VALUES
    (v_booking.id,v_booking.razorpay_payment_id,
     v_amount_paise::numeric/100,v_amount_paise,'INR',v_idempotency_key,
     'requested',left(v_request.reason,250),auth.uid())
  RETURNING * INTO v_existing;

  UPDATE public.srk_booking_refund_requests
     SET refund_record_id=v_existing.id,updated_at=clock_timestamp()
   WHERE id=v_request.id AND status='approved';

  RETURN jsonb_build_object(
    'success',true,'prepared',true,'provider_submitted',false,
    'refund_id',v_existing.id,'idempotency_key',v_existing.idempotency_key,
    'amount_paise',v_existing.amount_paise,'status',v_existing.status,
    'message','Durable refund intent created; provider executor is still required.'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_prepare_booking_refund(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_prepare_booking_refund(uuid) TO authenticated;

COMMIT;
