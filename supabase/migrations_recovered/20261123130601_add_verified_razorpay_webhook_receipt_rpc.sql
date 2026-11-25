ALTER TABLE public.srk_razorpay_webhook_events
  ADD COLUMN IF NOT EXISTS refund_amount_paise bigint,
  ADD COLUMN IF NOT EXISTS refund_currency text;

ALTER TABLE public.srk_razorpay_webhook_events
  ADD CONSTRAINT srk_razorpay_webhook_refund_amount_positive
  CHECK (refund_amount_paise IS NULL OR refund_amount_paise > 0) NOT VALID;
ALTER TABLE public.srk_razorpay_webhook_events
  VALIDATE CONSTRAINT srk_razorpay_webhook_refund_amount_positive;

CREATE OR REPLACE FUNCTION public.srk_service_record_verified_razorpay_webhook(
  p_event_id text,
  p_event_type text,
  p_event_payload jsonb,
  p_razorpay_order_id text DEFAULT NULL,
  p_razorpay_payment_id text DEFAULT NULL,
  p_payment_amount_paise bigint DEFAULT NULL,
  p_payment_currency text DEFAULT NULL,
  p_razorpay_refund_id text DEFAULT NULL,
  p_refund_amount_paise bigint DEFAULT NULL,
  p_refund_currency text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_existing public.srk_razorpay_webhook_events%rowtype;
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF p_event_id IS NULL OR length(p_event_id) NOT BETWEEN 1 AND 255
     OR p_event_type IS NULL OR length(p_event_type) NOT BETWEEN 1 AND 160
     OR p_event_payload IS NULL OR jsonb_typeof(p_event_payload) <> 'object'
     OR (p_payment_amount_paise IS NOT NULL AND p_payment_amount_paise <= 0)
     OR (p_refund_amount_paise IS NOT NULL AND p_refund_amount_paise <= 0)
     OR (p_payment_currency IS NOT NULL AND p_payment_currency <> 'INR')
     OR (p_refund_currency IS NOT NULL AND p_refund_currency <> 'INR') THEN
    RAISE EXCEPTION 'INVALID_VERIFIED_WEBHOOK_INPUT' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.srk_razorpay_webhook_events(
    event_id,event_type,event_payload,razorpay_order_id,razorpay_payment_id,
    payment_amount_paise,payment_currency,razorpay_refund_id,
    refund_amount_paise,refund_currency,processing_status,signature_verified_at,
    processing_attempts,received_at,updated_at
  ) VALUES (
    p_event_id,p_event_type,p_event_payload,p_razorpay_order_id,p_razorpay_payment_id,
    p_payment_amount_paise,p_payment_currency,p_razorpay_refund_id,
    p_refund_amount_paise,p_refund_currency,'received',clock_timestamp(),0,
    clock_timestamp(),clock_timestamp()
  )
  ON CONFLICT (event_id) DO NOTHING;

  IF FOUND THEN
    RETURN jsonb_build_object('success',true,'duplicate',false,'status','received');
  END IF;

  SELECT * INTO v_existing
  FROM public.srk_razorpay_webhook_events
  WHERE event_id=p_event_id
  FOR UPDATE;

  IF v_existing.event_type IS DISTINCT FROM p_event_type
     OR v_existing.event_payload IS DISTINCT FROM p_event_payload THEN
    RAISE EXCEPTION 'WEBHOOK_EVENT_ID_PAYLOAD_MISMATCH' USING ERRCODE='23505';
  END IF;

  RETURN jsonb_build_object(
    'success',true,'duplicate',true,
    'status',v_existing.processing_status
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_service_record_verified_razorpay_webhook(
  text,text,jsonb,text,text,bigint,text,text,bigint,text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_record_verified_razorpay_webhook(
  text,text,jsonb,text,text,bigint,text,text,bigint,text
) TO service_role;

COMMENT ON FUNCTION public.srk_service_record_verified_razorpay_webhook(
  text,text,jsonb,text,text,bigint,text,text,bigint,text
) IS 'Service-only receipt RPC. Caller must verify Razorpay HMAC signature against the raw request body before calling. Stores deduplicated verified event and parsed payment/refund fields; never accepts browser/client calls.';