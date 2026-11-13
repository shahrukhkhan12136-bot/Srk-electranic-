const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const html = fs.readFileSync('booking.html', 'utf8');

test('customer menu keeps the approved five-menu order and accessible tab controls', () => {
  const nav = html.match(/<nav class="customer-menu-nav"[\s\S]*?<\/nav>/)?.[0] || '';
  const names = [...nav.matchAll(/data-customer-menu="([^"]+)"/g)].map(match => match[1]);
  assert.deepEqual(names, ['Home', 'Bookings', 'Payments', 'Support', 'Profile']);
  assert.match(nav, /aria-label="ग्राहक मुख्य मेनू"/);
  assert.match(nav, /role="tablist"/);
  assert.equal((nav.match(/role="tab"/g) || []).length, 5);
});

test('each customer menu has exactly one matching tab panel', () => {
  for (const key of ['Home', 'Bookings', 'Payments', 'Support', 'Profile']) {
    assert.equal((html.match(new RegExp('id="customerMenu' + key + '"', 'g')) || []).length, 1);
    assert.equal((html.match(new RegExp('data-customer-menu="' + key + '"', 'g')) || []).length, 1);
  }
  assert.match(html, /function activate\(name,focus=false\)/);
  assert.match(html, /panel\.hidden=key!==name/);
  assert.match(html, /event\.key==='ArrowRight'/);
  assert.match(html, /event\.key==='ArrowLeft'/);
});

test('support and profile functions are mounted inside their respective menu panels', () => {
  assert.match(html, /Support:document\.getElementById\('customerSupportPanel'\)/);
  assert.match(html, /Profile:document\.getElementById\('customerProfilePanel'\)/);
  assert.match(html, /target\.appendChild\(node\)/);
  assert.match(html, /customerSupportCreate.*createCustomerSupportComplaint/s);
  assert.match(html, /customerSupportSend.*sendCustomerSupportMessage/s);
  assert.match(html, /saveCustomerProfile.*saveCustomerProfile/s);
});

test('customer menu actions lead to the existing booking and saved-address controls', () => {
  assert.match(html, /customerHomeBookNow[\s\S]*?getElementById\('booking'\)[\s\S]*?scrollIntoView/);
  assert.match(html, /customerProfileAddressLink[\s\S]*?getElementById\('savedAddressSelect'\)[\s\S]*?focus/);
  assert.match(html, /customerRefresh[\s\S]*?loadCustomerBookings/);
  assert.match(html, /customerPaymentHistoryRefresh[\s\S]*?loadCustomerPaymentHistory\(true\)/);
  assert.match(html, /customerSupportRefresh[\s\S]*?loadCustomerSupportBookings/);
});

test('customer payment menu only reads verified history and receipt through customer RPCs', () => {
  assert.match(html, /srk_customer_get_payment_history/);
  assert.match(html, /srk_customer_get_payment_receipt/);
  assert.match(html, /data\.document_type!=='payment_receipt'/);
  assert.match(html, /यह टैक्स इनवॉइस नहीं है/);
});


test('support booking selector is populated from only the signed-in customer bookings', () => {
  assert.match(html, /async function loadCustomerSupportBookings\(\)/);
  assert.match(html, /\.eq\('customer_user_id',session\.user\.id\)/);
  assert.match(html, /customerSupportBooking/);
  assert.match(html, /\.limit\(50\)/);
});

test('new customer complaint is validated and created through the ownership-checking RPC', () => {
  assert.match(html, /async function createCustomerSupportComplaint\(\)/);
  assert.match(html, /customerSupportComplaintCreateBusy/);
  assert.match(html, /description\.length<20\|\|description\.length>2000/);
  assert.match(html, /srk_customer_create_booking_complaint/);
  assert.match(html, /p_booking_id:bookingId,p_category:category,p_description:description/);
  assert.match(html, /COMPLAINT_DAILY_LIMIT_REACHED/);
  assert.match(html, /await loadCustomerSupportComplaints\(\)/);
  assert.match(html, /await loadCustomerSupportMessages\(\)/);
});
