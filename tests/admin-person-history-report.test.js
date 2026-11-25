const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261125150000_admin_person_history_and_category_skill_counts.sql'), 'utf8');
const districtMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261125152000_india_district_directory_and_rate_admin.sql'), 'utf8');
const bookingMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261125154000_apply_district_rates_to_bookings_and_commission_snapshot.sql'), 'utf8');
const historyMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20261125155000_district_rate_history_admin_rpc.sql'), 'utf8');
const customerApp = fs.readFileSync(path.join(root, 'apps/customer_app/lib/main.dart'), 'utf8');

test('Admin exposes six-category skill counts and loads them after login', () => {
  assert.match(admin, /adminCategorySkillCountsCard/);
  assert.match(admin, /srk_admin_get_category_skill_counts_v2/);
  assert.match(admin, /openAdminCategorySkillWorkers/);
  assert.match(admin, /srk_admin_list_category_skill_workers/);
  assert.match(migration, /cross join \(values \('technician'::text\),\('helper'::text\)\)/);
  assert.match(admin, /async function loadAll\(\)\{await loadAdminCategorySkillCounts\(\);/);
  for (const status of ['pending_skill_holders', 'approved_skill_holders', 'active_skill_holders', 'currently_working']) {
    assert.match(migration, new RegExp(status));
  }
});

test('Admin person history supports all four permanent ID types and date windows', () => {
  assert.match(admin, /adminUniversalPersonHistoryCard/);
  assert.match(admin, /adminPersonHistoryId/);
  assert.match(admin, /setAdminHistoryDays\(1\)/);
  assert.match(admin, /setAdminHistoryDays\(2\)/);
  assert.match(admin, /setAdminHistoryDays\(10\)/);
  assert.match(admin, /adminPersonHistoryPdfButton/);
  assert.match(admin, /srk_admin_get_person_history/);
  assert.match(migration, /worker_code/);
  assert.match(migration, /customer_code/);
  assert.match(migration, /staff_code/);
  assert.match(migration, /srk_staff_profiles/);
  assert.match(migration, /srk_worker_documents/);
  assert.match(migration, /srk_staff_documents/);
  assert.match(migration, /improvement_areas/);
  assert.match(migration, /'helper'/);
  assert.match(migration, /'technician'/);
});

test('Sensitive history access is Main-Admin checked and audited in a private schema', () => {
  assert.match(migration, /srk_private\.get_admin_person_history/);
  assert.match(migration, /auth\.uid\(\) is null or not public\.is_srk_admin\(\)/);
  assert.match(migration, /admin_person_history_access_log/);
  assert.match(migration, /alter table srk_private\.admin_person_history_access_log enable row level security/i);
  assert.match(migration, /security invoker/i);
  assert.match(migration, /revoke all on function public\.srk_admin_get_person_history/i);
});

test('Admin inline JavaScript parses without executing browser actions', () => {
  const inlineScripts = [...admin.matchAll(/<script>([\s\S]*?)<\/script>/gi)];
  assert.ok(inlineScripts.length > 0, 'expected an inline Admin script');
  assert.doesNotThrow(() => new Function(inlineScripts.at(-1)[1]));
});

test('Admin district directory and rate management require LGD snapshot and audited changes', () => {
  assert.match(admin, /adminDistrictPricingCard/);
  assert.match(admin, /india-lgd-index-api\.vercel\.app\/v1\/districts/);
  assert.match(admin, /srk_admin_sync_lgd_districts/);
  assert.match(admin, /srk_admin_list_india_districts/);
  assert.match(admin, /srk_admin_list_district_rate_matrix/);
  assert.match(admin, /srk_admin_save_district_rate_override/);
  assert.match(migration, /jsonb_array_length\(p_districts\) < 700/);
  assert.match(migration, /srk_district_service_rate_overrides/);
  assert.match(migration, /admin_district_rate_audit_log/);
  assert.match(migration, /effective_to=clock_timestamp\(\)/);
  assert.match(migration, /length\(btrim\(coalesce\(p_change_reason,''\)\)\)<10/);
});

test('District rates are snapshotted into bookings and drive customer pricing and worker rates', () => {
  assert.match(bookingMigration, /district_rate_snapshot jsonb/i);
  assert.match(bookingMigration, /company_commission_rate/);
  assert.match(bookingMigration, /create_booking_with_district_rates/);
  assert.match(bookingMigration, /preview_booking_price_with_district/);
  assert.match(bookingMigration, /get_district_worker_hourly_rate/);
  assert.match(bookingMigration, /get_district_fixed_service_amount/);
  assert.match(bookingMigration, /srk_process_booking_matching_queue/);
  assert.match(bookingMigration, /srk_admin_finalize_booking_bill/);
  assert.match(customerApp, /srk_customer_preview_booking_price_v3/);
  assert.match(customerApp, /srk_customer_create_booking_v2/);
  assert.match(customerApp, /'p_state': _state\.text\.trim\(\)/);
  assert.match(customerApp, /'p_district': _district\.text\.trim\(\)/);
});

test('District rate changes retain a readable Main-Admin audit history', () => {
  assert.match(historyMigration, /admin_list_district_rate_history/);
  assert.match(historyMigration, /srk_private\.admin_district_rate_audit_log/);
  assert.match(admin, /adminDistrictRateHistoryRows/);
  assert.match(admin, /srk_admin_list_district_rate_history/);
  assert.match(districtMigration, /effective_to=clock_timestamp\(\)/);
});

test('Category worker drilldown returns zero-safe counts and profile detail fields', () => {
  const drilldown = fs.readFileSync(path.join(root, 'supabase/migrations/20261125160000_admin_category_skill_worker_drilldown.sql'), 'utf8');
  assert.match(drilldown, /inactive_skill_holders/);
  assert.match(drilldown, /currently_working/);
  assert.match(drilldown, /cross join \(values\('technician'::text\),\('helper'::text\)\)/);
  assert.match(drilldown, /srk_admin_list_category_skill_workers/);
  assert.match(drilldown, /service_names text\[\]/);
  assert.match(drilldown, /skill_names text\[\]/);
});
