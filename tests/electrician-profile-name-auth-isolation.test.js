'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'electrician.html'), 'utf8');

test('Electrician profile-name save cannot update a different account view', () => {
  assert.ok(source.includes('electricianDisplayNameSaveRequest=0'));
  assert.ok(source.includes('function clearElectricianAccountView(){profile=null;electricianDisplayNameSaveRequest++;'));
  const start = source.indexOf('async function saveElectricianDisplayName()');
  assert.notEqual(start, -1);
  const end = source.indexOf('\n', start);
  const block = source.slice(start, end < 0 ? source.length : end);
  assert.ok(block.includes('requestedUserId=user.id,requestedProfileId=profile.id'));
  assert.ok(block.includes('user?.id===requestedUserId&&profile?.id===requestedProfileId'));
  assert.ok(block.includes('if(!isCurrent())return'));
  assert.ok(block.includes('if(isCurrent())button.disabled=false'));
});
