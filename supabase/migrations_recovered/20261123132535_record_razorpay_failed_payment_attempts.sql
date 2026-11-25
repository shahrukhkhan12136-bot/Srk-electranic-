CREATE OR REPLACE FUNCTION public.srk_service_record_razorpay_payment_failure(
  p_razorpay_order_id text,
  p_razorpay_payment_id text,
  p_amount_paise bigint,
  p_currency text,
  p_failure_code text DEFAULT NULL,
  p_failure_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_order public.srk_razorpay_payment_orders%rowtype;
  v_tx public.srk_booking_transactions%rowtype;
  v_key text;
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF p_razorpay_order_id IS NULL OR p_razorpay_order_id !~ '^order_[A-Za-z0-9]+$'
     OR p_razorpay_payment_id IS NULL OR p_razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$'
     OR p_amount_paise IS NULL OR p_amount_paise <= 0
     OR p_currency IS DISTINCT FROM 'INR' THEN
    RAISE EXCEPTION 'INVALID_RAZORPAY_PAYMENT_FAILURE' USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_order
  FROM public.srk_razorpay_payment_orders
  WHERE razorpay_order_id=p_razorpay_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('recorded',false,'reason','PAYMENT_ORDER_NOT_FOUND');
  END IF;

  IF v_order.amount_paise IS DISTINCT FROM p_amount_paise
     OR v_order.currency IS DISTINCT FROM p_currency THEN
    RETURN jsonb_build_object('recorded',false,'reason','PAYMENT_AMOUNT_OR_CURRENCY_MISMATCH');
  END IF;

  v_key := 'razorpay-payment-failed:'||p_razorpay_payment_id;

  SELECT * INTO v_tx
  FROM public.srk_booking_transactions
  WHERE idempotency_key=v_key;

  IF FOUND THEN
    IF v_tx.booking_id IS DISTINCT FROM v_order.booking_id
       OR v_tx.provider_reference IS DISTINCT FROM p_razorpay_payment_id
       OR v_tx.amount IS DISTINCT FROM (p_amount_paise::numeric/100) THEN
      RAISE EXCEPTION 'PAYMENT_FAILURE_REPLAY_MISMATCH' USING ERRCODE='22000';
    END IF;
    RETURN jsonb_build_object('recorded',true,'replayed',true,'transaction_id',v_tx.id);
  END IF;

  INSERT INTO public.srk_booking_transactions(
    booking_id,transaction_type,payment_method,amount,transaction_status,
    provider,provider_reference,order_reference,idempotency_key,verified_at,metadata
  ) VALUES (
    v_order.booking_id,'payment','online',p_amount_paise::numeric/100,'failed',
    'razorpay',p_razorpay_payment_id,p_razorpay_order_id,v_key,clock_timestamp(),
    jsonb_build_object(
      'source','verified_razorpay_webhook',
      'failure_code',left(coalesce(p_failure_code,''),120),
      'failure_description',left(coalesce(p_failure_description,''),1000),
      'amount_paise',p_amount_paise,'currency',p_currency
    )
  )
  ON CONFLICT(idempotency_key) DO NOTHING
  RETURNING * INTO v_tx;

  IF NOT FOUND THEN
    SELECT * INTO v_tx FROM public.srk_booking_transactions
    WHERE idempotency_key=v_key;
  END IF;

  IF v_tx.booking_id IS DISTINCT FROM v_order.booking_id
     OR v_tx.provider_reference IS DISTINCT FROM p_razorpay_payment_id THEN
    RAISE EXCEPTION 'PAYMENT_FAILURE_CONCURRENT_REPLAY_MISMATCH' USING ERRCODE='22000';
  END IF;

  -- A failed attempt does not fail the Razorpay Order or Booking:
  -- another payment attempt may still succeed against the same order.
  RETURN jsonb_build_object(
    'recorded',true,'replayed',false,'transaction_id',v_tx.id,
    'booking_id',v_order.booking_id,'order_status',v_order.status
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_service_record_razorpay_payment_failure(text,text,bigint,text,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_record_razorpay_payment_failure(text,text,bigint,text,text,text) TO service_role;