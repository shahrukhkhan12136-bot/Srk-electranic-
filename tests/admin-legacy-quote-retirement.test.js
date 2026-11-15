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
  assert.match(admin, /पुराना Quote:<\/strong> \$\{esc\(x\.quote_status\|\|'—'\)\}/);
  assert.match(admin, /ऐतिहासिक रिकॉर्ड केवल पढ़ने के लिए; Admin यहाँ Quote नहीं बदल सकता/);
  assert.doesNotMatch(admin, /quote_status[^\n]{0,250}(?:<select|<input|onclick)/i);
});

test('Admin status confirmation remains guarded by the dedicated Main-Admin RPC', () => {
  assert.match(admin, /booking\.status==='new'&&status==='confirmed'/);
  assert.match(admin, /srk_admin_confirm_legacy_booking/);
  assert.doesNotMatch(admin, /\.from\(['"]service_bookings['"]\)\.update\(/);
});
