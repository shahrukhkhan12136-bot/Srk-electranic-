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
  assert.match(save, /p_preferred_language:document\.getElementById\('customerProfileLanguage'\)\.value/);
  assert.match(booking, /customerProfileLanguage.*addEventListener\('change'/);
});


test('customer profile and saved-address loaders handle rejected auth session lookups', () => {
  const loadProfile=body('loadCustomerProfile');
  const loadAddresses=body('loadCustomerSavedAddresses');
  assert.match(loadProfile,/try\s*\{\s*const \{data:sessionData,error:sessionError\}=await customerSb\.auth\.getSession\(\)/);
  assert.match(loadProfile,/if\(sessionError\)throw sessionError/);
  assert.match(loadProfile,/catch\(e\)\{setCustomerProfileStatus\('प्रोफ़ाइल लोड नहीं हो सकी/);
  assert.match(loadAddresses,/try\s*\{\s*const \{data:sessionData,error:sessionError\}=await customerSb\.auth\.getSession\(\)/);
  assert.match(loadAddresses,/if\(sessionError\)throw sessionError/);
  assert.match(loadAddresses,/catch\(e\) \{ setSavedAddressStatus\('सेव किए गए पते अभी लोड नहीं हो सके/);
  assert.match(loadAddresses,/finally \{select\.disabled=false;\}/);
});


test('customer saved-address save catches rejected auth session lookup and restores button', () => {
  const start=booking.indexOf('async function saveCurrentBookingAddress()');
  const end=booking.indexOf('\nfunction editSelectedSavedAddress()',start);
  assert.ok(start>=0&&end>start);
  const save=booking.slice(start,end);
  assert.match(save,/button\.disabled=true;button\.textContent='पता सेव हो रहा है…';\s*try\s*\{\s*const \{data:sessionData,error:sessionError\}=await customerSb\.auth\.getSession\(\)/);
  assert.match(save,/if\(sessionError\)throw sessionError/);
  assert.match(save,/catch\(e\) \{setSavedAddressStatus/);
  assert.match(save,/finally \{button\.disabled=false;button\.textContent='यह पता सेव करें';\}/);
});


test('customer profile avatar, support, payment and booking check auth session errors', () => {
  const profileStart=booking.indexOf('async function saveCustomerProfile()');
  const profileEnd=booking.indexOf('\nlet customerSavedAddresses',profileStart);
  const supportStart=booking.indexOf('async function sendCustomerSupportMessage()');
  const supportEnd=booking.indexOf('\nasync function ',supportStart+10);
  const paymentStart=booking.indexOf('async function startRazorpayPayment()');
  const paymentEnd=booking.indexOf('\nasync function ',paymentStart+10);
  const submitStart=booking.indexOf('const { data: customerSessionData } = await customerSb.auth.getSession();',paymentEnd);
  assert.ok(profileStart>=0&&profileEnd>profileStart);
  assert.ok(supportStart>=0&&supportEnd>supportStart);
  assert.ok(paymentStart>=0&&paymentEnd>paymentStart);
  const profile=booking.slice(profileStart,profileEnd);
  const support=booking.slice(supportStart,supportEnd);
  const payment=booking.slice(paymentStart,paymentEnd);
  assert.match(profile,/error:sessionError\}=await customerSb\.auth\.getSession\(\);\s*if\(sessionError\)throw sessionError/);
  assert.match(support,/error:sessionError\}=await customerSb\.auth\.getSession\(\);\s*if\(sessionError\)throw sessionError/);
  assert.match(payment,/error: sessionError \} = await customerSb\.auth\.getSession\(\);\s*if \(sessionError\) throw sessionError/);
  assert.match(booking,/data: customerSessionData, error: sessionError \} = await customerSb\.auth\.getSession\(\);/);
  assert.ok(submitStart<0,'booking submission should no longer use the unchecked session lookup');
});
