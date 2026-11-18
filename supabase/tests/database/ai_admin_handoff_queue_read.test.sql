BEGIN;
SELECT plan(13);

SELECT has_table('public','srk_ai_handoff_queue','private AI handoff queue exists');
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_ai_handoff_queue'::regclass),
  'AI handoff queue has RLS enabled'
);
SELECT ok(
  NOT has_table_privilege('anon','public.srk_ai_handoff_queue','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_ai_handoff_queue','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_ai_handoff_queue','UPDATE'),
  'browser roles cannot directly read or mutate the handoff queue'
);
SELECT has_function('public','srk_admin_list_ai_handoff_queue',ARRAY['integer'],
  'Main Admin AI handoff queue read RPC exists');
SELECT ok(
  (SELECT prosecdef FROM pg_proc WHERE oid='public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure),
  'queue read RPC is SECURITY DEFINER'
);
SELECT ok(
  (SELECT provolatile='s' FROM pg_proc WHERE oid='public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure),
  'queue read RPC is STABLE'
);
SELECT ok(
  (SELECT proconfig @> ARRAY['search_path=""']::text[] FROM pg_proc
   WHERE oid='public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure),
  'queue read RPC pins an empty search_path'
);
SELECT ok(
  has_function_privilege('authenticated','public.srk_admin_list_ai_handoff_queue(integer)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_list_ai_handoff_queue(integer)','EXECUTE'),
  'only authenticated callers can reach the RPC permission gate'
);
SELECT ok(
  position('auth.uid()' in pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure))>0
  AND position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure))>0
  AND position('ADMIN_PERMISSION_REQUIRED' in pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure))>0,
  'queue RPC requires a signed-in Main Admin'
);
SELECT ok(
  position('p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100' in pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure))>0,
  'queue RPC rejects invalid and unbounded page sizes'
);
SELECT ok(
  position('q.status IN (''queued'',''assigned'')' in pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure))>0
  AND position('public.srk_ai_conversations' in pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure))>0,
  'queue RPC returns only active handoffs with conversation context'
);
SELECT ok(
  position('WHEN ''high'' THEN 0 WHEN ''normal'' THEN 1 ELSE 2 END' in pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure))>0
  AND position('q.created_at ASC' in pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure))>0
  AND position('q.id ASC' in pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure))>0,
  'queue ordering is priority-first and deterministic'
);
SELECT ok(
  position('INSERT INTO' in upper(pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure)))=0
  AND position('UPDATE ' in upper(pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure)))=0
  AND position('DELETE ' in upper(pg_get_functiondef('public.srk_admin_list_ai_handoff_queue(integer)'::regprocedure)))=0,
  'queue RPC is read-only and cannot assign or resolve handoffs'
);

SELECT * FROM finish();
ROLLBACK;
