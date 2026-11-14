begin;
select plan(11);
select ok(position('auth.uid()' in pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
 'payment history requires authenticated identity');
select ok(position('b.customer_user_id=v_uid' in pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
 'original payment rows are owner-scoped');
select ok(position('b.payment_status in (''paid'',''refunded'')' in pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
 'only verified paid or refunded booking payments are listed');
select ok(position('b.payment_verified_at is not null' in pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
 'payment event requires verification timestamp');
select ok(position('srk_booking_refund_requests' in pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
 'customer refund request history is included');
select ok(position('srk_razorpay_refunds' in pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
 'online refund events are included');
select ok(position('srk_manual_refund_entries' in pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
 'manual refund events are included');
select ok(position('limit v_limit offset v_offset' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure)))>0,
 'history is paginated with bounded limit and offset');
select ok(position('admin_note' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure)))=0
 and position('payload' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure)))=0,
 'history does not expose admin notes or raw provider payloads');
select ok(has_function_privilege('authenticated','public.srk_customer_get_payment_history(integer,integer)','EXECUTE')
 and not has_function_privilege('anon','public.srk_customer_get_payment_history(integer,integer)','EXECUTE'),
 'payment history RPC is authenticated-only');
select * from finish();
rollback;
select ok(coalesce((select proconfig @> ARRAY['search_path=""'] from pg_proc where oid='public.srk_customer_get_payment_history(integer,integer)'::regprocedure),false),
 'security definer RPC uses an empty search_path');
