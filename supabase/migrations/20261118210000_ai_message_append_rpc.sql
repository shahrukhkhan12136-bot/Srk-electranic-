-- Append one user or assistant message to an owned, open AI conversation.
-- This storage RPC does not invoke an AI provider or enable the API routes.

BEGIN;

CREATE OR REPLACE FUNCTION public.srk_ai_append_message(
  p_actor_user_id uuid,
  p_conversation_id uuid,
  p_sender_kind text,
  p_body text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_owner_user_id uuid;
  v_status text;
  v_sender_user_id uuid;
  v_message_id uuid;
  v_sequence_no bigint;
  v_created_at timestamptz;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF p_actor_user_id IS NULL OR p_conversation_id IS NULL OR
     p_sender_kind IS NULL OR p_sender_kind NOT IN ('user','assistant') OR
     p_body IS NULL OR length(btrim(p_body)) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'AI_INVALID_MESSAGE' USING ERRCODE='22023';
  END IF;

  SELECT conversation.owner_user_id, conversation.status
    INTO v_owner_user_id, v_status
  FROM public.srk_ai_conversations AS conversation
  WHERE conversation.id = p_conversation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('state','not_found');
  END IF;
  IF v_owner_user_id <> p_actor_user_id THEN
    RETURN jsonb_build_object('state','access_denied');
  END IF;
  IF v_status <> 'open' THEN
    RETURN jsonb_build_object('state','conversation_not_open');
  END IF;

  v_sender_user_id := CASE WHEN p_sender_kind = 'user' THEN p_actor_user_id ELSE NULL END;

  INSERT INTO public.srk_ai_messages (
    conversation_id, sender_kind, sender_user_id, body
  ) VALUES (
    p_conversation_id, p_sender_kind, v_sender_user_id, p_body
  )
  RETURNING id, sequence_no, created_at
    INTO v_message_id, v_sequence_no, v_created_at;

  UPDATE public.srk_ai_conversations
  SET updated_at = clock_timestamp()
  WHERE id = p_conversation_id;

  RETURN jsonb_build_object(
    'state','appended',
    'message_id',v_message_id,
    'sequence_no',v_sequence_no,
    'created_at',v_created_at
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_ai_append_message(uuid,uuid,text,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_append_message(uuid,uuid,text,text)
  TO service_role;

COMMIT;
