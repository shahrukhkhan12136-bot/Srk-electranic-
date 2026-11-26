const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'apps/customer_app/lib/main.dart'), 'utf8');
const picker = fs.readFileSync(path.join(root, 'apps/customer_app/lib/service_category_picker.dart'), 'utf8');
const dispatch = fs.readFileSync(path.join(root, 'supabase/migrations/20261125154000_apply_district_rates_to_bookings_and_commission_snapshot.sql'), 'utf8');

test('Customer dashboard exposes all six exact active catalogue category codes', () => {
  for (const code of [
    'electrician', 'plumber', 'painter', 'ac_fridge_technician',
    'motor_pump_technician', 'cooler_technician'
  ]) assert.ok(customer.includes("code: '" + code + "'"), 'missing dashboard category ' + code);
});

test('Customer booking picker order is category, qualification, service, then work skill', () => {
  const category = picker.indexOf("Text('सेवा की कैटेगरी'");
  const level = picker.indexOf("Text('इस कैटेगरी में किस स्तर का काम चाहिए?'");
  const service = picker.indexOf("labelText: 'काम की सर्विस चुनें'");
  const skill = picker.indexOf("Text('इस काम में कौन-कौन से काम आते हैं?'");
  assert.ok(category >= 0 && level > category && service > level && skill > service);
});

test('Customer booking supports 1 hour through 60 days and separate Technician/Helper counts', () => {
  assert.match(customer, /List\.generate\(60, \(i\) => i \+ 1\)/);
  assert.match(customer, /days \* 24/);
  assert.match(customer, /कितने Technician चाहिए/);
  assert.match(customer, /कितने Helper चाहिए/);
  assert.match(customer, /p_technician_count/);
  assert.match(customer, /p_helper_count/);
  assert.match(picker, /helperAvailable: unit == 'hour' && configuredHelperRate > 0/);
});

test('GPS reverse geocoding attempts to fill State, District and PIN before price preview', () => {
  assert.match(customer, /Geocoding\(\)\.placemarkFromCoordinates/);
  assert.match(customer, /_state\.text = stateName/);
  assert.match(customer, /_district\.text = districtName/);
  assert.match(customer, /_pincode\.text = pin/);
  assert.match(customer, /पहले राज्य, जिला, 6 अंकों का PIN Code और पूरा पता भरें/);
});

test('Booking price preview and creation use the district-aware server RPCs', () => {
  assert.match(customer, /srk_customer_preview_booking_price_v3/);
  assert.match(customer, /srk_customer_create_booking_v2/);
  assert.match(dispatch, /create or replace function public\.srk_customer_create_booking_v2/);
  assert.match(dispatch, /create or replace function public\.srk_customer_preview_booking_price_v3/);
});

test('Booking matching is dispatched immediately after the district rate snapshot is stored', () => {
  const snapshot = dispatch.indexOf("where id=v_booking.id returning * into v_booking;");
  const immediate = dispatch.indexOf('perform public.srk_process_booking_matching_queue();', snapshot);
  const returnBooking = dispatch.indexOf('return v_booking;', snapshot);
  assert.ok(snapshot >= 0 && immediate > snapshot && returnBooking > immediate);
});

test('Changing any price input invalidates in-flight and displayed customer estimates', () => {
  assert.match(customer, /void _invalidatePricePreview\(\)\s*\{\s*\+\+_previewRequest;/);
  assert.ok((customer.match(/_invalidatePricePreview\(\);/g) || []).length >= 5,
    'category, worker counts, duration, and unit changes must invalidate the preview');
  assert.match(customer, /setState\(_invalidatePricePreview\)/,
    'manual location edits must invalidate in-flight price previews');
});
test('Customer price preview separates service charge from any previous cancellation-fee balance', () => {
  const previewStart = customer.indexOf("Text('अनुमानित सर्विस चार्ज'");
  const previewEnd = customer.indexOf("Text((_pricePreview!['price_note']", previewStart);
  const preview = customer.slice(previewStart, previewEnd);
  assert.match(preview, /estimated_base_total/);
  assert.match(preview, /pending_cancellation_fee_amount/);
  assert.match(preview, /पिछली बुकिंग का बकाया रद्दीकरण शुल्क/);
  assert.match(preview, /estimated_customer_total/);
  assert.match(preview, /कुल अनुमानित देय राशि/);
  assert.doesNotMatch(preview, /estimated_company_commission|estimated_worker_net/);
});
test('Changing saved customer language rebuilds the full dashboard and unregisters its listener', () => {
  assert.match(customer, /customerLanguage\.addListener\(_handleCustomerLanguageChanged\)/);
  assert.match(customer, /void _handleCustomerLanguageChanged\(\)\s*\{\s*if \(mounted\) setState\(\(\) \{\}\);/);
  assert.match(customer, /customerLanguage\.removeListener\(_handleCustomerLanguageChanged\)/);
  assert.match(customer, /await _client\.auth\.updateUser\(UserAttributes\(data: \{'customer_language': value\}\)\)/);
});
test('Customer settings do not imply notification controls exist when none are implemented', () => {
  assert.match(customer, /सूचनाओं की अनुमति बदलने का विकल्प अभी ऐप में उपलब्ध नहीं है/);
  assert.match(customer, /Notification permission controls are not available inside the app yet/);
});
test('Customer booking form fixed interface labels are Hindi and do not leak English price notes', () => {
  const bookingStart = customer.indexOf('class CustomerBookingFormPage');
  const booking = customer.slice(bookingStart);
  for (const phrase of [
    'ओटीपी-सत्यापित मोबाइल खाते',
    'कितने टेक्नीशियन चाहिए?',
    'कितने सहायक चाहिए?',
    '6 अंकों का पिन कोड',
    'जीपीएस से वर्तमान लोकेशन जोड़ें',
    'जिला ${_district.text.trim()} की स्वीकृत दर के अनुसार',
  ]) assert.ok(booking.includes(phrase), 'missing Hindi booking label: ' + phrase);
  assert.doesNotMatch(booking, /OTP-verified|PIN Code|GPS coordinates|price_note|qualified Technician/);
});
