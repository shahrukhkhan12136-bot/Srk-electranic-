const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const html = fs.readFileSync(path.join(__dirname, "..", "booking.html"), "utf8");

test("Customer form generates a UUID v4 idempotency key", () => {
  assert.match(html, /function customerBookingRequestKey\(payload\)/);
  assert.match(html, /bytes\[6\]=\(bytes\[6\]&0x0f\)\|0x40/);
  assert.match(html, /bytes\[8\]=\(bytes\[8\]&0x3f\)\|0x80/);
});

test("Customer form persists the pending key across retries in session storage", () => {
  assert.match(html, /srk\.customer\.booking\.pending\.v1/);
  assert.match(html, /saved\.fingerprint===fingerprint/);
  assert.match(html, /sessionStorage\.setItem\(storageKey/);
});

test("Changed booking details generate a new key and successful submit clears only its own key", () => {
  assert.match(html, /saved\.fingerprint===fingerprint/);
  assert.match(html, /function clearCustomerBookingRequestKey\(key\)/);
  assert.match(html, /if\(saved\?\.key===key\)sessionStorage\.removeItem/);
});

test("Booking API receives the idempotency key and reuses it with the same payload", () => {
  assert.match(html, /bookingHeaders\['Idempotency-Key'\] = requestKey/);
  assert.match(html, /body: JSON\.stringify\(bookingPayload\)/);
});

test("Successful booking preserves its ID for the next online payment step", () => {
  assert.match(html, /pendingBookingId = result\.booking_id/);
});


test("Customer form fails closed if the pending idempotency key cannot be persisted", () => {
  assert.match(html, /sessionStorage\.setItem\(storageKey/);
  assert.match(html, /const persisted=JSON\.parse\(sessionStorage\.getItem\(storageKey\)\|\|'null'\)/);
  assert.match(html, /persisted\.key!==key\|\|persisted\.fingerprint!==fingerprint/);
  assert.match(html, /इस ब्राउज़र में सुरक्षित बुकिंग पहचान सेव नहीं हो सकी/);
});


test("Editing a saved address restores its saved map pin", () => {
  assert.match(html, /function editSelectedSavedAddress\(\)/);
  assert.match(html, /सेव किए गए पते की लोकेशन लोड हुई। पता बदलने पर लोकेशन दोबारा चुनें।/);
  assert.match(html, /customerMapLink'\)\.href=googleMapsUrl\(a\.location_lat,a\.location_lng,''\)/);
});

test("Manual address edits invalidate stale saved GPS coordinates", () => {
  assert.match(html, /function invalidateCustomerAddressLocation\(\)/);
  assert.match(html, /\['address','district','state','pin'\]\.forEach/);
  assert.match(html, /lat\.value='';lng\.value='';/);
  assert.match(html, /पते में बदलाव हुआ है। सही लोकेशन के लिए GPS लोकेशन दोबारा चुनें।/);
});
