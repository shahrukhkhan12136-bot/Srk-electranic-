// Synthetic-only Razorpay refund webhook reconciliation. No real network calls.
const assert=require("node:assert/strict");
const crypto=require("node:crypto");
process.env.SUPABASE_URL="https://mock.supabase.test";
process.env.SUPABASE_SERVICE_ROLE_KEY="mock-service-role";
process.env.RAZORPAY_WEBHOOK_SECRET="synthetic-refund-secret";
const events=new Map();
let refund,booking,payout;
let dbCalls=0;
const reset=()=>{
 events.clear();dbCalls=0;
 refund={id:"qa-refund-record",booking_id:"qa-booking",payment_id:"pay_QAREFUND01",refund_id:"rfnd_QAREFUND01",amount_paise:12000,status:"processing",previous_payout_note:"original payout note"};
 booking={id:"qa-booking",payment_status:"paid",razorpay_payment_id:"pay_QAREFUND01"};
 payout={booking_id:"qa-booking",payout_status:"blocked",payout_note:"Razorpay refund pending"};
};
global.fetch=async(input,init={})=>{
 dbCalls++;const url=new URL(input),method=init.method||"GET";
 if(url.pathname==="/rest/v1/srk_razorpay_webhook_events"){
  if(method==="POST"){const row=JSON.parse(init.body);events.set(row.event_id,{...(events.get(row.event_id)||{}),...row});return new Response(null,{status:201});}
  if(method==="PATCH"){const id=url.searchParams.get("event_id").slice(3);if(events.has(id))events.set(id,{...events.get(id),...JSON.parse(init.body)});return new Response(null,{status:204});}
 }
 if(url.pathname==="/rest/v1/srk_razorpay_refunds"&&method==="GET"){
  return Response.json(refund&&url.searchParams.get("payment_id")==="eq."+refund.payment_id&&url.searchParams.get("amount_paise")==="eq."+refund.amount_paise?[structuredClone(refund)]:[]);
 }
 if(url.pathname==="/rest/v1/srk_razorpay_refunds"&&method==="PATCH"){
  if(refund&&url.searchParams.get("id")==="eq."+refund.id)Object.assign(refund,JSON.parse(init.body));
  return Response.json(refund?[structuredClone(refund)]:[]);
 }
 if(url.pathname==="/rest/v1/service_bookings"&&method==="PATCH"){
  if(booking&&url.searchParams.get("id")==="eq."+booking.id&&url.searchParams.get("razorpay_payment_id")==="eq."+booking.razorpay_payment_id&&booking.payment_status==="paid")Object.assign(booking,JSON.parse(init.body));
  return Response.json(booking?.payment_status==="refunded"?[structuredClone(booking)]:[]);
 }
 if(url.pathname==="/rest/v1/service_bookings"&&method==="GET")return Response.json(booking?[{payment_status:booking.payment_status,razorpay_payment_id:booking.razorpay_payment_id}]:[]);
 if(url.pathname==="/rest/v1/srk_electrician_payouts"&&method==="PATCH"){
  if(payout&&url.searchParams.get("booking_id")==="eq."+payout.booking_id&&url.searchParams.get("payout_status")==="eq."+payout.payout_status&&url.searchParams.get("payout_note")==="eq."+payout.payout_note)Object.assign(payout,JSON.parse(init.body));
  return new Response(null,{status:204});
 }
 return new Response("unexpected mock request "+method+" "+url.pathname,{status:500});
};
const {handler}=require("../razorpay-webhook.js");
const entity={id:"rfnd_QAREFUND01",payment_id:"pay_QAREFUND01",amount:12000,currency:"INR",status:"processed"};
function event(status,id){
 const refundEntity={...entity,status};
 const raw=JSON.stringify({event:"refund."+status,payload:{refund:{entity:refundEntity}}});
 const signature=crypto.createHmac("sha256",process.env.RAZORPAY_WEBHOOK_SECRET).update(Buffer.from(raw)).digest("hex");
 return {httpMethod:"POST",headers:{"x-razorpay-signature":signature,"x-razorpay-event-id":id},body:raw,isBase64Encoded:false};
}
async function run(e){const r=await handler(e);return {status:r.statusCode,body:JSON.parse(r.body)}}
(async()=>{
 reset();
 let r=await run(event("processed","qa_refund_processed_1"));
 assert.equal(r.status,200);assert.equal(r.body.reconciled,true);
 assert.equal(refund.status,"processed");assert.equal(booking.payment_status,"refunded");
 assert.equal(payout.payout_status,"refunded");assert.equal(events.get("qa_refund_processed_1").processing_status,"reconciled");
 console.log("PASS signed refund.processed event updates refund, booking and payout hold");

 r=await run(event("processed","qa_refund_processed_1"));
 assert.equal(r.status,200);assert.equal(booking.payment_status,"refunded");assert.equal(payout.payout_status,"refunded");
 console.log("PASS duplicate refund webhook remains idempotent");

 reset();
 r=await run(event("failed","qa_refund_failed_1"));
 assert.equal(r.status,200);assert.equal(refund.status,"failed");
 assert.equal(payout.payout_status,"pending");assert.equal(payout.payout_note,"original payout note");
 assert.equal(booking.payment_status,"paid");
 console.log("PASS signed refund.failed event restores pending payout and leaves customer payment paid");

 reset();
 const invalid=event("processed","qa_invalid_refund_signature");invalid.headers["x-razorpay-signature"]="0".repeat(64);
 r=await run(invalid);assert.equal(r.status,400);assert.equal(dbCalls,0);
 console.log("PASS invalid webhook signature rejected before database access");
 console.log(JSON.stringify({passed:4,realSupabaseCalls:0,realRazorpayCalls:0,realRefundIssued:false},null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
