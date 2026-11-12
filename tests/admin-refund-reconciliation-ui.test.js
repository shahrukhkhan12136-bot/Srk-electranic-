'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');

const html = fs.readFileSync('admin.html', 'utf8');
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map(match => match[1])
  .filter(source => source.includes('const cfg=window.SRK_CONFIG'));
assert.equal(scripts.length, 1, 'Admin page should contain one application inline script');
const source = scripts[0];
assert.doesNotThrow(() => new Function(source), 'Admin inline JavaScript must parse');

const start = source.indexOf('// --- Admin-only, advisory refund evidence reconciliation.');
const end = source.indexOf('function esc(s){', start);
assert.ok(start >= 0 && end > start, 'Reconciliation workspace block must exist');
const block = source.slice(start, end);
for (const rpc of [
  'srk_admin_open_refund_reconciliation_case',
  'srk_admin_get_refund_reconciliation_case',
  'srk_admin_submit_refund_reconciliation_evidence',
  'srk_admin_review_refund_reconciliation_evidence'
]) assert.ok(block.includes(rpc), 'Missing reconciliation RPC call: ' + rpc);

assert.ok(block.includes('user.id!==c.opened_by&&user.id!==e.submitted_by'),
  'UI must not offer review to case opener or evidence submitter');
assert.ok(block.includes('financial/customer status नहीं बदलेगा'),
  'Review confirmation must clearly state financial state is unchanged');
assert.ok(block.includes('Retry पर वही Action ID'),
  'Ambiguous network retries must preserve stable action IDs');
assert.ok(block.includes('esc('), 'Dynamic database values must be escaped before HTML rendering');
for (const forbidden of ['sb.from(', 'sb.insert(', 'sb.update(', 'sb.delete(', 'fetch(']) {
  assert.ok(!block.includes(forbidden), 'Reconciliation UI must not perform direct writes/provider calls: ' + forbidden);
}
assert.ok(html.includes("['unknown','processing'].includes(r.status)"),
  'Reconciliation action should only appear on ambiguous/processing refund requests');
console.log('Admin refund reconciliation UI contract checks passed.');
