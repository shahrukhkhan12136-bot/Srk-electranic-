const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const edge = fs.readFileSync(path.join(__dirname, '..', 'supabase/functions/push-job-offer/index.ts'), 'utf8');
const worker = fs.readFileSync(path.join(__dirname, '..', 'netlify/functions/deliver-push-outbox.js'), 'utf8');
const migration = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261115180000_push_subscription_delivery_ledger.sql'), 'utf8');

test('outbox identity is required and passed to the Edge sender', () => {
  assert.match(edge, /outbox_id\?: string/);
  assert.match(edge, /typeof payload\.outbox_id !== "string"/);
  assert.match(worker, /outbox_id: row\.outbox_id/);
});

test('per-subscription delivery ledger deduplicates each outbox and endpoint', () => {
  assert.match(migration, /UNIQUE\(outbox_id,subscription_id\)/);
  assert.match(migration, /ON CONFLICT\(outbox_id,subscription_id\) DO NOTHING/);
  assert.match(migration, /srk_push_subscription_deliveries/);
});

test('only due delivery targets are claimed under row locks', () => {
  assert.match(migration, /FOR UPDATE SKIP LOCKED/);
  assert.match(migration, /locked_until=clock_timestamp\(\)\+interval '2 minutes'/);
  assert.match(migration, /attempt_count<5/);
});

test('successful subscription delivery is persisted and not intentionally resent', () => {
  assert.match(edge, /srk_finish_push_subscription_delivery/);
  assert.match(edge, /p_success: true/);
  assert.match(migration, /delivery_status='delivered'/);
});

test('transient endpoint errors retry per subscription; permanent gone endpoints are cleaned', () => {
  assert.match(edge, /status === 404 \|\| status === 410/);
  assert.match(edge, /p_success: false/);
  assert.match(migration, /delivery_status='dead'/);
  assert.match(migration, /next_attempt_at=clock_timestamp\(\)\+make_interval/);
});

test('outbox completion waits for all subscription deliveries to reach terminal state', () => {
  assert.match(edge, /srk_is_push_subscription_delivery_complete/);
  assert.match(worker, /result\.complete === true/);
  assert.match(migration, /delivery_status IN \('pending','processing'\)/);
});

test('delivery ledger and RPCs are private and service-role only', () => {
  assert.match(migration, /REVOKE ALL ON TABLE srk_private\.srk_push_subscription_deliveries FROM PUBLIC,anon,authenticated/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_claim_push_subscription_deliveries/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_finish_push_subscription_delivery/);
});
