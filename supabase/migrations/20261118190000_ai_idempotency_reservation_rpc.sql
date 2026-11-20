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
  v_now timestamptz := transaction_timestamp();
  v_id uuid;
  v_existing public.srk_ai_idempotency%ROWTYPE;
  v_message_id uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_actor_user_id IS NULL OR p_idempotency_key IS NULL OR
     p_request_sha256 IS NULL OR octet_length(p_request_sha256) <> 32 THEN
    RAISE EXCEPTION 'AI_INVALID_IDEMPOTENCY_ARGUMENT' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.srk_ai_idempotency (
    actor_user_id,idempotency_key,request_sha256,status,
    processing_lease_expires_at,lease_version
  ) VALUES (
    p_actor_user_id,p_idempotency_key,p_request_sha256,'processing',
    v_now+interval '5 minutes',1
  )
  ON CONFLICT (actor_user_id,idempotency_key) DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NOT NULL THEN
    RETURN jsonb_build_object('state','reserved','id',v_id,'lease_version',1);
  END IF;

  SELECT * INTO v_existing
  FROM public.srk_ai_idempotency
  WHERE actor_user_id=p_actor_user_id
    AND idempotency_key=p_idempotency_key
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'AI_IDEMPOTENCY_RESERVATION_UNAVAILABLE' USING ERRCODE='40001';
  END IF;

  IF v_existing.status='processing' THEN
    IF v_existing.request_sha256<>p_request_sha256 THEN
      RETURN jsonb_build_object('state','conflict');
    END IF;
    IF v_existing.processing_lease_expires_at<=v_now THEN
      UPDATE public.srk_ai_idempotency
      SET processing_lease_expires_at=v_now+interval '5 minutes',
          lease_version=lease_version+1,
          created_at=v_now
      WHERE id=v_existing.id
      RETURNING lease_version INTO v_existing.lease_version;
      RETURN jsonb_build_object(
        'state','reserved','id',v_existing.id,'lease_version',v_existing.lease_version
      );
    END IF;
    RETURN jsonb_build_object('state','processing');
  END IF;

  IF v_existing.status='completed' AND v_existing.retention_expires_at>=v_now THEN
    IF v_existing.request_sha256<>p_request_sha256 THEN
      RETURN jsonb_build_object('state','conflict');
    END IF;
    SELECT m.id INTO v_message_id
    FROM public.srk_ai_messages m
    JOIN public.srk_ai_conversations c ON c.id=m.conversation_id
    WHERE m.id=v_existing.response_message_id
      AND m.conversation_id=v_existing.conversation_id
      AND m.sender_kind='assistant'
      AND c.owner_user_id=p_actor_user_id;
    IF v_message_id IS NULL THEN
      RETURN jsonb_build_object('state','integrity_error');
    END IF;
    RETURN jsonb_build_object(
      'state','replay','response_message_id',v_message_id,
      'response_code',v_existing.response_code,
      'conversation_id',v_existing.conversation_id
    );
  END IF;

  IF v_existing.status='failed' AND v_existing.retention_expires_at>=v_now THEN
    IF v_existing.request_sha256<>p_request_sha256 THEN
      RETURN jsonb_build_object('state','conflict');
    END IF;
    RETURN jsonb_build_object(
      'state','failed','response_code',v_existing.response_code
    );
  END IF;

  UPDATE public.srk_ai_idempotency
  SET request_sha256=p_request_sha256,
      status='processing',
      conversation_id=NULL,
      response_message_id=NULL,
      response_code=NULL,
      created_at=v_now,
      completed_at=NULL,
      failed_at=NULL,
      processing_lease_expires_at=v_now+interval '5 minutes',
      retention_expires_at=NULL,
      lease_version=lease_version+1
  WHERE id=v_existing.id
  RETURNING lease_version INTO v_existing.lease_version;

  RETURN jsonb_build_object(
    'state','reserved','id',v_existing.id,'lease_version',v_existing.lease_version
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_ai_reserve_idempotency(uuid,uuid,bytea)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_reserve_idempotency(uuid,uuid,bytea)
  TO service_role;

COMMIT;
