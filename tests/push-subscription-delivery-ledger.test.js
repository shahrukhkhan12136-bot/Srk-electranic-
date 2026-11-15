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
  assert.match(migration, /locked_until=clock_timestamp\(\)\+interval '5 minutes'/);
  assert.match(migration, /attempt_count<5/);
});

test('successful subscription delivery is persisted and not intentionally resent', () => {
  assert.match(edge, /srk_finish_push_subscription_delivery/);
  assert.match(edge, /p_success: true/);
  assert.match(edge, /Invalid subscription identity/);
  assert.match(migration, /delivery_status='delivered'/);
});

test('transient endpoint errors retry per subscription; permanent gone endpoints are cleaned', () => {
  assert.match(edge, /status === 404 \|\| status === 410/);
  assert.match(edge, /p_success: false/);
  assert.match(migration, /delivery_status='dead'/);
  assert.match(migration, /next_attempt_at=clock_timestamp\(\)\+make_interval/);
});

test('sender waits for every device attempt and persists success or retry outcome', () => {
  assert.match(edge, /await Promise\.all\(claimed\.targets\.map/);
  assert.match(edge, /p_success: true/);
  assert.match(edge, /p_success: false/);
  assert.match(edge, /srk_is_push_subscription_delivery_complete/);
});

test('permanent endpoint responses remove the subscription and cascade its ledger row', () => {
  assert.match(edge, /status === 404 \|\| status === 410/);
  assert.match(edge, /\.from\("srk_push_subscriptions"\)\.delete\(\)\.eq\("id", target\.subscription_id\)/);
  assert.match(migration, /subscription_id uuid NOT NULL REFERENCES public\.srk_push_subscriptions\(id\) ON DELETE CASCADE/);
});

test('outbox completion requires every device delivered so dead devices remain recoverable', () => {
  assert.match(edge, /srk_is_push_subscription_delivery_complete/);
  assert.match(worker, /result\.complete === true/);
  assert.match(migration, /d\.delivery_status <> 'delivered'/);
  assert.equal((migration.match(/d\\.delivery_status <> 'delivered'/g) || []).length, 2);
});

test('delivery ledger and RPCs are private and service-role only', () => {
  assert.match(migration, /REVOKE ALL ON TABLE srk_private\.srk_push_subscription_deliveries FROM PUBLIC,anon,authenticated/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_claim_push_subscription_deliveries/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_finish_push_subscription_delivery/);
});

test('subscription ledger migration refuses to run before the outbox', () => {
  assert.match(migration, /to_regclass\('srk_private\.srk_push_delivery_outbox'\)/);
  assert.match(migration, /subscription id and user_id/);
});

test('delivery ledger terminalizes expired leases at the retry cap', () => {
  assert.match(migration, /delivery_status='processing' AND attempt_count>=5/);
  assert.match(migration, /Delivery lease expired after maximum attempts/);
  assert.match(migration, /auth\.role\(\) IS DISTINCT FROM 'service_role'/);
});

test('all ledger RPCs fail closed for null or non-service roles and recover null leases', () => {
  const checks = migration.match(/auth\.role\(\) IS DISTINCT FROM 'service_role'/g) || [];
  assert.equal(checks.length, 3);
  assert.match(migration, /locked_until IS NULL OR d\.locked_until<clock_timestamp\(\)/);
});

test('per-device finish RPC uses attempt fencing to reject stale sender results', () => {
  const fencing = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261115200000_push_delivery_lease_fencing.sql'), 'utf8');
  assert.match(edge, /p_attempt_count: target\.attempt_count/);
  assert.match(fencing, /p_delivery_id uuid,p_attempt_count integer,p_success boolean/);
  assert.match(fencing, /v_row\.attempt_count IS DISTINCT FROM p_attempt_count/);
  assert.match(fencing, /v_row\.delivery_status <> 'processing'/);
  assert.match(fencing, /RETURNS boolean/);
});

test('per-device fencing migration replaces the exact legacy RPC signature and matches every sender finish call', () => {
  const fencing = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261115200000_push_delivery_lease_fencing.sql'), 'utf8');
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.srk_finish_push_subscription_delivery\(/);
  assert.match(fencing, /DROP FUNCTION IF EXISTS public\.srk_finish_push_subscription_delivery\(uuid,boolean,text\)/);
  assert.match(fencing, /CREATE FUNCTION public\.srk_finish_push_subscription_delivery\(\s*p_delivery_id uuid,p_attempt_count integer,p_success boolean/);
  assert.match(fencing, /REVOKE ALL ON FUNCTION public\.srk_finish_push_subscription_delivery\(uuid,integer,boolean,text\)/);
  assert.match(fencing, /GRANT EXECUTE ON FUNCTION public\.srk_finish_push_subscription_delivery\(uuid,integer,boolean,text\) TO service_role/);
  const finishCalls = edge.match(/srk_finish_push_subscription_delivery", \{[\s\S]*?\}\)/g) || [];
  assert.equal(finishCalls.length, 3);
  for (const call of finishCalls) assert.match(call, /p_attempt_count: target\.attempt_count/);
  assert.match(migration, /'attempt_count',c\.attempt_count/);
});

test('sender does not count a stale/rejected device finish RPC as successful', () => {
  assert.match(edge, /if \(error \|\| data !== true\) failed\+\+; else sent\+\+/);
  assert.equal((edge.match(/finishResult\.error \|\| finishResult\.data !== true/g) || []).length, 2);
});
