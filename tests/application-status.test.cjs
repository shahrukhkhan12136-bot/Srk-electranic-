const test=require('node:test');
const assert=require('node:assert/strict');
process.env.SUPABASE_URL='https://unit-test.supabase.co';
process.env.SUPABASE_SERVICE_ROLE_KEY='unit-test-only-not-a-real-secret';
const {handler}=require('../application-status.js');
const originalFetch=global.fetch;
let calls,config;
function response(status,value){const raw=JSON.stringify(value);return{ok:status>=200&&status<300,status,json:async()=>JSON.parse(raw)};}
function setup(){calls=[];config={allowed:true,authStatus:200,rowsStatus:200,user:{id:'user-1',phone:'+919876543210',phone_confirmed_at:'2026-01-01T00:00:00Z'},rows:[{id:'app-1',verification_status:'pending',created_at:'2026-11-13T10:00:00Z',requested_category:'skilled_electrician',district:'Balrampur',state:'Uttar Pradesh',pincode:'271861',phone:'9876543210'}]};global.fetch=async(url,options={})=>{calls.push({url:String(url),options});if(String(url).includes('/rpc/srk_check_public_rate_limit'))return response(200,config.allowed);if(String(url).includes('/auth/v1/user'))return response(config.authStatus,config.user);if(String(url).includes('/rest/v1/electrician_applications'))return response(config.rowsStatus,config.rows);throw new Error('Unexpected fetch '+url);};}
function event(overrides={}){return{httpMethod:'GET',headers:{authorization:'Bearer verified-session-token','x-nf-client-connection-ip':'203.0.113.10'},...overrides};}
test.beforeEach(setup);test.afterEach(()=>{global.fetch=originalFetch;});
test('rejects non-GET requests',async()=>{const r=await handler(event({httpMethod:'POST'}));assert.equal(r.statusCode,405);assert.equal(calls.length,0);});
test('requires an authenticated bearer session',async()=>{const r=await handler(event({headers:{'x-nf-client-connection-ip':'203.0.113.10'}}));assert.equal(r.statusCode,401);assert.equal(calls.length,0);});
test('rejects invalid Supabase access tokens',async()=>{config.authStatus=401;const r=await handler(event());assert.equal(r.statusCode,401);assert.equal(calls.some(x=>x.url.includes('electrician_applications')),false);});
test('requires phone-confirmed auth user',async()=>{config.user={id:'user-1',phone:'+919876543210',phone_confirmed_at:null};const r=await handler(event());assert.equal(r.statusCode,403);assert.equal(calls.some(x=>x.url.includes('electrician_applications')),false);});
test('rate limits status checks before auth and application lookup',async()=>{config.allowed=false;const r=await handler(event());assert.equal(r.statusCode,429);assert.equal(calls.some(x=>x.url.includes('/auth/v1/user')),false);});
test('returns only minimal status fields for applications matching verified phone',async()=>{const r=await handler(event());assert.equal(r.statusCode,200);const body=JSON.parse(r.body);assert.equal(body.applications.length,1);assert.equal(body.applications[0].status,'pending');assert.equal(body.applications[0].district,'Balrampur');assert.equal('phone' in body.applications[0],false);assert.equal('full_name' in body.applications[0],false);const q=calls.find(x=>x.url.includes('/rest/v1/electrician_applications'));assert.ok(q.url.includes('phone=eq.9876543210'));assert.equal(q.options.headers.Authorization,'Bearer unit-test-only-not-a-real-secret');});
test('returns an empty result without exposing whether other phone numbers have applications',async()=>{config.rows=[];const r=await handler(event());assert.equal(r.statusCode,200);assert.deepEqual(JSON.parse(r.body).applications,[]);});
