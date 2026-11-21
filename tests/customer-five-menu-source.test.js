const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');

const menu = [
  ['Home', 'customerTabHome', 'customerMenuHome'],
  ['Bookings', 'customerTabBookings', 'customerMenuBookings'],
  ['Payments', 'customerTabPayments', 'customerMenuPayments'],
  ['Support', 'customerTabSupport', 'customerMenuSupport'],
  ['Profile', 'customerTabProfile', 'customerMenuProfile']
];

test('customer dashboard exposes exactly the five required menu tabs and panels', () => {
  for (const [name, tabId, panelId] of menu) {
    assert.match(booking, new RegExp('id="' + tabId + '"[^>]*data-customer-menu="' + name + '"'));
    assert.match(booking, new RegExp('id="' + panelId + '"[^>]*role="tabpanel"'));
  }
  assert.equal((booking.match(/class="customer-menu-tab(?:\s|")/g) || []).length, 5);
  assert.equal((booking.match(/class="customer-menu-page"/g) || []).length, 5);
});

test('customer private dashboard is hidden until the authenticated session flow reveals it', () => {
  assert.match(booking, /id="customer-dashboard"[^>]*style="display:none"/);
  assert.match(booking, /customerSb\.auth\.getSession\(\)/);
  assert.match(booking, /customer-dashboard/);
  assert.match(booking, /customerSb\.auth\.onAuthStateChange/);
});

test('customer menu handlers use the expected server RPC contracts', () => {
  for (const rpc of [
    'srk_customer_get_payment_history',
    'srk_customer_list_booking_refund_requests',
    'srk_customer_list_booking_complaints',
    'srk_customer_list_booking_complaint_messages',
    'srk_customer_send_booking_complaint_message',
    'srk_customer_get_my_profile',
    'srk_customer_update_my_profile',
    'srk_customer_list_my_saved_addresses'
  ]) {
    assert.ok(booking.includes(".rpc('" + rpc + "'"), 'missing customer RPC caller: ' + rpc);
  }
});

test('customer profile and support private-storage contracts have matching source migrations and SQL tests', () => {
  const required = [
    'supabase/migrations/20261114201428_customer_profile_saved_addresses_private_storage.sql',
    'supabase/migrations/20261113220000_customer_support_conversation_schema.sql',
    'supabase/migrations/20261113230000_support_attachment_paths_and_admin_message_list.sql',
    'supabase/migrations/20261114202250_customer_complaint_customer_safe_projection.sql',
    'supabase/tests/database/customer_profile_saved_addresses_private_storage.test.sql',
    'supabase/tests/database/support_attachment_admin_message_access.test.sql',
    'supabase/tests/database/customer_complaint_customer_safe_projection.test.sql'
  ];
  for (const file of required) {
    assert.ok(fs.existsSync(path.join(root, file)), 'missing source contract: ' + file);
  }
});
