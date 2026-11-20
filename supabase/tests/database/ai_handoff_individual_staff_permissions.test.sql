BEGIN;
SELECT plan(17);

SELECT has_table('public','srk_admin_staff_permission_grants','individual Staff permission grant table exists');
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_admin_staff_permission_grants'::regclass)
  AND NOT has_table_privilege('anon','public.srk_admin_staff_permission_grants','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_staff_permission_grants','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_staff_permission_grants','INSERT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_staff_permission_grants','DELETE'),
  'individual permission grants are RLS protected and inaccessible directly from browser roles'
);
SELECT ok(
  (SELECT count(*)=3 FROM public.srk_admin_permissions
    WHERE permission_key IN ('ai.handoff.read','ai.handoff.reply','ai.handoff.resolve'))
  AND NOT EXISTS (
    SELECT 1 FROM public.srk_admin_role_permissions
     WHERE permission_key IN ('ai.handoff.read','ai.handoff.reply','ai.handoff.resolve')
  ),
  'AI handoff permissions exist but are never granted to the whole Support role'
);
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid='public.srk_admin_staff_permission_grants'::regclass
       AND conname='srk_admin_staff_permission_ai_only'
       AND pg_get_constraintdef(oid) LIKE '%ai.handoff.read%'
  ),
  'individual grant table accepts only the three AI handoff permission keys'
);
SELECT has_function('public','srk_admin_set_staff_ai_handoff_permission',
  ARRAY['uuid','text','boolean','text'],'Main Admin individual permission grant/revoke RPC exists');
SELECT ok(
  (SELECT prosecdef FROM pg_proc WHERE oid=
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure)
  AND (SELECT proconfig @> ARRAY['search_path=""']::text[] FROM pg_proc
    WHERE oid='public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure),
  'permission management RPC is SECURITY DEFINER with empty search_path'
);
SELECT ok(
  has_function_privilege('authenticated',
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)','EXECUTE')
  AND NOT has_function_privilege('anon',
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)','EXECUTE'),
  'permission management RPC is authenticated-only with a Main Admin gate'
);
SELECT ok(
  position('public.is_srk_admin()' in pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure))>0
  AND position('MAIN_ADMIN_ONLY' in pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure))>0,
  'only Main Admin can grant or revoke individual AI handoff permissions'
);
SELECT ok(
  position('FOR UPDATE' in upper(pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure)))>0
  AND position('v_staff_status<>''active''' in pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure))>0,
  'grant/revoke locks and requires an active Staff account'
);
SELECT ok(
  position('p_permission_key NOT IN' in pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure))>0
  AND position('length(btrim(coalesce(p_reason' in pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure))>0,
  'permission key and audit reason are validated'
);
SELECT ok(
  position('ON CONFLICT (staff_user_id,permission_key) DO UPDATE' in pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure))>0
  AND position('DELETE FROM public.srk_admin_staff_permission_grants' in pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure))>0,
  'grant is idempotent and revoke deletes only the selected person/key pair'
);
SELECT ok(
  position('staff.ai_handoff.permission.granted' in pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure))>0
  AND position('staff.ai_handoff.permission.revoked' in pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure))>0
  AND position('public.srk_admin_staff_audit_events' in pg_get_functiondef(
    'public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)'::regprocedure))>0,
  'grant and revoke actions append an immutable Staff audit event'
);
SELECT ok(
  position('public.srk_admin_staff_sessions' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0
  AND position('tracked.revoked_at IS NULL' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0
  AND position('auth.sessions' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0,
  'individual permission evaluation still requires active tracked and Auth sessions'
);
SELECT ok(
  position('public.srk_admin_staff_permission_grants' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0
  AND position('p_permission_key IN' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0,
  'only explicitly granted AI permission keys use the individual grant path'
);
SELECT ok(
  position('public.srk_admin_role_permissions' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0
  AND position('ai.handoff.read' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0,
  'existing role permissions remain intact while AI permissions stay person-specific'
);


SELECT ok(
  position('s.status=''active''' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))
    < position('tracked.auth_session_id=v_session_id' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))
  AND position('tracked.auth_session_id=v_session_id' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))
    < position('auth.sessions auth_s' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))
  AND position('auth.sessions auth_s' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))
    < position('public.srk_admin_staff_permission_grants g' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure)),
  'active Staff status and both live session checks occur before individual permission grants are considered'
);
SELECT ok(
  position('g.staff_user_id=v_uid AND g.permission_key=p_permission_key' in
    pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0
  AND position('p_permission_key IN (''ai.handoff.read'',''ai.handoff.reply'',''ai.handoff.resolve'')' in
    pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0,
  'an individual grant applies only to the authenticated Staff member and the exact requested AI handoff permission'
);

SELECT * FROM finish();
ROLLBACK;
