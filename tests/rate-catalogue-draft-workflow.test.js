"use strict";
const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const migration=fs.readFileSync(path.join(__dirname,"../supabase/migrations/20261118240000_rate_catalogue_draft_scheduled_workflow.sql"),"utf8");
const publishMigration=fs.readFileSync(path.join(__dirname,"../supabase/migrations/20261118050000_versioned_rate_catalogue_and_multi_category_electricians.sql"),"utf8");
const admin=fs.readFileSync(path.join(__dirname,"../admin.html"),"utf8");
test("Rate Catalogue drafts are private and Main Admin-only",()=>{
 assert.ok(migration.includes("ENABLE ROW LEVEL SECURITY"));
 assert.ok(migration.includes("REVOKE ALL ON public.srk_rate_catalogue_drafts FROM PUBLIC,anon,authenticated"));
 assert.ok((migration.match(/is_srk_admin/g)||[]).length>=3);
});
test("draft saves validate all four positive integer-paise tiers and classify future effective times",()=>{
 assert.ok(migration.includes("EXACTLY_FOUR_RATE_TIERS_REQUIRED"));
 assert.ok(migration.includes("RATE_MUST_BE_INTEGER_PAISE"));
 assert.ok(migration.includes("p_effective_at>now() THEN 'scheduled' ELSE 'draft'"));
});
test("published drafts are immutable and publishing delegates to version-checked catalogue RPC",()=>{
 assert.ok(migration.includes("PUBLISHED_RATE_DRAFT_IS_IMMUTABLE"));
 assert.ok(migration.includes("status='published' AND published_rate_version_id IS NOT NULL"));
 assert.ok(migration.includes("public.srk_admin_publish_rate_catalogue("));
 assert.ok(migration.includes("p_expected_current_version_id"));
 assert.ok(publishMigration.includes("RATE_CATALOGUE_VERSION_CONFLICT"));
});
test("draft queue has bounded paging and excludes published records",()=>{
 assert.ok(migration.includes("INVALID_PAGE_LIMIT"));
 assert.ok(migration.includes("WHERE status IN ('draft','scheduled')"));
});
test("Main Admin UI can save drafts, view queue, and publish with expected current version",()=>{
 assert.ok(admin.includes("saveAdminRateCatalogueDraft"));
 assert.ok(admin.includes("srk_admin_save_rate_catalogue_draft"));
 assert.ok(admin.includes("srk_admin_list_rate_catalogue_drafts"));
 assert.ok(admin.includes("srk_admin_publish_rate_catalogue_draft"));
 assert.ok(admin.includes("p_expected_current_version_id:adminCurrentRateCatalogue?.rate_version_id||null"));
 assert.ok(admin.includes("adminRateCatalogueDraftQueue"));
});
