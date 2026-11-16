'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'booking.html'), 'utf8');

test('Customer profile saves are isolated across auth identity changes', () => {
  assert.ok(source.includes('let customerProfileSaveRequest=0;'));
  const start = source.indexOf('async function saveCustomerProfile()');
  const end = source.indexOf('let customerSavedAddresses', start);
  assert.notEqual(start, -1);
  assert.ok(end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes('const requestId=++customerProfileSaveRequest'));
  assert.ok(block.includes('requestedUserId=initialSession?.session?.user?.id||null'));
  assert.ok(block.includes('const isCurrent=()=>requestId===customerProfileSaveRequest&&!!requestedUserId'));
  assert.ok(block.includes('const stillSameUser=async()=>'));
  assert.ok(block.includes('data?.session?.user?.id===requestedUserId'));
  assert.ok(block.includes('if(!await stillSameUser())return'));
  assert.ok(block.includes('loadCustomerAvatar(avatarPath,isCurrent)'));
  assert.ok(block.includes('finally{if(isCurrent())button.disabled=false;}'));
  const auth = source.slice(source.indexOf('onAuthStateChange((event) =>'));
  assert.match(auth, /customerProfileSaveRequest\+\+/);
});
