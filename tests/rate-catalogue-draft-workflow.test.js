"use strict";
const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const vm=require("node:vm");
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
 assert.ok(admin.includes("editAdminRateCatalogueDraft"));
 for(const handler of ["saveAdminRateCatalogueDraft","publishAdminRateCatalogueDraft","loadAdminRateCatalogueDrafts"])assert.ok(admin.includes(`async function ${handler}(`),`${handler} must be async because it awaits Supabase RPCs`);
});

test("Admin page inline JavaScript parses without syntax errors",()=>{
 const scripts=admin.split("<script>").slice(1).map(part=>part.split("</script>")[0]).filter(Boolean);
 assert.ok(scripts.length>0,"inline admin script must exist");
 for(const script of scripts)new vm.Script(script[1],{filename:"admin.html"});
});

test("Draft save UI sends validated four-tier paise payload to the RPC",async()=>{
 const elements={rateElectricalAssistant:{value:"125.50"},rateSkilledElectrician:{value:"200"},rateExpertElectrician:{value:"275.25"},ratePremiumSpecialist:{value:"350"},rateCatalogueReason:{value:"Automated UI test"},rateCatalogueEffectiveAt:{value:""},adminRateCatalogueStatus:{textContent:""},adminRateCatalogueDraftQueue:{textContent:"",innerHTML:""}};
 const calls=[];
 const context=vm.createContext({
  window:{},document:{getElementById(id){return elements[id]||(elements[id]={value:"",textContent:"",innerHTML:""});}},
  __calls:calls,
  __rpc:async(name,args)=>{calls.push({name,args});if(name==="srk_admin_save_rate_catalogue_draft")return {data:{success:true,draft_id:"draft-test",status:"draft"},error:null};if(name==="srk_admin_list_rate_catalogue_drafts")return {data:[],error:null};return {data:null,error:null};}
 });
 const inlineScript=admin.split("<script>").slice(1).map(part=>part.split("</script>")[0]).filter(Boolean).at(-1);
 vm.runInContext(inlineScript,context);
 vm.runInContext("sb={rpc:__rpc};user={id:'admin-test'};adminPortalMode='main_admin';",context);
 await vm.runInContext("saveAdminRateCatalogueDraft()",context);
 const save=calls.find(call=>call.name==="srk_admin_save_rate_catalogue_draft");
 assert.ok(save,"draft save RPC must be called");
 assert.deepEqual({...save.args.p_rates},{electrical_assistant:12550,skilled_electrician:20000,expert_electrician:27525,premium_electrical_specialist:35000});
 assert.equal(save.args.p_reason,"Automated UI test");
 assert.equal(save.args.p_draft_id,null);
 assert.ok(Number.isFinite(Date.parse(save.args.p_effective_at)));
 assert.ok(calls.some(call=>call.name==="srk_admin_list_rate_catalogue_drafts"));
 assert.match(elements.adminRateCatalogueStatus.textContent,/Draft सेव हुआ/);
});
