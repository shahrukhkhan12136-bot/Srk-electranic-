"use strict";
const test=require("node:test");
const assert=require("node:assert/strict");
const {createAiAssistantRuntime}=require("../lib/ai-assistant-runtime");
const actor="123e4567-e89b-42d3-a456-426614174001";
const key="123e4567-e89b-42d3-a456-426614174002";
const conversation="123e4567-e89b-42d3-a456-426614174003";
const message="123e4567-e89b-42d3-a456-426614174004";
const input={module_key:"customer_support",message:"नमस्ते"};
const env={AI_GATEWAY_ENABLED:"true",AI_GATEWAY_API_KEY:"test-key",AI_GATEWAY_MODEL:"provider/test"};
const args={input,userId:actor,idempotencyKey:key,supabaseUrl:"https://project.supabase.co",serviceRoleKey:"service-test"};
const res=(data,status=200)=>({ok:status>=200&&status<300,status,json:async()=>data});

test("feature flag off is inert and makes no database or provider request",async()=>{
 let calls=0;
 const result=await createAiAssistantRuntime({env:{},fetchImpl:async()=>{calls++;}}).handle(args);
 assert.equal(result.statusCode,503);
 assert.equal(JSON.parse(result.body).error,"ai_not_enabled");
 assert.equal(calls,0);
});

test("new assistant turn persists user message and completes fenced idempotency response",async()=>{
 const calls=[];let internalError="";
 const runtime=createAiAssistantRuntime({env,onError:e=>{internalError=e;},fetchImpl:async(url,opt={})=>{
  calls.push({url,opt});
  if(url.includes("srk_ai_reserve_idempotency"))return res({state:"reserved",id:key,lease_version:1});
  if(url.includes("srk_ai_reserve_request_capacity"))return res({state:"allowed",remaining_window:9,remaining_today:99});
  if(url.includes("srk_ai_create_conversation"))return res({state:"created",conversation_id:conversation});
  if(url.includes("srk_ai_append_message"))return res({state:"appended"});
  if(url.includes("/rest/v1/srk_ai_messages?"))return res([{sender_kind:"user",body:"नमस्ते"}]);
  if(url==="https://ai-gateway.vercel.sh/v1/chat/completions"){
   assert.equal(JSON.parse(opt.body).messages.at(-1).content,"नमस्ते");
   return res({choices:[{message:{content:"नमस्ते! कैसे मदद करूँ?"}}],usage:{prompt_tokens:31,completion_tokens:12,total_tokens:43}});
  }
  if(url.includes("srk_ai_record_usage_event")){
   const body=JSON.parse(opt.body);
   assert.equal(body.p_actor_user_id,actor);
   assert.equal(body.p_conversation_id,conversation);
   assert.equal(body.p_request_id,key);
   assert.equal(body.p_provider_key,"vercel_ai_gateway");
   assert.equal(body.p_model_key,"provider/test");
   assert.equal(body.p_usage_available,true);
   assert.equal(body.p_prompt_tokens,31);
   assert.equal(body.p_completion_tokens,12);
   assert.equal(body.p_total_tokens,43);
   assert.equal(JSON.stringify(body).includes("नमस्ते"),false);
   return res({state:"recorded"});
  }
  if(url.includes("srk_ai_complete_idempotency")){
   const body=JSON.parse(opt.body);
   assert.equal(body.p_lease_version,1);
   assert.equal(body.p_conversation_id,conversation);
   assert.equal(body.p_request_sha256.length,66);
   assert.equal(body.p_response_body,"नमस्ते! कैसे मदद करूँ?");
   return res({state:"completed",response_message_id:message});
  }
  throw Error("unexpected request "+url);
 }});
 const result=await runtime.handle(args);
 assert.equal(result.statusCode,200,internalError);
 assert.equal(JSON.parse(result.body).reply,"नमस्ते! कैसे मदद करूँ?");
 assert.equal(calls.filter(x=>x.url==="https://ai-gateway.vercel.sh/v1/chat/completions").length,1);
});


test("server-side request limit returns 429 and never calls provider",async()=>{
 const calls=[];
 const runtime=createAiAssistantRuntime({env,fetchImpl:async(url,opt={})=>{
  calls.push({url,opt});
  if(url.includes("srk_ai_reserve_idempotency"))return res({state:"reserved",id:key,lease_version:1});
  if(url.includes("srk_ai_reserve_request_capacity"))return res({state:"rate_limited",scope:"window",retry_after_seconds:240});
  if(url.includes("srk_ai_finalize_idempotency"))return res({state:"failed"});
  if(url==="https://ai-gateway.vercel.sh/v1/chat/completions")throw Error("provider must not be called");
  throw Error("unexpected request "+url);
 }});
 const result=await runtime.handle(args);
 assert.equal(result.statusCode,429);
 assert.equal(result.headers["Retry-After"],"240");
 assert.equal(JSON.parse(result.body).error,"ai_rate_limited");
 assert.equal(calls.some(x=>x.url==="https://ai-gateway.vercel.sh/v1/chat/completions"),false);
 assert.equal(calls.some(x=>x.url.includes("srk_ai_finalize_idempotency")),true);
});

