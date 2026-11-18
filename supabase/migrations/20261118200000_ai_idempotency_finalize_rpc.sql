-- Finalize an actor-scoped AI idempotency reservation without storing response bodies.
-- This RPC is storage-only; route wiring and provider calls remain disabled.

BEGIN;

CREATE OR REPLACE FUNCTION public.srk_ai_finalize_idempotency(
  p_actor_user_id uuid,
  p_idempotency_key uuid,
  p_request_sha256 bytea,
  p_final_status text,
  p_response_code integer,
  p_conversation_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_existing public.srk_ai_idempotency%ROWTYPE;
  v_updated_id uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_actor_user_id IS NULL OR p_idempotency_key IS NULL OR
     p_request_sha256 IS NULL OR octet_length(p_request_sha256) <> 32 OR
     p_final_status IS NULL OR p_final_status NOT IN ('completed','failed') OR
     p_response_code IS NULL OR p_response_code NOT BETWEEN 100 AND 599 THEN
    RAISE EXCEPTION 'AI_INVALID_IDEMPOTENCY_FINALIZATION' USING ERRCODE='22023';
  END IF;

  UPDATE public.srk_ai_idempotency AS claim
  SET status = p_final_status,
      response_code = p_response_code,
      conversation_id = p_conversation_id,
      completed_at = clock_timestamp()
  WHERE claim.actor_user_id = p_actor_user_id
    AND claim.idempotency_key = p_idempotency_key
    AND claim.request_sha256 = p_request_sha256
    AND claim.status = 'processing'
    AND (
      p_conversation_id IS NULL OR EXISTS (
        SELECT 1 FROM public.srk_ai_conversations AS conversation
        WHERE conversation.id = p_conversation_id
          AND conversation.owner_user_id = p_actor_user_id
      )
    )
  RETURNING claim.id INTO v_updated_id;

  IF v_updated_id IS NOT NULL THEN
    RETURN jsonb_build_object('state','finalized','id',v_updated_id);
  END IF;

  SELECT * INTO v_existing
  FROM public.srk_ai_idempotency
  WHERE actor_user_id = p_actor_user_id
    AND idempotency_key = p_idempotency_key
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('state','not_found');
  END IF;
  IF v_existing.request_sha256 <> p_request_sha256 THEN
    RETURN jsonb_build_object('state','conflict');
  END IF;
  IF v_existing.status = p_final_status
     AND v_existing.response_code = p_response_code
     AND v_existing.conversation_id IS NOT DISTINCT FROM p_conversation_id THEN
    RETURN jsonb_build_object('state','already_finalized','id',v_existing.id);
  END IF;
  RETURN jsonb_build_object('state','not_processing');
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_ai_finalize_idempotency(uuid,uuid,bytea,text,integer,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_finalize_idempotency(uuid,uuid,bytea,text,integer,uuid)
  TO service_role;

COMMIT;
