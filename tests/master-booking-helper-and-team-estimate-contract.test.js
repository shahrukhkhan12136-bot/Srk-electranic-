const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const api = fs.readFileSync(path.join(root, 'create-booking.js'), 'utf8');
const catalogue = fs.readFileSync(path.join(root, 'supabase/migrations/20261121150000_master_service_rate_catalogue.sql'), 'utf8');
const timer = fs.readFileSync(path.join(root, 'supabase/migrations/20261121170000_shared_technician_workday_timer.sql'), 'utf8');
const guard = fs.readFileSync(path.join(root, 'supabase/migrations/20261121160000_master_booking_dispatch_assignment_status.sql'), 'utf8');

test('customer can choose optional helper explicitly; client cannot supply helper prices', () => {
  assert.match(api, /body\.srk_helper_included === true/);
  assert.match(api, /typeof body\.srk_helper_included !== "boolean"/);
  assert.match(api, /masterHelperIncluded && helperHourly <= 0/);
  assert.match(api, /srk_helper_included_snapshot: masterRate\.billing_model === "hourly" \? masterHelperIncluded : false/);
});

test('hourly estimate scales by requested Technician count and only adds helper when selected', () => {
  assert.match(api, /technicianHourly \+ \(masterHelperIncluded \? helperHourly : 0\)/);
  assert.match(api, /selectedHourly \* masterRequiredTechnicians \* masterDurationMinutes/);
  assert.match(api, /team_8h_paise/);
  assert.match(api, /required_technician_count: masterRequiredTechnicians/);
});

test('helper selection is immutable in booking snapshot and disallowed for fixed-price services', () => {
  assert.match(catalogue, /srk_helper_included_snapshot boolean NOT NULL DEFAULT false/);
  assert.match(catalogue, /srk_helper_included_snapshot=false AND srk_fixed_labour_paise_snapshot IS NULL/);
  assert.match(api, /if \(masterHelperIncluded \|\| masterDurationMinutes !== null/);
  assert.match(guard, /NEW\.srk_helper_included_snapshot IS DISTINCT FROM OLD\.srk_helper_included_snapshot/);
});

test('daily workday ledger separately records Technician and optional helper normal/overtime pay', () => {
  for (const field of [
    'helper_hourly_paise_snapshot','helper_included_snapshot',
    'technician_normal_amount_paise','technician_overtime_amount_paise',
    'helper_normal_amount_paise','helper_overtime_amount_paise',
    'technician_total_paise','helper_total_paise'
  ]) assert.ok(timer.includes(field), 'missing helper/team ledger field: ' + field);
  assert.match(timer, /v_helper_overtime_amount:=CASE WHEN v_w\.helper_included_snapshot/);
  assert.match(timer, /v_total:=v_tech_total\+v_helper_total/);
});
