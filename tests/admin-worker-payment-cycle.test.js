import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const admin = readFileSync(new URL('../admin.html', import.meta.url), 'utf8');
const migration = readFileSync(new URL('../supabase/migrations/20261125180000_admin_worker_payment_cycle_monitoring.sql', import.meta.url), 'utf8');

test('Admin payment-cycle panel uses the permission-checked read-only RPC', () => {
  assert.match(admin, /adminWorkerPaymentCycleCard/);
  assert.match(admin, /srk_admin_list_worker_payment_cycles/);
  assert.match(admin, /केवल Online/);
  assert.match(admin, /Cash \/ Online/);
  assert.match(admin, /recent_history/);
});

test('Admin cycle RPC is authenticated, permission-gated and read-only', () => {
  assert.match(migration, /security definer/i);
  assert.match(migration, /srk_has_admin_permission\('workers\.manage'\)/);
  assert.match(migration, /srk_has_admin_permission\('workers\.verify'\)/);
  assert.match(migration, /srk_has_admin_permission\('payouts\.read'\)/);
  assert.match(migration, /revoke all .* from public, anon/i);
  assert.match(migration, /grant execute .* to authenticated/i);
  assert.doesNotMatch(migration, /\b(insert into|update public\.|delete from)\b/i);
});

test('Admin RPC calculates an independent third-order online rule for each worker type', () => {
  assert.match(migration, /worker_type='technician' then tc\.completed_booking_count else hc\.completed_booking_count/);
  assert.match(migration, /mod\([\s\S]*?\+1,3\)=0/);
  assert.match(migration, /srk_technician_booking_sequence/);
  assert.match(migration, /srk_helper_booking_sequence/);
});

const completionMigration = readFileSync(new URL('../supabase/migrations/20261125181000_count_only_completed_worker_assignments_in_payment_cycle.sql', import.meta.url), 'utf8');
test('Only completed worker assignments advance the payment sequence', () => {
  assert.match(completionMigration, /srk_on_booking_payment_completed/);
  assert.match(completionMigration, /released-assignment branch not found/);
  assert.match(completionMigration, /Not all released-assignment branches were removed/);
});
