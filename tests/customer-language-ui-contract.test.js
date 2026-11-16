const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const booking = fs.readFileSync(path.join(__dirname, '../booking.html'), 'utf8');

function body(name) {
  const start = booking.indexOf('function ' + name + '(');
  assert.ok(start >= 0, name + ' function exists');
  const tail = booking.slice(start + 1);
  const next = tail.search(/\n(?:async )?function\s+[A-Za-z0-9_$]+\s*\(/);
  return booking.slice(start, next < 0 ? booking.length : start + 1 + next);
}

test('customer language dictionary includes key dashboard, payment, support and profile translations', () => {
  assert.match(booking, /const customerUiTranslations\s*=\s*\{/);
  for (const phrase of [
    'नई सर्विस बुक करें',
    'भुगतान इतिहास और रसीद',
    'सहायता और शिकायत',
    'ऐप की भाषा',
    'प्रोफ़ाइल सेव करें'
  ]) assert.ok(booking.includes("'" + phrase + "'"), 'dictionary includes ' + phrase);
  assert.match(booking, /'नई सर्विस बुक करें':'Book a New Service'/);
  assert.match(booking, /'भुगतान इतिहास और रसीद':'Payment History & Receipts'/);
});

test('language switching translates from preserved original text, so Hindi-English-Hindi does not double-translate', () => {
  const apply = body('applyCustomerUiLanguage');
  assert.match(apply, /language === 'en' \? 'en' : 'hi'/);
  assert.match(apply, /customerUiOriginalText\.has\(node\)/);
  assert.match(apply, /customerUiOriginalText\.get\(node\)/);
  assert.match(apply, /lang === 'en' \? customerUiText\(key\) : key/);
  assert.match(apply, /customerUiTranslateAttributes\(document\.body, lang\)/);
});

test('customer placeholders, titles and aria-labels restore their original Hindi values on language return', () => {
  const attrs = body('customerUiTranslateAttributes');
  assert.match(attrs, /placeholder: el\.getAttribute\('placeholder'\)/);
  assert.match(attrs, /title: el\.getAttribute\('title'\)/);
  assert.match(attrs, /ariaLabel: el\.getAttribute\('aria-label'\)/);
  assert.match(attrs, /lang === 'en' \? \(customerUiTranslations\[value\] \|\| value\) : original\[key\]/);
});

test('newly rendered dynamic customer content is translated while English is active', () => {
  const observerAt = booking.indexOf('const customerUiLanguageObserver');
  const observerEnd = booking.indexOf('customerUiLanguageObserver.observe', observerAt);
  assert.ok(observerAt >= 0 && observerEnd > observerAt);
  const observer = booking.slice(observerAt, observerEnd);
  assert.match(observer, /document\.documentElement\.lang !== 'en'/);
  assert.match(observer, /customerUiTranslateAttributes\(node, 'en'\)/);
  assert.match(observer, /Node\.TEXT_NODE/);
  assert.match(booking, /customerUiLanguageObserver\.observe\(document\.body, \{childList:true,subtree:true\}\)/);
});

test('customer profile restores the saved language and persists the selected preference through the profile RPC', () => {
  const load = body('loadCustomerProfile');
  const save = body('saveCustomerProfile');
  assert.match(load, /profile\.preferred_language\|\|'hi'/);
  assert.match(load, /applyCustomerUiLanguage\(profile\.preferred_language\|\|'hi'\)/);
  assert.match(save, /const preferredLanguage=document\.getElementById\('customerProfileLanguage'\)\.value/);
  assert.match(save, /p_preferred_language:preferredLanguage/);
  assert.match(booking, /customerProfileLanguage.*addEventListener\('change'/);
});


test('customer profile and saved-address loaders handle rejected auth session lookups', () => {
  const loadProfile=body('loadCustomerProfile');
  const loadAddresses=body('loadCustomerSavedAddresses');
  assert.match(loadProfile,/try\s*\{\s*const \{data:sessionData,error:sessionError\}=await customerSb\.auth\.getSession\(\)/);
  assert.match(loadProfile,/if\(sessionError\)throw sessionError/);
  assert.match(loadProfile,/catch\(e\)\s*\{if\(isCurrent\(\)\)setCustomerProfileStatus\('प्रोफ़ाइल लोड नहीं हो सकी/);
  assert.match(loadAddresses,/try\s*\{\s*const \{data:sessionData,error:sessionError\}=await customerSb\.auth\.getSession\(\)/);
  assert.match(loadAddresses,/if\(sessionError\)throw sessionError/);
  assert.match(loadAddresses,/catch\(e\)\s*\{\s*if\(isCurrent\(\)\)setSavedAddressStatus\('सेव किए गए पते अभी लोड नहीं हो सके/);
  assert.match(loadAddresses,/finally\s*\{\s*if\(isCurrent\(\)\)select\.disabled=false;\s*\}/);
});


test('customer saved-address save catches rejected auth session lookup and restores button', () => {
  const start=booking.indexOf('async function saveCurrentBookingAddress()');
  const end=booking.indexOf('\nfunction editSelectedSavedAddress()',start);
  assert.ok(start>=0&&end>start);
  const save=booking.slice(start,end);
  assert.match(save,/button\.disabled=true;button\.textContent='पता सेव हो रहा है…';\s*try\s*\{\s*const \{data:sessionData,error:sessionError\}=await customerSb\.auth\.getSession\(\)/);
  assert.match(save,/if\(sessionError\)throw sessionError/);
  assert.match(save,/catch\(e\)\{if\(isCurrent\(\)\)setSavedAddressStatus/);
  assert.match(save,/finally\{if\(isCurrent\(\)\)\{button\.disabled=false;button\.textContent='यह पता सेव करें';\}\}/);
});


test('customer profile avatar, support, payment and booking check auth session errors', () => {
  const profileStart=booking.indexOf('async function saveCustomerProfile()');
  const profileEnd=booking.indexOf('\nlet customerSavedAddresses',profileStart);
  const supportStart=booking.indexOf('async function sendCustomerSupportMessage()');
  const supportEnd=booking.indexOf('\nasync function ',supportStart+10);
  const paymentStart=booking.indexOf('async function startRazorpayPayment()');
  const paymentEnd=booking.indexOf('\nasync function ',paymentStart+10);
  const bookingSubmitStart=booking.indexOf("document.getElementById('booking').addEventListener('submit', async function (e) {");
  const bookingSubmitEnd=booking.indexOf('\n});',bookingSubmitStart);
  assert.ok(bookingSubmitStart>=0&&bookingSubmitEnd>bookingSubmitStart,'booking submit handler exists');
  const bookingSubmit=booking.slice(bookingSubmitStart,bookingSubmitEnd);
  assert.match(bookingSubmit,/const \{data,error\}=await customerSb\.auth\.getSession\(\)[\s\S]*?if\(error\)throw error/);
  assert.match(bookingSubmit,/const latestSession\\s*=\\s*latestSessionData\\?\\.session[\\s\\S]*?latestSession\\.user\\.id\\s*!==\\s*customerSession\\.user\\.id/);
  assert.match(bookingSubmit,/bookingHeaders\.Authorization = 'Bearer ' \+ latestSession\.access_token/);
  assert.ok(bookingSubmit.indexOf('if (latestSessionError) throw latestSessionError;') < bookingSubmit.indexOf("fetch('/api/create-booking'"),'session errors must stop booking submission before network request');
});


test('customer avatar upload safely reconciles a rejected profile-save RPC before deleting the object', () => {
  const save = body('saveCustomerProfile');
  assert.match(save, /let profileSaveResult/);
  assert.match(save, /catch\(saveError\)/);
  assert.match(save, /srk_customer_get_my_profile/);
  assert.match(save, /lookupSucceeded&&latestProfile\?\.full_name===fullName&&latestProfile\?\.preferred_language===preferredLanguage&&latestProfile\?\.avatar_path===avatarPath/);
  assert.match(save, /storage\.from\('srk-customer-avatars'\)\.remove\(\[avatarPath\]\)/);
  assert.match(save, /if\(lookupSucceeded&&file&&avatarPath!==customerCurrentAvatarPath\)/);
  assert.match(save, /throw profileSaveError/);
});


test('customer default-address update does not overwrite a failed address-list refresh with a success message', () => {
  const loadStart=booking.indexOf('async function loadCustomerSavedAddresses()');
  const loadEnd=booking.indexOf('\nfunction applySelectedSavedAddress()',loadStart);
  const defaultStart=booking.indexOf('async function makeSelectedAddressDefault()');
  const defaultEnd=booking.indexOf('\nfunction supportStatus',defaultStart);
  assert.ok(loadStart>=0&&loadEnd>loadStart&&defaultStart>=0&&defaultEnd>defaultStart);
  const load=booking.slice(loadStart,loadEnd),makeDefault=booking.slice(defaultStart,defaultEnd);
  assert.match(load,/return true;\s*\} catch\(e\).*return false;/s);
  assert.match(makeDefault,/const addressListRefreshed=await loadCustomerSavedAddresses\(\);/);
  assert.match(makeDefault,/if\(!addressListRefreshed\)\{setSavedAddressStatus\('डिफ़ॉल्ट पता बदल गया है, लेकिन सूची रीफ़्रेश नहीं हो सकी।/);
  assert.ok(makeDefault.indexOf('if(!addressListRefreshed)')<makeDefault.indexOf("setSavedAddressStatus('डिफ़ॉल्ट पता सफलतापूर्वक बदल दिया गया है।')"));
});


test('customer saved-address delete reconciles uncertain RPC results and checks refresh outcome', () => {
  const start=booking.indexOf('async function deleteSelectedSavedAddress()');
  const end=booking.indexOf('\nasync function makeSelectedAddressDefault()',start);
  assert.ok(start>=0&&end>start);
  const remove=booking.slice(start,end);
  assert.match(remove,/const refreshed=await loadCustomerSavedAddresses\(\);/);
  assert.match(remove,/if\(!refreshed\)\{setSavedAddressStatus\('पता हटाने का अनुरोध सफल रहा/);
  assert.match(remove,/srk_customer_list_my_saved_addresses/);
  assert.match(remove,/state=rows\.some\(row=>row\.id===id\)\?'present':'absent'/);
  assert.match(remove,/if\(state==='absent'\)/);
  assert.match(remove,/else if\(state==='present'\)/);
  assert.match(remove,/let state='unknown'/);
  assert.match(remove,/else setSavedAddressStatus\('पता हटाने का परिणाम स्पष्ट नहीं है/);
});


test('customer saved-address save does not report full success when the refreshed list fails', () => {
  const save = body('saveCurrentBookingAddress');
  assert.match(save, /const refreshed=await loadCustomerSavedAddresses\(\)/);
  assert.match(save, /if\(!refreshed\)[\s\S]*?पता सेव हो गया है, लेकिन सूची रीफ़्रेश नहीं हो सकी/);
  assert.ok(save.indexOf('if(!addressListRefreshed)') < save.indexOf("setSavedAddressStatus('पता सफलतापूर्वक सेव हो गया।')"));
  assert.match(save, /finally\{if\(isCurrent\(\)\)\{button\.disabled=false/);
});
