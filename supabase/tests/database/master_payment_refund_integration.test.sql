BEGIN;
SELECT plan(12);
SELECT has_table('public','srk_master_booking_payments','Master collection has its own immutable final-bill-linked payment record');
SELECT has_table('public','srk_master_technician_payables','each Technician receives a separate payable record');
SELECT has_table('public','srk_master_payment_events','Master payment and refund actions are auditable events');
SELECT has_function('public','srk_service_role_record_master_online_payment',ARRAY['uuid','text','text','bigint']::text[]);
SELECT has_function('public','srk_admin_record_master_manual_payment',ARRAY['uuid','text','text','text']::text[]);
SELECT has_trigger('public','srk_master_payment_events','srk_master_payment_events_append_only');
SELECT has_trigger('public','service_bookings','srk_master_refund_payable_state_sync');
SELECT has_trigger('public','srk_razorpay_refunds','srk_master_refund_failure_release');
SELECT ok(
 position('srk_booking_final_bills' in pg_get_functiondef('public.srk_service_role_record_master_online_payment(uuid,text,text,bigint)'::regprocedure))>0
 AND position('srk_booking_technician_labour_ledger' in pg_get_functiondef('public.srk_service_role_record_master_online_payment(uuid,text,text,bigint)'::regprocedure))>0,
 'online payment RPC checks final bill and allocates Technician labour'
);
SELECT ok(
 position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_record_master_manual_payment(uuid,text,text,text)'::regprocedure))>0,
 'manual payment recording is Admin-only'
);
SELECT ok(
 position('PAID_AMOUNT_DOES_NOT_MATCH_MASTER_FINAL_BILL' in pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0,
 'Master refund preparation reconciles to final bill, not quotation'
);
SELECT ok(
 position('srk_master_technician_payables' in pg_get_functiondef('public.srk_master_refund_payable_state_sync()'::regprocedure))>0,
 'processed refund marks unpaid Technician payable rows refunded'
);
SELECT * FROM finish();
ROLLBACK;
