const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const migration = fs.readFileSync(
  path.join(__dirname, '..', 'supabase/migrations/20261121140000_category_neutral_technician_dispatch.sql'),
  'utf8'
);
const worker = fs.readFileSync(
  path.join(__dirname, '..', 'netlify/functions/expire-booking-offers.js'),
  'utf8'
);

test('category-neutral dispatch has independent presence, request, offer and append-only event ledgers', () => {
  for (const table of [
    'srk_technician_presence',
    'srk_technician_dispatch_requests',
    'srk_technician_dispatch_offers',
    'srk_technician_dispatch_events'
  ]) assert.match(migration, new RegExp(`CREATE TABLE IF NOT EXISTS public\\.${table}`));
  assert.match(migration, /srk_technician_dispatch_events_append_only/);
});

test('dispatch supports one to ten technicians and snapshots the requested category and skill', () => {
  assert.match(migration, /required_technician_count smallint NOT NULL DEFAULT 1 CHECK \(required_technician_count BETWEEN 1 AND 10\)/);
  assert.match(migration, /category_code_snapshot text NOT NULL/);
  assert.match(migration, /skill_code_snapshot text NOT NULL/);
  assert.match(migration, /ACTIVE_CATEGORY_SKILL_PAIR_REQUIRED/);
});

test('only approved technicians with separately approved category skill can go online and receive offers', () => {
  assert.match(migration, /t\.account_status='active'/);
  assert.match(migration, /a\.status='approved'/);
  assert.match(migration, /aps\.review_status='approved'/);
  assert.match(migration, /APPROVED_CATEGORY_SKILL_REQUIRED_TO_GO_ONLINE/);
  assert.match(migration, /APPROVED_TECHNICIAN_ACCOUNT_REQUIRED/);
});

test('GPS is restricted to Online or active work and dispatch rejects stale location', () => {
  assert.match(migration, /GPS_UPDATES_ALLOWED_ONLY_WHILE_ONLINE_OR_ON_ACTIVE_BOOKING/);
  assert.match(migration, /last_location_at>=clock_timestamp\(\)-interval '5 minutes'/);
  assert.match(migration, /FRESH_GPS_LOCATION_REQUIRED_TO_GO_ONLINE/);
  assert.match(migration, /last_location_at=CASE WHEN p_latitude IS NOT NULL THEN clock_timestamp\(\) ELSE v_location_at END/);
});

test('automatic dispatch uses a 30 km radius and nearest eligible Technician first', () => {
  assert.match(migration, /candidate\.distance_km<=30|\)\)\)<=30/);
  assert.match(migration, /ORDER BY 2,t\.id/);
  assert.match(migration, /FOR UPDATE OF p SKIP LOCKED/);
  assert.match(migration, /radius_km',30/);
});

test('offers are sequential, time-limited, and cannot be simultaneously active for one booking or Technician', () => {
  assert.match(migration, /srk_technician_dispatch_one_live_offer_per_booking_uidx/);
  assert.match(migration, /srk_technician_dispatch_one_live_offer_per_technician_uidx/);
  assert.match(migration, /expires_at<=clock_timestamp\(\)/);
  assert.match(migration, /make_interval\(secs=>v_req\.offer_ttl_seconds\)/);
});

test('acceptance assigns the Technician transactionally and marks them unavailable for another job', () => {
  assert.match(migration, /srk_technician_respond_to_dispatch_offer/);
  assert.match(migration, /assignment_status,assigned_at,accepted_at/);
  assert.match(migration, /active_booking_id=v_offer\.booking_id/);
  assert.match(migration, /is_online=false,active_booking_id=v_offer\.booking_id/);
});

test('terminal booking releases active presence and keeps last GPS fix', () => {
  assert.match(migration, /srk_release_technician_presence_after_booking_terminal/);
  assert.match(migration, /active_booking_id=NULL,updated_at=clock_timestamp\(\)/);
  assert.match(migration, /Keep the last fix and its timestamp as history/);
});

test('trusted dispatch RPCs are not executable by anon or authenticated clients', () => {
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.srk_dispatch_create_for_booking\([\s\S]*?FROM PUBLIC,anon,authenticated/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_dispatch_create_for_booking\([\s\S]*?TO service_role/);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.srk_dispatch_issue_next_offer\([\s\S]*?FROM PUBLIC,anon,authenticated/);
});

test('existing expiry worker keeps legacy Electrician flow and safely adds Technician queue processing', () => {
  assert.match(worker, /srk_expire_and_advance_booking_offers/);
  assert.match(worker, /srk_dispatch_process_pending_queue/);
  assert.match(worker, /dispatchResponse\.status !== 404/);
  assert.match(worker, /electrician_offers_advanced/);
});
