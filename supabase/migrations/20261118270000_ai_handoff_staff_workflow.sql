-- Staff assignment, assigned-thread replies, and resolution for AI human handoff.
-- All Staff actions require active tracked session plus explicit per-person permissions.
-- Source migration only; no hosted database is modified by this commit.

BEGIN;

CREATE OR REPLACE FUNCTION public.srk_admin_assign_ai_handoff(
  p_handoff_id uuid,
  p_staff_user_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_staff_role text;
  v_handoff public.srk_ai_handoff_queue%ROWTYPE;
  v_module_key text;
BEGIN
  IF v_actor IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'MAIN_ADMIN_ONLY' USING ERRCODE='42501';
  END IF;
  IF p_handoff_id IS NULL OR p_staff_user_id IS NULL OR
     length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500 THEN
    RAISE EXCEPTION 'INVALID_AI_HANDOFF_ASSIGNMENT' USING ERRCODE='22023';
  END IF;

  SELECT s.role_key INTO v_staff_role
  FROM public.srk_admin_staff s
  WHERE s.user_id=p_staff_user_id AND s.status='active'
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'AI_HANDOFF_STAFF_NOT_ACTIVE' USING ERRCODE='22023';
  END IF;

  -- Assignment requires both read and reply permission, whether inherited from
  -- the Staff role or explicitly granted to this individual.
  IF NOT (
    (EXISTS (SELECT 1 FROM public.srk_admin_role_permissions rp
      WHERE rp.role_key=v_staff_role AND rp.permission_key='ai.handoff.read')
     OR EXISTS (SELECT 1 FROM public.srk_admin_staff_permission_grants g
      WHERE g.staff_user_id=p_staff_user_id AND g.permission_key='ai.handoff.read'))
    AND
    (EXISTS (SELECT 1 FROM public.srk_admin_role_permissions rp
      WHERE rp.role_key=v_staff_role AND rp.permission_key='ai.handoff.reply')
     OR EXISTS (SELECT 1 FROM public.srk_admin_staff_permission_grants g
      WHERE g.staff_user_id=p_staff_user_id AND g.permission_key='ai.handoff.reply'))
  ) THEN
    RAISE EXCEPTION 'AI_HANDOFF_STAFF_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;

  SELECT q.* INTO v_handoff
  FROM public.srk_ai_handoff_queue q
  WHERE q.id=p_handoff_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('state','not_found');
  END IF;
  IF v_handoff.status NOT IN ('queued','assigned') THEN
    RETURN jsonb_build_object('state','not_assignable');
  END IF;

  SELECT c.module_key INTO v_module_key
  FROM public.srk_ai_conversations c
  WHERE c.id=v_handoff.conversation_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('state','conversation_not_found');
  END IF;

  UPDATE public.srk_ai_handoff_queue
  SET status='assigned', assigned_to=p_staff_user_id, updated_at=clock_timestamp()
  WHERE id=p_handoff_id;

  INSERT INTO public.srk_ai_audit_events
    (conversation_id,actor_user_id,module_key,action_key,outcome)
  VALUES
    (v_handoff.conversation_id,v_actor,v_module_key,'handoff_assigned','accepted');

  INSERT INTO public.srk_admin_staff_audit_events
    (actor_user_id,target_user_id,action,outcome,details)
  VALUES
    (v_actor,p_staff_user_id,'staff.ai_handoff.assigned','success',
     jsonb_build_object('handoff_id',p_handoff_id,'reason',left(p_reason,500)));

  RETURN jsonb_build_object('state','assigned','handoff_id',p_handoff_id,
    'assigned_to',p_staff_user_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_staff_list_assigned_ai_handoffs(
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  handoff_id uuid,
  conversation_id uuid,
  module_key text,
  reason_code text,
  urgency text,
  summary text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path=''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.srk_has_admin_permission('ai.handoff.read') THEN
    RAISE EXCEPTION 'AI_HANDOFF_READ_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'INVALID_PAGE_LIMIT' USING ERRCODE='22023';
  END IF;

  RETURN QUERY
  SELECT q.id,q.conversation_id,c.module_key,q.reason_code,q.urgency,
         q.summary,q.created_at,q.updated_at
  FROM public.srk_ai_handoff_queue q
  JOIN public.srk_ai_conversations c ON c.id=q.conversation_id
  WHERE q.assigned_to=auth.uid() AND q.status='assigned'
  ORDER BY CASE q.urgency WHEN 'high' THEN 0 WHEN 'normal' THEN 1 ELSE 2 END,
           q.created_at ASC,q.id ASC
  LIMIT p_limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_staff_list_assigned_ai_handoff_messages(
  p_handoff_id uuid,
  p_limit integer DEFAULT 100
)
RETURNS TABLE (
  message_id uuid,
  sequence_no bigint,
  sender_kind text,
  sender_user_id uuid,
  body text,
  created_at timestamptz
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_conversation_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.srk_has_admin_permission('ai.handoff.read') THEN
    RAISE EXCEPTION 'AI_HANDOFF_READ_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_handoff_id IS NULL OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 200 THEN
    RAISE EXCEPTION 'INVALID_AI_HANDOFF_MESSAGE_QUERY' USING ERRCODE='22023';
  END IF;

  SELECT q.conversation_id INTO v_conversation_id
  FROM public.srk_ai_handoff_queue q
  WHERE q.id=p_handoff_id AND q.assigned_to=auth.uid() AND q.status='assigned';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'AI_HANDOFF_NOT_ASSIGNED_TO_STAFF' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT m.id,m.sequence_no,m.sender_kind,m.sender_user_id,m.body,m.created_at
  FROM public.srk_ai_messages m
  WHERE m.conversation_id=v_conversation_id
  ORDER BY m.sequence_no ASC,m.id ASC
  LIMIT p_limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_staff_reply_ai_handoff(
  p_handoff_id uuid,
  p_body text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_conversation_id uuid;
  v_module_key text;
  v_message_id uuid;
  v_sequence_no bigint;
  v_created_at timestamptz;
BEGIN
  IF v_actor IS NULL OR NOT public.srk_has_admin_permission('ai.handoff.reply') THEN
    RAISE EXCEPTION 'AI_HANDOFF_REPLY_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_handoff_id IS NULL OR p_body IS NULL OR
     length(btrim(p_body)) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'INVALID_AI_HANDOFF_REPLY' USING ERRCODE='22023';
  END IF;

  SELECT q.conversation_id,c.module_key
    INTO v_conversation_id,v_module_key
  FROM public.srk_ai_handoff_queue q
  JOIN public.srk_ai_conversations c ON c.id=q.conversation_id
  WHERE q.id=p_handoff_id AND q.assigned_to=v_actor AND q.status='assigned'
  FOR UPDATE OF q,c;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'AI_HANDOFF_NOT_ASSIGNED_TO_STAFF' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.srk_ai_messages
    (conversation_id,sender_kind,sender_user_id,body)
  VALUES
    (v_conversation_id,'human_agent',v_actor,p_body)
  RETURNING id,sequence_no,created_at
    INTO v_message_id,v_sequence_no,v_created_at;

  UPDATE public.srk_ai_conversations
  SET updated_at=clock_timestamp()
  WHERE id=v_conversation_id;

  INSERT INTO public.srk_ai_audit_events
    (conversation_id,actor_user_id,module_key,action_key,outcome)
  VALUES
    (v_conversation_id,v_actor,v_module_key,'message_recorded','completed');

  RETURN jsonb_build_object('state','replied','message_id',v_message_id,
    'sequence_no',v_sequence_no,'created_at',v_created_at);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_staff_resolve_ai_handoff(
  p_handoff_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_conversation_id uuid;
  v_module_key text;
BEGIN
  IF v_actor IS NULL OR NOT public.srk_has_admin_permission('ai.handoff.resolve') THEN
    RAISE EXCEPTION 'AI_HANDOFF_RESOLVE_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_handoff_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_AI_HANDOFF_ID' USING ERRCODE='22023';
  END IF;

  SELECT q.conversation_id,c.module_key
    INTO v_conversation_id,v_module_key
  FROM public.srk_ai_handoff_queue q
  JOIN public.srk_ai_conversations c ON c.id=q.conversation_id
  WHERE q.id=p_handoff_id AND q.assigned_to=v_actor AND q.status='assigned'
  FOR UPDATE OF q,c;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'AI_HANDOFF_NOT_ASSIGNED_TO_STAFF' USING ERRCODE='42501';
  END IF;

  UPDATE public.srk_ai_handoff_queue
  SET status='resolved',resolved_at=clock_timestamp(),updated_at=clock_timestamp()
  WHERE id=p_handoff_id;

  UPDATE public.srk_ai_conversations
  SET status='closed',closed_at=clock_timestamp(),updated_at=clock_timestamp()
  WHERE id=v_conversation_id AND status='handoff_requested';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'AI_HANDOFF_CONVERSATION_STATE_INVALID' USING ERRCODE='55000';
  END IF;

  INSERT INTO public.srk_ai_audit_events
    (conversation_id,actor_user_id,module_key,action_key,outcome)
  VALUES
    (v_conversation_id,v_actor,v_module_key,'handoff_resolved','completed');

  RETURN jsonb_build_object('state','resolved','handoff_id',p_handoff_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_assign_ai_handoff(uuid,uuid,text)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_assign_ai_handoff(uuid,uuid,text)
  TO authenticated;
REVOKE ALL ON FUNCTION public.srk_staff_list_assigned_ai_handoffs(integer)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_staff_list_assigned_ai_handoffs(integer)
  TO authenticated;
REVOKE ALL ON FUNCTION public.srk_staff_list_assigned_ai_handoff_messages(uuid,integer)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_staff_list_assigned_ai_handoff_messages(uuid,integer)
  TO authenticated;
REVOKE ALL ON FUNCTION public.srk_staff_reply_ai_handoff(uuid,text)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_staff_reply_ai_handoff(uuid,text)
  TO authenticated;
REVOKE ALL ON FUNCTION public.srk_staff_resolve_ai_handoff(uuid)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_staff_resolve_ai_handoff(uuid)
  TO authenticated;

COMMIT;
