const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');

test('customer booking copy does not mention the retired inspection quotation process', () => {
  assert.doesNotMatch(booking, /post-inspection quotation|निरीक्षण के बाद अलग quotation/i);
});

test('customer English dictionary covers remaining static booking and dashboard guidance', () => {
  for (const translated of [
    'Your private profile and saved addresses are managed securely.',
    'Your Saved Addresses',
    'Allow GPS to select the correct location.',
    'Open Location in Google Maps',
    'Your Estimated Labour',
    'Important Information Before Booking',
    'Final labour is calculated from actual work minutes recorded by the server.',
    'Materials/parts are not included in labour;',
    'Only your selected tier will be assigned.',
    'The payment method will not change from Cash or Online',
    'Secure Payment with Razorpay',
    'Pay with Razorpay',
    'Electrician’s Current Location',
    'Booking Status History'
  ]) {
    assert.ok(booking.includes(translated), 'Missing English customer translation: ' + translated);
  }
});

test('customer dynamic status messages and confirmation dialogs support English translation', () => {
  for (const translated of [
    'GPS location is not available on this device.',
    'Loading payment records…',
    'No payment or refund records are available yet.',
    'Could not load refund status. Please try again.',
    'Work start is approved. The server timer has started.',
    'Would you like to change this booking from Cash to Online (Razorpay) payment?',
    'The cancellation request was sent to Admin.',
    'Saving booking…',
    'Payment was successful and verified.',
    'You closed the payment window. Payment has not been confirmed.',
    'The booking was not saved in the database.'
  ]) {
    assert.ok(booking.includes(translated), 'Missing dynamic customer translation: ' + translated);
  }
  assert.match(booking, /window\.confirm\s*=\s*message\s*=>\s*customerNativeConfirm\(customerUiText\(message\)\)/);
});

test('customer confirmation copy translates cancellation policy and dynamic booking summary labels', () => {
  assert.ok(booking.includes('Send a cancellation request to Admin?'));
  assert.ok(booking.includes(".replace(/श्रेणी:/g,'Tier: ')"));
  assert.ok(booking.includes(".replace(/अवधि:/g,'Duration: ')"));
  assert.ok(booking.includes(".replace(/भुगतान तरीका:/g,'Payment method: ')"));
  assert.ok(booking.includes(".replace(/\\bAdmin\\b/g,'Admin')"));
});

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
    const scripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)];
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


test('electrician live-location stop failures preserve a retryable Stop control', () => {
  const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
  const start = electrician.indexOf('async function stopElectricianLiveLocation(id)');
  const end = electrician.indexOf('\nfunction focusElectricianOfferFromNotification', start);
  assert.ok(start >= 0 && end > start);
  const stop = electrician.slice(start, end);
  assert.match(stop, /electricianLocationStopBusy\.has\(id\)/);
  assert.match(stop, /navigator\.geolocation\.clearWatch\(watch\)/);
  assert.match(stop, /srk_electrician_stop_live_location/);
  assert.match(stop, /if\(error\)throw error/);
  assert.match(stop, /locationWatches\.delete\(id\)/);
  assert.match(stop, /catch\(error\)[\s\S]*?Keep the cleared watch ID as a retry handle/);
  assert.match(electrician, /locationWatches\.has\(o\.booking_id\)\?'पहुँच गया — Location बंद करें'/);
});


test('customer booking lifecycle, refund and location feedback have English translations', () => {
  assert.match(booking, /'इलेक्ट्रिशियन रास्ते में है':'Electrician is on the way'/);
  assert.match(booking, /'काम पूरा होने की पुष्टि प्रतीक्षित':'Work completion awaiting confirmation'/);
  assert.match(booking, /'ग्राहक ने काम पूरा स्वीकार किया':'Customer accepted work completion'/);
  assert.match(booking, /'रिफंड अनुरोध अस्वीकृत':'Refund request rejected'/);
  assert.match(booking, /'Cancellation fee बकाया लोड हो रहा है…':'Loading cancellation fee dues…'/);
  assert.match(booking, /'GPS लोकेशन प्राप्त हो रही है…':'Getting GPS location…'/);
  assert.match(booking, /'Admin ने अनुरोध अस्वीकार किया':'Admin rejected the request'/);
});


