const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261121160000_master_booking_dispatch_assignment_status.sql'), 'utf8');

test('Master dispatch completion promotes the existing booking only when required Technician count is met', () => {
  assert.match(migration, /srk_promote_fully_assigned_master_booking/);
  assert.match(migration, /NEW\.assigned_technician_count < NEW\.required_technician_count/);
  assert.match(migration, /SET status='assigned'/);
  assert.match(migration, /AFTER UPDATE OF status ON public\.srk_technician_dispatch_requests/);
});

test('Master booking status guard protects canonical service and rate snapshots', () => {
  assert.match(migration, /srk_guard_master_booking_status_transition/);
  for (const field of [
    'srk_service_category_code','srk_service_skill_code','srk_service_code',
    'srk_rate_level_code','srk_rate_version_snapshot','srk_billing_model_snapshot',
    'srk_technician_hourly_paise_snapshot','srk_helper_hourly_paise_snapshot',
    'srk_fixed_labour_paise_snapshot','srk_estimated_labour_paise',
    'srk_duration_minutes','srk_service_quantity'
  ]) assert.match(migration, new RegExp(field));
  assert.match(migration, /MASTER_BOOKING_SERVICE_AND_RATE_SNAPSHOTS_ARE_IMMUTABLE/);
});

test('legacy assignment check accepts canonical Master booking without requiring an electrician profile', () => {
  assert.match(migration, /OR srk_service_category_code IS NOT NULL/);
  assert.match(migration, /service_bookings_assignment_status_requires_electrician/);
});
