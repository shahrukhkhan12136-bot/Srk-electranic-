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

test('uncertain customer profile save is reconciled against every requested field, not avatar path alone', () => {
  const start = source.indexOf('async function saveCustomerProfile()');
  const end = source.indexOf('\nlet customerSavedAddresses', start);
  assert.notEqual(start, -1);
  assert.ok(end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes("const preferredLanguage=document.getElementById('customerProfileLanguage').value;"));
  assert.ok(block.includes('p_preferred_language:preferredLanguage'));
  assert.ok(block.includes('latestProfile?.full_name===fullName'));
  assert.ok(block.includes('latestProfile?.preferred_language===preferredLanguage'));
  assert.ok(block.includes('latestProfile?.avatar_path===avatarPath'));
  assert.ok(!block.includes('if(lookupSucceeded&&latestProfile?.avatar_path===avatarPath)'));
});

test('saved customer addresses are cleared and in-flight reads invalidated on auth changes', () => {
  const authStart = source.indexOf("customerSb.auth.onAuthStateChange");
  const authEnd = source.indexOf("const handleCustomerOffline", authStart);
  assert.ok(authStart >= 0 && authEnd > authStart);
  const authBlock = source.slice(authStart, authEnd);
  assert.ok(authBlock.includes('customerSavedAddressLoadRequest++'));
  assert.ok(authBlock.includes('customerSavedAddresses=[]'));
  assert.ok(authBlock.includes("savedAddressSelect.innerHTML='<option value=\"\">नया पता इस्तेमाल करें</option>'"));
  const loadStart = source.indexOf('async function loadCustomerSavedAddresses()');
  const loadEnd = source.indexOf('\nfunction applySelectedSavedAddress()', loadStart);
  assert.ok(loadStart >= 0 && loadEnd > loadStart);
  const loadBlock = source.slice(loadStart, loadEnd);
  assert.ok(loadBlock.includes('requestedUserId=sessionData.session.user.id'));
  assert.ok(loadBlock.includes('latestSessionData?.session?.user?.id!==requestedUserId'));
  assert.ok(loadBlock.includes('if(!isCurrent())return false'));
});
