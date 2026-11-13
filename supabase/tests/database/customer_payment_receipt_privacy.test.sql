begin;
select plan(10);

select ok(
 position('auth.uid()' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)) > 0,
 'receipt requires authenticated identity'
);
select ok(
 position('customer_user_id = v_uid' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)) > 0,
 'receipt is scoped to the booking owner'
);
select ok(
 position('payment_status' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)) > 0
 and position('payment_verified_at' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)) > 0,
 'receipt is limited to verified paid bookings'
);
select ok(
 position('coalesce(v_booking.amount_paid,0) <= 0' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)) > 0,
 'receipt requires a positive paid amount'
);
select ok(
 position('labour_amount' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)) > 0
 and position('materials_amount' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)) = 0
 and position('breakdown_available' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)) = 0,
 'receipt may expose verified labour only and never includes material fields'
);
select ok(
 position('phone' in lower(pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))) = 0,
 'receipt does not expose customer or electrician phone'
);
select ok(
 position('razorpay_payment_id' in lower(pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))) = 0
 and position('refund_id' in lower(pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))) = 0,
 'receipt does not expose provider identifiers'
);
select ok(
 position('admin_note' in lower(pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))) = 0
 and position('recorded_by' in lower(pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))) = 0,
 'receipt does not expose internal notes or staff identifiers'
);
select ok(
 not has_function_privilege('anon','public.srk_customer_get_payment_receipt(uuid)','EXECUTE')
 and has_function_privilege('authenticated','public.srk_customer_get_payment_receipt(uuid)','EXECUTE'),
 'receipt RPC is authenticated-only'
);
select ok(
 position('payment_receipt' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)) > 0,
 'document is explicitly typed as a payment receipt, not a tax invoice'
);

select * from finish();
rollback;
