"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const read = (name) => fs.readFileSync(path.join(__dirname, "..", name), "utf8");
const bookingUi = read("booking.html");
const bookingApi = read("create-booking.js");
const electricianUi = read("electrician.html");
const catalogueMigration = read("supabase/migrations/20261118050000_versioned_rate_catalogue_and_multi_category_electricians.sql");
const adminReadMigration = read("supabase/migrations/20261118070000_admin_rate_catalogue_read_rpcs.sql");

test("customer UI and booking server read the same published catalogue RPC", () => {
  assert.match(bookingUi, /rpc\(['"]srk_get_current_customer_rate_catalogue['"]\)/);
  assert.match(bookingApi, /rpc\/srk_get_current_customer_rate_catalogue/);
  assert.match(bookingApi, /Never accept client-supplied rate amounts\/version/);
  assert.match(bookingApi, /estimate_rate_card_version:\s*rateCardVersion/);
  assert.match(bookingApi, /estimated_labour_paise:\s*estimatedLabourPaise/);
});

test("booking API derives the estimate from server rate, selected tier and duration", () => {
  assert.match(bookingApi, /const rate8hPaise = rateCard\[selected_rate_tier\]/);
  assert.match(bookingApi, /Math\.floor\(\(rate8hPaise \* selected_duration_hours\) \/ 8 \+ 0\.5\)/);
  assert.match(bookingApi, /!Number\.isSafeInteger\(rateCard\[selected_rate_tier\]\) \|\| rateCard\[selected_rate_tier\] <= 0/);
  assert.match(bookingApi, /selected_duration_hours < 1 \|\| selected_duration_hours > 8/);
});

test("electrician rate list exposes only approved categories and the 85 percent rate", () => {
  assert.match(electricianUi, /rpc\(['"]srk_get_my_electrician_rate_list['"]\)/);
  const start = catalogueMigration.indexOf("CREATE OR REPLACE FUNCTION public.srk_get_my_electrician_rate_list()");
  const end = catalogueMigration.indexOf("$fn$;", start);
  const fn = catalogueMigration.slice(start, end);
  assert.ok(start >= 0 && end > start);
  assert.match(fn, /a\.is_active=true/);
  assert.match(fn, /electrician_rate_paise/);
  assert.match(fn, /8500\/10000/);
  assert.doesNotMatch(fn, /customer_rate_paise['"]\s*,\s*commission|company_share|gross_customer_amount/i);
});

test("Admin rate-category read and write RPCs are Main Admin protected", () => {
  assert.match(adminReadMigration, /auth\.uid\(\) IS NULL OR NOT public\.is_srk_admin\(\)/);
  assert.match(catalogueMigration, /FUNCTION public\.srk_admin_publish_rate_catalogue[\s\S]*?public\.is_srk_admin\(\)/);
  assert.match(catalogueMigration, /FUNCTION public\.srk_admin_set_electrician_approved_categories[\s\S]*?public\.is_srk_admin\(\)/);
  assert.match(adminReadMigration, /GRANT EXECUTE ON FUNCTION public\.srk_admin_list_electrician_rate_categories\(\) TO authenticated/);
});

test("catalogue publishing validates the exact four tier keys and expected current version", () => {
  assert.match(catalogueMigration, /EXACTLY_FOUR_RATE_TIERS_REQUIRED/);
  assert.match(catalogueMigration, /p_expected_current_version_id/);
  assert.match(catalogueMigration, /RATE_CATALOGUE_VERSION_CONFLICT/);
  assert.match(catalogueMigration, /effective_at<=now\(\)/);
});

test("Rate Catalogue RPC grants are least-privilege and base tables stay private", () => {
  assert.match(catalogueMigration, /REVOKE ALL ON public\.srk_rate_catalogue_versions,public\.srk_rate_catalogue_items,[\s\S]*?FROM PUBLIC,anon,authenticated/);
  assert.match(catalogueMigration, /GRANT EXECUTE ON FUNCTION public\.srk_get_current_customer_rate_catalogue\(\) TO anon,authenticated,service_role/);
  assert.match(catalogueMigration, /GRANT EXECUTE ON FUNCTION public\.srk_get_my_electrician_rate_list\(\) TO authenticated/);
  assert.match(catalogueMigration, /GRANT EXECUTE ON FUNCTION public\.srk_admin_publish_rate_catalogue\(jsonb,timestamptz,uuid,text\) TO authenticated/);
  assert.match(catalogueMigration, /GRANT EXECUTE ON FUNCTION public\.srk_admin_set_electrician_approved_categories\(uuid,text\[\],text\) TO authenticated/);
  assert.match(catalogueMigration, /GRANT SELECT ON TABLE public\.srk_rate_catalogue_items TO service_role/);
});


const electricianCatalogueGuard = read("supabase/migrations/20261118150000_block_electrician_gross_catalogue_access.sql");

test("authenticated electrician sessions cannot call the customer gross catalogue RPC", () => {
  assert.match(electricianCatalogueGuard, /ELECTRICIAN_CUSTOMER_RATE_CATALOGUE_FORBIDDEN/);
  assert.match(electricianCatalogueGuard, /ep\.user_id=auth\.uid\(\) OR ep\.auth_user_id=auth\.uid\(\)/);
  assert.match(electricianCatalogueGuard, /GRANT EXECUTE ON FUNCTION public\.srk_get_current_customer_rate_catalogue\(\) TO anon,authenticated,service_role/);
});

test("electrician net rate list resolves the published version without calling gross catalogue RPC", () => {
  const start = electricianCatalogueGuard.indexOf("CREATE OR REPLACE FUNCTION public.srk_get_my_electrician_rate_list()");
  const end = electricianCatalogueGuard.indexOf("$fn$;", start);
  const fn = electricianCatalogueGuard.slice(start, end);
  assert.ok(start >= 0 && end > start);
  assert.match(fn, /verification_status='approved'/);
  assert.match(fn, /active=true/);
  assert.match(fn, /electrician_rate_paise/);
  assert.match(fn, /customer_rate_paise-floor\(\(i\.customer_rate_paise::numeric\*1500\/10000\)\+0\.5\)::bigint/);
  assert.doesNotMatch(fn, /srk_get_current_customer_rate_catalogue|customer_rate_paise['"]\s*,\s*commission|company_share/i);
});


const electricianCatalogueFinalMigration = read("supabase/migrations/20261118150000_block_electrician_gross_catalogue_access.sql");

test("final electrician Rate List RPC requires an active approved identity and returns only net rates", () => {
  const start = electricianCatalogueFinalMigration.indexOf("CREATE OR REPLACE FUNCTION public.srk_get_my_electrician_rate_list()");
  const end = electricianCatalogueFinalMigration.indexOf("$fn$;", start);
  const fn = electricianCatalogueFinalMigration.slice(start, end);
  assert.ok(start >= 0 && end > start);
  assert.match(fn, /auth_user_id=auth\.uid\(\)/);
  assert.match(fn, /user_id=auth\.uid\(\)/);
  assert.match(fn, /verification_status='approved'/);
  assert.match(fn, /active=true/);
  assert.match(fn, /a\.is_active=true/);
  assert.match(fn, /electrician_rate_paise/);
  assert.match(fn, /customer_rate_paise-floor\(\(i\.customer_rate_paise::numeric\*1500\/10000\)\+0\.5\)::bigint/);
  assert.doesNotMatch(fn, /srk_get_current_customer_rate_catalogue|customer_rate_paise['"]\s*,\s*commission|company_share|gross_customer_amount/i);
});

test("Electrician Rate List UI fails closed on RPC errors or malformed payloads and escapes labels", () => {
  assert.match(electricianUi, /if\(rateListResult\.error\)throw rateListResult\.error/);
  assert.match(electricianUi, /!Array\.isArray\(rateList\.items\)/);
  assert.match(electricianUi, /Number\.isSafeInteger\(item\.electrician_rate_paise\)/);
  assert.match(electricianUi, /item\.duration_hours!==8/);
  assert.match(electricianUi, /esc\(item\.customer_facing_label\|\|item\.category_key\)/);
  assert.match(electricianUi, /आपकी स्वीकृत Rate List अभी उपलब्ध नहीं है/);
});


test("customer Rate Catalogue UI fails closed unless the published version and all four safe integer rates exist", () => {
  const start = bookingUi.indexOf("async function refreshCustomerRateCatalogue()");
  const end = bookingUi.indexOf("function updateLabourEstimate()", start);
  const fn = bookingUi.slice(start, end);
  assert.ok(start >= 0 && end > start);
  assert.match(fn, /customerSb\.rpc\(['"]srk_get_current_customer_rate_catalogue['"]\)/);
  assert.match(fn, /if\s*\(error\)\s*throw error/);
  assert.match(fn, /!data\?\.rate_version_id/);
  assert.match(fn, /Number\.isSafeInteger\(rates\[k\]\)/);
  assert.match(fn, /rates\[k\]\s*<=\s*0/);
  assert.match(fn, /Object\.fromEntries\(keys\.map\(k=>\[k,rates\[k\]\]\)\)/);
  assert.match(fn, /customerRateVersionId=data\.rate_version_id/);
  assert.doesNotMatch(fn, /\|\|\s*\d{3,}/, "customer UI must not fall back to hardcoded catalogue prices");
});

test("customer labour estimate uses only the selected published tier and bounded whole-hour duration", () => {
  const start = bookingUi.indexOf("function updateLabourEstimate()");
  const end = bookingUi.indexOf("function initCustomerMenuShell()", start);
  const fn = bookingUi.slice(start, end);
  assert.ok(start >= 0 && end > start);
  assert.match(fn, /!Number\.isInteger\(hours\)/);
  assert.match(fn, /hours<1\|\|hours>8/);
  assert.match(fn, /customerRateCard\[tier\]\*hours\/8\+0\.5/);
  assert.doesNotMatch(fn, /customer_rate_paise|company_share|commission/);
});
