const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const sosMigration = fs.readFileSync(
  path.join(root, 'supabase/migrations/20261115260000_sos_admin_support_alerts.sql'),
  'utf8'
);

test('SOS queue is visible to Support Staff as well as Main Admin', () => {
  assert.match(admin, /<div class="card admin-shared hidden" id="sosAlertCard">/);
  const start = admin.indexOf('function setAdminPortalMode(');
  const end = admin.indexOf('\n}', start);
  assert.ok(start >= 0 && end > start, 'portal mode switch exists');
  const modeSwitch = admin.slice(start, end);
  assert.match(modeSwitch, /if\(staffOnly\)el\.classList\.toggle\('hidden',mode!=='staff'\)/);
  assert.match(modeSwitch, /const adminShared=el\.classList\.contains\('admin-shared'\)/);\n  assert.match(modeSwitch, /else if\(adminShared\)el\.classList\.toggle\('hidden',mode!=='staff'&&mode!=='main_admin'\)/);\n  assert.match(modeSwitch, /else el\.classList\.toggle\('hidden',mode!=='main_admin'\)/);
});

test('Support role is granted SOS read and acknowledgement permissions', () => {
  assert.match(sosMigration, /\('support','support\.sos\.read'\)/);
  assert.match(sosMigration, /\('support','support\.sos\.acknowledge'\)/);
  assert.match(admin, /await Promise\.all\(\[loadStaffSupportInbox\(\),loadSosAlerts\(\)\]\)/);
});
