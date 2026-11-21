BEGIN;
SELECT plan(5);
SELECT has_function('public','srk_admin_list_master_commission_dues',ARRAY[]::text[]);
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid='public.srk_admin_list_master_commission_dues()'::regprocedure),'Admin report uses controlled definer execution');
SELECT ok(has_function_privilege('authenticated','public.srk_admin_list_master_commission_dues()','EXECUTE'),'authenticated role can call the guarded Admin RPC');
SELECT ok(NOT has_function_privilege('anon','public.srk_admin_list_master_commission_dues()','EXECUTE'),'anonymous role cannot call the Admin report');
SELECT ok((SELECT pg_get_functiondef('public.srk_admin_list_master_commission_dues()'::regprocedure) LIKE '%is_srk_admin%'),'RPC checks Main Admin authorization');
SELECT * FROM finish();
ROLLBACK;
