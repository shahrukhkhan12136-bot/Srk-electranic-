begin;
select plan(5);
select ok(
 position('auth.uid()' in pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests()'::regprocedure)) > 0,
 'refund request history requires authentication'
);
select ok(
 position('r.customer_user_id = auth.uid()' in pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests()'::regprocedure)) > 0,
 'refund request history is scoped to the authenticated customer'
);
select ok(
 position('admin_note' in lower(pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests()'::regprocedure))) = 0,
 'refund request history does not expose internal admin notes'
);
select ok(
 position('decided_by' in lower(pg_get_functiondef('public.srk_customer_list_my_booking_refund_requests()'::regprocedure))) = 0,
 'refund request history does not expose staff identity'
);
select ok(
 not has_function_privilege('anon', 'public.srk_customer_list_my_booking_refund_requests()', 'EXECUTE')
 and has_function_privilege('authenticated', 'public.srk_customer_list_my_booking_refund_requests()', 'EXECUTE'),
 'refund request history RPC is authenticated-only'
);
select * from finish();
rollback;
