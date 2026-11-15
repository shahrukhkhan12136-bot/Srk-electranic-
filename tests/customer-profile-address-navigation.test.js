const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'booking.html'), 'utf8');

test('Profile saved-address shortcut reveals Home tab before scrolling to the booking form', () => {
  const match = source.match(/document\\.getElementById\\('customerProfileAddressLink'\\)\\?\\.addEventListener\\('click',\\(\\)=>\\{([\\s\\S]*?)\\n \\}\\);/);
  assert.ok(match, 'profile saved-address click handler exists');
  const handler = match[1];
  const activateHome = handler.indexOf("activate('Home')");
  const scheduleScroll = handler.indexOf('requestAnimationFrame');
  const scrollBooking = handler.indexOf("getElementById('booking')?.scrollIntoView");
  const focusAddress = handler.indexOf("getElementById('savedAddressSelect')?.focus");
  assert.ok(activateHome >= 0 && scheduleScroll > activateHome, 'Home tab is revealed before deferred navigation');
  assert.ok(scrollBooking > scheduleScroll && focusAddress > scrollBooking, 'booking form and saved-address selector are focused after Home is visible');
});
