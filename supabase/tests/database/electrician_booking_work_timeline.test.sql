BEGIN;
SELECT plan(9);
SELECT has_function('public','srk_electrician_get_my_booking_work_timeline',ARRAY[]::text[],'electrician work timeline RPC exists');
SELECT ok(NOT has_function_privilege('anon','public.srk_electrician_get_my_booking_work_timeline()','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_electrician_get_my_booking_work_timeline()','EXECUTE'),
  'electrician timeline RPC is authenticated-only');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid='public.srk_electrician_get_my_booking_work_timeline()'::regprocedure),
  'electrician timeline RPC uses SECURITY DEFINER');
SELECT ok(pg_get_functiondef('public.srk_electrician_get_my_booking_work_timeline()'::regprocedure) ILIKE '%ep.id=b.assigned_electrician_id%'
  AND pg_get_functiondef('public.srk_electrician_get_my_booking_work_timeline()'::regprocedure) ILIKE '%ep.user_id=auth.uid()%'
  AND pg_get_functiondef('public.srk_electrician_get_my_booking_work_timeline()'::regprocedure) ILIKE '%ep.auth_user_id=auth.uid()%',
  'timeline is scoped to the authenticated owner of the assigned electrician profile');
SELECT ok(pg_get_functiondef('public.srk_electrician_get_my_booking_work_timeline()'::regprocedure) ILIKE '%e.actor_role%'
  AND pg_get_functiondef('public.srk_electrician_get_my_booking_work_timeline()'::regprocedure) ILIKE '%e.occurred_at%',
  'timeline exposes actor role and server event timestamp');
SELECT ok(pg_get_functiondef('public.srk_electrician_get_my_booking_work_timeline()'::regprocedure) NOT ILIKE '%e.details%'
  AND pg_get_functiondef('public.srk_electrician_get_my_booking_work_timeline()'::regprocedure) NOT ILIKE '%e.actor_id%',
  'timeline excludes private event details and actor identifiers');
SELECT ok(pg_get_functiondef('public.srk_electrician_get_my_booking_work_timeline()'::regprocedure) ILIKE '%ORDER BY e.booking_id,e.occurred_at,e.id%',
  'timeline uses deterministic chronological ordering');
SELECT ok(pg_get_functiondef('public.srk_electrician_get_my_booking_work_timeline()'::regprocedure) ILIKE '%auth.uid() IS NULL%',
  'timeline rejects unauthenticated calls');
SELECT ok(pg_get_functiondef('public.srk_electrician_get_my_booking_work_timeline()'::regprocedure) ILIKE '%SECURITY DEFINER%',
  'function definition documents protected execution context');
SELECT * FROM finish();
ROLLBACK;
