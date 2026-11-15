const test=require("node:test");
const assert=require("node:assert/strict");
process.env.SUPABASE_URL="https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY="service-key";
process.env.RAZORPAY_KEY_ID="key-id";
process.env.RAZORPAY_KEY_SECRET="key-secret";
const {handler}=require("../razorpay-refund-recovery.js");
const bookingId="123e4567-e89b-42d3-a456-426614174000";
const recordId="223e4567-e89b-42d3-a456-426614174000";
const auditId="323e4567-e89b-42d3-a456-426614174000";
const adminId="423e4567-e89b-42d3-a456-426614174000";
const paymentId="pay_recovery123";
const refundId="rfnd_recovery123";
const record={id:recordId,booking_id:bookingId,payment_id:paymentId,refund_id:refundId,amount_paise:12500,currency:"INR",idempotency_key:"srkrefund123456789",status:"processing"};
const providerRefund={id:refundId,payment_id:paymentId,amount:12500,currency:"INR",status:"processed",created_at:1794720000,acquirer_data:{arn:"ARN123"},notes:{srk_refund_record_id:recordId}};
const response=(status,data)=>({ok:status>=200&&status<300,status,text:async()=>JSON.stringify(data)});
const originalFetch=global.fetch;
function request(note="Verified against Razorpay Dashboard; proceed with accounting recovery."){return{httpMethod:"POST",headers:{authorization:"Bearer test-admin-token-123456789"},body:JSON.stringify({booking_id:bookingId,admin_note:note})};}
function setup({provider=providerRefund,finalizeOk=true,providerStatus="processed"}={}){
 const calls=[];
 global.fetch=async(url,options={})=>{
  const target=String(url);calls.push({target,options});
  if(target.endsWith("/auth/v1/user"))return response(200,{id:adminId});
  if(target.endsWith("/rpc/is_srk_admin"))return response(200,true);
  if(target.includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[record]);
  if(target.includes("/rest/v1/service_bookings?"))return response(200,[{id:bookingId,razorpay_payment_id:paymentId}]);
  if(target.includes("api.razorpay.com/v1/refunds/"))return response(200,{...provider,status:providerStatus});
  if(target.endsWith("/rpc/srk_service_record_razorpay_refund_recovery_evidence"))return response(200,auditId);
  if(target.endsWith("/rpc/srk_service_finalize_razorpay_refund_from_recovery_evidence"))return finalizeOk?response(200,{success:true,status:"processed"}):response(500,{message:"accounting trigger failed"});
  throw new Error("unexpected request "+target);
 };
 return calls;
}
test("requires a bounded audit note before any provider request",async t=>{
 let calls=0;global.fetch=async()=>{calls++;return response(200,{});};t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request("short"));assert.equal(result.statusCode,400);assert.equal(calls,0);
});
test("requires Main Admin membership before provider lookup",async t=>{
 let providerCalls=0;global.fetch=async url=>{const target=String(url);if(target.endsWith("/auth/v1/user"))return response(200,{id:adminId});if(target.endsWith("/rpc/is_srk_admin"))return response(200,false);if(target.includes("razorpay.com"))providerCalls++;throw new Error("unexpected "+target);};t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());assert.equal(result.statusCode,403);assert.equal(providerCalls,0);
});
test("persists exact provider evidence and finalizes in a separate request",async t=>{
 const calls=setup();t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);
 assert.equal(result.statusCode,200);assert.equal(body.evidence_saved,true);assert.equal(body.accounting_finalized,true);assert.equal(body.recovery_audit_id,auditId);
 const provider=calls.find(c=>c.target.includes("api.razorpay.com"));assert.equal(provider.options.method,"GET");
 const save=calls.find(c=>c.target.endsWith("/rpc/srk_service_record_razorpay_refund_recovery_evidence"));
 const finalize=calls.find(c=>c.target.endsWith("/rpc/srk_service_finalize_razorpay_refund_from_recovery_evidence"));
 assert.ok(save&&finalize);assert.notEqual(calls.indexOf(save),calls.indexOf(finalize));
 const saved=JSON.parse(save.options.body);assert.equal(saved.p_admin_user_id,adminId);assert.equal(saved.p_admin_note,"Verified against Razorpay Dashboard; proceed with accounting recovery.");assert.equal(saved.p_provider_status,"processed");assert.equal(saved.p_amount_paise,12500);assert.match(saved.p_provider_payload_sha256,/^[a-f0-9]{64}$/);
 assert.deepEqual(JSON.parse(finalize.options.body),{p_recovery_audit_id:auditId});
 assert.equal(calls.some(c=>c.target.includes("api.razorpay.com")&&c.options.method!=="GET"),false);
});
test("keeps evidence ID when accounting finalization fails",async t=>{
 const calls=setup({finalizeOk:false});t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);
 assert.equal(result.statusCode,202);assert.equal(body.evidence_saved,true);assert.equal(body.accounting_finalized,false);assert.equal(body.recovery_audit_id,auditId);assert.equal(body.safe_to_retry,false);
 assert.equal(calls.filter(c=>c.target.endsWith("/rpc/srk_service_record_razorpay_refund_recovery_evidence")).length,1);
 assert.equal(calls.filter(c=>c.target.endsWith("/rpc/srk_service_finalize_razorpay_refund_from_recovery_evidence")).length,1);
});
test("stores pending provider evidence but never finalizes accounting",async t=>{
 const calls=setup({providerStatus:"pending"});t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);
 assert.equal(result.statusCode,202);assert.equal(body.evidence_saved,true);assert.equal(body.accounting_finalized,false);assert.equal(body.provider_status,"pending");
 assert.equal(calls.some(c=>c.target.endsWith("/rpc/srk_service_finalize_razorpay_refund_from_recovery_evidence")),false);
});
test("fails closed on provider amount mismatch without saving evidence",async t=>{
 const calls=setup({provider:{...providerRefund,amount:9999}});t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);
 assert.equal(result.statusCode,409);assert.equal(body.safe_to_retry,false);
 assert.equal(calls.some(c=>c.target.endsWith("/rpc/srk_service_record_razorpay_refund_recovery_evidence")),false);
});