test('electrician live-location update network exceptions trigger safe sharing shutdown', () => {
  const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
  const start = electrician.indexOf('async function startElectricianLiveLocation(id)');
  const end = electrician.indexOf('\nasync function stopElectricianLiveLocation(id)', start);
  assert.ok(start >= 0 && end > start);
  const live = electrician.slice(start, end);
  assert.match(live, /try\s*\{[\s\S]*?srk_electrician_update_live_location/);
  assert.match(live, /if\(r\.error\)throw r\.error/);
  assert.match(live, /catch\(error\)\s*\{\s*await stopElectricianLiveLocationAfterGpsFailure/);
  assert.match(live, /stopElectricianLiveLocationAfterGpsFailure/);
});


test('customer dynamically inserted controls translate placeholder, title and accessible labels', () => {
  assert.match(booking, /function customerUiTranslateAttributes\(root, lang = document\.documentElement\.lang\)/);
  assert.match(booking, /customerUiTranslateAttributes\(document\.body, lang\)/);
  assert.match(booking, /node\.nodeType === Node\.ELEMENT_NODE\) customerUiTranslateAttributes\(node, 'en'\)/);
  assert.match(booking, /input\[placeholder\],textarea\[placeholder\],\[title\],\[aria-label\]/);
});

test('customer remaining login, form and booking feedback strings are localized', () => {
  assert.match(booking, /'10 अंकों का मोबाइल नंबर':'10-digit mobile number'/);
  assert.match(booking, /'OTP दर्ज करें':'Enter OTP'/);
  assert.match(booking, /'ग्राहक मुख्य मेनू':'Customer main menu'/);
  assert.match(booking, /'बुकिंग लोकेशन का Google Map':'Booking location on Google Maps'/);
  assert.match(booking, /'ग्राहक लॉगिन सेटअप अभी उपलब्ध नहीं है। OTP लॉगिन सेवा ठीक होने तक बुकिंग नहीं की जा सकेगी।':'Customer login setup is unavailable\./);
  assert.match(booking, /'भुगतान सत्यापित नहीं हुआ।':'Payment could not be verified.'/);
  assert.match(booking, /'रसीद प्रिंट \/ PDF सेव करें':'Print receipt \/ Save PDF'/);
});


test('customer support status messages and concatenated status prefixes are localized', () => {
  assert.match(booking, /if \(prefix\) return customerUiTranslations\[prefix\] \+ customerUiText\(text\.slice\(prefix\.length\)\)/);
  assert.match(booking, /'अभी इस शिकायत में कोई संदेश नहीं है।':'There are no messages in this complaint yet.'/);
  assert.match(booking, /'शिकायत दर्ज हो रही है…':'Submitting complaint…'/);
  assert.match(booking, /'बातचीत लोड नहीं हो सकी। कृपया फिर कोशिश करें।':'Conversation could not be loaded\. Please try again\.'/);
  assert.match(booking, /'आपका संदेश सहायता टीम को भेज दिया गया है।':'Your message has been sent to the support team\.'/);
  assert.match(booking, /'शिकायत की स्थिति: ':'Complaint status: '/);
  assert.match(booking, /const translated = lang === 'en' \? customerUiText\(key\) : key/);
});

test('electrician booking refresh handles profile, offer and per-booking RPC failures safely', () => {
  const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
  const start = electrician.indexOf('async function refresh(){');
  const end = electrician.indexOf('\nasync function setElectricianAvailability', start);
  assert.ok(start >= 0 && end > start);
  const refresh = electrician.slice(start, end);
  assert.match(refresh, /try\{const result=await sb\.from\('electrician_profiles'\)/);
  assert.match(refresh, /प्रोफाइल लोड नहीं हो सकी। इंटरनेट जाँचकर Refresh करें।/);
  assert.match(refresh, /try\{const offerResult=await sb\.rpc\('srk_get_my_offer_details'\)/);
  assert.match(refresh, /काम के ऑफर लोड नहीं हो सके। इंटरनेट जाँचकर Refresh करें।/);
  assert.match(refresh, /try\{const r=await sb\.rpc\('srk_electrician_get_my_live_location_status'/);
  assert.match(refresh, /Keep the location control available for a manual retry/);
  assert.match(refresh, /srk_electrician_get_labour_bill/);
  assert.match(refresh, /Bill can be retried on the next refresh/);
});
