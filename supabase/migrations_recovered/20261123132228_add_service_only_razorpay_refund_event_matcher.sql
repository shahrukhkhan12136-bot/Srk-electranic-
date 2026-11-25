CREATE INDEX IF NOT EXISTS srk_razorpay_refunds_payment_id_idx
ON public.srk_razorpay_refunds(payment_id);

CREATE OR REPLACE FUNCTION public.srk_service_match_razorpay_refund(
  p_payment_id text,
  p_provider_refund_id text,
  p_amount_paise bigint,
  p_currency text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_count bigint;
  v_refund public.srk_razorpay_refunds%rowtype;
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF p_payment_id IS NULL OR p_payment_id !~ '^pay_[A-Za-z0-9]+$'
     OR p_provider_refund_id IS NULL OR p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$'
     OR p_amount_paise IS NULL OR p_amount_paise <= 0
     OR p_currency IS DISTINCT FROM 'INR' THEN
    RAISE EXCEPTION 'INVALID_REFUND_MATCH_INPUT' USING ERRCODE='22023';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.srk_razorpay_refunds
  WHERE payment_id=p_payment_id;

  IF v_count=0 THEN
    RETURN jsonb_build_object('matched',false,'reason','REFUND_RECORD_NOT_FOUND');
  ELSIF v_count<>1 THEN
    RETURN jsonb_build_object('matched',false,'reason','AMBIGUOUS_PAYMENT_REFUND_MATCH');
  END IF;

  SELECT * INTO v_refund
  FROM public.srk_razorpay_refunds
  WHERE payment_id=p_payment_id
  FOR UPDATE;

  IF v_refund.amount_paise IS DISTINCT FROM p_amount_paise
     OR v_refund.currency IS DISTINCT FROM p_currency THEN
    RETURN jsonb_build_object('matched',false,'reason','REFUND_AMOUNT_OR_CURRENCY_MISMATCH');
  END IF;

  IF v_refund.refund_id IS NOT NULL
     AND v_refund.refund_id IS DISTINCT FROM p_provider_refund_id THEN
    RETURN jsonb_build_object('matched',false,'reason','PROVIDER_REFUND_ID_MISMATCH');
  END IF;

  RETURN jsonb_build_object(
    'matched',true,
    'refund_record_id',v_refund.id,
    'booking_id',v_refund.booking_id,
    'refund_status',v_refund.status
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_service_match_razorpay_refund(text,text,bigint,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_match_razorpay_refund(text,text,bigint,text) TO service_role;