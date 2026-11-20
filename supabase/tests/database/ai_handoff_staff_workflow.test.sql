BEGIN;
SELECT plan(18);

SELECT has_function('public','srk_admin_assign_ai_handoff',ARRAY['uuid','uuid','text'],
  'Main Admin handoff assignment RPC exists');
SELECT has_function('public','srk_staff_list_assigned_ai_handoffs',ARRAY['integer'],
  'assigned Staff handoff list RPC exists');
SELECT has_function('public','srk_staff_list_assigned_ai_handoff_messages',ARRAY['uuid','integer'],
  'assigned Staff transcript RPC exists');
SELECT has_function('public','srk_staff_reply_ai_handoff',ARRAY['uuid','text'],
  'assigned Staff reply RPC exists');
SELECT has_function('public','srk_staff_resolve_ai_handoff',ARRAY['uuid'],
  'assigned Staff resolve RPC exists');

SELECT ok(
  (SELECT count(*)=5 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname IN (
    'srk_admin_assign_ai_handoff','srk_staff_list_assigned_ai_handoffs',
    'srk_staff_list_assigned_ai_handoff_messages','srk_staff_reply_ai_handoff',
    'srk_staff_resolve_ai_handoff') AND p.prosecdef
    AND p.proconfig @> ARRAY['search_path=""']::text[]),
  'all five workflow RPCs are SECURITY DEFINER with empty search_path'
);
SELECT ok(
  NOT has_function_privilege('anon','public.srk_admin_assign_ai_handoff(uuid,uuid,text)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_assign_ai_handoff(uuid,uuid,text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_staff_reply_ai_handoff(uuid,text)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_staff_reply_ai_handoff(uuid,text)','EXECUTE'),
  'workflow RPCs are callable only by authenticated sessions behind internal permission gates'
);
SELECT ok(
  position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_assign_ai_handoff(uuid,uuid,text)'::regprocedure))>0
  AND position('MAIN_ADMIN_ONLY' in pg_get_functiondef('public.srk_admin_assign_ai_handoff(uuid,uuid,text)'::regprocedure))>0,
  'only Main Admin can assign handoffs'
);
SELECT ok(
  position('s.status=''active''' in pg_get_functiondef('public.srk_admin_assign_ai_handoff(uuid,uuid,text)'::regprocedure))>0
  AND position('ai.handoff.read' in pg_get_functiondef('public.srk_admin_assign_ai_handoff(uuid,uuid,text)'::regprocedure))>0
  AND position('ai.handoff.reply' in pg_get_functiondef('public.srk_admin_assign_ai_handoff(uuid,uuid,text)'::regprocedure))>0,
  'assignment target must be active and have both read and reply permission'
);
SELECT ok(
  position('public.srk_has_admin_permission(''ai.handoff.read'')' in pg_get_functiondef('public.srk_staff_list_assigned_ai_handoffs(integer)'::regprocedure))>0
  AND position('q.assigned_to=auth.uid()' in pg_get_functiondef('public.srk_staff_list_assigned_ai_handoffs(integer)'::regprocedure))>0,
  'Staff can list only their own assigned handoffs with read permission'
);
SELECT ok(
  position('public.srk_has_admin_permission(''ai.handoff.read'')' in pg_get_functiondef('public.srk_staff_list_assigned_ai_handoff_messages(uuid,integer)'::regprocedure))>0
  AND position('q.assigned_to=auth.uid()' in pg_get_functiondef('public.srk_staff_list_assigned_ai_handoff_messages(uuid,integer)'::regprocedure))>0,
  'Staff transcript access is limited to assigned handoffs'
);
SELECT ok(
  position('public.srk_has_admin_permission(''ai.handoff.reply'')' in pg_get_functiondef('public.srk_staff_reply_ai_handoff(uuid,text)'::regprocedure))>0
  AND position('q.assigned_to=v_actor' in pg_get_functiondef('public.srk_staff_reply_ai_handoff(uuid,text)'::regprocedure))>0
  AND position('human_agent' in pg_get_functiondef('public.srk_staff_reply_ai_handoff(uuid,text)'::regprocedure))>0,
  'reply requires individual reply permission and assigned ownership'
);
SELECT ok(
  position('public.srk_has_admin_permission(''ai.handoff.resolve'')' in pg_get_functiondef('public.srk_staff_resolve_ai_handoff(uuid)'::regprocedure))>0
  AND position('q.assigned_to=v_actor' in pg_get_functiondef('public.srk_staff_resolve_ai_handoff(uuid)'::regprocedure))>0,
  'resolve requires individual resolve permission and assigned ownership'
);
SELECT ok(
  position('staff.ai_handoff.assigned' in pg_get_functiondef('public.srk_admin_assign_ai_handoff(uuid,uuid,text)'::regprocedure))>0
  AND position('handoff_assigned' in pg_get_functiondef('public.srk_admin_assign_ai_handoff(uuid,uuid,text)'::regprocedure))>0
  AND position('handoff_resolved' in pg_get_functiondef('public.srk_staff_resolve_ai_handoff(uuid)'::regprocedure))>0,
  'assignment and resolution append audit events'
);
SELECT ok(
  position('message_recorded' in pg_get_functiondef('public.srk_staff_reply_ai_handoff(uuid,text)'::regprocedure))>0,
  'Staff reply appends a message audit event'
);
SELECT ok(
  position('NOT BETWEEN 1 AND 4000' in pg_get_functiondef('public.srk_staff_reply_ai_handoff(uuid,text)'::regprocedure))>0
  AND position('p_limit NOT BETWEEN 1 AND 200' in pg_get_functiondef('public.srk_staff_list_assigned_ai_handoff_messages(uuid,integer)'::regprocedure))>0,
  'reply body and transcript page size are bounded'
);
SELECT ok(
  position('SET status=''resolved''' in pg_get_functiondef('public.srk_staff_resolve_ai_handoff(uuid)'::regprocedure))>0
  AND position('SET status=''closed''' in pg_get_functiondef('public.srk_staff_resolve_ai_handoff(uuid)'::regprocedure))>0,
  'resolution closes both handoff and conversation'
);
SELECT ok(
  position('FOR UPDATE' in upper(pg_get_functiondef('public.srk_staff_reply_ai_handoff(uuid,text)'::regprocedure)))>0
  AND position('FOR UPDATE' in upper(pg_get_functiondef('public.srk_staff_resolve_ai_handoff(uuid)'::regprocedure)))>0,
  'reply and resolve lock the assigned queue/conversation rows against concurrent actions'
);

SELECT * FROM finish();
ROLLBACK;
