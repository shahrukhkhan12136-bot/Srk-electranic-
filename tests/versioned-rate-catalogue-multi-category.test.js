"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118050000_versioned_rate_catalogue_and_multi_category_electricians.sql"), "utf8");
const bookingApi = fs.readFileSync(path.join(__dirname, "../create-booking.js"), "utf8");
const customerUi = fs.readFileSync(path.join(__dirname, "../booking.html"), "utf8");
const electricianUi = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");
const netPolicy = fs.readFileSync(path.join(__dirname, "../lib/electrician-net-rate.js"), "utf8");
const adminRateReadMigration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118070000_admin_rate_catalogue_read_rpcs.sql"), "utf8");
const adminUi = fs.readFileSync(path.join(__dirname, "../admin.html"), "utf8");

test("catalogue publish is Main Admin only, version-checked, and validates exactly four integer paise rates", () => {
  assert.match(migration, /public\.srk_admin_publish_rate_catalogue/);
  assert.match(migration, /NOT public\.is_srk_admin\(\)/);
  assert.match(migration, /p_expected_current_version_id/);
  assert.match(migration, /RATE_CATALOGUE_VERSION_CONFLICT/);
  assert.match(migration, /EXACTLY_FOUR_RATE_TIERS_REQUIRED/);
  assert.match(migration, /pg_advisory_xact_lock/);
});

test("customer catalogue RPC returns the active published version and all customer rates", () => {
  assert.match(migration, /public\.srk_get_current_customer_rate_catalogue/);
  assert.match(migration, /effective_at<=now\(\)/);
  assert.match(migration, /'rate_version_id',v_id/);
  assert.match(migration, /'rates',v_rates/);
});

test("electrician rate RPC requires the authenticated linked approved profile and returns only approved net items", () => {
  const rpc = migration.slice(migration.indexOf("FUNCTION public.srk_get_my_electrician_rate_list"));
  assert.match(rpc, /auth_user_id=auth\.uid\(\) AND user_id=auth\.uid\(\)/);
  assert.match(rpc, /verification_status='approved'/);
  assert.match(rpc, /srk_electrician_approved_rate_categories/);
  assert.match(rpc, /a\.is_active=true/);
  assert.match(rpc, /'electrician_rate_paise'/);
  assert.doesNotMatch(rpc, /'customer_rate_paise'|'company_share'|'commission_amount'/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_get_my_electrician_rate_list\(\) TO authenticated/);
});

