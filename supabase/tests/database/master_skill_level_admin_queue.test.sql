BEGIN;
SELECT plan(7);
SELECT has_function('public','srk_admin_list_master_skill_level_options',ARRAY[]::text[],
 'Main Admin can list approved Technician skills and available rate levels');
SELECT ok(
 has_function_privilege('authenticated','public.srk_admin_list_master_skill_level_options()','EXECUTE')
 AND NOT has_function_privilege('anon','public.srk_admin_list_master_skill_level_options()','EXECUTE'),
 'skill-level queue is authenticated-only'
);
SELECT ok(
 position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_list_master_skill_level_options()'::regprocedure))>0,
 'skill-level queue verifies Main Admin server-side'
);
SELECT ok(
 position('a.status = ''approved''' in replace(pg_get_functiondef('public.srk_admin_list_master_skill_level_options()'::regprocedure),'a.status=''approved''','a.status = ''approved'''))>0
 OR position('a.status=''approved''' in pg_get_functiondef('public.srk_admin_list_master_skill_level_options()'::regprocedure))>0,
 'only approved Technician applications are returned'
);
SELECT ok(
 position('aps.review_status=''approved''' in pg_get_functiondef('public.srk_admin_list_master_skill_level_options()'::regprocedure))>0,
 'only Admin-approved skills are returned'
);
SELECT ok(
 position('r.status=''active''' in pg_get_functiondef('public.srk_admin_list_master_skill_level_options()'::regprocedure))>0,
 'only active rate levels are offered for assignment'
);
SELECT ok(
 has_function('public','srk_admin_set_technician_skill_level',ARRAY['uuid','text']),
 'assignment uses the existing audited Admin skill-level RPC'
);
SELECT * FROM finish();
ROLLBACK;
