-- DRAFT ONLY — static pgTAP contract test; not in the active test runner.
-- Requires the proposed read RPC migration to be implemented in an isolated DB.
BEGIN;
SELECT plan(10);

SELECT has_function(
  'public','srk_admin_list_financial_audit_events',
  ARRAY['integer','timestamp with time zone','uuid','text','uuid','uuid','text'],
  'Finance Audit read RPC exists with explicit filter/cursor signature'
);

SELECT ok(
  (SELECT prosecdef FROM pg_proc
    WHERE oid='public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)'::regprocedure),
  'Finance Audit read RPC is SECURITY DEFINER'
);

SELECT ok(
  (SELECT proconfig @> ARRAY['search_path=""'] FROM pg_proc
    WHERE oid='public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)'::regprocedure),
  'Finance Audit read RPC pins empty search_path'
);

SELECT ok(
  position('public.is_srk_admin()' IN pg_get_functiondef(
    'public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)'::regprocedure
  )) > 0,
  'Finance Audit read RPC explicitly requires Main Admin'
);

SELECT ok(
  position('MAIN_ADMIN_ONLY' IN pg_get_functiondef(
    'public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)'::regprocedure
  )) > 0,
  'non-admin access fails with explicit authorization error'
);

SELECT ok(
  position('greatest(1, least(coalesce(p_limit, 50), 100))' IN lower(pg_get_functiondef(
    'public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)'::regprocedure
  ))) > 0,
  'page size is clamped to 1..100'
);

SELECT ok(
  position('p_before_created_at' IN pg_get_functiondef(
    'public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)'::regprocedure
  )) > 0
  AND position('p_before_id' IN pg_get_functiondef(
    'public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)'::regprocedure
  )) > 0,
  'keyset cursor uses timestamp and UUID together'
);

SELECT ok(
  position('before_data' IN lower(pg_get_function_result(
    'public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)'::regprocedure
  ))) = 0
  AND position('after_data' IN lower(pg_get_function_result(
    'public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)'::regprocedure
  ))) = 0,
  'RPC does not expose raw before/after JSON'
);

SELECT ok(
  NOT has_table_privilege('authenticated','public.srk_admin_audit_events','SELECT'),
  'authenticated users still cannot directly SELECT financial audit table'
);

SELECT ok(
  has_function_privilege('authenticated','public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_list_financial_audit_events(integer,timestamp with time zone,uuid,text,uuid,uuid,text)','EXECUTE'),
  'only authenticated role can invoke RPC; Main Admin gate remains inside function'
);

SELECT * FROM finish();
ROLLBACK;
