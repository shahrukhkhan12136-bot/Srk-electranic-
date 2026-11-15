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
  assert.match(worker, /p_limit: 3/);
});

test('push outbox worker authenticates the Supabase Edge gateway and webhook sender', () => {
  assert.match(worker, /apikey: key/);
  assert.match(worker, /Authorization: /);
  assert.match(worker, /x-srk-push-secret/);
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

test('outbox migration atomically removes the legacy synchronous push trigger', () => {
  const legacyDrop = migration.indexOf('DROP TRIGGER IF EXISTS trg_srk_push_job_offer ON public.job_offers');
  const outboxCreate = migration.indexOf('CREATE TRIGGER trg_srk_enqueue_job_offer_push');
  assert.notEqual(legacyDrop, -1);
  assert.notEqual(outboxCreate, -1);
  assert.ok(legacyDrop < outboxCreate);
  assert.match(migration, /AFTER INSERT ON public\.job_offers/);
  assert.match(migration, /DROP TRIGGER IF EXISTS trg_srk_push_job_offer/);
});

test('outbox migration fails fast when required schema prerequisites are absent', () => {
  assert.match(migration, /to_regnamespace\('srk_private'\)/);
  assert.match(migration, /job_offers\.expires_at/);
  assert.match(migration, /electrician_profiles\.available_for_work/);
  assert.match(migration, /subscription id\/user_id\/endpoint\/p256dh\/auth columns/);
});

test('outbox terminalizes expired exhausted leases and uses a bounded worker batch', () => {
  assert.match(migration, /delivery_status='processing' AND attempt_count>=8/);
  assert.match(migration, /Outbox lease expired after maximum attempts/);
  assert.match(migration, /auth\.role\(\) IS DISTINCT FROM 'service_role'/);
  assert.match(worker, /p_limit: 3/);
  assert.match(migration, /interval '5 minutes'/);
});

test('all outbox RPCs fail closed for null or non-service roles', () => {
  const checks = migration.match(/auth\.role\(\) IS DISTINCT FROM 'service_role'/g) || [];
  assert.equal(checks.length, 2);
  assert.match(migration, /locked_until IS NULL OR o\.locked_until < clock_timestamp\(\)/);
});

test('worker emits structured degraded alerts and fails scheduled invocation on retry/dead letters', () => {
  assert.match(worker, /push_delivery_degraded/);
  assert.match(worker, /deadOutbox > 0 \|\| deadDevices > 0/);
  assert.match(worker, /statusCode: degraded \? 502 : 200/);
  assert.match(worker, /push_outbox_finish_failed/);
  assert.match(worker, /srk_get_push_delivery_health/);
});

test('health and dead-letter recovery RPCs are service-role only and do not expose payloads', () => {
  const monitoring = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261115190000_push_delivery_health_monitoring.sql'), 'utf8');
  assert.match(monitoring, /srk_get_push_delivery_health/);
  assert.match(monitoring, /GRANT EXECUTE ON FUNCTION public\.srk_get_push_delivery_health\(\) TO service_role/);
  assert.match(monitoring, /REVOKE ALL ON FUNCTION public\.srk_get_push_delivery_health\(\) FROM PUBLIC,anon,authenticated/);
  assert.match(monitoring, /srk_retry_push_delivery_dead_letter/);
  assert.match(monitoring, /Only dead outbox items can be manually recovered/);
  assert.match(monitoring, /delivery_status='delivered'/);
  assert.match(monitoring, /delivery_status='pending',attempt_count=0/);
  assert.match(monitoring, /GRANT EXECUTE ON FUNCTION public\.srk_retry_push_delivery_dead_letter\(uuid\) TO service_role/);
});

test('outbox finish RPC uses an attempt fencing token to reject stale workers', () => {
  const fencing = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261115200000_push_delivery_lease_fencing.sql'), 'utf8');
  assert.match(worker, /p_attempt_count: row\.attempt_count/);
  assert.match(fencing, /p_outbox_id uuid,p_attempt_count integer,p_success boolean/);
  assert.match(fencing, /v_row\.attempt_count IS DISTINCT FROM p_attempt_count/);
  assert.match(fencing, /v_row\.delivery_status <> 'processing'/);
  assert.match(fencing, /RETURNS boolean/);
});

test('outbox fencing migration replaces the exact legacy RPC signature and grants only the new signature', () => {
  const fencing = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261115200000_push_delivery_lease_fencing.sql'), 'utf8');
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.srk_finish_push_delivery_outbox\(\s*p_outbox_id uuid, p_success boolean, p_error text DEFAULT NULL/);
  assert.match(fencing, /DROP FUNCTION IF EXISTS public\.srk_finish_push_delivery_outbox\(uuid,boolean,text\)/);
  assert.match(fencing, /CREATE FUNCTION public\.srk_finish_push_delivery_outbox\(\s*p_outbox_id uuid,p_attempt_count integer,p_success boolean/);
  assert.match(fencing, /REVOKE ALL ON FUNCTION public\.srk_finish_push_delivery_outbox\(uuid,integer,boolean,text\)/);
  assert.match(fencing, /GRANT EXECUTE ON FUNCTION public\.srk_finish_push_delivery_outbox\(uuid,integer,boolean,text\) TO service_role/);
  assert.match(worker, /p_attempt_count: row\.attempt_count/);
  assert.match(worker, /result\.complete === true/);
});

test('worker treats an HTTP-success stale fencing rejection as a failed finish', () => {
  assert.match(worker, /finish\.ok && \(await finish\.json\(\)\.catch\(\(\) => false\)\) === true/);
  assert.match(worker, /stale_or_rejected: finish\.ok/);
});
