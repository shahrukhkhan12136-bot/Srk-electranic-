-- Admin refund queue v3 exposes provider state without enabling failed retries.
BEGIN;
SELECT plan(8);
SELECT has_function('public','srk_admin_list_booking_refund_requests_v3',
  ARRAY[]::text[],'Admin refund queue v3 exists');
SELECT ok(position('provider_refund_status' in pg_get_function_result(
  'public.srk_admin_list_booking_refund_requests_v3()'::regprocedure))>0,
  'queue returns provider intent status');
SELECT ok(position('provider_status' in pg_get_function_result(
  'public.srk_admin_list_booking_refund_requests_v3()'::regprocedure))>0,
  'queue returns provider status');
SELECT ok(position('provider_last_error' in pg_get_function_result(
  'public.srk_admin_list_booking_refund_requests_v3()'::regprocedure))>0,
  'queue returns provider error for Admin reconciliation');
SELECT ok(position('ri.id=r.refund_record_id AND ri.booking_id=r.booking_id' in
  pg_get_functiondef('public.srk_admin_list_booking_refund_requests_v3()'::regprocedure))>0,
  'provider intent is joined by both request linkage and booking ownership');
SELECT ok(position('auth.uid() IS NULL OR NOT public.is_srk_admin()' in
  pg_get_functiondef('public.srk_admin_list_booking_refund_requests_v3()'::regprocedure))>0,
  'queue remains Admin-gated');
SELECT ok(has_function_privilege('authenticated',
  'public.srk_admin_list_booking_refund_requests_v3()','EXECUTE'),
  'authenticated role can call the Admin-gated RPC');
SELECT ok(NOT has_function_privilege('anon',
  'public.srk_admin_list_booking_refund_requests_v3()','EXECUTE'),
  'anonymous role cannot call the Admin queue');
SELECT * FROM finish();
ROLLBACK;
