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
  assert.match(block, /profileSaveError=profileSaveResult\?\.error\|\|\(/);
  assert.match(block, /catch\(saveError\)\{if\(!await stillSameUser\(\)\)return;profileSaveError=saveError;\}/);
  assert.match(block, /srk_customer_get_my_profile/);
  assert.match(block, /lookupSucceeded&&latestProfile\?\.avatar_path===avatarPath/);
  assert.match(block, /if\(lookupSucceeded&&file&&avatarPath!==customerCurrentAvatarPath\)\{await customerSb\.storage\.from\('srk-customer-avatars'\)\.remove\(\[avatarPath\]\)\.catch\(\(\)=>\{\}\);/);
  assert.doesNotMatch(block, /if\(error\)\s*\{\s*if\(file[\s\S]*?remove\(\[avatarPath\]\)/);
});

test('Customer saved-address writes reconcile uncertain RPC outcomes before allowing another save', () => {
  const start = source.indexOf('async function saveCurrentBookingAddress() {');
  const end = source.indexOf('function editSelectedSavedAddress()', start);
  assert.ok(start >= 0 && end > start, 'saved-address handler exists');
  const handler = source.slice(start, end);
  assert.match(handler, /srk_customer_save_my_address/);
  assert.match(handler, /srk_customer_list_my_saved_addresses/);
  assert.match(handler, /const matches=latestAddresses\.filter/);
  assert.match(handler, /const normalizedText=value=>String/);
  assert.match(handler, /normalizedText.*recipient_name.*payload/);
  assert.match(handler, /normalizedText.*address_line.*payload/);
  assert.match(handler, /normalizedText.*district.*payload/);
  assert.match(handler, /normalizedText.*state.*payload/);
  assert.match(handler, /normalizedText.*landmark.*null/);
  assert.match(handler, /matches\.length===1\?matches\[0\]:null/);
  assert.match(handler, /editingId\?latestAddresses\.find/);
  assert.match(handler, /अभी वही अनुरोध दोबारा न भेजें/);
  assert.match(handler, /if\(savedMatch\)\{savedId=savedMatch\.id;\}/);
});

test('Customer default-address updates reconcile uncertain RPC responses against the authoritative list', () => {
  const start = source.indexOf('async function makeSelectedAddressDefault() {');
  const end = source.indexOf('let customerSupportComplaints', start);
  assert.ok(start >= 0 && end > start, 'default-address handler exists');
  const handler = source.slice(start, end);
  assert.match(handler, /srk_customer_save_my_address/);
  assert.match(handler, /returnedId!==id/);
  assert.match(handler, /srk_customer_list_my_saved_addresses/);
  assert.match(handler, /row\.id===id&&row\.is_default===true/);
  assert.match(handler, /अभी अनुरोध दोबारा न भेजें/);
});

test('Customer uncertain saved-address deletion refreshes the cached list and selector from server state', () => {
  const start = source.indexOf('async function deleteSelectedSavedAddress() {');
  const end = source.indexOf('async function makeSelectedAddressDefault()', start);
  assert.ok(start >= 0 && end > start, 'saved-address delete handler exists');
  const handler = source.slice(start, end);
  assert.match(handler, /srk_customer_list_my_saved_addresses/);
  assert.match(handler, /customerSavedAddresses=latestAddresses/);
  assert.match(handler, /select\.innerHTML=.*latestAddresses\.map/);
  assert.match(handler, /select\.value=deleteState==='absent'\?''\:id/);
  assert.match(handler, /सूची सर्वर से अपडेट कर दी गई है/);
});

test('Customer saved-address list refresh ignores stale session and RPC responses', () => {
  const start = source.indexOf('async function loadCustomerSavedAddresses() {');
  const end = source.indexOf('function applySelectedSavedAddress()', start);
  assert.ok(start >= 0 && end > start, 'saved-address list loader exists');
  const loader = source.slice(start, end);
  assert.match(source, /let customerSavedAddressLoadRequest=0/);
  assert.match(loader, /const requestId=\+\+customerSavedAddressLoadRequest/);
  assert.match(loader, /if\(!isCurrent\(\)\)return false/);
  assert.match(loader, /finally\s*\{\s*if\(isCurrent\(\)\)select\.disabled=false;\s*\}/);
});
