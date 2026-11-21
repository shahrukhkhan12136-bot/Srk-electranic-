BEGIN;
SELECT plan(13);

SELECT has_table('public','srk_booking_final_bills',
  'one immutable consolidated final bill is stored per booking');
SELECT has_table('public','srk_booking_material_requests',
  'technician material estimate waits for customer decision');
SELECT has_table('public','srk_booking_material_request_items',
  'material estimates preserve itemized quantity and price snapshots');
SELECT has_table('public','srk_booking_material_decision_events',
  'customer material decisions are recorded as append-only events');

SELECT has_column('public','service_bookings','srk_commission_rate_snapshot',
  'commission percentage is snapshotted on booking creation');
SELECT has_column('public','srk_booking_final_bills','labour_ledger_rows',
  'final bill records the number of consolidated daily ledger rows');
SELECT has_column('public','srk_booking_final_bills','technician_total_payable_paise',
  'final bill separates company commission from Technician payable');

SELECT has_function('public','srk_technician_submit_booking_materials',ARRAY['uuid','jsonb']::text[]);
SELECT has_function('public','srk_customer_decide_booking_materials',ARRAY['uuid','text','text']::text[]);
SELECT has_function('public','srk_service_role_build_master_final_bill',ARRAY['uuid']::text[]);

SELECT has_trigger('public','srk_booking_material_request_items','srk_master_material_items_immutable');
SELECT has_trigger('public','srk_booking_material_decision_events','srk_master_material_decisions_append_only');
SELECT has_trigger('public','srk_booking_final_bills','srk_master_final_bill_immutable');

SELECT * FROM finish();
ROLLBACK;
