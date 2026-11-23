const test=require("node:test");
const assert=require("node:assert/strict");
const crypto=require("node:crypto");
const fs=require("node:fs");
const path=require("node:path");

process.env.SUPABASE_URL="https://supabase.test";
process.env.SUPABASE_SERVICE_ROLE_KEY="service-role-test";
process.env.RAZORPAY_KEY_ID="rzp_test_key";
process.env.RAZORPAY_KEY_SECRET="rzp_test_secret";
process.env.RAZORPAY_WEBHOOK_SECRET="webhook-test-secret";

const createOrder=require("../create-order").handler;
const verifyPayment=require("../verify-payment").handler;
const webhook=require("../razorpay-webhook").handler;
const BOOKING_ID="123e4567-e89b-42d3-a456-426614174000";
const USER_ID="123e4567-e89b-42d3-a456-426614174001";
const BILL_ID="123e4567-e89b-42d3-a456-426614174002";
const ATTEMPT_ID="123e4567-e89b-42d3-a456-426614174003";
const ORDER_ID="order_test123456";
const PAYMENT_ID="pay_test123456";
const EVENT_ID="evt_test123456";
const AUTH="Bearer customer-session-token";
const baseBooking=()=>({
 id:BOOKING_ID,phone:"9876543210",customer_user_id:USER_ID,
 payment_status:"unpaid",payment_method:"Online",
 razorpay_order_id:null,razorpay_payment_id:null,status:"completed"
});
const baseBill=()=>({
 id:BILL_ID,booking_id:BOOKING_ID,service_amount:199,
 materials_amount:1000,discount_amount:0,tax_amount:0,
 total_amount:1199,revision_no:1,status:"issued"
});
const baseAttempt=()=>({
 id:ATTEMPT_ID,booking_id:BOOKING_ID,customer_user_id:USER_ID,
 final_bill_id:BILL_ID,final_bill_revision:1,amount_paise:119900,
 currency:"INR",idempotency_key:"srk-order-test-12345678",
 receipt:"srk_testreceipt123456",status:"creating",razorpay_order_id:null
});
function response(status,value){const raw=JSON.stringify(value);return {ok:status>=200&&status<300,status,text:async()=>raw,json:async()=>JSON.parse(raw)};}
function event(body,headers={}){return {httpMethod:"POST",headers,body:typeof body==="string"?body:JSON.stringify(body)};}
function setupFetch({booking=baseBooking(),bill=baseBill(),attempt=baseAttempt(),lock=true,
 capturedAmount=119900,finalizeResult={success:true,already_processed:false},
 existingAttempt=null,webhookEventStatus="received"}={}){
 const calls=[];
 global.fetch=async(input,options={})=>{
  const url=String(input),method=options.method||"GET",body=options.body?JSON.parse(options.body):null;
  calls.push({url,method,body,headers:options.headers||{}});
  if(url.includes("/auth/v1/user"))return response(200,{id:USER_ID,phone:"+919876543210",phone_confirmed_at:"2026-01-01T00:00:00Z"});
  if(url.includes("/rpc/srk_claim_payment_order_lock"))return response(200,lock?"lock-token":null);
  if(url.includes("/rpc/srk_release_payment_order_lock"))return response(200,true);
  if(url.includes("/rpc/srk_service_start_razorpay_payment_order"))return response(200,attempt);
  if(url.includes("/rpc/srk_service_attach_razorpay_order"))return response(200,{...attempt,status:"created",razorpay_order_id:ORDER_ID});
  if(url.includes("/rpc/srk_service_mark_razorpay_order_failure"))return response(200,true);
  if(url.includes("/rpc/srk_service_finalize_razorpay_payment"))return response(200,finalizeResult);
  if(url.includes("api.razorpay.com/v1/orders")&&method==="POST")return response(200,{id:ORDER_ID,status:"created",amount:capturedAmount,currency:"INR"});
  if(url.includes("api.razorpay.com/v1/orders/"))return response(200,{id:ORDER_ID,status:"created",amount:capturedAmount,currency:"INR"});
  if(url.includes("api.razorpay.com/v1/payments/"))return response(200,{id:PAYMENT_ID,order_id:ORDER_ID,status:"captured",currency:"INR",amount:capturedAmount});
  if(url.includes("/rest/v1/service_bookings"))return response(200,[booking]);
  if(url.includes("/rest/v1/srk_booking_final_bills"))return response(200,[bill]);
  if(url.includes("/rest/v1/srk_razorpay_payment_orders")){
   if(url.includes("razorpay_order_id=eq."))return response(200,[{...attempt,status:"created",razorpay_order_id:ORDER_ID}]);
   return response(200,existingAttempt?[existingAttempt]:[]);
  }
  if(url.includes("/rest/v1/srk_razorpay_webhook_events")&&method==="POST")return response(201,[]);
  if(url.includes("/rest/v1/srk_razorpay_webhook_events")&&method==="GET")return response(200,[{event_id:EVENT_ID,processing_status:webhookEventStatus}]);
  if(url.includes("/rest/v1/srk_razorpay_webhook_events")&&method==="PATCH")return response(200,[{event_id:EVENT_ID,processing_status:body.processing_status}]);
  return response(404,{message:"unexpected request "+url});
 };
 return {calls,booking,bill,attempt};
}

