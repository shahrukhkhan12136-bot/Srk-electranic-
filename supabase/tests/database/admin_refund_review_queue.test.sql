BEGIN;
SELECT plan(8);
SELECT has_function('public','srk_admin_list_booking_refund_requests','Admin refund queue RPC exists');
SELECT has_function('public','srk_admin_decide_booking_refund_request','Admin refund decision RPC exists');
SELECT ok(
 position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_list_booking_refund_requests()'::regprocedure))>0,
 'Admin queue verifies Admin role'
);
SELECT ok(
 position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_decide_booking_refund_request(uuid,text,text)'::regprocedure))>0,
 'Admin decision verifies Admin role'
);
SELECT ok(
 position('FOR UPDATE' in upper(pg_get_functiondef('public.srk_admin_decide_booking_refund_request(uuid,text,text)'::regprocedure)))>0,
 'Admin decision locks request row'
);
SELECT ok(
 position('INVALID_REFUND_STATUS_TRANSITION' in pg_get_functiondef('public.srk_admin_decide_booking_refund_request(uuid,text,text)'::regprocedure))>0,
 'Only allowed review state transitions accepted'
);
SELECT ok(
 NOT has_function_privilege('anon','public.srk_admin_list_booking_refund_requests()','EXECUTE')
 AND has_function_privilege('authenticated','public.srk_admin_list_booking_refund_requests()','EXECUTE'),
 'Admin queue RPC not exposed to anonymous role'
);
SELECT ok(
 NOT has_function_privilege('anon','public.srk_admin_decide_booking_refund_request(uuid,text,text)','EXECUTE')
 AND has_function_privilege('authenticated','public.srk_admin_decide_booking_refund_request(uuid,text,text)','EXECUTE'),
 'Admin decision RPC not exposed to anonymous role'
);
SELECT * FROM finish();
ROLLBACK;
