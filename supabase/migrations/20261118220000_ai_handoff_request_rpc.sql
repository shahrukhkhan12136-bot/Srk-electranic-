-- Atomically queue a human handoff and move the owned conversation to handoff_requested.
-- This records a queue item only; it does not notify or assign a human agent.

BEGIN;

CREATE OR REPLACE FUNCTION public.srk_ai_request_handoff(
  p_actor_user_id uuid,
  p_conversation_id uuid,
  p_reason_code text,
  p_urgency text,
  p_summary text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_owner_user_id uuid;
  v_module_key text;
  v_status text;
  v_queue_id uuid;
  v_queue_status text;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF p_actor_user_id IS NULL OR p_conversation_id IS NULL OR
     p_reason_code IS NULL OR p_reason_code NOT IN (
       'needs_human_support','safety_concern','account_issue','billing_question','other'
     ) OR
     p_urgency IS NULL OR p_urgency NOT IN ('low','normal','high') OR
     p_summary IS NULL OR length(btrim(p_summary)) NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'AI_INVALID_HANDOFF' USING ERRCODE='22023';
  END IF;

  SELECT conversation.owner_user_id, conversation.module_key, conversation.status
    INTO v_owner_user_id, v_module_key, v_status
  FROM public.srk_ai_conversations AS conversation
  WHERE conversation.id = p_conversation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('state','not_found');
  END IF;
  IF v_owner_user_id <> p_actor_user_id THEN
    RETURN jsonb_build_object('state','access_denied');
  END IF;

  IF v_status = 'handoff_requested' THEN
    SELECT queue.id, queue.status
      INTO v_queue_id, v_queue_status
    FROM public.srk_ai_handoff_queue AS queue
    WHERE queue.conversation_id = p_conversation_id
      AND queue.status IN ('queued','assigned')
    ORDER BY queue.created_at DESC, queue.id DESC
    LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object(
        'state','already_queued','handoff_id',v_queue_id,'status',v_queue_status
      );
    END IF;
    RETURN jsonb_build_object('state','handoff_unavailable');
  END IF;

  IF v_status <> 'open' THEN
    RETURN jsonb_build_object('state','conversation_not_open');
  END IF;

  INSERT INTO public.srk_ai_handoff_queue (
    conversation_id, requested_by, reason_code, urgency, summary
  ) VALUES (
    p_conversation_id, p_actor_user_id, p_reason_code, p_urgency, p_summary
  )
  RETURNING id INTO v_queue_id;

  UPDATE public.srk_ai_conversations
  SET status = 'handoff_requested', updated_at = clock_timestamp()
  WHERE id = p_conversation_id;

  INSERT INTO public.srk_ai_audit_events (
    conversation_id, actor_user_id, module_key, action_key, outcome
  ) VALUES (
    p_conversation_id, p_actor_user_id, v_module_key, 'handoff_requested', 'accepted'
  );

  RETURN jsonb_build_object('state','queued','handoff_id',v_queue_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_ai_request_handoff(uuid,uuid,text,text,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_request_handoff(uuid,uuid,text,text,text)
  TO service_role;

COMMIT;
