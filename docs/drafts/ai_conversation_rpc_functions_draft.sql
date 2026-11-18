-- DRAFT ONLY: trusted-server RPCs for the AI conversation foundation.
-- Not a migration. Do not apply to hosted Supabase projects.
-- Functions live in a non-exposed schema and accept calls only with a service_role JWT.
BEGIN;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;

CREATE OR REPLACE FUNCTION private.ai_claim_idempotency(
  p_owner_user_id uuid,
  p_endpoint_key text,
  p_idempotency_key text,
  p_request_hash text,
  p_lease_seconds integer DEFAULT 90
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_row public.srk_ai_idempotency%ROWTYPE;
  v_now timestamptz := pg_catalog.clock_timestamp();
BEGIN
  IF COALESCE(pg_catalog.current_setting('request.jwt.claim.role', true), '') <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF p_owner_user_id IS NULL
     OR p_endpoint_key NOT IN ('assistant','handoff','action')
     OR p_idempotency_key IS NULL OR pg_catalog.length(p_idempotency_key) NOT BETWEEN 16 AND 128
     OR p_request_hash !~ '^[0-9a-f]{64}$'
     OR p_lease_seconds NOT BETWEEN 15 AND 600 THEN
    RAISE EXCEPTION 'invalid_idempotency_claim' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.srk_ai_idempotency(
    owner_user_id, endpoint_key, idempotency_key, request_hash,
    state, lease_expires_at, expires_at
  ) VALUES (
    p_owner_user_id, p_endpoint_key, p_idempotency_key, p_request_hash,
    'processing', v_now + pg_catalog.make_interval(secs => p_lease_seconds),
    v_now + interval '24 hours'
  )
  ON CONFLICT (owner_user_id, endpoint_key, idempotency_key) DO NOTHING;

  SELECT * INTO v_row
  FROM public.srk_ai_idempotency
  WHERE owner_user_id = p_owner_user_id
    AND endpoint_key = p_endpoint_key
    AND idempotency_key = p_idempotency_key
  FOR UPDATE;

  IF v_row.request_hash <> p_request_hash THEN
    RETURN pg_catalog.jsonb_build_object('status','conflict');
  END IF;
  IF v_row.state = 'completed' THEN
    RETURN pg_catalog.jsonb_build_object(
      'status','replay','response_status',v_row.response_status,'response_body',v_row.response_body
    );
  END IF;
  IF v_row.state = 'processing' AND v_row.lease_expires_at > v_now THEN
    RETURN pg_catalog.jsonb_build_object('status','processing');
  END IF;

  UPDATE public.srk_ai_idempotency
  SET state='processing',
      response_status=NULL,
      response_body=NULL,
      lease_expires_at=v_now + pg_catalog.make_interval(secs => p_lease_seconds),
      expires_at=v_now + interval '24 hours'
  WHERE id=v_row.id;

  RETURN pg_catalog.jsonb_build_object('status','claimed','id',v_row.id);
END;
$$;

CREATE OR REPLACE FUNCTION private.ai_append_message(
  p_owner_user_id uuid,
  p_conversation_id uuid,
  p_sender_type text,
  p_body text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_sequence bigint;
  v_message_id uuid;
BEGIN
  IF COALESCE(pg_catalog.current_setting('request.jwt.claim.role', true), '') <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF p_owner_user_id IS NULL OR p_conversation_id IS NULL
     OR p_sender_type NOT IN ('user','assistant','system')
     OR p_body IS NULL OR pg_catalog.length(pg_catalog.btrim(p_body)) NOT BETWEEN 1 AND 8000 THEN
    RAISE EXCEPTION 'invalid_ai_message' USING ERRCODE = '22023';
  END IF;

  PERFORM 1 FROM public.srk_ai_conversations
  WHERE id=p_conversation_id AND owner_user_id=p_owner_user_id AND status='open'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation_not_found_or_closed' USING ERRCODE = 'P0002';
  END IF;

  SELECT COALESCE(pg_catalog.max(sequence_no),0)+1 INTO v_sequence
  FROM public.srk_ai_messages WHERE conversation_id=p_conversation_id;

  INSERT INTO public.srk_ai_messages(conversation_id,sequence_no,sender_type,body)
  VALUES(p_conversation_id,v_sequence,p_sender_type,p_body)
  RETURNING id INTO v_message_id;

  UPDATE public.srk_ai_conversations SET updated_at=pg_catalog.clock_timestamp()
  WHERE id=p_conversation_id;

  RETURN pg_catalog.jsonb_build_object('message_id',v_message_id,'sequence_no',v_sequence);
END;
$$;

CREATE OR REPLACE FUNCTION private.ai_append_audit_event(
  p_actor_user_id uuid,
  p_actor_type text,
  p_module_key text,
  p_event_type text,
  p_outcome text,
  p_conversation_id uuid DEFAULT NULL,
  p_handoff_id uuid DEFAULT NULL,
  p_correlation_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF COALESCE(pg_catalog.current_setting('request.jwt.claim.role', true), '') <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF p_actor_type NOT IN ('customer','electrician','staff','main_admin','system')
     OR p_module_key NOT IN ('customer_support','booking_assistant','electrician_assistant','system')
     OR p_event_type NOT IN ('conversation_created','message_persisted','provider_requested','provider_failed','handoff_created','handoff_status_changed','access_denied','rate_limited','safety_block')
     OR p_outcome NOT IN ('allowed','denied','success','failure')
     OR p_metadata IS NULL OR pg_catalog.pg_column_size(p_metadata)>8192 THEN
    RAISE EXCEPTION 'invalid_ai_audit_event' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.srk_ai_audit_events(
    actor_user_id,actor_type,module_key,event_type,outcome,
    conversation_id,handoff_id,correlation_id,metadata
  ) VALUES (
    p_actor_user_id,p_actor_type,p_module_key,p_event_type,p_outcome,
    p_conversation_id,p_handoff_id,p_correlation_id,p_metadata
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;


CREATE OR REPLACE FUNCTION private.ai_complete_idempotency(
  p_owner_user_id uuid,
  p_endpoint_key text,
  p_idempotency_key text,
  p_response_status integer,
  p_response_body jsonb,
  p_conversation_id uuid DEFAULT NULL,
  p_assistant_body text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $
DECLARE
  v_row public.srk_ai_idempotency%ROWTYPE;
  v_message jsonb;
BEGIN
  IF COALESCE(pg_catalog.current_setting('request.jwt.claim.role', true), '') <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF p_owner_user_id IS NULL
     OR p_endpoint_key NOT IN ('assistant','handoff','action')
     OR p_idempotency_key IS NULL OR pg_catalog.length(p_idempotency_key) NOT BETWEEN 16 AND 128
     OR p_response_status NOT BETWEEN 200 AND 599
     OR p_response_body IS NULL OR pg_catalog.pg_column_size(p_response_body) > 65536
     OR ((p_conversation_id IS NULL) <> (p_assistant_body IS NULL))
     OR (p_assistant_body IS NOT NULL AND pg_catalog.length(pg_catalog.btrim(p_assistant_body)) NOT BETWEEN 1 AND 8000) THEN
    RAISE EXCEPTION 'invalid_idempotency_completion' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row
  FROM public.srk_ai_idempotency
  WHERE owner_user_id=p_owner_user_id
    AND endpoint_key=p_endpoint_key
    AND idempotency_key=p_idempotency_key
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'idempotency_claim_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_row.state <> 'processing' OR v_row.lease_expires_at IS NULL
     OR v_row.lease_expires_at <= pg_catalog.clock_timestamp() THEN
    RAISE EXCEPTION 'idempotency_claim_not_active' USING ERRCODE = '55000';
  END IF;

  IF p_conversation_id IS NOT NULL THEN
    v_message := private.ai_append_message(
      p_owner_user_id,p_conversation_id,'assistant',p_assistant_body
    );
  END IF;

  UPDATE public.srk_ai_idempotency
  SET state='completed',
      response_status=p_response_status,
      response_body=p_response_body,
      lease_expires_at=NULL
  WHERE id=v_row.id;

  RETURN pg_catalog.jsonb_build_object(
    'status','completed',
    'message_id',v_message->>'message_id',
    'sequence_no',v_message->>'sequence_no'
  );
END;
$;

REVOKE ALL ON FUNCTION private.ai_claim_idempotency(uuid,text,text,text,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.ai_append_message(uuid,uuid,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.ai_append_audit_event(uuid,text,text,text,text,uuid,uuid,uuid,jsonb) FROM PUBLIC, anon, authenticated;\nREVOKE ALL ON FUNCTION private.ai_complete_idempotency(uuid,text,text,integer,jsonb,uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.ai_claim_idempotency(uuid,text,text,text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION private.ai_append_message(uuid,uuid,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION private.ai_append_audit_event(uuid,text,text,text,text,uuid,uuid,uuid,jsonb) TO service_role;\nGRANT EXECUTE ON FUNCTION private.ai_complete_idempotency(uuid,text,text,integer,jsonb,uuid,text) TO service_role;

COMMIT;
