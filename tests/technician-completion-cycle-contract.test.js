const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const migration = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261121120000_unified_technician_identity_completion_cycle.sql'), 'utf8');

test('canonical Technician identity bridges existing electrician profiles without deleting them', () => {
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.srk_technicians/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.srk_technician_profile_links/);
  assert.match(migration, /REFERENCES public\.electrician_profiles\(id\) ON DELETE RESTRICT/);
  assert.match(migration, /INSERT INTO public\.srk_technician_profile_links/);
  assert.doesNotMatch(migration, /DROP TABLE\s+public\.electrician_profiles/i);
});

test('booking assignment model supports multiple category-neutral Technician IDs', () => {
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.srk_booking_technician_assignments/);
  assert.match(migration, /UNIQUE \(booking_id, technician_id\)/);
  assert.match(migration, /service_category_snapshot text NOT NULL/);
  assert.match(migration, /srk_sync_legacy_electrician_assignment/);
});

test('only customer-confirmed completed bookings create completion events', () => {
  assert.match(migration, /NEW\.status IS DISTINCT FROM 'completed'/);
  assert.match(migration, /NEW\.completion_approval_status IS DISTINCT FROM 'approved'/);
  assert.match(migration, /NEW\.customer_completed_at IS NULL/);
  assert.match(migration, /UNIQUE \(technician_id, booking_id\)/);
  assert.match(migration, /ON CONFLICT \(technician_id,booking_id\) DO NOTHING/);
});

test('every third completed booking requires online payment and counter update is serialized', () => {
  assert.match(migration, /UPDATE public\.srk_technician_booking_counters[\s\S]*?completed_booking_count=completed_booking_count\+1[\s\S]*?RETURNING completed_booking_count INTO v_ordinal/);
  assert.match(migration, /IF mod\(v_ordinal,3\)=0 AND NOT v_online THEN/);
  assert.match(migration, /TECHNICIAN_EVERY_THIRD_COMPLETED_BOOKING_REQUIRES_ONLINE_PAYMENT/);
});

test('counter read RPC checks the signed-in Technician identity or Admin role', () => {
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.srk_technician_get_completed_booking_count/);
  assert.match(migration, /t\.auth_user_id=auth\.uid\(\)/);
  assert.match(migration, /public\.is_srk_admin\(\)/);
});
