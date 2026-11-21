const test=require("node:test");
const assert=require("node:assert/strict");
process.env.SUPABASE_URL="https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY="service-key";
process.env.RAZORPAY_KEY_ID="key-id";
process.env.RAZORPAY_KEY_SECRET="key-secret";
const {handler}=require("../razorpay-refund-status.js");
const bookingId="123e4567-e89b-42d3-a456-426614174000";
const recordId="223e4567-e89b-42d3-a456-426614174000";
const paymentId="pay_status123";
const refundId="rfnd_status123";
const record={id:recordId,booking_id:bookingId,payment_id:paymentId,refund_id:refundId,amount_paise:12500,idempotency_key:"srkrefund123456789",status:"processing",provider_status:"pending",last_error:null};
const response=(status,data)=>({ok:status>=200&&status<300,status,text:async()=>JSON.stringify(data)});
const originalFetch=global.fetch;
const request=()=>({httpMethod:"POST",headers:{authorization:"Bearer test-admin-token-123456789"},body:JSON.stringify({booking_id:bookingId})});
function setupProvider(refund= {id:refundId,payment_id:paymentId,amount:12500,currency:"INR",status:"processed",notes:{srk_refund_record_id:recordId},created_at:123,acquirer_data:{arn:"ARN123"},notes:{srk_refund_record_id:recordId}}){
 const calls=[];
 global.fetch=async(url,options={})=>{
  const target=String(url);calls.push({target,options});
  if(target.endsWith("/auth/v1/user"))return response(200,{id:"admin-1"});
  if(target.endsWith("/rpc/is_srk_admin"))return response(200,true);
  if(target.includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[record]);
  if(target.includes("/rest/v1/service_bookings?"))return response(200,[{id:bookingId,razorpay_payment_id:paymentId}]);
  if(target.includes("api.razorpay.com/v1/refunds/"))return response(200,refund);
  throw new Error("unexpected request "+target);
 };
 return calls;
}
test("rejects missing admin session before any provider request",async t=>{
 let calls=0;global.fetch=async()=>{calls++;return response(401,{});};t.after(()=>{global.fetch=originalFetch;});
 const result=await handler({httpMethod:"POST",headers:{},body:"{}"});
 assert.equal(result.statusCode,401);assert.equal(calls,0);
});
test("requires Main Admin membership before provider lookup",async t=>{
 let providerCalls=0;global.fetch=async url=>{if(String(url).endsWith("/auth/v1/user"))return response(200,{id:"user"});if(String(url).endsWith("/rpc/is_srk_admin"))return response(200,false);if(String(url).includes("razorpay.com"))providerCalls++;throw new Error("unexpected");};t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());assert.equal(result.statusCode,403);assert.equal(providerCalls,0);
});
test("fetches exact stored refund ID using GET and makes no provider writes",async t=>{
 const calls=setupProvider();t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);
 assert.equal(result.statusCode,200);assert.equal(body.verified,true);assert.equal(body.provider.status,"processed");assert.equal(body.provider.acquirer_reference,"ARN123");
 const provider=calls.find(x=>x.target.includes("api.razorpay.com"));
 assert.equal(provider.options.method,"GET");assert.equal(provider.target,"https://api.razorpay.com/v1/refunds/"+refundId);
 assert.equal(calls.some(x=>x.target.includes("/rpc/")&&!x.target.endsWith("/rpc/is_srk_admin")),false);
});
test("does not claim no refund when first page has no matching provider record",async t=>{
 const calls=[];global.fetch=async(url,options={})=>{const target=String(url);calls.push({target,options});if(target.endsWith("/auth/v1/user"))return response(200,{id:"admin"});if(target.endsWith("/rpc/is_srk_admin"))return response(200,true);if(target.includes("/srk_razorpay_refunds?"))return response(200,[{...record,refund_id:null}]);if(target.includes("/service_bookings?"))return response(200,[{id:bookingId,razorpay_payment_id:paymentId}]);if(target.includes("/payments/"+paymentId+"/refunds?"))return response(200,{items:[]});throw new Error("unexpected "+target);};t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);assert.equal(result.statusCode,202);assert.equal(body.verified,false);assert.equal(body.safe_to_retry,false);assert.equal(body.status,"provider_record_not_found_after_all_pages");
});
test("fails closed when provider refund amount or payment differs",async t=>{
 const calls=setupProvider({id:refundId,payment_id:paymentId,amount:9999,currency:"INR",status:"processed"});t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);assert.equal(result.statusCode,409);assert.equal(body.verified,false);assert.equal(body.safe_to_retry,false);
});
test("requires internal booking payment ID to match before contacting Razorpay",async t=>{
 let providerCalls=0;global.fetch=async url=>{const target=String(url);if(target.endsWith("/auth/v1/user"))return response(200,{id:"admin"});if(target.endsWith("/rpc/is_srk_admin"))return response(200,true);if(target.includes("/srk_razorpay_refunds?"))return response(200,[record]);if(target.includes("/service_bookings?"))return response(200,[{id:bookingId,razorpay_payment_id:"pay_different"}]);if(target.includes("razorpay.com"))providerCalls++;throw new Error("unexpected "+target);};t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());assert.equal(result.statusCode,409);assert.equal(providerCalls,0);
});


test("read-only status lookup paginates to the exact refund on page two",async t=>{
 const calls=[],firstPage=Array.from({length:100},(_,i)=>({
  id:"rfnd_status_other"+i,payment_id:paymentId,amount:12500,currency:"INR",status:"processed",
  notes:{srk_refund_record_id:"other-record"},receipt:"other-receipt"
 }));
 const unlinkedRecord={...record,refund_id:null};
 global.fetch=async(url,options={})=>{
  const target=String(url);calls.push({target,options});
  if(target.endsWith("/auth/v1/user"))return response(200,{id:"admin-1"});
  if(target.endsWith("/rpc/is_srk_admin"))return response(200,true);
  if(target.includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[unlinkedRecord]);
  if(target.includes("/rest/v1/service_bookings?"))return response(200,[{id:bookingId,razorpay_payment_id:paymentId}]);
  if(target.includes("/payments/"+paymentId+"/refunds?count=100&skip=0"))return response(200,{items:firstPage});
  if(target.includes("/payments/"+paymentId+"/refunds?count=100&skip=100"))return response(200,{items:[{id:refundId,payment_id:paymentId,amount:12500,currency:"INR",status:"processed",notes:{srk_refund_record_id:recordId},created_at:123,acquirer_data:{arn:"ARN123"}}]});
  throw new Error("unexpected request "+target);
 };
 t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(request());const body=JSON.parse(result.body);
 assert.equal(result.statusCode,200);assert.equal(body.verified,true);assert.equal(body.provider.refund_id,refundId);
 assert.equal(body.read_only,true);
 const pages=calls.filter(c=>c.target.includes("/payments/"+paymentId+"/refunds?"));
 assert.equal(pages.length,2);assert.ok(pages[0].target.endsWith("count=100&skip=0"));assert.ok(pages[1].target.endsWith("count=100&skip=100"));
});
