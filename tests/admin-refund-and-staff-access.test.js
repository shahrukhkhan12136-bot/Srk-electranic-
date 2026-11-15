const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const staffMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261114390000_admin_staff_rbac_foundation.sql'), 'utf8');
const staffFunction = fs.readFileSync(path.join(root, 'supabase/functions/admin-staff-management/index.ts'), 'utf8');
const workMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261114240000_server_authoritative_customer_approved_work_timer.sql'), 'utf8');
const legacyStatusMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115160000_legacy_booking_status_write_guard.sql'), 'utf8');
const manualRefundMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115130000_admin_manual_refund_request_completion.sql'), 'utf8');

test('Admin refund queue does not offer another launch action after a processed refund', () => {
  assert.match(admin, /state==='approved'\s*&&\s*r\.refund_record_status!=='processed'/);
  assert.match(admin, /Provider Refund: <b>/);
});

test('Support Staff portal is isolated from Main Admin modules', () => {
  assert.match(admin, /if\(staffOnly\)el\.classList\.toggle\('hidden',mode!=='staff'\);\s*else el\.classList\.toggle\('hidden',mode!=='main_admin'\);/);
  assert.match(admin, /srk_admin_staff_register_session/);
  assert.match(admin, /srk_has_admin_permission/);
});

test('Staff invitation is independently authorized as Main Admin and role is fixed to support', () => {
  assert.match(staffFunction, /rpc\("is_srk_admin"\)/);
  assert.match(staffFunction, /body\.action !== "invite_support_staff"/);
  assert.match(staffFunction, /role: "support"/);
  assert.match(staffFunction, /srk_admin_staff_register_invited_user/);
});

test('Staff data access is assignment-scoped and migration has no direct private phone projection', () => {
  assert.match(staffMigration, /assigned_staff_user_id=auth\.uid\(\)/);
  assert.doesNotMatch(staffMigration, /customer_phone|electrician_phone/);
  assert.match(staffMigration, /support\.customer\.read/);
  assert.match(staffMigration, /support\.electrician\.read/);
});


test('new-category booking status changes require protected server workflow', () => {
  assert.match(admin, /status!==booking\.status&&\!\( !booking\.selected_category&&booking\.status==='new'&&status==='confirmed'\)/);
  assert.match(workMigration, /CREATE OR REPLACE FUNCTION public\.srk_guard_new_category_booking_status_transition\(\)/);
  assert.match(workMigration, /work_transition_authorizations a[\s\S]*?a\.target_status=NEW\.status/);
  assert.match(workMigration, /NEW_CATEGORY_STATUS_REQUIRES_PROTECTED_WORKFLOW/);
  assert.match(workMigration, /BOOKING_CATEGORY_IS_IMMUTABLE/);
});


test('Admin cannot manually mark an unfinished booking completed through the generic Save path', () => {
  assert.match(admin, /if\(status==='completed'&&booking\.status!=='completed'\)[\s\S]*?सुरक्षित completion workflow से ही दर्ज होगी/);
  assert.doesNotMatch(admin, /\.update\(\{status,quoted_amount:quoted\}\)/);
  assert.match(admin, /sb\.rpc\('srk_admin_confirm_legacy_booking'/);
});


test('legacy booking status is no longer directly writable by authenticated clients', () => {
  assert.match(legacyStatusMigration, /revoke update on table public\.service_bookings from authenticated/i);
  assert.match(legacyStatusMigration, /grant update \(quoted_amount,amount_paid,payment_status\)/i);
  assert.match(legacyStatusMigration, /create or replace function public\.srk_admin_confirm_legacy_booking/i);
  assert.match(legacyStatusMigration, /v_booking\.selected_category is not null/i);
  assert.match(legacyStatusMigration, /v_booking\.status is distinct from 'new'/i);
  assert.match(legacyStatusMigration, /set status='confirmed'/i);
});

test('Admin generic Save keeps historical quote read-only and uses dedicated legacy confirmation RPC', () => {
  assert.doesNotMatch(admin, /srk_admin_update_legacy_booking_quote/);
  assert.doesNotMatch(admin, /id="amt-/);
  assert.match(admin, /ऐतिहासिक रिकॉर्ड केवल पढ़ने के लिए/);
  assert.doesNotMatch(admin, /\.update\(\{quoted_amount:quoted\}\)/);
  assert.match(admin, /sb\.rpc\('srk_admin_confirm_legacy_booking',\{p_booking_id:id\}\)/);
  assert.match(admin, /status!==booking\.status&&\!\( !booking\.selected_category&&booking\.status==='new'&&status==='confirmed'\)/);
  assert.doesNotMatch(admin, /\.update\(\{status:/);
});


test('new-category manual refunds reconcile against immutable labour bill and settled fee ledger', () => {
  assert.match(manualRefundMigration, /v_booking\.selected_category is not null/);
  assert.match(manualRefundMigration, /NEW_CATEGORY_REFUND_REQUIRES_COMPLETED_BOOKING/);
  assert.match(manualRefundMigration, /customer_user_id=v_booking\.customer_user_id/);
  assert.match(manualRefundMigration, /electrician_profile_id is distinct from v_booking\.assigned_electrician_id/);
  assert.match(manualRefundMigration, /CANCELLATION_FEE_ITEMS_NOT_FULLY_SETTLED/);
  assert.match(manualRefundMigration, /v_expected_paise:=v_labour_paise\+v_fee_paise/);
  assert.match(manualRefundMigration, /MANUAL_REFUND_AMOUNT_DOES_NOT_MATCH_IMMUTABLE_LABOUR_AND_FEE_LEDGER/);
});

const refundRecoveryMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115240000_harden_refund_recovery_full_amount.sql'), 'utf8');

test('Razorpay recovery finalizer rejects evidence unless refund equals full verified booking collection', () => {
  assert.match(refundRecoveryMigration, /select \* into v_booking from public\.service_bookings where id=v_audit\.booking_id for update/i);
  assert.match(refundRecoveryMigration, /v_audit\.amount_paise is distinct from round\(v_booking\.amount_paid\*100\)::bigint/);
  assert.match(refundRecoveryMigration, /RECOVERY_REFUND_AMOUNT_DOES_NOT_MATCH_FULL_BOOKING_COLLECTION/);
  assert.match(refundRecoveryMigration, /v_refund\.amount_paise is distinct from v_audit\.amount_paise/);
});
