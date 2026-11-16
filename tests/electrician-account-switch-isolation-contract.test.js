'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'electrician.html'), 'utf8');

test('Electrician account history loaders ignore stale responses after account changes', () => {
  for (const counter of ['electricianSupportListRequest=0','electricianPhoneHistoryRequest=0','electricianAreaHistoryRequest=0','electricianKycListRequest=0']) {
    assert.ok(source.includes(counter), counter);
  }
  for (const [name, counter] of [
    ['loadElectricianSupportTickets','electricianSupportListRequest'],
    ['loadElectricianPhoneChangeHistory','electricianPhoneHistoryRequest'],
    ['loadMyAreaChangeRequests','electricianAreaHistoryRequest'],
    ['loadVerificationDocuments','electricianKycListRequest']
  ]) {
    const start = source.indexOf('async function ' + name);
    assert.notEqual(start, -1, name + ' exists');
    const next = source.indexOf('\nasync function ', start + 1);
    const block = source.slice(start, next < 0 ? source.length : next);
    assert.ok(block.includes('++' + counter), name + ' increments request generation');
    assert.ok(block.includes('requestedUserId=user.id'), name + ' captures user identity');
    assert.ok(block.includes('if(!isCurrent())return'), name + ' rejects stale response');
  }
  assert.ok(source.includes('electricianSupportListRequest++;electricianPhoneHistoryRequest++;electricianAreaHistoryRequest++;electricianKycListRequest++;clearElectricianAccountView();'));
});
