'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const customer = fs.readFileSync('apps/customer_app/lib/main.dart', 'utf8');
const migration = fs.readFileSync('supabase/migrations/20261125094654_expose_customer_booking_online_only_payment_cycle.sql', 'utf8');

test('Customer payment screen hides Cash and explains Online-only booking cycles', () => {
  assert.match(customer, /srk_customer_get_booking_payment_cycle/);
  assert.match(customer, /if \(!onlineOnly\)/);
  assert.match(customer, /केवल Online भुगतान होगा/);
  assert.match(customer, /cycle_unverified/);
});

test('Customer cycle RPC only exposes the signed-in customer own completed booking', () => {
  assert.match(migration, /auth\.uid\(\) is null/);
  assert.match(migration, /customer_user_id=auth\.uid\(\) and b\.status='completed'/);
  assert.match(migration, /srk_technician_booking_sequence/);
  assert.match(migration, /srk_helper_booking_sequence/);
  assert.match(migration, /mod\(s\.sequence_number,3\)=0/);
  assert.match(migration, /revoke all .* from public,anon/);
  assert.match(migration, /grant execute .* to authenticated/);
});
