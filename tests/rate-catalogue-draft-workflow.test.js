"use strict";
const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const migration=fs.readFileSync(path.join(__dirname,"../supabase/migrations/20261118240000_rate_catalogue_draft_scheduled_workflow.sql"),"utf8");
const publishMigration=fs.readFileSync(path.join(__dirname,"../supabase/migrations/20261118050000_versioned_rate_catalogue_and_multi_category_electricians.sql"),"utf8");
const admin=fs.readFileSync(path.join(__dirname,"../admin.html"),"utf8");
test("Rate Catalogue drafts are private and Main Admin-only",()=>{
 assert.match(migration,/ENABLE ROW LEVEL SECURITY/);
 assert.match(migration,/REVOKE ALL ON public\.srk_rate_catalogue_drafts FROM PUBLIC,anon,authenticated/);
 assert.equal((migration.match(/auth\.uid\(\) IS NULL OR NOT public\.is_srk_admin\(\)/g)||[]).length,3);
});
test("draft saves validate all four positive integer-paise tiers and classify future effective times",()=>{
 assert.match(migration,/EXACTLY_FOUR_RATE_TIERS_REQUIRED/);
 assert.match(migration,/RATE_MUST_BE_INTEGER_PAISE/);
 assert.match(migration,/v_status:=CASE WHEN p_effective_at>now\(\) THEN 'scheduled' ELSE 'draft' END/);
});
test("published drafts are immutable and customer catalogue remains separate",()=>{
 assert.match(migration,/PUBLISHED_RATE_DRAFT_IS_IMMUTABLE/);
 assert.match(migration,/status='published' AND published_rate_version_id IS NOT NULL/);
 assert.match(migration,/srk_admin_publish_rate_catalogue\(/);
 assert.match(migration,/p_expected_current_version_id/);
 assert.match(migration,/public\\.srk_admin_publish_rate_catalogue\\(/);
 assert.match(publishMigration,/RATE_CATALOGUE_VERSION_CONFLICT/);
});
test("draft queue has bounded paging and excludes published records",()=>{
 assert.match(migration,/INVALID_PAGE_LIMIT/);
 assert.match(migration,/WHERE status IN \('draft','scheduled'\)/);
});
test("Main Admin UI can save drafts, view queue, and publish with expected current version",()=>{
 assert.match(admin,/saveAdminRateCatalogueDraft/);
 assert.match(admin,/srk_admin_save_rate_catalogue_draft/);
 assert.match(admin,/srk_admin_list_rate_catalogue_drafts/);
 assert.match(admin,/srk_admin_publish_rate_catalogue_draft/);
 assert.match(admin,/p_expected_current_version_id:adminCurrentRateCatalogue\?\.rate_version_id\|\|null/);
 assert.match(admin,/adminRateCatalogueDraftQueue/);
});
