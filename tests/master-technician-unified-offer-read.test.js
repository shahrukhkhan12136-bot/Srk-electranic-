'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const migration=fs.readFileSync('supabase/migrations/20261121310000_master_technician_unified_offer_read.sql','utf8');
const technician=fs.readFileSync('electrician.html','utf8');
test('Unified offer read RPC preserves legacy offers and adds Master dispatch offers',()=>{
 assert.match(migration,/DROP FUNCTION IF EXISTS public\.srk_get_my_offer_details/);
 assert.match(migration,/public\.job_offers/);
 assert.match(migration,/public\.srk_technician_dispatch_offers/);
 assert.match(migration,/offer_source/);
 assert.match(migration,/srk_service_category_code/);
 assert.match(migration,/workday_id/);
});
test('Shared Technician App can respond to Master dispatch offers and manage workday timer',()=>{
 assert.match(technician,/srk_technician_respond_to_dispatch_offer/);
 assert.match(technician,/srk_technician_request_workday_start/);
 assert.match(technician,/srk_technician_pause_workday/);
 assert.match(technician,/srk_technician_resume_workday/);
 assert.match(technician,/srk_technician_stop_workday/);
});
test('Technician app identifies Master offers separately from legacy Electrician offers',()=>{
 assert.match(technician,/offer_source/);
 assert.match(technician,/srk_service_category_code/);
});
test('Technician inline JavaScript parses',()=>{
 const scripts=[...technician.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim());
 assert.ok(scripts.length>0);
 scripts.forEach((script,index)=>assert.doesNotThrow(()=>new vm.Script(script,{filename:'electrician.html#'+index})));
});
