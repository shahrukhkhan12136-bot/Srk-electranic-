-- Atomic, actor-scoped idempotency reservation for AI server requests.
-- Storage/RPC only: no route wiring, provider calls, or feature enablement.
-- Apply only after a separately approved disposable/staging replay.

BEGIN;

CREATE OR REPLACE FUNCTION public.srk_ai_reserve_idempotency(
  p_actor_user_id uuid,
  p_idempotency_key uuid,
  p_request_sha256 bytea
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_id uuid;
  v_existing public.srk_ai_idempotency%ROWTYPE;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_actor_user_id IS NULL OR p_idempotency_key IS NULL OR
     p_request_sha256 IS NULL OR octet_length(p_request_sha256) <> 32 THEN
    RAISE EXCEPTION 'AI_INVALID_IDEMPOTENCY_ARGUMENT' USING ERRCODE='22023';
  END IF;

  -- A new key is claimed once. An expired record may be recycled, but a live
  -- processing record is never overwritten by a concurrent request.
  INSERT INTO public.srk_ai_idempotency AS current_row (
    actor_user_id, idempotency_key, request_sha256, status, expires_at
  )
  VALUES (
    p_actor_user_id, p_idempotency_key, p_request_sha256,
    'processing', clock_timestamp() + interval '24 hours'
  )
  ON CONFLICT (actor_user_id, idempotency_key) DO UPDATE
    SET request_sha256 = EXCLUDED.request_sha256,
        status = 'processing',
        conversation_id = NULL,
        response_code = NULL,
        created_at = clock_timestamp(),
        completed_at = NULL,
        expires_at = clock_timestamp() + interval '24 hours'
    WHERE current_row.expires_at <= clock_timestamp()
  RETURNING id INTO v_id;

  IF v_id IS NOT NULL THEN
    RETURN jsonb_build_object('state','reserved','id',v_id);
  END IF;

  SELECT * INTO v_existing
  FROM public.srk_ai_idempotency
  WHERE actor_user_id = p_actor_user_id
    AND idempotency_key = p_idempotency_key
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'AI_IDEMPOTENCY_RESERVATION_UNAVAILABLE' USING ERRCODE='40001';
  END IF;
  IF v_existing.request_sha256 <> p_request_sha256 THEN
    RETURN jsonb_build_object('state','conflict');
  END IF;
  IF v_existing.status = 'completed' THEN
    RETURN jsonb_build_object(
      'state','replay',
      'response_code',v_existing.response_code,
      'conversation_id',v_existing.conversation_id
    );
  END IF;
  IF v_existing.status = 'processing' THEN
    RETURN jsonb_build_object('state','processing');
  END IF;
  RETURN jsonb_build_object(
    'state','failed',
    'response_code',v_existing.response_code,
    'conversation_id',v_existing.conversation_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_ai_reserve_idempotency(uuid,uuid,bytea)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_reserve_idempotency(uuid,uuid,bytea)
  TO service_role;

COMMIT;
