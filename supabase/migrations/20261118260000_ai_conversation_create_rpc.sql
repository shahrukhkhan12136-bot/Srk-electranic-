-- Create an owned AI conversation and its metadata-only audit event atomically.
-- This storage RPC does not enable AI routes or invoke an AI provider.

BEGIN;

CREATE OR REPLACE FUNCTION public.srk_ai_create_conversation(
  p_actor_user_id uuid,
  p_module_key text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_conversation_id uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF p_actor_user_id IS NULL OR p_module_key IS NULL OR
     p_module_key NOT IN (
       'customer_support','booking_assistant','electrician_assistant'
     ) THEN
    RAISE EXCEPTION 'AI_INVALID_CONVERSATION' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.srk_ai_conversations (owner_user_id, module_key)
  VALUES (p_actor_user_id, p_module_key)
  RETURNING id INTO v_conversation_id;

  INSERT INTO public.srk_ai_audit_events (
    conversation_id, actor_user_id, module_key, action_key, outcome
  ) VALUES (
    v_conversation_id, p_actor_user_id, p_module_key,
    'conversation_created', 'accepted'
  );

  RETURN jsonb_build_object(
    'state','created',
    'conversation_id',v_conversation_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_ai_create_conversation(uuid,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_create_conversation(uuid,text)
  TO service_role;

COMMIT;
