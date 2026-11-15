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
