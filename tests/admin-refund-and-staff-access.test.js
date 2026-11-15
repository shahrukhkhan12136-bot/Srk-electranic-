const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const staffMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261114390000_admin_staff_rbac_foundation.sql'), 'utf8');
const staffFunction = fs.readFileSync(path.join(root, 'supabase/functions/admin-staff-management/index.ts'), 'utf8');
const workMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261114240000_server_authoritative_customer_approved_work_timer.sql'), 'utf8');

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


test('new-category booking status and category changes require protected server workflow', () => {
  assert.match(admin, /if\(booking\.selected_category&&\(status!==booking\.status\|\|quoted!==currentQuoted\)\)/);
  assert.match(workMigration, /CREATE OR REPLACE FUNCTION public\.srk_guard_new_category_booking_status_transition\(\)/);
  assert.match(workMigration, /work_transition_authorizations a[\s\S]*?a\.target_status=NEW\.status/);
  assert.match(workMigration, /NEW_CATEGORY_STATUS_REQUIRES_PROTECTED_WORKFLOW/);
  assert.match(workMigration, /BOOKING_CATEGORY_IS_IMMUTABLE/);
});
