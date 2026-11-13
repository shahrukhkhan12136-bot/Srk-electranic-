BEGIN;
SELECT plan(12);

SELECT has_table('public','srk_razorpay_refunds','Razorpay refund records table exists');
SELECT has_table('public','srk_manual_refund_entries','manual refund audit table exists');
SELECT has_table('public','srk_booking_refund_requests','customer refund request table exists');

SELECT ok(
  position('v_booking.status <> ''completed''' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure)) > 0,
  'customer refund request requires completed booking'
);
SELECT ok(
  position('v_booking.completion_approval_status <> ''approved''' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure)) > 0,
  'customer refund request requires customer-approved completion'
);
SELECT ok(
  position('srk_booking_labour_bills' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure)) > 0,
  'refund amount is derived from immutable labour bill'
);
SELECT ok(
  position('labour_amount_paise' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure)) > 0,
  'refund amount reconciles integer paise'
);
SELECT ok(
  position('srk_manual_payment_entries' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure)) > 0,
  'manual payment evidence is reconciled'
);
SELECT ok(
  position('status <> ''rejected''' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure)) > 0,
  'only rejected request can be reopened by customer'
);
SELECT ok(
  position('customer_user_id=v_uid' in pg_get_functiondef('public.srk_customer_create_booking_refund_request(uuid,text)'::regprocedure)) > 0,
  'booking ownership is enforced'
);
SELECT ok(
  NOT has_function_privilege('anon','public.srk_customer_create_booking_refund_request(uuid,text)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_customer_create_booking_refund_request(uuid,text)','EXECUTE'),
  'customer refund RPC is authenticated-only'
);
SELECT ok(
  NOT has_table_privilege('authenticated','public.srk_booking_refund_requests','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_razorpay_refunds','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_manual_refund_entries','SELECT'),
  'refund tables are not directly readable by authenticated clients'
);

SELECT * FROM finish();
ROLLBACK;
