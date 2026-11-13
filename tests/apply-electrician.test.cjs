const test = require('node:test');
const assert = require('node:assert/strict');
process.env.SUPABASE_URL = 'https://unit-test.supabase.co';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'unit-test-only-not-a-real-secret';
const { handler } = require('../apply-electrician.js');
const originalFetch = global.fetch;
const validBody = {
  full_name:'Test Electrician',phone:'9876543210',state:'Uttar Pradesh',
  district:'Balrampur',pincode:'271861',skills:'Wiring and repairs',
  requested_category:'skilled_electrician',requested_skill_keys:['house_wiring','fan_installation'],experience_years:4,about:'Test application'
};
function response(status,value){
  const raw=typeof value==='string'?value:JSON.stringify(value);
  return {ok:status>=200&&status<300,status,text:async()=>raw,json:async()=>JSON.parse(raw)};
}
let calls,config,inserted;
function setup(){
  calls=[];inserted=null;config={rateAllowed:true,insertStatus:201};
  global.fetch=async(url,options={})=>{
    calls.push({url:String(url),options});
    if(String(url).includes('/rpc/srk_check_public_rate_limit'))return response(200,config.rateAllowed);
    if(String(url).includes('/rest/v1/electrician_applications')){
      inserted=JSON.parse(options.body);
      return config.insertStatus>=400?response(config.insertStatus,{code:'insert_failed'}):response(201,[{id:'application-1',verification_status:'pending'}]);
    }
    throw new Error('Unexpected fetch '+url);
  };
}
function event(overrides={}){return {httpMethod:'POST',headers:{'x-nf-client-connection-ip':'203.0.113.10'},body:JSON.stringify(validBody),...overrides};}
test.beforeEach(setup);test.afterEach(()=>{global.fetch=originalFetch;});
test('rejects non-POST requests without Supabase calls',async()=>{const r=await handler(event({httpMethod:'GET'}));assert.equal(r.statusCode,405);assert.equal(calls.length,0);});
test('rejects oversized payload before network calls',async()=>{const r=await handler(event({body:'x'.repeat(16385)}));assert.equal(r.statusCode,413);assert.equal(calls.length,0);});
test('requires client IP for rate limiting',async()=>{const r=await handler(event({headers:{}}));assert.equal(r.statusCode,503);assert.equal(calls.length,0);});
test('rejects rate-limited application before insert',async()=>{config.rateAllowed=false;const r=await handler(event());assert.equal(r.statusCode,429);assert.equal(inserted,null);});
test('rejects unknown or missing requested commercial category',async()=>{const r=await handler(event({body:JSON.stringify({...validBody,requested_category:'home_wiring'})}));assert.equal(r.statusCode,400);assert.equal(inserted,null);});
test('persists requested category with pending and inactive status',async()=>{const r=await handler(event());assert.equal(r.statusCode,200);assert.equal(inserted[0].requested_category,'skilled_electrician');assert.deepEqual(inserted[0].requested_skill_keys,['house_wiring','fan_installation']);assert.equal(inserted[0].verification_status,'pending');assert.equal(inserted[0].active,false);});
test('does not report success when database insert fails',async()=>{config.insertStatus=500;const r=await handler(event());assert.equal(r.statusCode,502);assert.equal(inserted[0].requested_category,'skilled_electrician');});

test('rejects unknown structured skill keys',async()=>{const r=await handler(event({body:JSON.stringify({...validBody,requested_skill_keys:['made_up_skill']})}));assert.equal(r.statusCode,400);assert.equal(inserted,null);});
test('rejects missing structured skills',async()=>{const r=await handler(event({body:JSON.stringify({...validBody,requested_skill_keys:[]})}));assert.equal(r.statusCode,400);assert.equal(inserted,null);});
test('deduplicates declared skills before persistence',async()=>{const r=await handler(event({body:JSON.stringify({...validBody,requested_skill_keys:['house_wiring','house_wiring']})}));assert.equal(r.statusCode,200);assert.deepEqual(inserted[0].requested_skill_keys,['house_wiring']);});

test('rejects more than ten structured skills',async()=>{const r=await handler(event({body:JSON.stringify({...validBody,requested_skill_keys:Array(11).fill('house_wiring')})}));assert.equal(r.statusCode,400);assert.equal(inserted,null);});
