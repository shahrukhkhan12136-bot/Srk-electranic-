begin;
select plan(16);
select has_function('public','srk_customer_create_booking_refund_request',array['uuid','text'],'customer refund request RPC exists');
select has_function('public','srk_customer_list_booking_refund_requests',array[]::text[],'customer refund history RPC exists');
select ok(position('auth.uid()' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure))>0,'refund submission requires authenticated identity');
select ok(position('customer_user_id=v_uid' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure))>0,'refund submission is scoped to the booking owner');
select ok(position('for update' in lower(pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure)))>0,'booking row is locked to serialize duplicate refund requests');
select ok(position('p_reason is null' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure))>0,'null refund reason is explicitly rejected');
select ok(position('payment_verified_at is null' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure))>0,'refund request requires verified payment');
select ok(position('IMMUTABLE_LABOUR_BILL_REQUIRED' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure))>0,'categorized booking requires immutable final labour bill');
select ok(position('srk_booking_cancellation_fee_items' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure))>0,'categorized booking reconciles settled cancellation fee ledger');
select ok(position('PAID_AMOUNT_DOES_NOT_MATCH_IMMUTABLE_LABOUR_AND_FEE_LEDGER' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure))>0,'captured amount must exactly match labour and settled fees');
select ok(position('srk_razorpay_refunds' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure))>0
 and position('srk_manual_refund_entries' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure))>0,'existing online or manual refund blocks a new request');
select ok(position('v_request.status<>''rejected''' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure))>0,'only rejected requests may be resubmitted');
select ok(position('r.customer_user_id=v_uid' in pg_get_functiondef('public.srk_customer_list_booking_refund_requests()'::regprocedure))>0,'refund history is scoped to the authenticated customer');
select ok(position('admin_note' in lower(pg_get_functiondef('public.srk_customer_list_booking_refund_requests()'::regprocedure)))=0,'customer refund history never exposes private Admin notes');
select ok(has_function_privilege('authenticated','public.srk_customer_create_booking_refund_request(uuid,text)','EXECUTE')
 and not has_function_privilege('anon','public.srk_customer_create_booking_refund_request(uuid,text)','EXECUTE')
 and has_function_privilege('authenticated','public.srk_customer_list_booking_refund_requests()','EXECUTE')
 and not has_function_privilege('anon','public.srk_customer_list_booking_refund_requests()','EXECUTE'),'both customer refund RPCs are authenticated-only');
select ok(coalesce((select proconfig @> ARRAY['search_path=""'] from pg_proc where oid='public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure),false)
 and coalesce((select proconfig @> ARRAY['search_path=""'] from pg_proc where oid='public.srk_customer_list_booking_refund_requests()'::regprocedure),false),'both security definer RPCs use an empty search_path');
select * from finish();
rollback;
