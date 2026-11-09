// Synthetic-only Admin Razorpay refund endpoint test; provider and Supabase are mocked.
const assert=require("node:assert/strict");
process.env.SUPABASE_URL="https://mock.supabase.test";
process.env.SUPABASE_SERVICE_ROLE_KEY="mock-service-role";
process.env.RAZORPAY_KEY_ID="rzp_test_mock";
process.env.RAZORPAY_KEY_SECRET="mock-secret";
const {handler}=require("../razorpay-refund.js");
const token="synthetic.admin.jwt.token.with.sufficient.length";
let prepared,providerCalls=[],patches=[];
let providerStatus=200;
const reset=()=>{prepared={refund_record_id:"qa-refund-row",booking_id:"11111111-1111-4111-8111-111111111111",payment_id:"pay_QATEST01",amount_paise:12000,idempotency_key:"0123456789abcdef0123456789abcdef",status:"requested",previous_payout_note:"old note"};providerCalls=[];patches=[];providerStatus=200;};
global.fetch=async(input,init={})=>{
 const url=new URL(input),method=init.method||"GET";
 if(url.pathname==="/auth/v1/user")return Response.json({id:"22222222-2222-4222-8222-222222222222"});
 if(url.pathname==="/rest/v1/rpc/srk_admin_prepare_razorpay_refund")return Response.json([structuredClone(prepared)]);
 if(url.hostname==="api.razorpay.com"){
  providerCalls.push({url:url.toString(),headers:init.headers,body:JSON.parse(init.body)});
  if(providerStatus!==200)return Response.json({error:{description:"mock provider response"}},{status:providerStatus});
  return Response.json({id:"rfnd_QATEST01",payment_id:"pay_QATEST01",amount:12000,status:"pending"});
 }
 if(url.pathname==="/rest/v1/srk_razorpay_refunds"&&method==="PATCH"){patches.push(JSON.parse(init.body));return new Response(null,{status:204});}
 if(url.pathname==="/rest/v1/srk_electrician_payouts"&&method==="PATCH"){patches.push(JSON.parse(init.body));return new Response(null,{status:204});}
 return new Response("unexpected mock request "+url.pathname,{status:500});
};
const request=(headers={},body={booking_id:"11111111-1111-4111-8111-111111111111",reason:"Customer approved full refund after service issue"})=>({httpMethod:"POST",headers,body:JSON.stringify(body)});
(async()=>{
 reset();
 let r=await handler(request());
 assert.equal(r.statusCode,401);assert.equal(providerCalls.length,0);
 console.log("PASS refund endpoint requires Admin session token");

 reset();
 r=await handler(request({authorization:"Bearer "+token}));
 assert.equal(r.statusCode,202);let out=JSON.parse(r.body);assert.equal(out.status,"processing");
 assert.equal(providerCalls.length,1);assert.equal(providerCalls[0].headers["X-Refund-Idempotency"],prepared.idempotency_key);
 assert.equal(providerCalls[0].body.amount,12000);assert.equal(patches[0].status,"processing");
 console.log("PASS Admin request uses persisted same-operation idempotency key and exact full amount");

 prepared.status="unknown";
 r=await handler(request({authorization:"Bearer "+token}));
 assert.equal(r.statusCode,202);assert.equal(providerCalls[1].headers["X-Refund-Idempotency"],providerCalls[0].headers["X-Refund-Idempotency"]);
 console.log("PASS uncertain retry reuses same Razorpay refund idempotency key");

 reset();providerStatus=400;
 r=await handler(request({authorization:"Bearer "+token}));
 assert.equal(r.statusCode,409);assert.equal(patches[0].status,"failed");
 assert.equal(patches[1].payout_status,"pending");assert.equal(patches[1].payout_note,"old note");
 console.log("PASS definitive provider rejection marks failed and restores payout hold");

 console.log(JSON.stringify({passed:4,realSupabaseCalls:0,realRazorpayCalls:0,realRefundIssued:false},null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
