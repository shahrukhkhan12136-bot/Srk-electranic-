const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");

process.env.SUPABASE_URL="https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY="service-role-test-secret";
process.env.RAZORPAY_WEBHOOK_SECRET="webhook-test-secret";
const {handler}=require("../netlify/functions/razorpay-webhook-consumer.js");
const originalFetch=global.fetch;
const response=(status,data)=>({ok:status>=200&&status<300,status,json:async()=>data});
const event=(eventId)=>({body:JSON.stringify({event_id:eventId}),headers:{"x-srk-webhook-worker-auth":crypto.createHmac("sha256",process.env.SUPABASE_SERVICE_ROLE_KEY).update(eventId).digest("hex")}});
const rpcName=url=>String(url).split("/").pop();

test("rejects an unauthenticated consumer invocation before claiming an event",async t=>{
  let calls=0;global.fetch=async()=>{calls++;throw new Error("must not fetch");};t.after(()=>{global.fetch=originalFetch;});
  const result=await handler({body:JSON.stringify({event_id:"evt_private"}),headers:{}});
  assert.equal(result.statusCode,401);assert.equal(calls,0);
});

test("claims one durable event, runs the processor, and fences completion with the worker claim token",async t=>{
  const calls=[];global.fetch=async(url,options={})=>{
    const fn=rpcName(url);calls.push(fn);
    if(fn==="srk_service_claim_razorpay_webhook_event_for_worker")return response(200,[{event_id:"evt_worker_ok",event_type:"payment.authorized",event_payload:{},claim_token:"123e4567-e89b-42d3-a456-426614174000",attempt_count:1}]);
    if(fn==="srk_service_complete_razorpay_webhook_event"){const body=JSON.parse(options.body);assert.equal(body.p_event_id,"evt_worker_ok");assert.equal(body.p_claim_token,"123e4567-e89b-42d3-a456-426614174000");assert.equal(body.p_outcome,"ignored");assert.equal(body.p_error,"unsupported_event_type");return response(200,{success:true,state:"ignored"});}
    throw new Error("unexpected request "+String(url));
  };
  t.after(()=>{global.fetch=originalFetch;});
  const result=await handler(event("evt_worker_ok"));
  assert.equal(result.statusCode,200);assert.equal(JSON.parse(result.body).state,"ignored");
  assert.deepEqual(calls,["srk_service_claim_razorpay_webhook_event_for_worker","srk_service_complete_razorpay_webhook_event"]);
});

test("persists retryable state when refund reconciliation fails and surfaces the worker failure",async t=>{
  const completions=[];global.fetch=async(url,options={})=>{
    const target=String(url),fn=rpcName(target);
    if(fn==="srk_service_claim_razorpay_webhook_event_for_worker")return response(200,[{event_id:"evt_worker_retry",event_type:"refund.processed",event_payload:{payload:{refund:{entity:{id:"rfnd_worker123",payment_id:"pay_worker123",status:"processed",currency:"INR",amount:12500,receipt:"refund_key"}}}},claim_token:"223e4567-e89b-42d3-a456-426614174000",attempt_count:1}]);
    if(target.includes("/rest/v1/srk_razorpay_refunds?"))return response(503,{});
    if(fn==="srk_service_complete_razorpay_webhook_event"){completions.push(JSON.parse(options.body));return response(200,{success:true,state:"retryable"});}
    throw new Error("unexpected request "+target);
  };
  t.after(()=>{global.fetch=originalFetch;});
  await assert.rejects(()=>handler(event("evt_worker_retry")));
  assert.equal(completions.length,1);assert.equal(completions[0].p_outcome,"retryable");
  assert.equal(completions[0].p_claim_token,"223e4567-e89b-42d3-a456-426614174000");
});

test("does not acknowledge a worker claim when durable completion is rejected",async t=>{
  global.fetch=async(url)=>{
    const fn=rpcName(url);
    if(fn==="srk_service_claim_razorpay_webhook_event_for_worker")return response(200,[{event_id:"evt_worker_stale",event_type:"payment.authorized",event_payload:{},claim_token:"323e4567-e89b-42d3-a456-426614174000",attempt_count:1}]);
    if(fn==="srk_service_complete_razorpay_webhook_event")return response(200,{success:false,stale_claim:true});
    throw new Error("unexpected request "+String(url));
  };
  t.after(()=>{global.fetch=originalFetch;});
  await assert.rejects(()=>handler(event("evt_worker_stale")));
});
