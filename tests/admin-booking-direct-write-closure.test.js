const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115230000_admin_booking_direct_write_closure.sql'), 'utf8');

test('Admin booking location uses dedicated RPC; historical quotes are read-only and no direct table writes exist', () => {
  assert.match(admin, /srk_admin_update_booking_customer_location/);
  assert.doesNotMatch(admin, /srk_admin_update_legacy_booking_quote/);
  assert.doesNotMatch(admin, /id="amt-/);
  assert.match(admin, /ऐतिहासिक रिकॉर्ड केवल पढ़ने के लिए/);
  assert.doesNotMatch(admin, /\.from\(['"]service_bookings['"]\)\s*\.update\s*\(/);
});

test('location RPC is Main-Admin-only, row-locked, validated and records before/after audit evidence', () => {
  const start = migration.indexOf('function public.srk_admin_update_booking_customer_location');
  const end = migration.indexOf('$function$;', start);
  const fn = migration.slice(start, end);
  assert.match(fn, /auth\.uid\(\) is null or not public\.is_srk_admin\(\)/);
  assert.match(fn, /for update/i);
  assert.match(fn, /INVALID_CUSTOMER_LOCATION/);
  assert.match(fn, /insert into public\.srk_admin_audit_events/i);
  assert.match(fn, /before_data,after_data/i);
  assert.match(migration, /revoke all on function public\.srk_admin_update_booking_customer_location\(uuid,text,text,text,text\) from public,anon/i);
});

test('legacy quote mutation RPC remains guarded for compatibility but is no longer exposed by Admin UI', () => {
  const start = migration.indexOf('function public.srk_admin_update_legacy_booking_quote');
  const end = migration.indexOf('$function$;', start);
  const fn = migration.slice(start, end);
  assert.match(fn, /auth\.uid\(\) is null or not public\.is_srk_admin\(\)/);
  assert.match(fn, /for update/i);
  assert.match(fn, /NEW_CATEGORY_BOOKING_USES_SERVER_WORKFLOW/);
  assert.match(fn, /PAID_OR_ONLINE_BOOKING_QUOTE_IS_LOCKED/);
  assert.match(fn, /CUSTOMER_APPROVED_QUOTE_IS_IMMUTABLE/);
  assert.match(fn, /QUOTE_MUST_MATCH_LABOUR_PLUS_MATERIALS/);
  assert.match(migration, /revoke update on table public\.service_bookings from authenticated/i);
  assert.match(migration, /revoke update \(status,quoted_amount,amount_paid,payment_status,address,district,state,pincode\)/i);
});
