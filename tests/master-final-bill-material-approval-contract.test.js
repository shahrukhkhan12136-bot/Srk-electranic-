const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const migration = fs.readFileSync(
  path.resolve(__dirname, '../supabase/migrations/20261121180000_master_final_bill_and_customer_material_approval.sql'),
  'utf8'
);

test('Master final bill consolidates every immutable Technician daily labour ledger row', () => {
  assert.match(migration, /FROM public\.srk_booking_technician_labour_ledger WHERE booking_id=p_booking_id/);
  assert.match(migration, /sum\(total_labour_paise\)/);
  assert.match(migration, /labour_ledger_rows integer NOT NULL CHECK\(labour_ledger_rows>0\)/);
  assert.match(migration, /ALL_TECHNICIAN_WORKDAYS_MUST_BE_STOPPED/);
  assert.match(migration, /CUSTOMER_CONFIRMED_MASTER_COMPLETION_REQUIRED/);
});

test('Technician material estimates are itemized and require customer approval or rejection', () => {
  assert.match(migration, /srk_technician_submit_booking_materials/);
  assert.match(migration, /srk_customer_decide_booking_materials/);
  assert.match(migration, /pending_customer/);
  assert.match(migration, /MATERIAL_DECISION_ALREADY_CLOSED/);
  assert.match(migration, /srk_booking_material_request_items/);
  assert.match(migration, /srk_booking_material_decision_events/);
  assert.match(migration, /CUSTOMER_MATERIAL_DECISION_PENDING/);
});

test('only approved materials enter the final bill; rejected or absent materials remain zero', () => {
  assert.match(migration, /IF v_has_req AND v_req\.status='approved' THEN v_materials:=v_req\.materials_total_paise/);
  assert.match(migration, /CASE WHEN NOT v_has_req THEN 'not_requested' ELSE v_req\.status END/);
  assert.match(migration, /technician_material_reimbursement_paise=materials_amount_paise/);
});

test('commission is snapshotted and applied only to labour, never materials', () => {
  assert.match(migration, /srk_commission_rate_snapshot/);
  assert.match(migration, /company_commission_paise=round\(labour_amount_paise\*commission_rate_snapshot\/100\)::bigint/);
  assert.match(migration, /technician_labour_payable_paise=labour_amount_paise-company_commission_paise/);
  assert.match(migration, /technician_total_payable_paise=technician_labour_payable_paise\+technician_material_reimbursement_paise/);
});

test('financial snapshots are protected, client table access is revoked, and final bill builder is service-role-only', () => {
  assert.match(migration, /MASTER_FINANCIAL_HISTORY_IS_IMMUTABLE/);
  assert.match(migration, /REVOKE ALL ON public\.srk_booking_material_requests[\s\S]*FROM PUBLIC,anon,authenticated/);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.srk_service_role_build_master_final_bill\(uuid\) FROM PUBLIC,anon,authenticated/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_service_role_build_master_final_bill\(uuid\) TO service_role/);
});

test('final bill creation is idempotent and refuses inconsistent replay', () => {
  assert.match(migration, /ON CONFLICT\(booking_id\) DO NOTHING/);
  assert.match(migration, /FINAL_BILL_REPLAY_MISMATCH/);
});
