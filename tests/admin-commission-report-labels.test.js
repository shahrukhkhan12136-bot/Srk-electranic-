const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const accounting = fs.readFileSync(path.join(root, 'supabase/migrations/20261115150000_admin_readonly_booking_accounting_reconciliation.sql'), 'utf8');
const commission = fs.readFileSync(path.join(root, 'supabase/migrations/20261109003000_secure_commission_reporting.sql'), 'utf8');

test('aggregate commission report labels calculated commission separately from cash received', () => {
  assert.match(admin, /गणना किया गया कंपनी कमीशन \(प्राप्त नकद नहीं\)/);
  assert.match(admin, /गणना किया गया कमीशन \(बैंक भुगतान नहीं\)/);
  const reportStart = admin.indexOf('<h2>कमीशन रिपोर्ट</h2>');
  const reportEnd = admin.indexOf('</div></div></section>', reportStart);
  assert.notEqual(reportStart, -1, 'aggregate commission report section must exist');
  assert.notEqual(reportEnd, -1, 'aggregate commission report section must be bounded');
  assert.doesNotMatch(admin.slice(reportStart, reportEnd), /\broute\b|route_platform_commission/i);
});

test('per-booking accounting report uses the current read-only ledger contract without retired Route fields', () => {
  assert.match(admin, /srk_admin_get_booking_accounting_reconciliation/);
  assert.match(accounting, /customer_collection_paise/);
  assert.match(accounting, /cancellation_fee_ledger_entries/);
  assert.match(accounting, /is_reconciled/);
  assert.doesNotMatch(accounting, /srk_route_transfers|route_platform_commission|transfer_status|settlement_status/);
});

test('aggregate commission report is scoped to Main Admin and only completed paid bookings', () => {
  assert.match(commission, /auth\.uid\(\) is null or not public\.is_srk_admin\(\)/);
  assert.match(commission, /status = 'completed' and payment_status = 'paid'/);
});
