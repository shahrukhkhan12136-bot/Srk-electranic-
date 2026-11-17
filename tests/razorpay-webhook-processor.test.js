const test=require("node:test");
const assert=require("node:assert/strict");
process.env.SUPABASE_URL="https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY="service-role-test-secret";
process.env.RAZORPAY_WEBHOOK_SECRET="webhook-test-secret";
const {processWebhookPayload}=require("../razorpay-webhook.js");
const originalFetch=global.fetch;
const response=(status,data)=>({ok:status>=200&&status<300,status,json:async()=>data});
const deadline=()=>Date.now()+52000;
const rpcName=url=>String(url).split("/").pop();

test("does not settle a Cash booking from a captured webhook",async t=>{
  const calls=[];global.fetch=async url=>{calls.push(String(url));if(String(url).includes("/rest/v1/service_bookings?"))return response(200,[{id:"booking-cash",payment_method:"Cash",payment_status:"unpaid",razorpay_payment_id:null,selected_category:"home_wiring",status:"completed"}]);throw new Error("unexpected request "+String(url));};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await processWebhookPayload({payload:{payment:{entity:{id:"pay_cashblocked",order_id:"order_cashblocked",status:"captured",amount:50000,currency:"INR"}}}},"payment.captured",deadline());
  assert.deepEqual(result,{outcome:"ignored",reason:"payment_method_not_online"});
  assert.equal(calls.length,1);
});

test("does not re-open a refunded booking from a captured webhook",async t=>{
  let calls=0;global.fetch=async url=>{calls++;if(String(url).includes("/rest/v1/service_bookings?"))return response(200,[{id:"booking-refunded",payment_method:"Razorpay online",payment_status:"refunded",razorpay_payment_id:null,selected_category:"home_wiring",status:"completed"}]);throw new Error("unexpected request "+String(url));};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await processWebhookPayload({payload:{payment:{entity:{id:"pay_refundblocked",order_id:"order_refundblocked",status:"captured",amount:50000,currency:"INR"}}}},"payment.captured",deadline());
  assert.deepEqual(result,{outcome:"ignored",reason:"payment_refunded"});assert.equal(calls,1);
});

test("settles only an exact new-category payment breakdown",async t=>{
  const calls=[];global.fetch=async(url,options={})=>{const target=String(url);calls.push(target);if(target.includes("/rest/v1/service_bookings?"))return response(200,[{id:"booking-new",payment_method:"online",payment_status:"pending",razorpay_payment_id:null,selected_category:"new_category",status:"completed"}]);if(rpcName(target)==="srk_service_role_get_booking_payment_breakdown")return response(200,{total_amount_paise:12500});if(rpcName(target)==="srk_service_role_record_online_booking_payment"){const body=JSON.parse(options.body);assert.equal(body.p_booking_id,"booking-new");assert.equal(body.p_amount_paise,12500);return response(200,{success:true});}throw new Error("unexpected request "+target);};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await processWebhookPayload({payload:{payment:{entity:{id:"pay_new123",order_id:"order_new123",status:"captured",amount:12500,currency:"INR"}}}},"payment.captured",deadline());
  assert.deepEqual(result,{outcome:"processed",result:"updated"});assert.equal(calls.length,3);
});

test("reconciles a processed refund against exact payment, amount and receipt",async t=>{
  let reconcile=null;global.fetch=async(url,options={})=>{const target=String(url);if(target.includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[{id:"refund-record-1",payment_id:"pay_refund123",refund_id:null,idempotency_key:"refund_key_12345",amount_paise:12500,status:"processing"}]);if(rpcName(target)==="srk_service_reconcile_booking_refund"){reconcile=JSON.parse(options.body);return response(200,{success:true,status:"processed"});}throw new Error("unexpected request "+target);};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await processWebhookPayload({payload:{refund:{entity:{id:"rfnd_processed123",payment_id:"pay_refund123",amount:12500,currency:"INR",status:"processed",receipt:"refund_key_12345"}}}},"refund.processed",deadline());
  assert.equal(result.outcome,"processed");assert.equal(reconcile.p_refund_record_id,"refund-record-1");assert.equal(reconcile.p_provider_refund_id,"rfnd_processed123");
});

