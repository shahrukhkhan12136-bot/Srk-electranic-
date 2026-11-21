BEGIN;
SELECT plan(5);
SELECT has_function('public','srk_admin_list_master_service_taxonomy',ARRAY[]::text[],
 'Main Admin can list configurable service categories and skills');
SELECT ok(
 has_function_privilege('authenticated','public.srk_admin_list_master_service_taxonomy()','EXECUTE')
 AND NOT has_function_privilege('anon','public.srk_admin_list_master_service_taxonomy()','EXECUTE'),
 'service taxonomy read model is authenticated-only'
);
SELECT ok(
 position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_list_master_service_taxonomy()'::regprocedure))>0,
 'service taxonomy read model checks Admin on the server'
);
SELECT ok(
 has_function('public','srk_admin_upsert_service_category',ARRAY['text','text','boolean','integer'])
 AND has_function('public','srk_admin_upsert_service_skill',ARRAY['text','text','text','boolean','boolean']),
 'Admin can manage category and skill taxonomy through audited RPCs'
);
SELECT ok(
 has_function('public','srk_admin_upsert_service_offering',ARRAY['text','text','text','text','text','text','boolean'])
 AND has_function('public','srk_admin_upsert_service_rate',ARRAY['text','text','text','bigint','bigint','bigint','text','text','timestamp with time zone','timestamp with time zone'])
 AND has_function('public','srk_admin_list_service_rates',ARRAY[]::text[]),
 'Admin can manage and review service offerings and versioned rates'
);
SELECT * FROM finish();
ROLLBACK;
