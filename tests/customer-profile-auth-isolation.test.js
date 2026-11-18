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
    assert.match(block, /finally\s*\{if\(isCurrent\(\)\)/);
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


test('customer session synchronization ignores stale session reads and stops after account changes', () => {
  const start = source.indexOf('async function syncCustomerSession()');
  const end = source.indexOf('\nasync function customerSendOtp', start);
  assert.ok(start >= 0 && end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes('const generation=customerActionGeneration'));
  assert.ok(block.includes('if(!isCurrent())return'));
  assert.ok(block.includes('await loadCustomerBookings();if(!isCurrent())return;'));
  assert.ok(block.includes('await loadCustomerProfile();if(!isCurrent())return;'));
});

test('customer OTP send suppresses stale results and only restores its own busy state', () => {
  const start = source.indexOf('async function customerSendOtp()');
  const end = source.indexOf('\nasync function customerVerifyOtp', start);
  assert.ok(start >= 0 && end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes('const generation=customerActionGeneration'));
  assert.ok(block.includes('if(!isCurrent())return'));
  assert.match(block, /finally\{if\(isCurrent\(\)\)/);
});

test('customer OTP verification checks the verified session phone before continuing', () => {
  const start = source.indexOf('async function customerVerifyOtp()');
  const end = source.indexOf('\nasync function customerLogout', start);
  assert.ok(start >= 0 && end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes('customerSb.auth.getSession()'));
  assert.ok(block.includes('actualPhone!==requestedPhone'));
  assert.ok(block.includes('if(!data?.session?.user?.id)return'));
  assert.match(block, /finally\{if\(isCurrent\(\)\)/);
});

test('customer logout suppresses stale status and button changes after another auth transition', () => {
  const start = source.indexOf('async function customerLogout()');
  const end = source.indexOf('\nif (customerCfg.', start);
  assert.ok(start >= 0 && end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes('const generation=customerActionGeneration'));
  assert.ok(block.includes('if(!isCurrent())return'));
  assert.ok(block.includes('finally{if(isCurrent())button.disabled=false;}'));
});

test('customer auth transitions release OTP busy state and recover OTP controls', () => {
  const start = source.indexOf('customerSb.auth.onAuthStateChange');
  const end = source.indexOf('const handleCustomerOffline', start);
  assert.ok(start >= 0 && end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes('customerOtpBusy=false'));
  assert.ok(block.includes('otpSendButton.disabled=false'));
  assert.ok(block.includes('otpVerifyButton.disabled=false'));
});


test('customer auth transitions restore logout button after an in-flight logout', () => {
  const start = source.indexOf('customerSb.auth.onAuthStateChange');
  const end = source.indexOf('const handleCustomerOffline', start);
  assert.ok(start >= 0 && end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes("const customerLogoutButton=document.getElementById('customerLogout')"));
  assert.ok(block.includes('if(customerLogoutButton)customerLogoutButton.disabled=false'));
});


test('customer auth transitions immediately clear prior profile, avatar and booking address form values', () => {
  const authStart = source.indexOf('customerSb.auth.onAuthStateChange');
  const authEnd = source.indexOf('const handleCustomerOffline', authStart);
  assert.ok(authStart >= 0 && authEnd > authStart);
  const block = source.slice(authStart, authEnd);
  assert.ok(block.includes("['customerProfileName','customerProfilePhone','name','state','district','pin','address','place','bookingLat','bookingLng'].forEach"));
  assert.ok(block.includes("customerCurrentAvatarPath=null;setCustomerAvatarPreview(null);"));
  assert.ok(block.includes("const avatarFile=document.getElementById('customerAvatarFile');if(avatarFile)avatarFile.value=''"));
  assert.ok(block.includes("const profileLanguage=document.getElementById('customerProfileLanguage');if(profileLanguage)profileLanguage.value='hi'"));
  assert.ok(block.includes("const mapWrap=document.getElementById('customerMapWrap');if(mapWrap)mapWrap.style.display='none'"));
});


test('customer auth transitions immediately clear identity-scoped profile and booking form values', () => {
  const start = source.indexOf('customerSb.auth.onAuthStateChange');
  const end = source.indexOf('const handleCustomerOffline', start);
  assert.ok(start >= 0 && end > start);
  const block = source.slice(start, end);
  for (const id of ['customerProfileName','customerProfilePhone','name','state','district','pin','address','place','bookingLat','bookingLng']) {
    assert.ok(block.includes(id), 'auth transition clears ' + id);
  }
  assert.ok(block.includes('customerCurrentAvatarPath=null;setCustomerAvatarPreview(null)'));
  assert.ok(block.includes("profileLanguage.value='hi'"));
  assert.ok(block.includes("mapWrap.style.display='none'"));
});

test('selecting a saved customer address restores its saved recipient name into the booking form', () => {
  const start = source.indexOf('function applySelectedSavedAddress()');
  const end = source.indexOf('async function saveCurrentBookingAddress()', start);
  assert.ok(start >= 0 && end > start);
  const block = source.slice(start, end);
  assert.ok(block.includes("document.getElementById('name').value=a.recipient_name||''"));
  assert.ok(block.includes("document.getElementById('address').value=a.address_line"));
});


test('customer auth transitions reset the previous account language and saved-address status', () => {
  const authStart = source.indexOf('customerSb.auth.onAuthStateChange');
  const authEnd = source.indexOf('const handleCustomerOffline', authStart);
  assert.ok(authStart >= 0 && authEnd > authStart);
  const block = source.slice(authStart, authEnd);
  assert.ok(block.includes("const profileLanguage=document.getElementById('customerProfileLanguage');if(profileLanguage)profileLanguage.value='hi'"));
  assert.ok(block.includes("applyCustomerUiLanguage('hi');"));
  assert.ok(block.includes("setSavedAddressStatus('');"));
});

test('Customer AI widgets mount only after a verified profile row is loaded', () => {
  const loadStart = source.indexOf('async function loadCustomerProfile()');
  const loadEnd = source.indexOf('\\nasync function saveCustomerProfile()', loadStart);
  assert.ok(loadStart >= 0 && loadEnd > loadStart);
  const loadBlock = source.slice(loadStart, loadEnd);
  assert.match(loadBlock, /if\\(profile\\)[\\s\\S]*?return true/);
  assert.match(loadBlock, /नई प्रोफ़ाइल है[\\s\\S]*?return false/);
  assert.match(loadBlock, /catch\\(e\\)[\\s\\S]*?return false/);

  const syncStart = source.indexOf('async function syncCustomerSession()');
  const syncEnd = source.indexOf('\\nasync function customerSendOtp', syncStart);
  assert.ok(syncStart >= 0 && syncEnd > syncStart);
  const syncBlock = source.slice(syncStart, syncEnd);
  assert.match(syncBlock, /const customerProfileReady=await loadCustomerProfile\\(\\)/);
  assert.match(syncBlock, /if\\(customerProfileReady\\)mountCustomerAiAssistant\\(\\);\\s*else destroyCustomerAiAssistant\\(\\)/);
  assert.match(syncBlock, /else \\{\\s*destroyCustomerAiAssistant\\(\\)/);

  const saveStart = source.indexOf('async function saveCustomerProfile()');
  const saveEnd = source.indexOf('\\nlet customerSavedAddresses', saveStart);
  assert.ok(saveStart >= 0 && saveEnd > saveStart);
  const saveBlock = source.slice(saveStart, saveEnd);
  assert.match(saveBlock, /const profileReady=await loadCustomerProfile\\(\\)/);
  assert.match(saveBlock, /if\\(profileReady&&document\\.getElementById\\('customer-dashboard'\\)\\?\\.style\\.display!=='none'\\)mountCustomerAiAssistant\\(\\)/);
  assert.match(saveBlock, /else destroyCustomerAiAssistant\\(\\)/);
});
