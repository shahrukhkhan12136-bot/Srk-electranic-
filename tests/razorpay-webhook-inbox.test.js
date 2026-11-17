const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");

process.env.SUPABASE_URL = "https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY = "service-role-test-secret";
process.env.RAZORPAY_WEBHOOK_SECRET = "webhook-test-secret";
process.env.URL = "https://srk-test.netlify.app";

const { handler } = require("../razorpay-webhook.js");
const originalFetch = global.fetch;
const response = (status,data) => ({ok:status>=200&&status<300,status,json:async()=>data});
const event = (payload,eventId="evt_test_123",mixedCase=false) => {
  const body=JSON.stringify(payload);
  const signature=crypto.createHmac("sha256",process.env.RAZORPAY_WEBHOOK_SECRET).update(Buffer.from(body)).digest("hex");
  return {httpMethod:"POST",headers:mixedCase?{"X-RaZoRpAy-SiGnAtUrE":signature,"X-RaZoRpAy-EvEnT-Id":eventId}:{"x-razorpay-signature":signature,"x-razorpay-event-id":eventId},body,isBase64Encoded:false};
};
const rpcName = url => String(url).split("/").pop();

test("rejects invalid signature before durable enqueue",async t=>{
  let calls=0; global.fetch=async()=>{calls++;throw new Error("must not fetch");};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await handler({...event({event:"payment.captured"}),headers:{"x-razorpay-signature":"0".repeat(64)}});
  assert.equal(result.statusCode,400); assert.equal(calls,0);
});

test("verifies mixed-case headers, durably queues a minimal payment projection, and triggers background processing",async t=>{
  const calls=[]; global.fetch=async(url,options={})=>{
    calls.push({url:String(url),options});
    if(rpcName(url)==="srk_service_enqueue_razorpay_webhook_event"){
      const body=JSON.parse(options.body);
      assert.equal(body.p_event_id,"evt_fast_ack"); assert.equal(body.p_event_type,"payment.captured");
      assert.match(body.p_payload_sha256,/^[a-f0-9]{64}$/);
      assert.deepEqual(body.p_event_payload,{payload:{payment:{entity:{id:"pay_abc123",order_id:"order_abc123",status:"captured",amount:12500,currency:"INR"}}}});
      assert.ok(options.signal instanceof AbortSignal);
      return response(200,{success:true,accepted:true,queued:true,event_id:"evt_fast_ack"});
    }
    assert.equal(new URL(url).pathname,"/.netlify/functions/razorpay-webhook-consumer");
    assert.equal(JSON.parse(options.body).event_id,"evt_fast_ack");
    assert.equal(options.headers["x-srk-webhook-worker-auth"],crypto.createHmac("sha256",process.env.SUPABASE_SERVICE_ROLE_KEY).update("evt_fast_ack").digest("hex"));
    return response(202,{});
  };
  t.after(()=>{global.fetch=originalFetch;});
  const incoming=event({event:"payment.captured",payload:{payment:{entity:{id:"pay_abc123",order_id:"order_abc123",status:"captured",amount:12500,currency:"INR",email:"private@example.com",contact:"9999999999"}}}},"evt_fast_ack",true);
  const result=await handler(incoming);
  assert.equal(result.statusCode,200); assert.equal(JSON.parse(result.body).accepted,true);
  assert.equal(calls.length,2);
});

test("does not trigger a worker again for an already processed duplicate",async t=>{
  let calls=0; global.fetch=async(url)=>{calls++;assert.equal(rpcName(url),"srk_service_enqueue_razorpay_webhook_event");return response(200,{success:true,accepted:true,duplicate:true,state:"processed",event_id:"evt_done"});};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await handler(event({event:"payment.authorized"},"evt_done"));
  assert.equal(result.statusCode,200); assert.equal(calls,1); assert.equal(JSON.parse(result.body).duplicate,true);
});

test("retries when the durable inbox cannot confirm acceptance",async t=>{
  global.fetch=async()=>response(503,{}); t.after(()=>{global.fetch=originalFetch;});
  const result=await handler(event({event:"payment.captured"},"evt_db_down"));
  assert.equal(result.statusCode,503); assert.equal(JSON.parse(result.body).retry,true);
});

test("asks Razorpay to retry when the background consumer trigger is not accepted",async t=>{
  let calls=0; global.fetch=async(url)=>{calls++;if(calls===1)return response(200,{success:true,accepted:true,queued:true,event_id:"evt_trigger_down"});return response(500,{});};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await handler(event({event:"payment.captured"},"evt_trigger_down"));
  assert.equal(result.statusCode,503); assert.equal(calls,2);
});

test("reuses the canonical event ID when the same signed body is replayed with a different header",async t=>{
  const ids=[];global.fetch=async(url,options={})=>{
    if(rpcName(url)==="srk_service_enqueue_razorpay_webhook_event"){const b=JSON.parse(options.body);ids.push(b.p_event_id);assert.deepEqual(b.p_event_payload,{payload:{refund:{entity:{id:"rfnd_abc123",payment_id:"pay_abc123",status:"processed",currency:"INR",amount:12500,receipt:"refund_key",notes:{srk_refund_record_id:"refund-record-id"}}}}});return response(200,{success:true,accepted:true,duplicate:true,state:"queued",event_id:"evt_original"});}
    assert.equal(JSON.parse(options.body).event_id,"evt_original");
    return response(202,{});
  };
  t.after(()=>{global.fetch=originalFetch;});
  const payload={event:"refund.processed",payload:{refund:{entity:{id:"rfnd_abc123",payment_id:"pay_abc123",status:"processed",currency:"INR",amount:12500,receipt:"refund_key",notes:{srk_refund_record_id:"refund-record-id",private_note:"do not persist"}}}}};
  const body=JSON.stringify(payload);
  const signature=crypto.createHmac("sha256",process.env.RAZORPAY_WEBHOOK_SECRET).update(body).digest("hex");
  const first=await handler({httpMethod:"POST",headers:{"x-razorpay-signature":signature,"x-razorpay-event-id":"evt_original"},body});
  const second=await handler({httpMethod:"POST",headers:{"x-razorpay-signature":signature,"x-razorpay-event-id":"evt_changed"},body});
  assert.equal(first.statusCode,200);assert.equal(second.statusCode,200);assert.deepEqual(ids,["evt_original","evt_changed"]);
});

test("returns a payload conflict without replacing an existing signed event",async t=>{
  global.fetch=async()=>response(200,{success:false,accepted:false,payload_conflict:true});
  t.after(()=>{global.fetch=originalFetch;});
  const result=await handler(event({event:"payment.captured"},"evt_conflict"));
  assert.equal(result.statusCode,200);assert.equal(JSON.parse(result.body).reason,"event_id_payload_conflict");
});
