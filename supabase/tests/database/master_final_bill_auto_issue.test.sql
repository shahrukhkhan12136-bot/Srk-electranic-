BEGIN;
SELECT plan(4);
SELECT has_trigger('public','service_bookings','srk_master_final_bill_after_customer_completion');
SELECT has_trigger('public','srk_booking_material_requests','srk_master_final_bill_after_material_decision');
SELECT has_trigger('public','srk_booking_technician_labour_ledger','srk_master_final_bill_after_labour_ledger');
SELECT ok(
 position('pg_trigger_depth()=0' in pg_get_functiondef('public.srk_service_role_build_master_final_bill(uuid)'::regprocedure))>0,
 'bill builder is callable by service role directly or internally from a protected trigger'
);
SELECT * FROM finish();
ROLLBACK;
