const test=require("node:test");
const assert=require("node:assert/strict");
const crypto=require("node:crypto");
process.env.SUPABASE_URL="https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY="service-role-test-secret";
process.env.URL="https://srk-test.netlify.app";
const {handler,config}=require("../netlify/functions/razorpay-webhook-sweeper.js");
const originalFetch=global.fetch;
const response=(status,data)=>({ok:status>=200&&status<300,status,json:async()=>data});

test("scheduled sweeper re-dispatches due events to the authenticated background consumer",async t=>{
  const calls=[];global.fetch=async(url,options={})=>{calls.push({url:String(url),options});if(String(url).includes("srk_service_list_due_razorpay_webhook_events"))return response(200,[{event_id:"evt_sweep_1"},{event_id:"evt_sweep_2"}]);assert.equal(new URL(url).pathname,"/.netlify/functions/razorpay-webhook-consumer");const id=JSON.parse(options.body).event_id;assert.equal(options.headers["x-srk-webhook-worker-auth"],crypto.createHmac("sha256",process.env.SUPABASE_SERVICE_ROLE_KEY).update(id).digest("hex"));return response(202,{});};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await handler();assert.equal(result.statusCode,200);assert.deepEqual(JSON.parse(result.body),{success:true,due:2,triggered:2,failed:0});
  assert.equal(calls.length,3);assert.equal(config.schedule,"* * * * *");
});

test("reports partial recovery dispatch without deleting or completing queued events",async t=>{
  let trigger=0;global.fetch=async url=>{if(String(url).includes("srk_service_list_due_razorpay_webhook_events"))return response(200,[{event_id:"evt_sweep_ok"},{event_id:"evt_sweep_fail"}]);trigger++;return response(trigger===2?500:202,{});};
  t.after(()=>{global.fetch=originalFetch;});
  const result=await handler();assert.equal(result.statusCode,200);assert.deepEqual(JSON.parse(result.body),{success:false,due:2,triggered:1,failed:1});
});
