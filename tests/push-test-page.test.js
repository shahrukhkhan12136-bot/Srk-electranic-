import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const html = readFileSync('push-test/index.html', 'utf8');
const worker = readFileSync('push-test/sw.js', 'utf8');
const inlineScript = html.split('<script>')[1]?.split('</script>')[0];

assert.ok(inlineScript, 'Push test page must contain its application script');
assert.ok(html.includes("register('./sw.js'"), 'Page must register its dedicated service worker');
assert.ok(html.includes("rpc('srk_save_push_subscription'"), 'Page must use the guarded subscription RPC');
assert.ok(!html.includes(".from('srk_push_subscriptions').upsert"), 'Page must not bypass the subscription RPC');
assert.ok(!html.includes('value="shahrookhkhan206@gmail.com"'), 'Page must not prefill an email address');
assert.ok(worker.includes("addEventListener('push'"), 'Worker must handle push events');
assert.ok(worker.includes("addEventListener('notificationclick'"), 'Worker must handle notification clicks');
assert.ok(worker.includes('candidate.origin === self.location.origin'), 'Worker must reject cross-origin navigation');
assert.ok(worker.includes("candidate.pathname === '/electrician.html'"), 'Worker must only open the electrician dashboard');

new vm.Script(inlineScript);
new vm.Script(worker);

console.log('Push test page and dedicated service worker contract passed.');
