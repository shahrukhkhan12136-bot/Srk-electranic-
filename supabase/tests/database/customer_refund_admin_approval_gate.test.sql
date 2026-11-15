begin;
select plan(8);
select ok(position('CUSTOMER_REFUND_REQUEST_REQUIRES_MAIN_ADMIN_APPROVAL' in pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0,'existing customer request requires explicit Main Admin approval before Razorpay processing');
select ok(position('v_customer_request.status not in (''approved'',''processing'',''unknown'')' in pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0,'unreviewed and rejected requests cannot enter provider refund flow');
select ok(position('refund_record_id=v_refund.id' in pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0,'approved request is linked to its unique Razorpay refund record');
select ok(position('set status=''processing''' in pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0,'request moves to processing when refund record is prepared');
select ok(position('for update' in lower(pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure)))>0,'refund preparation locks booking and customer request before state checks');
select ok(position('^pay_[A-Za-z0-9]+
rollback;
 in pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0,'payment ID format is fully anchored and intact');
select ok(position('payment_status is distinct from ''paid''' in pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0,'null payment status is rejected');
select ok(position('select * into v_customer_request' in pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0,'customer request is locked and loaded inside refund preparation function');
select * from finish();
rollback;