test("finds an unlinked provider refund only by exact internal record note",async t=>{
 const calls=[];
 const unlinkedRecord={...record,refund_id:null};
 global.fetch=async(url,options={})=>{
  const target=String(url);calls.push({target,options});
  if(target.endsWith("/auth/v1/user"))return response(200,{id:adminId});
  if(target.endsWith("/rpc/is_srk_admin"))return response(200,true);
  if(target.includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[unlinkedRecord]);
  if(target.includes("/rest/v1/service_bookings?"))return response(200,[{id:bookingId,razorpay_payment_id:paymentId}]);
  if(target.includes("/payments/"+paymentId+"/refunds?count=100"))return response(200,{items:[providerRefund]});
  if(target.endsWith("/rpc/srk_service_record_razorpay_refund_recovery_evidence"))return response(200,auditId);
  if(target.endsWith("/rpc/srk_service_finalize_razorpay_refund_from_recovery_evidence"))return response(200,{success:true,status:"processed"});
  throw new Error("unexpected request "+target);
 };
 t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);
 assert.equal(result.statusCode,200);assert.equal(body.evidence_saved,true);assert.equal(body.accounting_finalized,true);
 const provider=calls.find(c=>c.target.includes("/payments/"+paymentId+"/refunds?"));
 assert.equal(provider.options.method,"GET");
 const saved=calls.find(c=>c.target.endsWith("/rpc/srk_service_record_razorpay_refund_recovery_evidence"));
 assert.equal(JSON.parse(saved.options.body).p_provider_refund_id,refundId);
});

test("does not bind an unrelated same-payment same-amount refund without exact record note or receipt",async t=>{
 const calls=[];
 const unlinkedRecord={...record,refund_id:null};
 const unrelated={...providerRefund,notes:{other_reference:"not-this-refund"},receipt:"different_receipt"};
 global.fetch=async(url,options={})=>{
  const target=String(url);calls.push(target);
  if(target.endsWith("/auth/v1/user"))return response(200,{id:adminId});
  if(target.endsWith("/rpc/is_srk_admin"))return response(200,true);
  if(target.includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[unlinkedRecord]);
  if(target.includes("/rest/v1/service_bookings?"))return response(200,[{id:bookingId,razorpay_payment_id:paymentId}]);
  if(target.includes("/payments/"+paymentId+"/refunds?count=100"))return response(200,{items:[unrelated]});
  throw new Error("unexpected request "+target);
 };
 t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);
 assert.equal(result.statusCode,202);assert.equal(body.evidence_saved,false);
 assert.equal(body.status,"provider_record_not_found_after_all_pages");assert.equal(body.safe_to_retry,false);
 assert.equal(calls.some(target=>target.endsWith("/rpc/srk_service_record_razorpay_refund_recovery_evidence")),false);
 assert.equal(calls.some(target=>target.endsWith("/rpc/srk_service_finalize_razorpay_refund_from_recovery_evidence")),false);
});


test("paginates past the first 100 refunds and recovers the exact second-page match",async t=>{
 const calls=[],firstPage=Array.from({length:100},(_,i)=>({
  id:"rfnd_other"+i,payment_id:paymentId,amount:12500,currency:"INR",status:"processed",
  notes:{srk_refund_record_id:"different-record"},receipt:"different-receipt"
 }));
 const unlinkedRecord={...record,refund_id:null};
 global.fetch=async(url,options={})=>{
  const target=String(url);calls.push({target,options});
  if(target.endsWith("/auth/v1/user"))return response(200,{id:adminId});
  if(target.endsWith("/rpc/is_srk_admin"))return response(200,true);
  if(target.includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[unlinkedRecord]);
  if(target.includes("/rest/v1/service_bookings?"))return response(200,[{id:bookingId,razorpay_payment_id:paymentId}]);
  if(target.includes("/payments/"+paymentId+"/refunds?count=100&skip=0"))return response(200,{items:firstPage});
  if(target.includes("/payments/"+paymentId+"/refunds?count=100&skip=100"))return response(200,{items:[providerRefund]});
  if(target.endsWith("/rpc/srk_service_record_razorpay_refund_recovery_evidence"))return response(200,auditId);
  if(target.endsWith("/rpc/srk_service_finalize_razorpay_refund_from_recovery_evidence"))return response(200,{success:true,status:"processed"});
  throw new Error("unexpected request "+target);
 };
 t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);
 assert.equal(result.statusCode,200);assert.equal(body.accounting_finalized,true);
 const pages=calls.filter(c=>c.target.includes("/payments/"+paymentId+"/refunds?"));
 assert.equal(pages.length,2);assert.ok(pages[0].target.endsWith("count=100&skip=0"));assert.ok(pages[1].target.endsWith("count=100&skip=100"));
});
