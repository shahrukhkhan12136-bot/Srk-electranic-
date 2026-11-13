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
  assert.match(migration, /revoke all on table private\.srk_booking_offer_events from public, anon, authenticated/i);
  assert.match(migration, /b\.customer_user_id=auth\.uid\(\)/i);
  assert.doesNotMatch(migration, /select\s+[^;]*electrician_id/i);
  assert.match(migration, /grant execute on function public\.srk_customer_get_my_booking_offer_timeline\(\) to authenticated/i);
});
