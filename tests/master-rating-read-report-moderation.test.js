'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const migration=fs.readFileSync('supabase/migrations/20261121290000_master_rating_read_report_moderation.sql','utf8');
const customer=fs.readFileSync('booking.html','utf8');
const technician=fs.readFileSync('electrician.html','utf8');
const admin=fs.readFileSync('admin.html','utf8');
test('Rating read APIs expose only completed participant bookings and published aggregates',()=>{
 assert.match(migration,/b\.customer_user_id=auth\.uid\(\)/);
 assert.match(migration,/a\.assignment_status='completed'/);
 assert.match(migration,/b\.completion_approval_status='approved'/);
 assert.match(migration,/moderation_status='published'/);
 assert.match(migration,/srk_customer_list_master_rating_tasks/);
 assert.match(migration,/srk_technician_list_master_rating_tasks/);
});
test('Rating reports can be submitted only by the person targeted by that rating',()=>{
 assert.match(migration,/ONLY_RATING_SUBJECT_CAN_REPORT/);
 assert.match(migration,/srk_master_rating_reporter_once_uidx/);
 assert.match(migration,/srk_master_report_booking_rating/);
});
test('Admin moderation/report queue is Main Admin-gated and audit events are append-only',()=>{
 assert.match(migration,/public\.is_srk_admin\(\)/);
 assert.match(migration,/srk_admin_list_master_booking_ratings/);
 assert.match(migration,/srk_admin_list_master_rating_reports/);
 assert.match(migration,/srk_admin_resolve_master_rating_report/);
 assert.match(migration,/RATING_REPORT_HISTORY_IS_APPEND_ONLY/);
});
test('Customer, Technician and Admin rating panels are wired to secured RPCs',()=>{
 assert.match(customer,/srk_customer_list_master_rating_tasks/);
 assert.match(customer,/srk_customer_rate_master_technician/);
 assert.match(technician,/srk_technician_list_master_rating_tasks/);
 assert.match(technician,/srk_technician_rate_master_customer/);
 assert.match(admin,/srk_admin_list_master_booking_ratings/);
 assert.match(admin,/srk_admin_list_master_rating_reports/);
});
test('Rating UI inline scripts parse',()=>{
 for(const [name,source] of [['booking.html',customer],['electrician.html',technician],['admin.html',admin]]){
  const scripts=[...source.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim());
  assert.ok(scripts.length>0);
  scripts.forEach((script,index)=>assert.doesNotThrow(()=>new vm.Script(script,{filename:name+'#'+index})));
 }
});
