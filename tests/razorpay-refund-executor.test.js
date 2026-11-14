const test=require("node:test");
const assert=require("node:assert/strict");
process.env.SUPABASE_URL="https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY="test-key";
process.env.RAZORPAY_KEY_ID="test-id";
process.env.RAZORPAY_KEY_SECRET="test-secret";
const {handler}=require("../razorpay-refund.js");
test("refund endpoint rejects missing login",async()=>{
 const result=await handler({httpMethod:"POST",headers:{},body:"{}"});
 assert.equal(result.statusCode,401);
});

const bookingId="123e4567-e89b-42d3-a456-426614174000";
const record={refund_record_id:"223e4567-e89b-42d3-a456-426614174000",booking_id:bookingId,payment_id:"pay_ABC123456",amount_paise:12500,idempotency_key:"srkrefund123456789",status:"requested"};
const req=()=>({httpMethod:"POST",headers:{authorization:"Bearer test-user-token-1234567890"},body:JSON.stringify({booking_id:bookingId,reason:"ग्राहक की सत्यापित शिकायत के कारण पूरा refund आवश्यक है।"})});
const reply=(status,data)=>({ok:status>=200&&status<300,status,json:async()=>data,text:async()=>JSON.stringify(data)});
const originalFetch=global.fetch;

test("requires Main Admin membership before provider request",async t=>{
 let providerCalls=0;
 global.fetch=async url=>{
  if(String(url).endsWith("/auth/v1/user"))return reply(200,{id:"user-1"});
  if(String(url).endsWith("/rpc/is_srk_admin"))return reply(200,false);
  if(String(url).includes("razorpay.com"))providerCalls++;
  throw new Error("unexpected request");
 };
 t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(req());
 assert.equal(result.statusCode,403);
 assert.equal(providerCalls,0);
});

test("uses stable refund idempotency key and reconciles provider response",async t=>{
 let providerOptions,reconcileBody;
 global.fetch=async(url,options={})=>{
  const target=String(url);
  if(target.endsWith("/auth/v1/user"))return reply(200,{id:"admin-1"});
  if(target.endsWith("/rpc/is_srk_admin"))return reply(200,true);
  if(target.endsWith("/rpc/srk_admin_prepare_razorpay_refund"))return reply(200,[record]);
  if(target.includes("api.razorpay.com/v1/payments/")){
   providerOptions=options;
   return reply(200,{id:"rfnd_ABC123",payment_id:record.payment_id,amount:record.amount_paise,currency:"INR",status:"pending"});
  }
  if(target.endsWith("/rpc/srk_service_reconcile_booking_refund")){
   reconcileBody=JSON.parse(options.body);
   return reply(200,{success:true,status:"processing"});
  }
  throw new Error("unexpected request: "+target);
 };
 t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(req());
 assert.equal(result.statusCode,200);
 assert.equal(providerOptions.headers["X-Refund-Idempotency"],record.idempotency_key);
 assert.equal(JSON.parse(providerOptions.body).amount,record.amount_paise);
 assert.equal(reconcileBody.p_provider_refund_id,"rfnd_ABC123");
 assert.equal(reconcileBody.p_provider_status,"pending");
});

test("does not mark an ambiguous provider timeout as failed",async t=>{
 let reconcileCalls=0;
 global.fetch=async url=>{
  const target=String(url);
  if(target.endsWith("/auth/v1/user"))return reply(200,{id:"admin-1"});
  if(target.endsWith("/rpc/is_srk_admin"))return reply(200,true);
  if(target.endsWith("/rpc/srk_admin_prepare_razorpay_refund"))return reply(200,[record]);
  if(target.includes("api.razorpay.com"))throw new Error("network timeout");
  if(target.endsWith("/rpc/srk_service_reconcile_booking_refund"))reconcileCalls++;
  throw new Error("unexpected request: "+target);
 };
 t.after(()=>{global.fetch=originalFetch;});
 const result=await handler(req());
 assert.equal(result.statusCode,503);
 assert.equal(JSON.parse(result.body).status,"unknown");
 assert.equal(reconcileCalls,0);
});
