const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115200000_push_delivery_lease_fencing.sql'), 'utf8');
const contract = fs.readFileSync(path.join(root, 'supabase/tests/database/push_delivery_lease_fencing.test.sql'), 'utf8');

for (const [label, fnName, rowName, maxAttempts] of [
  ['outbox', 'srk_finish_push_delivery_outbox', 'v_row', 8],
  ['device', 'srk_finish_push_subscription_delivery', 'v_row', 5]
]) {
  test(label + ' push completion is fenced to the current processing attempt', () => {
    const start = migration.indexOf('CREATE FUNCTION public.' + fnName);
    assert.notEqual(start, -1, 'fenced function exists');
    const end = migration.indexOf('$function$;', start);
    const fn = migration.slice(start, end);
    assert.match(fn, new RegExp(rowName + '\\.attempt_count IS DISTINCT FROM p_attempt_count'));
    assert.match(fn, /delivery_status <> 'processing'/);
    assert.match(fn, /FOR UPDATE/);
    assert.match(fn, new RegExp(rowName + '\\.attempt_count>=' + maxAttempts));
    assert.match(fn, /delivery_status='delivered'/);
    assert.match(fn, /delivery_status='dead'/);
    assert.ok(fn.includes('left(coalesce(p_error'));
    assert.ok(fn.includes('next_attempt_at=clock_timestamp()+make_interval'));
    assert.match(fn, /WHERE id=p_(?:outbox|delivery)_id AND attempt_count=p_attempt_count AND delivery_status='processing'/);
  });
}

test('push lease fencing SQL contract covers privilege, stale attempts and bounded retry behaviour', () => {
  assert.match(contract, /select plan\\(20\\)/);
  assert.match(contract, /stale worker attempt numbers/);
  assert.match(contract, /service-role-only/);
  assert.match(contract, /terminal rows cannot be overwritten/);
  assert.match(contract, /capped exponential backoff/);
});
