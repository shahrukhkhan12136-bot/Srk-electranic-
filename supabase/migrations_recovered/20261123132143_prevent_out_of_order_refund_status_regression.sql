CREATE OR REPLACE FUNCTION public.srk_service_reconcile_booking_refund(
  p_refund_record_id uuid,
  p_provider_refund_id text,
  p_provider_status text,
  p_provider_amount_paise bigint,
  p_provider_currency text,
  p_error text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_refund public.srk_razorpay_refunds%rowtype;
  v_status text;
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF p_refund_record_id IS NULL
     OR p_provider_status NOT IN ('pending','processed','failed')
     OR p_provider_refund_id IS NULL
     OR p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$'
     OR p_provider_amount_paise IS NULL OR p_provider_amount_paise <= 0
     OR p_provider_currency IS DISTINCT FROM 'INR' THEN
    RAISE EXCEPTION 'INVALID_PROVIDER_REFUND_RESULT' USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_refund
  FROM public.srk_razorpay_refunds
  WHERE id=p_refund_record_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REFUND_RECORD_NOT_FOUND';
  END IF;

  IF v_refund.currency IS DISTINCT FROM p_provider_currency
     OR v_refund.amount_paise IS DISTINCT FROM p_provider_amount_paise THEN
    RAISE EXCEPTION 'PROVIDER_REFUND_AMOUNT_OR_CURRENCY_MISMATCH'
      USING ERRCODE='22000';
  END IF;

  IF v_refund.status='processed' THEN
    IF v_refund.refund_id IS DISTINCT FROM p_provider_refund_id THEN
      RAISE EXCEPTION 'PROCESSED_REFUND_ID_MISMATCH';
    END IF;
    RETURN jsonb_build_object('success',true,'status','processed','replayed',true);
  END IF;

  IF v_refund.refund_id IS NOT NULL
     AND v_refund.refund_id IS DISTINCT FROM p_provider_refund_id THEN
    RAISE EXCEPTION 'PROVIDER_REFUND_ID_MISMATCH';
  END IF;

  -- Provider events can arrive out of order. A late "created/pending"
  -- event must never roll a terminal failed refund back into processing.
  IF v_refund.status='failed' AND p_provider_status='pending' THEN
    RETURN jsonb_build_object(
      'success',true,'status','failed','stale_event_ignored',true,
      'refund_record_id',v_refund.id
    );
  END IF;

  v_status := CASE p_provider_status
    WHEN 'pending' THEN 'processing'
    WHEN 'processed' THEN 'processed'
    ELSE 'failed'
  END;

  UPDATE public.srk_razorpay_refunds
  SET refund_id=p_provider_refund_id,
      provider_status=p_provider_status,
      status=v_status,
      last_error=CASE WHEN p_provider_status='failed'
        THEN left(coalesce(p_error,'Refund failed'),500) ELSE NULL END,
      processed_at=CASE WHEN p_provider_status='processed'
        THEN clock_timestamp() ELSE NULL END,
      updated_at=clock_timestamp()
  WHERE id=p_refund_record_id;

  UPDATE public.srk_booking_refund_requests
  SET status=CASE WHEN p_provider_status='processed' THEN 'processed'
                  WHEN p_provider_status='failed' THEN 'unknown'
                  ELSE 'processing' END,
      updated_at=clock_timestamp(),
      processed_at=CASE WHEN p_provider_status='processed'
        THEN clock_timestamp() ELSE NULL END
  WHERE refund_record_id=p_refund_record_id;

  IF p_provider_status='processed' THEN
    UPDATE public.service_bookings
    SET payment_status='refunded'
    WHERE id=v_refund.booking_id AND payment_status='paid';
  END IF;

  RETURN jsonb_build_object(
    'success',true,'status',v_status,'booking_id',v_refund.booking_id,
    'amount_paise',v_refund.amount_paise,'currency',v_refund.currency
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_service_reconcile_booking_refund(uuid,text,text,bigint,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_reconcile_booking_refund(uuid,text,text,bigint,text,text) TO service_role;