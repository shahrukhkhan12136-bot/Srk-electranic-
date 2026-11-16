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

test('Electrician phone-change OTP state and responses are isolated across account switches', () => {
  assert.ok(source.includes('electricianPhoneChangeActionRequest=0'));
  const clearStart = source.indexOf('function clearElectricianAccountView()');
  const clearEnd = source.indexOf('\nfunction init()', clearStart);
  assert.ok(clearStart >= 0 && clearEnd > clearStart);
  const clearBlock = source.slice(clearStart, clearEnd);
  assert.ok(clearBlock.includes('electricianPhoneChangeActionRequest++'));
  assert.ok(clearBlock.includes('phoneChangeRequestId=null'));
  assert.ok(clearBlock.includes("phoneOtpBox.classList.add('hidden')"));
  assert.ok(clearBlock.includes("'phoneChangeOtp','phoneChangeNew','phoneChangeReason'"));
  for (const name of ['sendElectricianPhoneChangeOtp','verifyElectricianPhoneChangeOtp']) {
    const start = source.indexOf('async function ' + name);
    const next = source.indexOf('\nasync function ', start + 1);
    const block = source.slice(start, next < 0 ? source.length : next);
    assert.ok(block.includes('const actionRequest=++electricianPhoneChangeActionRequest'));
    assert.ok(block.includes('requestedUserId=user?.id'));
    assert.ok(block.includes('if(!isCurrent())return'));
    assert.ok(block.includes('finally{if(isCurrent())'), name + ' releases busy state only for the current session');
    assert.ok(block.includes('phoneChangeBusy=false'), name + ' clears its busy state');
  }
});

test('Electrician support create and reply do not clear a newer account busy lock', () => {
  for (const [name, flag] of [
    ['createElectricianSupportTicket', 'electricianSupportCreateBusy'],
    ['sendElectricianSupportReply', 'electricianSupportReplyBusy']
  ]) {
    const start = source.indexOf('async function ' + name);
    assert.notEqual(start, -1, name + ' exists');
    const next = source.indexOf('\\nasync function ', start + 1);
    const block = source.slice(start, next < 0 ? source.length : next);
    assert.match(block, new RegExp('finally\\s*\\{\\s*if\\(isCurrent\\(\\)\\)\\s*\\{\\s*' + flag + '=false'));
    assert.match(block, /if\(button\)\{button\.disabled=false/);
  }
});
