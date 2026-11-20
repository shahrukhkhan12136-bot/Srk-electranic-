-- Finalize an actor-scoped AI idempotency reservation without storing response bodies.
-- This RPC is storage-only; route wiring and provider calls remain disabled.

BEGIN;

DROP FUNCTION IF EXISTS public.srk_ai_finalize_idempotency(uuid,uuid,bytea,text,integer,uuid);

CREATE OR REPLACE FUNCTION public.srk_ai_complete_idempotency(
  p_actor_user_id uuid,
  p_idempotency_key uuid,
  p_request_sha256 bytea,
  p_lease_version bigint,
  p_conversation_id uuid,
  p_response_body text,
  p_response_code integer DEFAULT 200
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_now timestamptz := transaction_timestamp();
  v_claim public.srk_ai_idempotency%ROWTYPE;
  v_owner_user_id uuid;
  v_conversation_status text;
  v_message_id uuid;
  v_sequence_no bigint;
  v_created_at timestamptz;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_actor_user_id IS NULL OR p_idempotency_key IS NULL OR
     p_request_sha256 IS NULL OR octet_length(p_request_sha256)<>32 OR
     p_lease_version IS NULL OR p_lease_version<1 OR
     p_conversation_id IS NULL OR p_response_body IS NULL OR
     length(btrim(p_response_body)) NOT BETWEEN 1 AND 4000 OR
     p_response_code IS NULL OR p_response_code NOT BETWEEN 100 AND 599 THEN
    RAISE EXCEPTION 'AI_INVALID_IDEMPOTENCY_COMPLETION' USING ERRCODE='22023';
  END IF;

  -- Global lock order: idempotency row first, conversation row second.
  SELECT * INTO v_claim
  FROM public.srk_ai_idempotency
  WHERE actor_user_id=p_actor_user_id AND idempotency_key=p_idempotency_key
  FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('state','not_found'); END IF;
  IF v_claim.request_sha256<>p_request_sha256 THEN
    RETURN jsonb_build_object('state','conflict');
  END IF;

  IF v_claim.status='completed' AND v_claim.retention_expires_at>=v_now THEN
    SELECT m.id INTO v_message_id
    FROM public.srk_ai_messages m
    JOIN public.srk_ai_conversations c ON c.id=m.conversation_id
    WHERE m.id=v_claim.response_message_id
      AND m.conversation_id=v_claim.conversation_id
      AND m.sender_kind='assistant'
      AND c.owner_user_id=p_actor_user_id;
    IF v_message_id IS NULL THEN RETURN jsonb_build_object('state','integrity_error'); END IF;
    RETURN jsonb_build_object(
      'state','replay','response_message_id',v_message_id,
      'response_code',v_claim.response_code,
      'conversation_id',v_claim.conversation_id
    );
  END IF;
  IF v_claim.status='failed' AND v_claim.retention_expires_at>=v_now THEN
    RETURN jsonb_build_object('state','failed','response_code',v_claim.response_code);
  END IF;
  IF v_claim.status<>'processing' THEN
    RETURN jsonb_build_object('state','retention_expired');
  END IF;
  IF v_claim.lease_version<>p_lease_version THEN
    RETURN jsonb_build_object('state','stale_lease');
  END IF;
  IF v_claim.processing_lease_expires_at<=v_now THEN
    RETURN jsonb_build_object('state','lease_expired');
  END IF;

  SELECT c.owner_user_id,c.status
    INTO v_owner_user_id,v_conversation_status
  FROM public.srk_ai_conversations c
  WHERE c.id=p_conversation_id
  FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('state','conversation_not_found'); END IF;
  IF v_owner_user_id<>p_actor_user_id THEN
    RETURN jsonb_build_object('state','access_denied');
  END IF;
  IF v_conversation_status<>'open' THEN
    RETURN jsonb_build_object('state','conversation_not_open');
  END IF;

  INSERT INTO public.srk_ai_messages(
    conversation_id,sender_kind,sender_user_id,body
  ) VALUES (p_conversation_id,'assistant',NULL,p_response_body)
  RETURNING id,sequence_no,created_at
    INTO v_message_id,v_sequence_no,v_created_at;

  UPDATE public.srk_ai_idempotency
  SET status='completed',
      conversation_id=p_conversation_id,
      response_message_id=v_message_id,
      response_code=p_response_code,
      completed_at=v_now,
      failed_at=NULL,
      processing_lease_expires_at=NULL,
      retention_expires_at=v_now+interval '7 days'
  WHERE id=v_claim.id;

  UPDATE public.srk_ai_conversations
  SET updated_at=v_now
  WHERE id=p_conversation_id;

  INSERT INTO public.srk_ai_audit_events(
    conversation_id,actor_user_id,module_key,action_key,outcome,request_id
  )
  SELECT c.id,p_actor_user_id,c.module_key,'message_recorded','completed',p_idempotency_key
  FROM public.srk_ai_conversations c WHERE c.id=p_conversation_id;

  RETURN jsonb_build_object(
    'state','completed','response_message_id',v_message_id,
    'conversation_id',p_conversation_id,'response_code',p_response_code,
    'sequence_no',v_sequence_no,'created_at',v_created_at
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_ai_finalize_idempotency(
  p_actor_user_id uuid,
  p_idempotency_key uuid,
  p_request_sha256 bytea,
  p_lease_version bigint,
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
  v_now timestamptz := transaction_timestamp();
  v_claim public.srk_ai_idempotency%ROWTYPE;
  v_owner_user_id uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_actor_user_id IS NULL OR p_idempotency_key IS NULL OR
     p_request_sha256 IS NULL OR octet_length(p_request_sha256)<>32 OR
     p_lease_version IS NULL OR p_lease_version<1 OR
     p_final_status IS DISTINCT FROM 'failed' OR
     p_response_code IS NULL OR p_response_code NOT BETWEEN 100 AND 599 THEN
    RAISE EXCEPTION 'AI_INVALID_IDEMPOTENCY_FAILURE' USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_claim
  FROM public.srk_ai_idempotency
  WHERE actor_user_id=p_actor_user_id AND idempotency_key=p_idempotency_key
  FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('state','not_found'); END IF;
  IF v_claim.request_sha256<>p_request_sha256 THEN
    RETURN jsonb_build_object('state','conflict');
  END IF;
  IF v_claim.status<>'processing' THEN
    RETURN jsonb_build_object('state','not_processing');
  END IF;
  IF v_claim.lease_version<>p_lease_version THEN
    RETURN jsonb_build_object('state','stale_lease');
  END IF;
  IF v_claim.processing_lease_expires_at<=v_now THEN
    RETURN jsonb_build_object('state','lease_expired');
  END IF;

  IF p_conversation_id IS NOT NULL THEN
    SELECT c.owner_user_id INTO v_owner_user_id
    FROM public.srk_ai_conversations c
    WHERE c.id=p_conversation_id
    FOR UPDATE;
    IF NOT FOUND OR v_owner_user_id<>p_actor_user_id THEN
      RETURN jsonb_build_object('state','access_denied');
    END IF;
  END IF;

  UPDATE public.srk_ai_idempotency
  SET status='failed',
      conversation_id=p_conversation_id,
      response_code=p_response_code,
      completed_at=NULL,
      failed_at=v_now,
      processing_lease_expires_at=NULL,
      retention_expires_at=v_now+interval '7 days'
  WHERE id=v_claim.id;

  RETURN jsonb_build_object('state','failed','id',v_claim.id,'response_code',p_response_code);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_ai_complete_idempotency(uuid,uuid,bytea,bigint,uuid,text,integer)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_complete_idempotency(uuid,uuid,bytea,bigint,uuid,text,integer)
  TO service_role;

REVOKE ALL ON FUNCTION public.srk_ai_finalize_idempotency(uuid,uuid,bytea,bigint,text,integer,uuid)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_finalize_idempotency(uuid,uuid,bytea,bigint,text,integer,uuid)
  TO service_role;

COMMIT;
