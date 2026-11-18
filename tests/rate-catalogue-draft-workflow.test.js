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

test("Admin catalogue loader clears stale values and rejects missing or malformed published data",()=>{
 const start=admin.indexOf("async function loadAdminRateCatalogue()");
 const end=admin.indexOf("async function loadAdminRateCatalogueDrafts()",start);
 const fn=admin.slice(start,end);
 assert.ok(start>=0&&end>start);
 assert.match(fn,/adminCurrentRateCatalogue=null;\s*clearInputs\(\)/);
 assert.match(fn,/if\(data==null\)[\s\S]*?return;/);
 assert.match(fn,/actualKeys\.length===expectedKeys\.length/);
 assert.match(fn,/Number\.isSafeInteger\(data\.rates\[key\]\)&&data\.rates\[key\]>0/);
 assert.match(fn,/data\.currency!=='INR'\|\|data\.base_duration_hours!==8/);
 assert.match(fn,/catch\(e\)\{[\s\S]*?adminCurrentRateCatalogue=null;\s*clearInputs\(\)/);
 assert.match(fn,/पुरानी दरें इस्तेमाल नहीं की गई हैं/);
});

test("electrician tier selector displays the current published catalogue prices, never legacy hardcoded amounts",()=>{
 const helperStart=admin.indexOf("function paiseToRupees");
 const helperEnd=admin.indexOf("function rupeesToPaise",helperStart);
 assert.ok(helperStart>=0&&helperEnd>helperStart);
 const context=vm.createContext({
  esc:value=>String(value).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;"),
  adminCurrentRateCatalogue:null,
  SRK_RATE_TIERS:[
   ["electrical_assistant","Electrical Assistant"],
   ["skilled_electrician","Skilled Electrician"],
   ["expert_electrician","Expert Electrician"],
   ["premium_electrical_specialist","Premium Electrical Specialist"]
  ]
 });
 vm.runInContext(admin.slice(helperStart,helperEnd),context);
 context.adminCurrentRateCatalogue={rates:{electrical_assistant:12550,skilled_electrician:20000,expert_electrician:27525,premium_electrical_specialist:35000}};
 const dynamic=vm.runInContext("SRK_RATE_TIERS.map(([key,label])=>adminRateTierOption(key,label,'skilled_electrician')).join('')",context);
 assert.match(dynamic,/Electrical Assistant — ₹125\.50/);
 assert.match(dynamic,/Skilled Electrician — ₹200\.00/);
 assert.match(dynamic,/Expert Electrician — ₹275\.25/);
 assert.match(dynamic,/Premium Electrical Specialist — ₹350\.00/);
 assert.match(dynamic,/value="skilled_electrician" selected/);
 assert.doesNotMatch(dynamic,/₹899|₹1,199|₹1,599|₹1,999/);
 context.adminCurrentRateCatalogue=null;
 const unavailable=vm.runInContext("adminRateTierOption('electrical_assistant','Electrical Assistant','')",context);
 assert.match(unavailable,/प्रकाशित दर उपलब्ध नहीं/);
 assert.doesNotMatch(unavailable,/₹\d/);
});

test("Admin page inline JavaScript parses without syntax errors",()=>{
 const scripts=admin.split("<script>").slice(1).map(part=>part.split("</script>")[0]).filter(Boolean);
 assert.ok(scripts.length>0,"inline admin script must exist");
 for(const script of scripts)new vm.Script(script,{filename:"admin.html"});
});

test("Draft queue renders safe rows and Edit Draft restores all saved values",async()=>{
 const elements={adminRateCatalogueDraftQueue:{textContent:"",innerHTML:""},rateElectricalAssistant:{value:""},rateSkilledElectrician:{value:""},rateExpertElectrician:{value:""},ratePremiumSpecialist:{value:""},rateCatalogueEffectiveAt:{value:""},rateCatalogueReason:{value:""},adminRateCatalogueStatus:{textContent:""}};
 const row={id:"draft-42",status:"scheduled",effective_at:"2027-12-01T10:00:00.000Z",reason:"Review <safe>",rates:{electrical_assistant:12550,skilled_electrician:20000,expert_electrician:27525,premium_electrical_specialist:35000}};
 const context=vm.createContext({window:{},document:{getElementById(id){return elements[id]||(elements[id]={value:"",textContent:"",innerHTML:""});}},__rpc:async(name)=>({data:name==="srk_admin_list_rate_catalogue_drafts"?[row]:[],error:null})});
 const script=admin.split("<script>").slice(1).map(part=>part.split("</script>")[0]).filter(Boolean).at(-1);
 vm.runInContext(script,context);
 vm.runInContext("sb={rpc:__rpc};user={id:'admin-test'};adminPortalMode='main_admin';",context);
 await vm.runInContext("loadAdminRateCatalogueDrafts()",context);
 assert.match(elements.adminRateCatalogueDraftQueue.innerHTML,/Scheduled/);
 assert.match(elements.adminRateCatalogueDraftQueue.innerHTML,/Review &lt;safe&gt;/);
 assert.match(elements.adminRateCatalogueDraftQueue.innerHTML,/editAdminRateCatalogueDraft\(0\)/);
 vm.runInContext("editAdminRateCatalogueDraft(0)",context);
 assert.equal(elements.rateElectricalAssistant.value,"125.50");
 assert.equal(elements.rateSkilledElectrician.value,"200.00");
 assert.equal(elements.rateExpertElectrician.value,"275.25");
 assert.equal(elements.ratePremiumSpecialist.value,"350.00");
 assert.equal(elements.rateCatalogueReason.value,row.reason);
 assert.match(elements.adminRateCatalogueStatus.textContent,/draft-42/);
});
test("Draft publish uses the current version guard and refreshes catalogue and queue",async()=>{
 const calls=[],elements={adminRateCatalogueStatus:{textContent:""},adminRateCatalogueDraftQueue:{textContent:"",innerHTML:""}};
 const context=vm.createContext({window:{},document:{getElementById(id){return elements[id]||(elements[id]={value:"",textContent:"",innerHTML:""});}},confirm:()=>true,__rpc:async(name,args)=>{calls.push({name,args});if(name==="srk_admin_publish_rate_catalogue_draft")return {data:{success:true,rate_version_id:"version-9",effective_at:"2027-12-01T10:00:00.000Z"},error:null};return {data:[],error:null};}});
 const script=admin.split("<script>").slice(1).map(part=>part.split("</script>")[0]).filter(Boolean).at(-1);
 vm.runInContext(script,context);
 vm.runInContext("sb={rpc:__rpc};user={id:'admin-test'};adminPortalMode='main_admin';adminCurrentRateCatalogue={rate_version_id:'version-8'};loadAdminRateCatalogue=async()=>{__refreshed.catalogue=true};loadAdminRateCatalogueDrafts=async()=>{__refreshed.queue=true};",context);
 context.__refreshed={catalogue:false,queue:false};
 await vm.runInContext("publishAdminRateCatalogueDraft('draft-42')",context);
 const publish=calls.find(x=>x.name==="srk_admin_publish_rate_catalogue_draft");
 assert.deepEqual({...publish.args},{p_draft_id:"draft-42",p_expected_current_version_id:"version-8"});
 assert.equal(context.__refreshed.catalogue,true);
 assert.equal(context.__refreshed.queue,true);
 assert.match(elements.adminRateCatalogueStatus.textContent,/Version publish हुआ/);
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

test("Draft queue ignores stale concurrent refresh responses",async()=>{
 const elements={adminRateCatalogueDraftQueue:{textContent:"",innerHTML:""}};
 let resolveFirst;
 const first=new Promise(resolve=>{resolveFirst=resolve;});
 let calls=0;
 const context=vm.createContext({window:{},document:{getElementById(id){return elements[id];}},__rpc:async()=>{calls++;return calls===1?await first:{data:[{id:"newer",status:"draft",effective_at:"2027-12-02T10:00:00Z",reason:"Newest",rates:{}}],error:null};}});
 const script=admin.split("<script>").slice(1).map(part=>part.split("</script>")[0]).filter(Boolean).at(-1);
 vm.runInContext(script,context);
 vm.runInContext("sb={rpc:__rpc};user={id:'admin-test'};adminPortalMode='main_admin';",context);
 const older=vm.runInContext("loadAdminRateCatalogueDrafts()",context);
 await vm.runInContext("loadAdminRateCatalogueDrafts()",context);
 resolveFirst({data:[{id:"older",status:"draft",effective_at:"2027-12-01T10:00:00Z",reason:"Stale",rates:{}}],error:null});
 await older;
 assert.match(elements.adminRateCatalogueDraftQueue.innerHTML,/Newest/);
 assert.doesNotMatch(elements.adminRateCatalogueDraftQueue.innerHTML,/Stale/);
 assert.equal(vm.runInContext("adminRateCatalogueDraftCache[0].id",context),"newer");
});
