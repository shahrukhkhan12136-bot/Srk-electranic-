-- Durable payload inbox and worker claims for fast Razorpay webhook acknowledgement.
-- The HTTP handler only stores a minimal, signed-event projection; a background
-- Netlify Function performs the existing payment/refund reconciliation later.

ALTER TABLE public.srk_razorpay_webhook_events
  ADD COLUMN IF NOT EXISTS event_payload jsonb;

ALTER TABLE public.srk_razorpay_webhook_events
  DROP CONSTRAINT IF EXISTS srk_razorpay_webhook_events_state_check;
ALTER TABLE public.srk_razorpay_webhook_events
  ADD CONSTRAINT srk_razorpay_webhook_events_state_check
  CHECK (state IN ('queued','processing','processed','ignored','retryable'));

DROP INDEX IF EXISTS public.srk_razorpay_webhook_events_retry_idx;
CREATE INDEX srk_razorpay_webhook_events_retry_idx
  ON public.srk_razorpay_webhook_events(state,lease_expires_at,first_received_at)
  WHERE state IN ('queued','processing','retryable');

CREATE OR REPLACE FUNCTION public.srk_service_enqueue_razorpay_webhook_event(
  p_event_id text,p_event_type text,p_payload_sha256 text,p_event_payload jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
  v_event public.srk_razorpay_webhook_events%rowtype;
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_event_id IS NULL OR length(p_event_id) NOT BETWEEN 1 AND 128
     OR p_event_type IS NULL OR length(p_event_type) NOT BETWEEN 1 AND 100
     OR p_payload_sha256 IS NULL OR p_payload_sha256 !~ '^[a-f0-9]{64}$'
     OR p_event_payload IS NULL OR jsonb_typeof(p_event_payload) <> 'object'
     OR octet_length(p_event_payload::text) > 32768 THEN
    RAISE EXCEPTION 'INVALID_RAZORPAY_WEBHOOK_EVENT' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.srk_razorpay_webhook_events(
    event_id,event_type,payload_sha256,event_payload,state,attempt_count
  ) VALUES (p_event_id,p_event_type,p_payload_sha256,p_event_payload,'queued',0)
  ON CONFLICT DO NOTHING;
  IF FOUND THEN
    RETURN jsonb_build_object('success',true,'accepted',true,'queued',true,'event_id',p_event_id);
  END IF;

  SELECT * INTO v_event FROM public.srk_razorpay_webhook_events
    WHERE event_id=p_event_id FOR UPDATE;
  IF NOT FOUND THEN
    SELECT * INTO v_event FROM public.srk_razorpay_webhook_events
      WHERE payload_sha256=p_payload_sha256 FOR UPDATE;
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'WEBHOOK_EVENT_ENQUEUE_RETRY'; END IF;
  IF v_event.event_type <> p_event_type OR v_event.payload_sha256 <> p_payload_sha256 THEN
    RETURN jsonb_build_object('success',false,'payload_conflict',true,'accepted',false);
  END IF;
  IF v_event.event_payload IS NULL AND v_event.state NOT IN ('processed','ignored') THEN
    UPDATE public.srk_razorpay_webhook_events
      SET event_payload=p_event_payload,state='queued',claim_token=NULL,lease_expires_at=NULL,
          completed_at=NULL,last_error=NULL,last_received_at=clock_timestamp()
      WHERE event_id=v_event.event_id;
    v_event.state := 'queued';
  ELSE
    UPDATE public.srk_razorpay_webhook_events
      SET last_received_at=clock_timestamp() WHERE event_id=v_event.event_id;
  END IF;
  RETURN jsonb_build_object('success',true,'accepted',true,'duplicate',true,
    'state',v_event.state,'event_id',v_event.event_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_service_enqueue_razorpay_webhook_event(text,text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_enqueue_razorpay_webhook_event(text,text,text,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.srk_service_claim_razorpay_webhook_event_for_worker(p_event_id text)
RETURNS TABLE(event_id text,event_type text,event_payload jsonb,claim_token uuid,attempt_count integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE v_token uuid := gen_random_uuid();
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  WITH picked AS (
    SELECT e.event_id FROM public.srk_razorpay_webhook_events e
    WHERE e.event_id=p_event_id AND e.event_payload IS NOT NULL
      AND (e.state IN ('queued','retryable')
        OR (e.state='processing' AND (e.lease_expires_at IS NULL OR e.lease_expires_at<=clock_timestamp())))
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.srk_razorpay_webhook_events e
    SET state='processing',attempt_count=e.attempt_count+1,claim_token=v_token,
        lease_expires_at=clock_timestamp()+interval '2 minutes',
        last_received_at=clock_timestamp(),last_error=NULL,completed_at=NULL
  FROM picked WHERE e.event_id=picked.event_id
  RETURNING e.event_id,e.event_type,e.event_payload,e.claim_token,e.attempt_count;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_service_claim_razorpay_webhook_event_for_worker(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_claim_razorpay_webhook_event_for_worker(text) TO service_role;

COMMENT ON COLUMN public.srk_razorpay_webhook_events.event_payload IS
  'Minimal validated Razorpay event projection required by the server-side asynchronous reconciler; service-role RPC only.';

CREATE OR REPLACE FUNCTION public.srk_service_list_due_razorpay_webhook_events(p_limit integer DEFAULT 20)
RETURNS TABLE(event_id text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT e.event_id FROM public.srk_razorpay_webhook_events e
    WHERE e.event_payload IS NOT NULL
      AND (e.state IN ('queued','retryable')
        OR (e.state='processing' AND (e.lease_expires_at IS NULL OR e.lease_expires_at<=clock_timestamp())))
    ORDER BY e.first_received_at
    LIMIT greatest(1,least(coalesce(p_limit,20),50));
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_service_list_due_razorpay_webhook_events(integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_list_due_razorpay_webhook_events(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.srk_service_complete_razorpay_webhook_event(
  p_event_id text,p_claim_token uuid,p_outcome text,p_error text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE v_event public.srk_razorpay_webhook_events%rowtype;
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_event_id IS NULL OR p_claim_token IS NULL
     OR p_outcome NOT IN ('processed','ignored','retryable')
     OR (p_error IS NOT NULL AND length(p_error)>500) THEN
    RAISE EXCEPTION 'INVALID_RAZORPAY_WEBHOOK_COMPLETION' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_event FROM public.srk_razorpay_webhook_events
    WHERE event_id=p_event_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'WEBHOOK_EVENT_NOT_FOUND'; END IF;
  IF v_event.state <> 'processing' OR v_event.claim_token IS DISTINCT FROM p_claim_token THEN
    RETURN jsonb_build_object('success',false,'stale_claim',true,'state',v_event.state);
  END IF;
  UPDATE public.srk_razorpay_webhook_events
    SET state=p_outcome,
        completed_at=CASE WHEN p_outcome IN ('processed','ignored') THEN clock_timestamp() ELSE NULL END,
        lease_expires_at=CASE WHEN p_outcome='retryable' THEN clock_timestamp() ELSE NULL END,
        last_error=CASE WHEN p_outcome='retryable' THEN left(coalesce(p_error,'Retryable processing error'),500) ELSE NULL END,
        event_payload=CASE WHEN p_outcome IN ('processed','ignored') THEN NULL ELSE event_payload END,
        claim_token=NULL,last_received_at=clock_timestamp()
    WHERE event_id=p_event_id;
  RETURN jsonb_build_object('success',true,'state',p_outcome);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_service_complete_razorpay_webhook_event(text,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_complete_razorpay_webhook_event(text,uuid,text,text) TO service_role;
