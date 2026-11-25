const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const html=fs.readFileSync(require("node:path").join(__dirname,"..","admin.html"),"utf8");

test("Admin panel loads worker applications through permission-gated masked RPC",()=>{
 assert.match(html,/srk_admin_list_worker_applications_masked/);
 assert.match(html,/srkWorkerApplicationsCard/);
 assert.match(html,/loadSrkWorkerApplications\(\)/);
 assert.match(html,/masked_phone/);
});

test("Admin worker review uses constrained decisions and records an audit note",()=>{
 assert.match(html,/srk_admin_review_worker_application_masked/);
 for(const decision of ["approved","rejected","under_review","more_info"]) assert.ok(html.includes(decision));
 assert.match(html,/कम-से-कम 10 अक्षरों/);
 assert.match(html,/confirm\(/);
});

test("Worker review UI does not request or render unmasked application phone numbers",()=>{
 const start=html.indexOf("async function loadSrkWorkerApplications()");
 const end=html.indexOf("async function reviewSrkWorkerApplication",start);
 assert.ok(start>=0&&end>start);
 const loader=html.slice(start,end);
 assert.match(loader,/masked_phone/);
 assert.doesNotMatch(loader,/\.phone\b/);
});
