// Static safety checks for Razorpay full-refund workflow. No real API calls.
const assert=require("node:assert/strict");
const fs=require("node:fs");
const vm=require("node:vm");
const migration=fs.readFileSync("supabase/migrations/20261110070000_razorpay_refund_workflow.sql","utf8");
const handler=fs.readFileSync("razorpay-refund.js","utf8");
const webhook=fs.readFileSync("razorpay-webhook.js","utf8");
const admin=fs.readFileSync("admin.html","utf8");
const config=fs.readFileSync("netlify.toml","utf8");
assert.match(migration,/CREATE TABLE IF NOT EXISTS public\.srk_razorpay_refunds/i);
assert.match(migration,/ENABLE ROW LEVEL SECURITY/i);
assert.match(migration,/REVOKE ALL ON TABLE public\.srk_razorpay_refunds FROM PUBLIC,anon,authenticated/i);
assert.match(migration,/auth\.uid\(\) IS NULL OR NOT public\.is_srk_admin\(\)/i);
assert.match(migration,/FOR UPDATE/i);
assert.match(migration,/payout_status='blocked'/i);
assert.match(migration,/payout_status='paid'/i);
assert.match(migration,/RETURN QUERY SELECT v_refund\.id,v_refund\.booking_id,v_refund\.payment_id,v_refund\.amount_paise,v_refund\.idempotency_key,v_refund\.status,v_refund\.previous_payout_note;/i);
assert.match(handler,/X-Refund-Idempotency/);
assert.match(handler,/srk_admin_prepare_razorpay_refund/);
assert.match(handler,/auth\/v1\/user/);
assert.match(handler,/api\.razorpay\.com\/v1\/payments/);
assert.match(handler,/status:uncertain\?"unknown":"failed"/);
assert.match(webhook,/refund\.processed/);
assert.match(webhook,/refund\.failed/);
assert.match(webhook,/processRefundWebhook/);
assert.match(webhook,/payment_status:"refunded"/);
assert.match(webhook,/payout_status:"refunded"/);
assert.match(webhook,/payout_status:"pending"/);
assert.match(admin,/requestRazorpayRefund/);
assert.match(admin,/srk_admin_list_razorpay_refunds/);
assert.match(admin,/वास्तविक FULL REFUND/);
assert.match(config,/from = "\/api\/razorpay-refund"/);
for(const [label,src] of [["refund",handler],["webhook",webhook]]){
  new vm.Script(src,{filename:label+".js"});
}
const scripts=[...admin.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim());
scripts.forEach((src,i)=>new vm.Script(src,{filename:"admin-inline-"+i+".js"}));
console.log("PASS Razorpay refund Admin gate, idempotent request, signed webhook reconciliation, payout hold and Admin UI wiring");
console.log(JSON.stringify({passed:1,scope:"static syntax/source only",realRazorpayCalls:0,realRefundIssued:false,migrationApplied:false},null,2));