test("create-order charges the complete issued final bill, including materials, without adding Razorpay fee",async()=>{
 const {calls}=setupFetch();
 const result=await createOrder(event({booking_id:BOOKING_ID},{authorization:AUTH}));
 assert.equal(result.statusCode,200);
 const body=JSON.parse(result.body);
 assert.equal(body.amount,119900);
 const orderCall=calls.find(x=>x.url.includes("api.razorpay.com/v1/orders")&&x.method==="POST");
 assert.ok(orderCall);
 assert.equal(orderCall.body.amount,119900);
 assert.equal(orderCall.body.notes.billing_basis,"final_bill_total");
 assert.ok(calls.some(x=>x.url.includes("/rpc/srk_service_start_razorpay_payment_order")));
 assert.ok(calls.some(x=>x.url.includes("/rpc/srk_service_attach_razorpay_order")));
 assert.equal(calls.some(x=>x.url.includes("srk_service_get_labour_bill_for_payment")),false);
 assert.equal(calls.some(x=>x.url.includes("/rpc/srk_link_payment_order")),false);
});

test("create-order rejects a payment attempt created against a newer final bill revision",async()=>{
 const attempt={...baseAttempt(),final_bill_revision:2};
 const {calls}=setupFetch({attempt});
 const result=await createOrder(event({booking_id:BOOKING_ID},{authorization:AUTH}));
 assert.equal(result.statusCode,409);
 assert.equal(calls.some(x=>x.url.includes("api.razorpay.com/v1/orders")&&x.method==="POST"),false);
 assert.ok(calls.some(x=>x.url.includes("/rpc/srk_service_start_razorpay_payment_order")));
 const failure=calls.find(x=>x.url.includes("/rpc/srk_service_mark_razorpay_order_failure"));
 assert.equal(failure.body.p_failure_code,"final_bill_snapshot_changed");
 assert.equal(failure.body.p_uncertain,false);
});

test("create-order fails closed when no issued final bill exists",async()=>{
 setupFetch({bill:null});
 const result=await createOrder(event({booking_id:BOOKING_ID},{authorization:AUTH}));
 assert.equal(result.statusCode,409);
});

test("create-order rejects a booking owned by another customer",async()=>{
 const {booking}=setupFetch();
 booking.customer_user_id="123e4567-e89b-42d3-a456-426614174099";
 const result=await createOrder(event({booking_id:BOOKING_ID},{authorization:AUTH}));
 assert.equal(result.statusCode,403);
});

test("create-order refuses Cash bookings",async()=>{
 const {booking}=setupFetch();booking.payment_method="Cash";
 const result=await createOrder(event({booking_id:BOOKING_ID},{authorization:AUTH}));
 assert.equal(result.statusCode,409);
});

test("create-order does not call Razorpay when the DB order lock is held elsewhere",async()=>{
 const {calls}=setupFetch({lock:false});
 const result=await createOrder(event({booking_id:BOOKING_ID},{authorization:AUTH}));
 assert.equal(result.statusCode,409);
 assert.equal(calls.some(x=>x.url.includes("api.razorpay.com/v1/orders")&&x.method==="POST"),false);
});

test("create-order reuses an existing created order only when it matches the exact final bill revision",async()=>{
 const existing={...baseAttempt(),status:"created",razorpay_order_id:ORDER_ID};
 const {calls}=setupFetch({existingAttempt:existing});
 const result=await createOrder(event({booking_id:BOOKING_ID},{authorization:AUTH}));
 assert.equal(result.statusCode,200);
 assert.equal(JSON.parse(result.body).order_id,ORDER_ID);
 assert.equal(calls.some(x=>x.url.includes("api.razorpay.com/v1/orders")&&x.method==="POST"),false);
});