test("rejects a refund whose provider amount differs from the prepared record",async t=>{
  let reconcileCalls=0;global.fetch=async url=>{if(String(url).includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[{id:"refund-record-2",payment_id:"pay_mismatch",refund_id:null,idempotency_key:"key_expected",amount_paise:12500,status:"processing"}]);if(rpcName(url)==="srk_service_reconcile_booking_refund")reconcileCalls++;throw new Error("unexpected request "+String(url));};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await processWebhookPayload({payload:{refund:{entity:{id:"rfnd_mismatch123",payment_id:"pay_mismatch",amount:9999,currency:"INR",status:"processed"}}}},"refund.processed",deadline());
  assert.deepEqual(result,{outcome:"ignored",reason:"refund_record_mismatch"});assert.equal(reconcileCalls,0);
});

test("does not match an unrelated same-payment same-amount refund without receipt or record note",async t=>{
  let reconcileCalls=0;global.fetch=async url=>{if(String(url).includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[{id:"refund-record-3",payment_id:"pay_unrelated",refund_id:null,idempotency_key:"expected_receipt",amount_paise:12500,status:"processing"}]);if(rpcName(url)==="srk_service_reconcile_booking_refund")reconcileCalls++;throw new Error("unexpected request "+String(url));};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await processWebhookPayload({payload:{refund:{entity:{id:"rfnd_unrelated",payment_id:"pay_unrelated",amount:12500,currency:"INR",status:"processed",receipt:"different_receipt",notes:{srk_booking_id:"other"}}}}},"refund.processed",deadline());
  assert.deepEqual(result,{outcome:"ignored",reason:"refund_record_mismatch"});assert.equal(reconcileCalls,0);
});

test("allows an immediately processed refund.created event",async t=>{
  let providerStatus=null;global.fetch=async(url,options={})=>{const target=String(url);if(target.includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[{id:"refund-record-4",payment_id:"pay_created",refund_id:null,idempotency_key:"created_receipt",amount_paise:12500,status:"processing"}]);if(rpcName(target)==="srk_service_reconcile_booking_refund"){providerStatus=JSON.parse(options.body).p_provider_status;return response(200,{success:true,status:"processed"});}throw new Error("unexpected request "+target);};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await processWebhookPayload({payload:{refund:{entity:{id:"rfnd_created123",payment_id:"pay_created",amount:12500,currency:"INR",status:"processed",receipt:"created_receipt"}}}},"refund.created",deadline());
  assert.equal(result.outcome,"processed");assert.equal(providerStatus,"processed");
});

test("routes a signed failed refund status to the server-side reconciliation RPC",async t=>{
  let body=null;global.fetch=async(url,options={})=>{const target=String(url);if(target.includes("/rest/v1/srk_razorpay_refunds?"))return response(200,[{id:"refund-record-5",payment_id:"pay_failed",refund_id:"rfnd_failed123",idempotency_key:"failed_receipt",amount_paise:12500,status:"processing"}]);if(rpcName(target)==="srk_service_reconcile_booking_refund"){body=JSON.parse(options.body);return response(200,{success:true,status:"failed"});}throw new Error("unexpected request "+target);};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await processWebhookPayload({payload:{refund:{entity:{id:"rfnd_failed123",payment_id:"pay_failed",amount:12500,currency:"INR",status:"failed"}}}},"refund.failed",deadline());
  assert.equal(result.outcome,"processed");assert.equal(body.p_provider_status,"failed");assert.equal(body.p_provider_refund_id,"rfnd_failed123");
});

test("surfaces transient refund lookup failure for durable worker retry",async t=>{
  global.fetch=async url=>{if(String(url).includes("/rest/v1/srk_razorpay_refunds?"))return response(503,{});throw new Error("unexpected request "+String(url));};
  t.after(()=>{global.fetch=originalFetch;});
  await assert.rejects(()=>processWebhookPayload({payload:{refund:{entity:{id:"rfnd_retry123",payment_id:"pay_retry123",amount:12500,currency:"INR",status:"processed"}}}},"refund.processed",deadline()),/Refund record lookup failed/);
});
