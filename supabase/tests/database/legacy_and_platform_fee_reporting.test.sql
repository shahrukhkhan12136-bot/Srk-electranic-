BEGIN;
SELECT plan(8);

SELECT has_function('public','srk_get_my_earnings',ARRAY[]::text[],
  'electrician earnings RPC exists after reporting contract update');

SELECT ok(pg_get_function_result('public.srk_get_my_earnings()'::regprocedure)
  ILIKE '%platform_fee_amount%' AND
  pg_get_function_result('public.srk_get_my_earnings()'::regprocedure)
  ILIKE '%legacy_commission_amount%',
  'electrician earnings RPC exposes distinct Platform Fee and legacy commission columns');

SELECT ok(pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)
  ILIKE '%CASE WHEN b.selected_category IS NOT NULL%' AND
  pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)
  ILIKE '%ELSE coalesce(b.commission_amount,0)%',
  'electrician earnings classify new and legacy bookings separately');

SELECT ok(has_function_privilege('authenticated','public.srk_get_my_earnings()','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_get_my_earnings()','EXECUTE'),
  'earnings RPC is executable only by authenticated users');

SELECT ok(pg_get_functiondef('public.srk_admin_commission_report()'::regprocedure)
  ILIKE '%total_legacy_commission%' AND
  pg_get_functiondef('public.srk_admin_commission_report()'::regprocedure)
  ILIKE '%total_platform_fee%',
  'Admin finance report returns both legacy commission and new Platform Fee totals');

SELECT ok(pg_get_functiondef('public.srk_admin_commission_report()'::regprocedure)
  ILIKE '%AS legacy_commission%' AND
  pg_get_functiondef('public.srk_admin_commission_report()'::regprocedure)
  ILIKE '%AS platform_fee%',
  'Admin partner rows expose distinct legacy commission and Platform Fee values');

SELECT ok(has_function_privilege('authenticated','public.srk_admin_commission_report()','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_commission_report()','EXECUTE'),
  'Admin report RPC remains unavailable to anonymous users');

SELECT ok(pg_get_functiondef('public.srk_admin_commission_report()'::regprocedure)
  ILIKE '%public.is_srk_admin()%',
  'Admin report continues to enforce Admin role inside the security-definer RPC');

SELECT * FROM finish();
ROLLBACK;
