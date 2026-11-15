const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');

test('Admin booking editor does not expose legacy quote editing controls', () => {
  assert.match(admin, /ऐतिहासिक रिकॉर्ड केवल पढ़ने के लिए; Admin यहाँ Quote नहीं बदल सकता।/);
  assert.doesNotMatch(admin, /id="quote-status-/);
  assert.doesNotMatch(admin, /id="quote-amount-/);
});

test('Admin save handler does not read a removed amount input before secure booking checks', () => {
  const start = admin.indexOf('async function saveBookingInternal(id){');
  const end = admin.indexOf('\n}', start);
  assert.notEqual(start, -1, 'saveBookingInternal must exist');
  const handler = admin.slice(start, end === -1 ? undefined : end);
  assert.doesNotMatch(handler, /getElementById\(['"]amt-/);
  assert.match(handler, /srk_admin_confirm_legacy_booking/);
  assert.match(handler, /srk_admin_record_new_booking_cash_payment/);
  assert.match(handler, /srk_admin_record_manual_payment/);
});