test("rate-limit storage failure fails closed before conversation or provider work",async()=>{
 const calls=[];
 const runtime=createAiAssistantRuntime({env,fetchImpl:async(url,opt={})=>{
  calls.push(url);
  if(url.includes("srk_ai_reserve_idempotency"))return res({state:"reserved",id:key,lease_version:1});
  if(url.includes("srk_ai_reserve_request_capacity"))throw Error("database unavailable");
  if(url.includes("srk_ai_finalize_idempotency"))return res({state:"failed"});
  throw Error("unexpected request "+url);
 }});
 const result=await runtime.handle(args);
 assert.equal(result.statusCode,503);
 assert.equal(JSON.parse(result.body).error,"ai_service_unavailable");
 assert.equal(calls.some(url=>url.includes("srk_ai_create_conversation")),false);
 assert.equal(calls.some(url=>url==="https://ai-gateway.vercel.sh/v1/chat/completions"),false);
});
test("idempotent replay returns persisted reply without another model request",async()=>{
 let modelCalls=0;let internalError="";
 const runtime=createAiAssistantRuntime({env,onError:e=>{internalError=e;},fetchImpl:async(url)=>{
  if(url.includes("srk_ai_reserve_idempotency"))return res({state:"replay",response_message_id:message,response_code:200,conversation_id:conversation});
  if(url.includes("/rest/v1/srk_ai_messages?"))return res([{id:message,conversation_id:conversation,sender_kind:"assistant",body:"पहले वाला जवाब"}]);
  if(url==="https://ai-gateway.vercel.sh/v1/chat/completions")modelCalls++;
  throw Error("unexpected request");
 }});
 const result=await runtime.handle(args);
 assert.equal(result.statusCode,200,internalError);
 assert.equal(JSON.parse(result.body).reply,"पहले वाला जवाब");
 assert.equal(JSON.parse(result.body).replayed,true);
 assert.equal(modelCalls,0);
});

test("processing, conflicting and failed idempotency claims do not invoke provider",async()=>{
 for(const state of ["processing","conflict","failed"]){
  let modelCalls=0;
  const runtime=createAiAssistantRuntime({env,fetchImpl:async(url)=>{
   if(url.includes("srk_ai_reserve_idempotency"))return res({state});
   if(url==="https://ai-gateway.vercel.sh/v1/chat/completions")modelCalls++;
   throw Error("unexpected request");
  }});
  const result=await runtime.handle(args);
  assert.equal(result.statusCode,state==="failed"?503:409);
  assert.equal(modelCalls,0);
 }
});


test("missing provider usage is explicitly recorded without inventing token counts",async()=>{
 let recorded;
 const runtime=createAiAssistantRuntime({env,fetchImpl:async(url,opt={})=>{
  if(url.includes("srk_ai_reserve_idempotency"))return res({state:"reserved",id:key,lease_version:1});
  if(url.includes("srk_ai_reserve_request_capacity"))return res({state:"allowed"});
  if(url.includes("srk_ai_create_conversation"))return res({state:"created",conversation_id:conversation});
  if(url.includes("srk_ai_append_message"))return res({state:"appended"});
  if(url.includes("/rest/v1/srk_ai_messages?"))return res([{sender_kind:"user",body:"नमस्ते"}]);
  if(url==="https://ai-gateway.vercel.sh/v1/chat/completions")return res({choices:[{message:{content:"ठीक है"}}]});
  if(url.includes("srk_ai_record_usage_event")){
   recorded=JSON.parse(opt.body);
   return res({state:"recorded"});
  }
  if(url.includes("srk_ai_complete_idempotency"))return res({state:"completed"});
  if(url.includes("srk_ai_finalize_idempotency"))return res({state:"failed"});
  throw Error("unexpected request "+url);
 }});
 const result=await runtime.handle(args);
 assert.equal(result.statusCode,200);
 assert.equal(recorded.p_usage_available,false);
 assert.equal(recorded.p_prompt_tokens,null);
 assert.equal(recorded.p_completion_tokens,null);
 assert.equal(recorded.p_total_tokens,null);
});

test("usage ledger failure prevents an unmetered assistant response",async()=>{
 const calls=[];
 const runtime=createAiAssistantRuntime({env,fetchImpl:async(url,opt={})=>{
  calls.push(url);
  if(url.includes("srk_ai_reserve_idempotency"))return res({state:"reserved",id:key,lease_version:1});
  if(url.includes("srk_ai_reserve_request_capacity"))return res({state:"allowed"});
  if(url.includes("srk_ai_create_conversation"))return res({state:"created",conversation_id:conversation});
  if(url.includes("srk_ai_append_message"))return res({state:"appended"});
  if(url.includes("/rest/v1/srk_ai_messages?"))return res([{sender_kind:"user",body:"नमस्ते"}]);
  if(url==="https://ai-gateway.vercel.sh/v1/chat/completions")return res({choices:[{message:{content:"उत्तर"}}],usage:{prompt_tokens:3,completion_tokens:2,total_tokens:5}});
  if(url.includes("srk_ai_record_usage_event"))throw Error("ledger unavailable");
  if(url.includes("srk_ai_finalize_idempotency"))return res({state:"failed"});
  throw Error("unexpected request "+url);
 }});
 const result=await runtime.handle(args);
 assert.equal(result.statusCode,503);
 assert.equal(calls.some(url=>url.includes("srk_ai_complete_idempotency")),false);
 assert.equal(calls.some(url=>url.includes("srk_ai_finalize_idempotency")),true);
});
