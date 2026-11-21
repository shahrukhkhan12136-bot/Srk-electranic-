const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261121260000_master_cash_commission_due_and_online_offset.sql'), 'utf8');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');

test('Main Admin can read a scoped SRK cash commission due report', () => {
  const i=migration.indexOf('CREATE OR REPLACE FUNCTION public.srk_admin_list_master_commission_dues()');
  assert.notEqual(i,-1);
  const sql=migration.slice(i);
  assert.match(sql,/auth\.uid\(\) IS NULL OR NOT public\.is_srk_admin\(\)/);
  assert.match(sql,/'outstanding_paise'/);
  assert.match(sql,/'recovered_paise'/);
  assert.match(sql,/'technicians'/);
  assert.match(sql,/'dues'/);
  assert.match(sql,/REVOKE ALL ON FUNCTION public\.srk_admin_list_master_commission_dues\(\) FROM PUBLIC,anon/);
  assert.match(sql,/GRANT EXECUTE ON FUNCTION public\.srk_admin_list_master_commission_dues\(\) TO authenticated/);
  assert.doesNotMatch(sql,/\b(INSERT INTO|UPDATE public\.|DELETE FROM)\b/i);
});

test('Admin Panel displays outstanding 15 percent commission by Technician and booking', () => {
  assert.match(admin,/srk_admin_list_master_commission_dues/);
  assert.match(admin,/Master Cash Commission — SRK का 15% बकाया/);
  assert.match(admin,/Technician के अनुसार बकाया/);
  assert.match(admin,/Booking-wise कमीशन हिस्ट्री/);
  assert.match(admin,/loadMasterCommissionDues\(\)/);
  assert.match(admin,/रिपोर्ट केवल read-only है/);
});
