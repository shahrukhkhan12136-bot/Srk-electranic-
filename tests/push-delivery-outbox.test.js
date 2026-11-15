const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const worker = fs.readFileSync(path.join(__dirname, '..', 'netlify/functions/deliver-push-outbox.js'), 'utf8');
const migration = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261115170000_durable_push_delivery_outbox.sql'), 'utf8');

test('push outbox worker uses server-only credentials and bounded batch claim', () => {
  assert.match(worker, /SUPABASE_SERVICE_ROLE_KEY/);
  assert.match(worker, /PUSH_WEBHOOK_SECRET/);
  assert.match(worker, /srk_claim_push_delivery_outbox/);
  assert.match(worker, /p_limit: 20/);
});

test('push outbox worker sends only claimed payloads to the fixed Edge Function', () => {
  assert.match(worker, /\/functions\/v1\/push-job-offer/);
  assert.match(worker, /x-srk-push-secret/);
  assert.match(worker, /row\.payload/);
});

test('push outbox worker records delivery outcome and has a scheduled cadence', () => {
  assert.match(worker, /srk_finish_push_delivery_outbox/);
  assert.match(worker, /p_outbox_id: row\.outbox_id/);
  assert.match(worker, /schedule: "\* \* \* \* \*"/);
});

test('outbox deduplicates offers and keeps delivery state private', () => {
  assert.match(migration, /offer_id uuid NOT NULL UNIQUE/);
  assert.match(migration, /REVOKE ALL ON TABLE srk_private\.srk_push_delivery_outbox FROM PUBLIC, anon, authenticated/);
  assert.match(migration, /FOR UPDATE SKIP LOCKED/);
});

test('outbox retries with bounded attempts and exponential backoff', () => {
  assert.match(migration, /attempt_count < 8/);
  assert.match(migration, /delivery_status='dead'/);
  assert.match(migration, /make_interval\(secs => least\(3600/);
});

test('subscription table retains owner-scoped CRUD and revokes excess privileges', () => {
  assert.match(migration, /REVOKE ALL ON TABLE public\.srk_push_subscriptions FROM PUBLIC, anon, authenticated/);
  assert.match(migration, /GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public\.srk_push_subscriptions TO authenticated/);
  assert.match(migration, /WITH CHECK \(user_id = \(SELECT auth\.uid\(\)\)\)/);
});
