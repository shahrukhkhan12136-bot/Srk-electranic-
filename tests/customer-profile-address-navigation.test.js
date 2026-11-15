const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'booking.html'), 'utf8');

test('Profile saved-address shortcut reveals Home tab before scrolling to the booking form', () => {
  const marker = "document.getElementById('customerProfileAddressLink')?.addEventListener('click',()=>{";
  const start = source.indexOf(marker);
  assert.ok(start >= 0, 'profile saved-address click handler exists');
  const end = source.indexOf('\n });', start);
  assert.ok(end > start, 'profile saved-address click handler closes');
  const handler = source.slice(start + marker.length, end);
  const activateHome = handler.indexOf("activate('Home')");
  const scheduleScroll = handler.indexOf('requestAnimationFrame');
  const scrollBooking = handler.indexOf("getElementById('booking')?.scrollIntoView");
  const focusAddress = handler.indexOf("getElementById('savedAddressSelect')?.focus");
  assert.ok(activateHome >= 0 && scheduleScroll > activateHome, 'Home tab is revealed before deferred navigation');
  assert.ok(scrollBooking > scheduleScroll && focusAddress > scrollBooking, 'booking form and saved-address selector are focused after Home is visible');
});

test('Customer avatar save reconciles returned and thrown RPC errors before deleting uploaded storage', () => {
  const start = source.indexOf('let profileSaveResult=null,profileSaveError=null;');
  const end = source.indexOf('const oldAvatar=customerCurrentAvatarPath;', start);
  assert.ok(start >= 0 && end > start, 'profile save reconciliation block exists');
  const block = source.slice(start, end);
  assert.match(block, /profileSaveError=profileSaveResult\?\.error\|\|null/);
  assert.match(block, /catch\(saveError\)\{profileSaveError=saveError;\}/);
  assert.match(block, /srk_customer_get_my_profile/);
  assert.match(block, /lookupSucceeded&&latestProfile\?\.avatar_path===avatarPath/);
  assert.match(block, /if\(lookupSucceeded&&file&&avatarPath!==customerCurrentAvatarPath\)/);
  assert.match(block, /If the read failed, leave the object in place/);
  assert.doesNotMatch(block, /if\(error\)\s*\{\s*if\(file[\s\S]*?remove\(\[avatarPath\]\)/);
});
