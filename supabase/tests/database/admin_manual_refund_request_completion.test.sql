begin;
select plan(9);
select has_function('public','srk_admin_record_manual_refund',array['uuid','text','text'],'manual refund RPC exists');
select ok(position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure))>0,
  'manual refund remains Main Admin only');
select ok(position('from public.srk_booking_refund_requests' in lower(pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure)))>0
  and position('for update' in lower(pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure)))>0,
  'manual refund locks the related customer request before processing');
select ok(position('v_request.status is distinct from ''approved''' in pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure))>0,
  'manual customer refund requires prior Main Admin approval');
select ok(position('update public.srk_booking_refund_requests' in lower(pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure)))>0
  and position('status=''processed''' in replace(lower(pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure)),' ','') )>0,
  'successful manual refund marks the approved customer request processed');
select ok(position('MANUAL_PAYMENT_AUDIT_RECORD_NOT_FOUND' in pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure))>0
  and position('RECORDED_PAYMENT_AMOUNT_DOES_NOT_MATCH_BOOKING_AMOUNT' in pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure))>0,
  'manual refund requires an existing matching manual payment audit record');
select ok(position('RAZORPAY_REFUNDS_MUST_USE_RAZORPAY_RECONCILIATION' in pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure))>0,
  'manual refund RPC cannot process Razorpay bookings');
select ok(position('like ''%online%''' in lower(pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure)))>0
  and position('like ''%razorpay%''' in lower(pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure)))>0,
  'manual refund RPC rejects online payment methods even when provider IDs are missing');
select ok(has_function_privilege('authenticated','public.srk_admin_record_manual_refund(uuid,text,text)','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_record_manual_refund(uuid,text,text)','EXECUTE'),
  'manual refund RPC is authenticated-only with Main Admin checked inside');
select * from finish();
rollback;
