const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const accounting = fs.readFileSync(path.join(root, 'supabase/migrations/20261115130000_admin_readonly_booking_accounting_reconciliation.sql'), 'utf8');
const commission = fs.readFileSync(path.join(root, 'supabase/migrations/20261109003000_secure_commission_reporting.sql'), 'utf8');

test('aggregate commission report labels calculated commission separately from cash received', () => {
  assert.match(admin, /गणना किया गया कंपनी कमीशन \(प्राप्त नकद नहीं\)/);
  assert.match(admin, /गणना किया गया कमीशन \(Route Settlement नहीं\)/);
  assert.doesNotMatch(admin, /<small>वास्तव में प्राप्त भुगतान<\/small>/);
});

test('per-booking report keeps Route processing and settlement as distinct states', () => {
  assert.match(admin, /Transfer '\+esc\(t\.transfer_status\)\+' · Settlement '\+esc\(t\.settlement_status\)/);
  assert.match(accounting, /route_platform_commission_processed_paise/);
  assert.match(accounting, /route_platform_commission_settled_paise/);
  assert.match(accounting, /COMMISSION_TRANSFER_NOT_PROCESSED/);
  assert.match(accounting, /COMMISSION_TRANSFER_NOT_SETTLED/);
});

test('aggregate commission report is scoped to Main Admin and only completed paid bookings', () => {
  assert.match(commission, /auth\.uid\(\) is null or not public\.is_srk_admin\(\)/);
  assert.match(commission, /status = 'completed' and payment_status = 'paid'/);
});
