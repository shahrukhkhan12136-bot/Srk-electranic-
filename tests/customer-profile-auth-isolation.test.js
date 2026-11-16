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


test('saved address save and delete actions reject stale customer sessions', () => {
  for (const name of ['saveCurrentBookingAddress', 'deleteSelectedSavedAddress']) {
    const start = source.indexOf('async function ' + name + '(');
    const next = source.indexOf('\nfunction ', start + 10);
    assert.ok(start >= 0, name + ' handler exists');
    assert.ok(next > start, name + ' handler boundary exists');
    const block = source.slice(start, next);
    assert.ok(block.includes('const generation=customerActionGeneration'));
    assert.ok(block.includes('customerSb.auth.getSession()'));
    assert.ok(block.includes('const sameSession=async()'));
    assert.ok(block.includes('if(!await sameSession())return'));
    assert.match(block, /finally\s*\{if\(generation===customerActionGeneration\)/);
  }
});

test('default saved address mutation is isolated across customer account switches', () => {
  const start = source.indexOf('async function makeSelectedAddressDefault()');
  const end = source.indexOf('\nfunction supportStatus', start);
  assert.ok(start >= 0 && end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes('const generation=customerActionGeneration'));
  assert.ok(block.includes('customerSb.auth.getSession()'));
  assert.ok(block.includes('if(!await sameSession())return'));
  assert.match(block, /finally\s*\{if\(generation===customerActionGeneration\)/);
});

test('customer payment-method mutation is isolated across account switches', () => {
  const start = source.indexOf('async function customerChangePaymentMethod(');
  const end = source.indexOf('\nfunction customerPayBooking', start);
  assert.ok(start >= 0 && end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes('const generation=customerActionGeneration'));
  assert.ok(block.includes('customerSb.auth.getSession()'));
  assert.ok(block.includes('if(!await sameSession())return'));
  assert.ok(block.includes('if(!isCurrent())return'));
});

test('saved address mutation buttons are restored when customer auth changes', () => {
  const authStart = source.indexOf('customerSb.auth.onAuthStateChange');
  const authEnd = source.indexOf('const handleCustomerOffline', authStart);
  assert.ok(authStart >= 0 && authEnd > authStart);
  const block = source.slice(authStart, authEnd);
  assert.ok(block.includes("['saveCurrentAddress','deleteSavedAddress','setDefaultSavedAddress'].forEach"));
  assert.ok(block.includes('if(button)button.disabled=false'));
});