test("verify-payment requires valid HMAC and finalizes exact captured full bill amount",async()=>{
 const {calls}=setupFetch();
 const signature=crypto.createHmac("sha256",process.env.RAZORPAY_KEY_SECRET).update(ORDER_ID+"|"+PAYMENT_ID).digest("hex");
 const result=await verifyPayment(event({razorpay_payment_id:PAYMENT_ID,razorpay_order_id:ORDER_ID,razorpay_signature:signature},{authorization:AUTH}));
 assert.equal(result.statusCode,200);
 const finalize=calls.find(x=>x.url.includes("/rpc/srk_service_finalize_razorpay_payment"));
 assert.ok(finalize);
 assert.deepEqual(finalize.body,{
  p_razorpay_order_id:ORDER_ID,p_razorpay_payment_id:PAYMENT_ID,
  p_amount_paise:119900,p_currency:"INR"
 });
 assert.equal(calls.some(x=>x.url.includes("srk_service_finalize_captured_payment")),false);
});

test("verify-payment rejects a captured amount that differs from the final bill order snapshot",async()=>{
 setupFetch({capturedAmount:119800});
 const signature=crypto.createHmac("sha256",process.env.RAZORPAY_KEY_SECRET).update(ORDER_ID+"|"+PAYMENT_ID).digest("hex");
 const result=await verifyPayment(event({razorpay_payment_id:PAYMENT_ID,razorpay_order_id:ORDER_ID,razorpay_signature:signature},{authorization:AUTH}));
 assert.equal(result.statusCode,409);
});

test("verify-payment rejects an invalid signature before contacting Razorpay",async()=>{
 const {calls}=setupFetch();
 const result=await verifyPayment(event({razorpay_payment_id:PAYMENT_ID,razorpay_order_id:ORDER_ID,razorpay_signature:"a".repeat(64)},{authorization:AUTH}));
 assert.equal(result.statusCode,400);
 assert.equal(calls.some(x=>x.url.includes("api.razorpay.com/v1/payments/")),false);
});

test("webhook verifies signature, stores deduplicated event, and finalizes through atomic DB RPC",async()=>{
 const {calls}=setupFetch();
 const payload={event:"payment.captured",payload:{payment:{entity:{id:PAYMENT_ID,order_id:ORDER_ID,status:"captured",currency:"INR",amount:119900}}}};
 const raw=JSON.stringify(payload);
 const signature=crypto.createHmac("sha256",process.env.RAZORPAY_WEBHOOK_SECRET).update(raw).digest("hex");
 const result=await webhook(event(raw,{"x-razorpay-signature":signature,"x-razorpay-event-id":EVENT_ID}));
 assert.equal(result.statusCode,200);
 assert.equal(JSON.parse(result.body).reconciled,true);
 assert.ok(calls.some(x=>x.url.includes("/rest/v1/srk_razorpay_webhook_events")&&x.method==="POST"));
 assert.ok(calls.some(x=>x.url.includes("/rpc/srk_service_finalize_razorpay_payment")));
 assert.equal(calls.some(x=>x.method==="PATCH"&&x.body?.processing_status==="reconciled"),true);
});

test("webhook refuses captured amount mismatch and preserves exception for reconciliation",async()=>{
 const {calls}=setupFetch({capturedAmount:119800,finalizeResult:{success:false}});
 const payload={event:"payment.captured",payload:{payment:{entity:{id:PAYMENT_ID,order_id:ORDER_ID,status:"captured",currency:"INR",amount:119800}}}};
 const raw=JSON.stringify(payload);
 const signature=crypto.createHmac("sha256",process.env.RAZORPAY_WEBHOOK_SECRET).update(raw).digest("hex");
 const result=await webhook(event(raw,{"x-razorpay-signature":signature,"x-razorpay-event-id":EVENT_ID}));
 assert.equal(result.statusCode,500);
 assert.equal(JSON.parse(result.body).reconciled,false);
 assert.equal(calls.some(x=>x.method==="PATCH"&&x.body?.processing_status==="exception"),true);
});

test("webhook requires provider event ID for safe deduplication",async()=>{
 const {calls}=setupFetch();
 const raw=JSON.stringify({event:"payment.captured",payload:{payment:{entity:{id:PAYMENT_ID,order_id:ORDER_ID,status:"captured",currency:"INR",amount:119900}}}});
 const signature=crypto.createHmac("sha256",process.env.RAZORPAY_WEBHOOK_SECRET).update(raw).digest("hex");
 const result=await webhook(event(raw,{"x-razorpay-signature":signature}));
 assert.equal(result.statusCode,400);
 assert.equal(calls.length,0);
});

test("payment finalizer requires an exact non-null Booking-to-Order link and immutable bill revision",()=>{
 const migration=fs.readFileSync(path.join(__dirname,"../supabase/migrations/20261123091500_require_exact_booking_order_link_in_razorpay_finalizer.sql"),"utf8");
 assert.match(migration,/razorpay_order_id is distinct from p_razorpay_order_id/);
 assert.match(migration,/v_bill\.revision_no is distinct from v_attempt\.final_bill_revision/);
 assert.match(migration,/round\(v_bill\.total_amount\*100\)::bigint<>v_attempt\.amount_paise/);
});
