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

test('Electrician account changes stop old GPS watchers and stale callbacks cannot update location', () => {
  const clearStart = source.indexOf('function clearElectricianAccountView()');
  const clearEnd = source.indexOf('function init()', clearStart);
  const clearBlock = source.slice(clearStart, clearEnd);
  assert.ok(clearBlock.includes('locationWatches.forEach(watch=>navigator.geolocation.clearWatch(watch))'));
  assert.ok(clearBlock.includes('locationWatches.clear()'));
  assert.ok(clearBlock.includes('electricianLocationStartBusy.clear()'));
  assert.ok(clearBlock.includes('electricianLocationStopBusy.clear()'));
  const start = source.indexOf('async function startElectricianLiveLocation');
  const end = source.indexOf('async function stopElectricianLiveLocation', start);
  const live = source.slice(start, end);
  assert.ok(live.includes('if(!isCurrent()){\n    navigator.geolocation.clearWatch(watch)'));
  assert.ok(live.includes('if(locationWatches.get(id)===watch)locationWatches.delete(id)'));
});

test('Electrician availability changes are bound to the same account and view generation', () => {
  const start = source.indexOf('async function setElectricianAvailability');
  const end = source.indexOf('const electricianLifecycleBusy', start);
  assert.ok(start >= 0 && end > start);
  const action = source.slice(start, end);
  assert.ok(action.includes('requestedUserId=user?.id'));
  assert.ok(action.includes('requestedProfileId=profile?.id'));
  assert.ok(action.includes('requestedGeneration=electricianAccountViewGeneration'));
  assert.ok(action.includes('electricianAccountViewGeneration===requestedGeneration'));
  assert.ok(action.includes('if(!isCurrent())return;'));
  assert.ok(action.includes("sb.rpc('srk_electrician_set_availability'"));
  assert.ok(action.includes("if(!data?.success)throw new Error('Availability update not confirmed')"));
  assert.ok(action.includes('if(isCurrent())await refresh()'));
  assert.ok(action.includes('if(!isCurrent())return;\n  alert('));
});

test('Electrician push controls ignore stale account results and bind writes to the captured user', () => {
  const extract = name => {
    const start = source.indexOf('async function ' + name);
    const next = source.indexOf('\\nasync function ', start + 1);
    assert.ok(start >= 0, name + ' exists');
    return source.slice(start, next < 0 ? source.length : next);
  };
  const refresh = extract('refreshElectricianPushState');
  assert.ok(refresh.includes('requestedUserId=user?.id'));
  assert.ok(refresh.includes('electricianAccountViewGeneration'));
  assert.ok(refresh.includes('if(!isCurrent())return'));
  const enable = extract('enableElectricianPushNotifications');
  assert.ok(enable.includes('requestedProfileId=profile?.id'));
  assert.ok(enable.includes('user?.id===requestedUserId'));
  assert.ok(enable.includes('if(!isCurrent())return'));
  assert.ok(enable.includes('ctx.data.user.id!==requestedUserId'));
  assert.ok(enable.includes('user_id:requestedUserId'));
  assert.ok(enable.includes('finally{if(isCurrent())button.disabled=false}'));
  const disable = extract('disableElectricianPushNotifications');
  assert.ok(disable.includes('ctx.data.user.id!==requestedUserId'));
  assert.ok(disable.includes(".eq('user_id',requestedUserId)"));
  assert.ok(disable.includes('if(!isCurrent())return'));
  assert.ok(disable.includes('finally{if(isCurrent())'));
});
