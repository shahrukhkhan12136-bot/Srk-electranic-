ALTER TABLE public.srk_razorpay_webhook_events
  ADD COLUMN IF NOT EXISTS processing_claim_token uuid,
  ADD COLUMN IF NOT EXISTS processing_claimed_at timestamptz;

CREATE INDEX IF NOT EXISTS srk_razorpay_webhook_claimable_idx
ON public.srk_razorpay_webhook_events (received_at)
WHERE processing_status IN ('received','processing_error')
  AND signature_verified_at IS NOT NULL;

CREATE OR REPLACE FUNCTION public.srk_service_claim_razorpay_webhook_events(
  p_limit integer DEFAULT 10
)
RETURNS TABLE(
  event_id text,
  event_type text,
  event_payload jsonb,
  razorpay_order_id text,
  razorpay_payment_id text,
  payment_amount_paise bigint,
  payment_currency text,
  razorpay_refund_id text,
  refund_amount_paise bigint,
  refund_currency text,
  processing_attempts integer,
  claim_token uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 25 THEN
    RAISE EXCEPTION 'INVALID_CLAIM_LIMIT' USING ERRCODE='22023';
  END IF;

  RETURN QUERY
  WITH candidates AS (
    SELECT e.event_id
    FROM public.srk_razorpay_webhook_events e
    WHERE e.signature_verified_at IS NOT NULL
      AND (
        (e.processing_status='received' AND e.processing_claimed_at IS NULL)
        OR
        (e.processing_status='processing_error'
          AND e.next_retry_at IS NOT NULL
          AND e.next_retry_at <= clock_timestamp()
          AND e.processing_claimed_at IS NULL)
        OR
        (e.processing_claimed_at IS NOT NULL
          AND e.processing_claimed_at < clock_timestamp() - interval '2 minutes'
          AND e.processing_status IN ('received','processing_error'))
      )
    ORDER BY e.received_at, e.event_id
    FOR UPDATE SKIP LOCKED
    LIMIT p_limit
  )
  UPDATE public.srk_razorpay_webhook_events e
  SET processing_claim_token=gen_random_uuid(),
      processing_claimed_at=clock_timestamp(),
      processing_attempts=e.processing_attempts+1,
      next_retry_at=NULL,
      updated_at=clock_timestamp()
  FROM candidates c
  WHERE e.event_id=c.event_id
  RETURNING e.event_id,e.event_type,e.event_payload,e.razorpay_order_id,
    e.razorpay_payment_id,e.payment_amount_paise,e.payment_currency,
    e.razorpay_refund_id,e.refund_amount_paise,e.refund_currency,
    e.processing_attempts,e.processing_claim_token;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_service_finish_razorpay_webhook_event(
  p_event_id text,
  p_claim_token uuid,
  p_outcome text,
  p_error text DEFAULT NULL,
  p_next_retry_at timestamptz DEFAULT NULL,
  p_reconciliation_reason text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_rows integer;
BEGIN
  IF coalesce(auth.role(),'') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_event_id IS NULL OR p_claim_token IS NULL
     OR p_outcome NOT IN ('reconciled','exception','ignored','processing_error')
     OR (p_outcome='processing_error' AND p_next_retry_at IS NOT NULL
         AND p_next_retry_at <= clock_timestamp())
     OR (p_outcome<>'processing_error' AND p_next_retry_at IS NOT NULL) THEN
    RAISE EXCEPTION 'INVALID_WEBHOOK_FINISH_INPUT' USING ERRCODE='22023';
  END IF;

  UPDATE public.srk_razorpay_webhook_events
  SET processing_status=p_outcome,
      reconciliation_reason=left(coalesce(p_reconciliation_reason,p_error),1000),
      last_error=CASE WHEN p_outcome='processing_error'
        THEN left(coalesce(p_error,'Webhook processing failed'),1000) ELSE NULL END,
      next_retry_at=CASE WHEN p_outcome='processing_error'
        THEN p_next_retry_at ELSE NULL END,
      processed_at=CASE WHEN p_outcome IN ('reconciled','exception','ignored')
        THEN clock_timestamp() ELSE NULL END,
      processing_claim_token=NULL,
      processing_claimed_at=NULL,
      updated_at=clock_timestamp()
  WHERE event_id=p_event_id
    AND processing_claim_token=p_claim_token
    AND processing_claimed_at IS NOT NULL;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows=0 THEN
    RAISE EXCEPTION 'WEBHOOK_CLAIM_NOT_FOUND_OR_EXPIRED' USING ERRCODE='55000';
  END IF;

  RETURN jsonb_build_object('success',true,'event_id',p_event_id,'status',p_outcome);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_service_claim_razorpay_webhook_events(integer)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_claim_razorpay_webhook_events(integer)
  TO service_role;

REVOKE ALL ON FUNCTION public.srk_service_finish_razorpay_webhook_event(text,uuid,text,text,timestamptz,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_finish_razorpay_webhook_event(text,uuid,text,text,timestamptz,text)
  TO service_role;

COMMENT ON FUNCTION public.srk_service_claim_razorpay_webhook_events(integer)
IS 'Atomically claims signature-verified Razorpay webhook events using SKIP LOCKED; reclaims stale claims after two minutes; service_role only.';
COMMENT ON FUNCTION public.srk_service_finish_razorpay_webhook_event(text,uuid,text,text,timestamptz,text)
IS 'Finishes a claimed Razorpay webhook using its one-time claim token; supports retry scheduling without inventing a maximum retry count; service_role only.';