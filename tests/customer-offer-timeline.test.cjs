const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261114230000_customer_safe_offer_timeline.sql'), 'utf8');

test('customer booking history loads and merges safe offer lifecycle events', () => {
  assert.match(html, /srk_customer_get_my_booking_offer_timeline/);
  assert.match(html, /addTimelineRows\(offerTimelineResult\.data\)/);
  assert.match(html, /offerTimelineResult\.error/);
  for (const event of ['offer_created','offer_accepted','offer_declined','offer_expired','offer_cancelled']) {
    assert.match(html, new RegExp(event + ':'));
    assert.match(migration, new RegExp("'" + event + "'"));
  }
  assert.match(html, /events\.sort\(/);
});

test('offer event storage is private and customer RPC is owner scoped', () => {
  assert.match(migration, /create table if not exists private\.srk_booking_offer_events/i);
  assert.match(migration, /enable row level security/i);
  assert.match(migration, /revoke all on function private\.srk_capture_booking_offer_event\(\) from public, anon, authenticated/i);
  assert.doesNotMatch(migration, /revoke all on schema private/i);
  assert.match(migration, /revoke all on table private\.srk_booking_offer_events from public, anon, authenticated/i);
  assert.match(migration, /b\.customer_user_id=auth\.uid\(\)/i);
  assert.doesNotMatch(migration, /select\s+[^;]*electrician_id/i);
  assert.match(migration, /grant execute on function public\.srk_customer_get_my_booking_offer_timeline\(\) to authenticated/i);
});


test('offer timeline captures status transitions once and backfills legacy final states', () => {
  assert.match(migration, /unique \(offer_id,event_type\)/i);
  assert.match(migration, /on conflict \(offer_id,event_type\) do nothing/i);
  assert.match(migration, /after insert or update of status on public\.job_offers/i);
  assert.match(migration, /new\.status is distinct from old\.status/i);
  assert.match(migration, /where o\.status in \('accepted','declined','expired','cancelled'\)/i);
  assert.match(migration, /coalesce\(o\.responded_at,o\.created_at,now\(\)\)/i);
});

test('customer offer timeline RPC returns only owner bookings in chronological order', () => {
  assert.match(migration, /b\.customer_user_id=auth\.uid\(\)/i);
  assert.match(migration, /order by e\.occurred_at asc,e\.id asc/i);
  assert.match(migration, /limit 1000/i);
  assert.doesNotMatch(migration, /electrician_id/i);
});