test("multiple categories are Admin-managed, audited, and used by booking dispatch", () => {
  assert.match(migration, /srk_admin_set_electrician_approved_categories/);
  assert.match(migration, /MAIN_ADMIN_ONLY/);
  assert.match(migration, /srk_electrician_rate_category_audit/);
  assert.match(migration, /INSERT INTO public\.srk_electrician_approved_rate_categories/);
  assert.match(migration, /EXISTS \(\s*SELECT 1 FROM public\.srk_electrician_approved_rate_categories a/);
  assert.match(migration, /a\.category_key=v_booking\.selected_rate_tier/);
  assert.match(migration, /Legacy single-category approval copied/);
  assert.doesNotMatch(migration, /DROP COLUMN[^;]*approved_rate_tier/i);
});

test("unchanged active electrician categories do not create false approval audit events", () => {
  assert.match(migration, /GET DIAGNOSTICS v_rows = ROW_COUNT/);
  assert.match(migration, /IF v_rows > 0 THEN[\s\S]*srk_electrician_rate_category_audit/);
});

test("customer UI and booking API consume the same published catalogue RPC", () => {
  assert.match(customerUi, /rpc\('srk_get_current_customer_rate_catalogue'\)/);
  assert.match(bookingApi, /rpc\/srk_get_current_customer_rate_catalogue/);
  assert.doesNotMatch(bookingApi, /electrical_assistant:\s*89900/);
  assert.doesNotMatch(customerUi, /const customerRateCard = \{/);
});

test("electrician UI consumes only the authenticated electrician rate-list RPC", () => {
  assert.match(electricianUi, /rpc\('srk_get_my_electrician_rate_list'\)/);
  assert.match(electricianUi, /electrician_rate_paise/);
});

test("booking replay reads its original immutable rate version rather than today's catalogue", () => {
  assert.match(bookingApi, /loadSnapshotRate8h/);
  assert.match(bookingApi, /estimate_rate_card_version/);
  assert.match(bookingApi, /rate_version_id=eq\./);
});

test("dynamic catalogue estimate drops only the obsolete hard-coded rate equality constraint", () => {
  assert.match(migration, /DROP CONSTRAINT IF EXISTS service_bookings_estimate_matches_rate_card/);
  assert.match(migration, /COMMENT ON CONSTRAINT service_bookings_estimate_snapshot_complete/);
  assert.doesNotMatch(migration, /ADD CONSTRAINT service_bookings_estimate_matches_rate_card/);
});

test("electrician rate-list RPC calculates direct 85 percent using half-up integer-paise rounding", () => {
  assert.match(migration, /'electrician_rate_paise',floor\(\(i\.customer_rate_paise::numeric\*8500\/10000\)\+0\.5\)::bigint/);
  assert.doesNotMatch(migration, /'electrician_rate_paise',\(i\.customer_rate_paise-floor/);
});

test("payout accounting retains one rounded 15 percent commission while rate-list display uses separate direct 85 percent", () => {
  assert.match(netPolicy, /PLATFORM_COMMISSION_BPS = 1500/);
  assert.match(netPolicy, /const net = Number\(gross - commission\)/);
  assert.match(netPolicy, /ELECTRICIAN_RATE_LIST_BPS = 8500/);
  assert.match(migration, /'electrician_rate_paise',floor\(\(i\.customer_rate_paise::numeric\*8500\/10000\)\+0\.5\)::bigint/);
  assert.doesNotMatch(migration, /'electrician_rate_paise',\(i\.customer_rate_paise-floor/);
});

test("catalogue version, item, and audit rows cannot be updated or deleted", () => {
  assert.match(migration, /srk_rate_catalogue_versions_immutable/);
  assert.match(migration, /srk_rate_catalogue_items_immutable/);
  assert.match(migration, /srk_rate_catalogue_audit_immutable/);
});


test("Admin rate controls are Main Admin-only in the portal and call version-checked publish RPC", () => {
  assert.match(adminUi, /id="adminRateCatalogueCard"/);
  assert.match(adminUi, /id="adminElectricianRateCategoryCard"/);
  assert.match(adminUi, /adminPortalMode!=='main_admin'/);
  assert.match(adminUi, /srk_admin_publish_rate_catalogue/);
  assert.match(adminUi, /p_expected_current_version_id:adminCurrentRateCatalogue\?\.rate_version_id\|\|null/);
  assert.match(adminUi, /function rupeesToPaise/);
  assert.ok(adminUi.includes("if(!/^\\\\d+(?:\\\\.\\\\d{1,2})?$/.test(raw))"));
});

test("Admin electrician category list is server-gated to Main Admin and writes full desired category state", () => {
  assert.match(adminRateReadMigration, /srk_admin_list_electrician_rate_categories/);
  assert.match(adminRateReadMigration, /NOT public\.is_srk_admin\(\)/);
  assert.match(adminRateReadMigration, /active_categories/);
  assert.match(adminUi, /srk_admin_list_electrician_rate_categories/);
  assert.match(adminUi, /srk_admin_set_electrician_approved_categories/);
  assert.match(adminUi, /p_category_keys:selected/);
  assert.match(adminUi, /p_reason:reason/);
  assert.match(adminRateReadMigration, /GRANT EXECUTE ON FUNCTION public\.srk_admin_list_electrician_rate_categories\(\) TO authenticated/);
});

test("Admin activation accepts new multi-category approvals as well as preserved legacy approvals", () => {
  assert.match(adminUi, /srk_admin_list_electrician_rate_categories/);
  assert.match(adminUi, /categoryProfile\?\.active_categories/);
  assert.match(adminUi, /hasMultiCategoryApproval\|\|!hasLegacyApproval/);
  assert.match(adminUi, /कम-से-कम एक Admin-approved Rate Category/);
});
