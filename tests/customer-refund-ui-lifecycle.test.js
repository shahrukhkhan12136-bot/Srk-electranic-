const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115100000_customer_refund_request_contract.sql'), 'utf8');

test('categorized customer refund UI is available only after completed work', () => {
  assert.match(booking, /const refundLifecycleEligible=row\.selected_category==null\|\|row\.status==='completed';/);
  assert.match(booking, /const canRequestRefund=refundLifecycleEligible\s+&& String\(row\.payment_status\|\|' '\)\.toLowerCase\(\)==='paid'/);
});

test('server independently enforces completed categorized booking and verified paid amount', () => {
  assert.match(migration, /if v_booking\.selected_category is not null then\s+if v_booking\.status is distinct from 'completed' then\s+raise exception 'BOOKING_NOT_COMPLETED'/);
  assert.match(migration, /v_booking\.payment_status is distinct from 'paid'/);
  assert.match(migration, /v_booking\.payment_verified_at is null/);
});
