const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const migrations = path.join(root, 'supabase/migrations');
const early = fs.readFileSync(path.join(migrations, '20261109002500_restore_service_bookings_amount_paid_before_financial_grants.sql'), 'utf8');
const grant = fs.readFileSync(path.join(migrations, '20261109003000_secure_commission_reporting.sql'), 'utf8');
const later = fs.readFileSync(path.join(migrations, '20261116200000_restore_service_bookings_amount_paid.sql'), 'utf8');
const baseline = fs.readFileSync(path.join(root, 'COMPLETE_DATABASE_SETUP.sql'), 'utf8');

test('amount_paid exists before the column-level financial UPDATE grant', () => {
  assert.ok('20261109002500' < '20261109003000', 'restoration migration sorts before the grant migration');
  assert.match(early, /ADD COLUMN IF NOT EXISTS amount_paid numeric\(12,2\)/i);
  assert.match(early, /service_bookings_amount_paid_nonnegative_check/);
  assert.match(grant, /grant update \(status, quoted_amount, amount_paid, payment_status\)/i);
  assert.doesNotMatch(baseline.slice(
    baseline.indexOf('create table if not exists public.service_bookings'),
    baseline.indexOf(');', baseline.indexOf('create table if not exists public.service_bookings'))
  ), /amount_paid/i, 'baseline omission remains explicitly covered');
});

test('later amount_paid restoration remains safe and idempotent', () => {
  assert.match(later, /ADD COLUMN IF NOT EXISTS amount_paid numeric\(12,2\)/i);
  assert.match(later, /IF NOT EXISTS \([\s\S]*service_bookings_amount_paid_nonnegative_check/);
});
