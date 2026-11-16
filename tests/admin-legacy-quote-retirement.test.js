const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const admin = fs.readFileSync(path.join(__dirname, '..', 'admin.html'), 'utf8');

test('Admin booking table exposes status confirmation only for unassigned legacy new bookings', () => {
  assert.match(admin, /!x\.selected_category&&x\.status==='new'&&!x\.assigned_electrician_id/);
  assert.match(admin, /केवल पुरानी नई बुकिंग को Confirm करें/);
  assert.match(admin, /स्थिति: '\+esc\(x\.status\)/);
  assert.doesNotMatch(admin, /\['new','confirmed','assigned','in_progress','completed'\]\.map\(s=>/);
});

test('Admin keeps historical quote fields display-only and does not expose quote editing controls', () => {
  const quoteCellStart = admin.indexOf('<strong>पुराना Quote:</strong>');
  const quoteCellEnd = admin.indexOf('</td>', quoteCellStart);
  assert.notEqual(quoteCellStart, -1, 'historical quote cell must exist');
  assert.notEqual(quoteCellEnd, -1, 'historical quote cell must be bounded');
  const quoteCell = admin.slice(quoteCellStart, quoteCellEnd);
  assert.match(quoteCell, /ऐतिहासिक रिकॉर्ड केवल पढ़ने के लिए/);
  assert.doesNotMatch(quoteCell, /<(?:input|select|button)\b|onclick=/i);
});

test('Admin status confirmation remains guarded by the dedicated Main-Admin RPC', () => {
  assert.match(admin, /booking\.status==='new'&&status==='confirmed'/);
  assert.match(admin, /srk_admin_confirm_legacy_booking/);
  assert.doesNotMatch(admin, /\.from\(['"]service_bookings['"]\)\.update\(/);
});



test('Read-only status display preserves the current value for the shared Save handler', () => {
  assert.ok(
    admin.includes(`<input type="hidden" id="st-'+x.id+'" value="'+esc(x.status)+'"><span class="tag">स्थिति: '+esc(x.status)`),
    'non-editable status cell must retain its current status for Save'
  );
  const start = admin.indexOf('async function saveBookingInternal(id){');
  const end = admin.indexOf('\n}', start);
  assert.notEqual(start, -1, 'saveBookingInternal must exist');
  const handler = admin.slice(start, end === -1 ? undefined : end);
  assert.match(handler, /if\(status!==booking\.status&&!\( !booking\.selected_category&&booking\.status==='new'&&status==='confirmed'\)\)/);
  assert.match(handler, /srk_admin_confirm_legacy_booking/);
});

test('Manual payment UI remains available without exposing arbitrary status transitions', () => {
  assert.ok(admin.includes('id="pay-${x.id}"'));
  assert.ok(admin.includes('id="manual-method-${x.id}"'));
  assert.ok(admin.includes('id="ref-${x.id}"'));
  assert.match(admin, /payment_status!==\(booking\.payment_status\|\|'unpaid'\)/);
  assert.match(admin, /srk_admin_record_manual_payment/);
  assert.match(admin, /srk_admin_record_new_booking_cash_payment/);
  assert.doesNotMatch(admin, /\.from\(['"]service_bookings['"]\)\s*\.update\s*\(/);
});


test('Admin manual payment handler enforces booking, receipt, and Razorpay guards', () => {
  const start = admin.indexOf('async function saveBookingInternal(id){');
  const end = admin.indexOf('\n}', start);
  assert.notEqual(start, -1, 'saveBookingInternal must exist');
  const handler = admin.slice(start, end === -1 ? undefined : end);
  assert.match(handler, /booking\.payment_status==='paid'&&payment_status!=='paid'/);
  assert.match(handler, /payment_reference\.length<4\|\|payment_reference\.length>120/);
  assert.match(handler, /booking\.status!=='completed'\|\|status!=='completed'/);
  assert.match(handler, /razorpay_payment_id\|\|booking\.razorpay_order_id/);
  assert.match(handler, /manual_method!=='cash'/);
  assert.match(handler, /srk_admin_record_new_booking_cash_payment/);
  assert.match(handler, /srk_admin_record_manual_payment/);
  assert.doesNotMatch(handler, /\.from\(['"]service_bookings['"]\)\s*\.update\s*\(/);
});
