const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('Admin accounting reconciliation never treats Route ledger status as bank settlement proof', () => {
  const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
  const retiredRouteMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115170000_admin_route_transfer_accounting_reconciliation.sql'), 'utf8');
  const latestAccountingMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261117010000_reconcile_booking_commission_and_manual_payment_method.sql'), 'utf8');

  assert.match(retiredRouteMigration, /'route_provider_settlement_verified',false/);
  assert.match(retiredRouteMigration, /'route_ledger_retired_no_route_transfers'/);
  assert.match(retiredRouteMigration, /'route_transfers','\[\]'::jsonb/);
  assert.doesNotMatch(latestAccountingMigration, /'route_provider_settlement_verified'/);
  assert.match(admin, /route_settlement_evidence_status\|\|'not_independently_verified'/);
  assert.match(admin, /Razorpay Route Transfers — स्वतंत्र पुष्टि बाकी/);
  assert.match(admin, /Route ledger की processed\/settled स्थिति बैंक में रकम पहुँचने का प्रमाण नहीं है/);
  assert.match(admin, /route_provider_settlement_verified===true/);
  assert.match(admin, /route_settlement_evidence_status/);
  assert.match(admin, /x\.transfer_status/);
  assert.match(admin, /x\.settlement_status/);
});
