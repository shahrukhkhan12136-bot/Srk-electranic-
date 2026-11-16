'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'booking.html'), 'utf8');

test('Customer profile and avatar responses are isolated across auth changes', () => {
  assert.ok(source.includes('let customerProfileLoadRequest=0;'));
  assert.ok(source.includes('customerProfileLoadRequest++;'));
  const start = source.indexOf('async function loadCustomerProfile()');
  const end = source.indexOf('\nasync function saveCustomerProfile()', start);
  assert.notEqual(start, -1);
  assert.ok(end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes('const requestId=++customerProfileLoadRequest'));
  assert.ok(block.includes('const requestedUserId=session.user.id'));
  assert.ok(block.includes('data?.session?.user?.id===requestedUserId'));
  assert.ok(block.includes('if(!await stillSameUser())return'));
  const avatarStart = source.indexOf('async function loadCustomerAvatar(');
  const avatarEnd = source.indexOf('\nasync function loadCustomerProfile()', avatarStart);
  const avatarBlock = source.slice(avatarStart, avatarEnd);
  assert.ok(avatarBlock.includes('if(!isCurrent())return'));
  assert.ok(avatarBlock.includes('if(isCurrent())setCustomerProfileStatus'));
});
