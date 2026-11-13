BEGIN;
SELECT plan(8);
SELECT ok(to_regprocedure('public.srk_customer_list_my_booking_refund_requests(integer,integer)') IS NOT NULL,
 'paginated refund history overload exists');
SELECT ok(position('auth.uid()' in pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests(integer,integer)'::regprocedure))>0,
 'refund history requires authenticated identity');
SELECT ok(position('r.customer_user_id=v_uid' in pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests(integer,integer)'::regprocedure))>0,
 'refund history is scoped to the signed-in customer');
SELECT ok(position('order by r.created_at desc,r.id desc' in lower(pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests(integer,integer)'::regprocedure)))>0,
 'refund history ordering is deterministic');
SELECT ok(position('limit v_limit offset v_offset' in lower(pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests(integer,integer)'::regprocedure)))>0,
 'refund history supports bounded pagination');
SELECT ok(position('least(greatest(coalesce(p_limit,25),1),50)' in lower(pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests(integer,integer)'::regprocedure)))>0,
 'page size is clamped to 1 through 50');
SELECT ok(position('v_offset > 10000' in pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests(integer,integer)'::regprocedure))>0,
 'excessive offsets are rejected');
SELECT ok(has_function_privilege('authenticated','public.srk_customer_list_my_booking_refund_requests(integer,integer)','EXECUTE')
 and not has_function_privilege('anon','public.srk_customer_list_my_booking_refund_requests(integer,integer)','EXECUTE'),
 'paginated refund history is authenticated-only');
SELECT * FROM finish();
ROLLBACK;
