const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('Admin accounting reconciliation reports Route as retired and keeps Manual Payout as the only payout path', () => {
  const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
  const retirement = fs.readFileSync(path.join(root, 'supabase/migrations/20261115092149_retire_unused_razorpay_route_transfer_ledger.sql'), 'utf8');
  const bridge = fs.readFileSync(path.join(root, 'supabase/migrations/20261117010000_reconcile_booking_commission_and_manual_payment_method.sql'), 'utf8');

  assert.match(retirement, /drop table public\\.srk_route_transfers/i);
  assert.doesNotMatch(bridge, /public\\.srk_route_transfers/);
  assert.match(bridge, /'route_provider_settlement_verified', false/);
  assert.match(bridge, /'route_settlement_evidence_status', 'route_ledger_retired_no_route_transfers'/);
  assert.match(admin, /Razorpay Route Transfers — Retired/);
  assert.match(admin, /Electrician को भुगतान केवल Admin के Manual Payout workflow से दर्ज होगा/);
  assert.match(admin, /route_settlement_evidence_status/);
  assert.match(admin, /Route ledger retired है/);
});
