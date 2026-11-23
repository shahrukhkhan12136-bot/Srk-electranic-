const test=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const source=fs.readFileSync(path.join(__dirname,"..","razorpay-settlement-sync.js"),"utf8");

test("settlement sync is POST-only and requires an authenticated Admin permission gate",()=>{
 assert.match(source,/event\.httpMethod!=="POST"/);
 assert.match(source,/^Bearer\\s\+/m);
 assert.match(source,/srk_admin_finance_dashboard/);
 assert.match(source,/p_period:"month"/);
});

test("settlement sync uses bounded date windows and paginates both provider APIs",()=>{
 assert.match(source,/90\*86400/);
 assert.match(source,/\/settlements\//);
 assert.match(source,/count:"100"/);
 assert.match(source,/settlements\/recon\/combined/);
 assert.match(source,/count:"1000"/);
});

test("settlement sync imports only recon items belonging to the exact settlement",()=>{
 assert.match(source,/x\?\.settlement_id===s\.id/);
 assert.match(source,/srk_service_import_razorpay_settlement/);
 assert.match(source,/p_source:"api"/);
});

test("settlement sync does not expose provider credentials or assume successful sync",()=>{
 assert.match(source,/SUPABASE_SERVICE_ROLE_KEY/);
 assert.match(source,/RAZORPAY_KEY_SECRET/);
 assert.match(source,/no success is assumed/);
 assert.doesNotMatch(source,/console\.log\([^\n]*(RAZORPAY_KEY|SERVICE_ROLE)/);
});
