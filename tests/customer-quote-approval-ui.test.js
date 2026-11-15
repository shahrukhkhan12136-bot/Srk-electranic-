const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const booking = fs.readFileSync(path.join(__dirname, '..', 'booking.html'), 'utf8');

test('customer can review separate labour and materials quote before responding', () => {
  assert.match(booking, /quote_status==='pending'&&row\.status==='awaiting_quote_approval'/);
  assert.match(booking, /formatCustomerMoney\(row\.service_charge\)/);
  assert.match(booking, /formatCustomerMoney\(row\.materials_amount\)/);
  assert.match(booking, /formatCustomerMoney\(row\.quoted_amount\)/);
  assert.match(booking, /मेहनताना और सामान अलग-अलग हैं/);
});

test('customer quote approval and rejection use the authenticated owner-scoped RPC contract', () => {
  assert.match(booking, /customerSb\.rpc\('srk_customer_respond_booking_quote',\{p_booking_id:bookingId,p_response:response\}\)/);
  assert.match(booking, /customerRespondBookingQuote\('\\+customerEsc\(row\.id\)\+'\\,'approved'\)/);
  assert.match(booking, /customerRespondBookingQuote\('\\+customerEsc\(row\.id\)\+'\\,'rejected'\)/);
  assert.match(booking, /await loadCustomerBookings\(\)/);
});
