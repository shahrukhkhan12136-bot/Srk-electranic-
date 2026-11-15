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
