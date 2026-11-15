const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');

test('customer dashboard exposes all five accessible menu tabs and matching panels', () => {
  const tabs = ['Home', 'Bookings', 'Payments', 'Support', 'Profile'];
  for (const name of tabs) {
    assert.match(booking, new RegExp('data-customer-menu="' + name + '"'));
    assert.match(booking, new RegExp('id="customerMenu' + name + '"'));
    assert.match(booking, new RegExp('aria-controls="customerMenu' + name + '"'));
  }
  assert.match(booking, /role="tablist"/);
  assert.match(booking, /role="tabpanel"/);
  assert.match(booking, /ArrowRight/);
  assert.match(booking, /ArrowLeft/);
});

test('customer menu routes payments, support and profile content into their own tabs', () => {
  assert.match(booking, /Payments:\s*document\.getElementById\('customerPaymentHistoryPanel'\)/);
  assert.match(booking, /Support:\s*document\.getElementById\('customerSupportPanel'\)/);
  assert.match(booking, /Profile:\s*document\.getElementById\('customerProfilePanel'\)/);
  assert.match(booking, /if\(node&&target\)target\.appendChild\(node\)/);
  assert.match(booking, /document\.getElementById\('customerProfileAddressLink'\)[\s\S]*?savedAddressSelect/);
});

test('support and profile remain behind the authenticated customer dashboard', () => {
  assert.match(booking, /const dashboard = document\.getElementById\('customer-dashboard'\)/);
  assert.match(booking, /document\.getElementById\('customer-dashboard'\)\.style\.display = session \? 'block' : 'none'/);
  assert.match(booking, /srk_customer_create_booking_complaint/);
  assert.match(booking, /srk_customer_list_booking_complaints/);
  assert.match(booking, /srk_customer_update_my_profile/);
  assert.match(booking, /srk_customer_get_my_profile/);
});


test('customer profile language preference applies reversible Hindi and English UI translations', () => {
  assert.match(booking, /const customerUiTranslations =/);
  assert.match(booking, /function applyCustomerUiLanguage\(language\)/);
  assert.match(booking, /document\.documentElement\.lang = lang/);
  assert.match(booking, /customerProfileLanguage.*addEventListener\('change'/);
  assert.match(booking, /applyCustomerUiLanguage\(profile\.preferred_language\|\|'hi'\)/);
  assert.match(booking, /customerUiOriginalText = new WeakMap\(\)/);
  assert.match(booking, /customerUiLanguageObserver\.observe\(document\.body/);
  assert.match(booking, /'सर्विस बुक करें':'Book a Service'/);
});


test('customer dynamic payment messages and printable receipt respect selected language', () => {
  assert.match(booking, /const customerNativeAlert = window\.alert\.bind\(window\)/);
  assert.match(booking, /window\.alert = message => customerNativeAlert\(customerUiText\(message\)\)/);
  assert.match(booking, /'भुगतान रिकॉर्ड':'Payment Record'/);
  assert.match(booking, /'रिफंड स्वीकृत':'Refund Approved'/);
  assert.match(booking, /const receiptLang=document\.documentElement\.lang==='en'\?'en':'hi'/);
  assert.match(booking, /toLocaleString\(receiptLang==='en'\?'en-IN':'hi-IN'/);
  assert.match(booking, /<html lang=\"'\+receiptLang\+\'\"/);
  assert.match(booking, /'कुल सत्यापित भुगतान':'Total Verified Payment'/);
  const receiptStart = booking.indexOf('async function customerPrintPaymentReceipt');
  const receiptEnd = booking.indexOf('async function loadCustomerPaymentHistory', receiptStart);
  assert.ok(receiptStart >= 0 && receiptEnd > receiptStart);
  assert.doesNotMatch(booking.slice(receiptEnd), /\bR\(/);
});


test('customer and electrician inline browser scripts are syntactically valid JavaScript', () => {
  for (const file of ['booking.html', 'electrician.html']) {
    const html = fs.readFileSync(path.join(root, file), 'utf8');
    const scripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\\s\\S]*?)<\\/script>/gi)];
    assert.ok(scripts.length > 0, file + ' should contain an inline application script');
    for (const match of scripts) {
      assert.doesNotThrow(() => new Function(match[1]), file + ' inline script should parse');
    }
  }
});

test('electrician app keeps the fixed-duration server-timed work lifecycle and no quotation UI', () => {
  const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
  assert.match(electrician, /srk_get_my_offer_details/);
  assert.match(electrician, /srk_electrician_request_work_start/);
  assert.match(electrician, /srk_electrician_request_work_completion/);
  assert.match(electrician, /formatElectricianTimer/);
  assert.match(electrician, /srk_electrician_get_labour_bill/);
  assert.doesNotMatch(electrician, /quoted_amount|submit.*quote|quotation approval|inspection quote/i);
});
