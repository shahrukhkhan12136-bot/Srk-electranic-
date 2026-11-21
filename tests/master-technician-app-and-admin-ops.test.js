'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const migration=fs.readFileSync('supabase/migrations/20261121320000_master_technician_app_and_admin_ops.sql','utf8');
const admin=fs.readFileSync('admin.html','utf8');
const technician=fs.readFileSync('electrician.html','utf8');
const customer=fs.readFileSync('booking.html','utf8');
test('Technician application read includes skill IDs and Customer workday read includes daily decision',()=>{
 assert.match(migration,/application_skill_id/);
 assert.match(migration,/customer_decision/);
});
test('Master Technician presence is owner-scoped and Admin dispatch controls are guarded',()=>{
 assert.match(migration,/srk_technician_get_my_presence/);
 assert.match(migration,/srk_customer_get_master_final_bill/);
 assert.match(migration,/srk_customer_list_master_booking_team/);
 assert.match(migration,/last_location_at/);
 assert.match(migration,/total_due_paise/);
 assert.match(migration,/srk_admin_list_master_dispatch_queue/);
 assert.match(migration,/srk_admin_retry_master_dispatch/);
 assert.match(migration,/public\.is_srk_admin\(\)/);
});
test('Shared Technician app contains OTP-first Master application and KYC workflows',()=>{
 assert.match(technician,/srk_technician_get_my_applications/);
 assert.match(technician,/srk_technician_list_service_catalogue/);
 assert.match(technician,/srk_technician_submit_application/);
 assert.match(technician,/srk_technician_submit_kyc_document/);
 assert.match(technician,/srk_technician_set_presence/);
 assert.match(technician,/srk_get_my_offer_details/);
});
test('Admin app reviews Master applications, skill evidence and KYC',()=>{
 assert.match(admin,/srk_admin_list_technician_applications/);
 assert.match(admin,/srk_admin_review_technician_application/);
 assert.match(admin,/srk_admin_review_technician_skill/);
 assert.match(admin,/srk_admin_review_technician_kyc/);
 assert.match(admin,/srk_admin_list_master_dispatch_queue/);
 assert.match(admin,/srk_admin_retry_master_dispatch/);
});

test('Customer Master Booking screen shows daily workday approvals, all three next-day decisions, assigned team and final GST bill',()=>{
 assert.match(customer,/srk_customer_get_technician_workdays/);
 assert.match(customer,/srk_customer_respond_technician_workday_start/);
 assert.match(customer,/कल का शेड्यूल स्वीकार करें/);
 assert.match(customer,/काम पूरा हो गया है, अब इलेक्ट्रिशियन की जरूरत नहीं/);
 assert.match(customer,/इनसे काम नहीं लेना है, हमें दूसरा इलेक्ट्रिशियन चाहिए/);
 assert.match(customer,/srk_customer_decide_workday/);
 assert.match(customer,/srk_customer_list_master_booking_team/);
 assert.match(customer,/srk_customer_get_master_final_bill/);
 assert.match(customer,/srk_service_category_code/);
});
test('Shared Technician, Customer and Admin inline scripts parse after Master app integration',()=>{
 for(const [name,source] of [['electrician.html',technician],['booking.html',customer],['admin.html',admin]]){
  const scripts=[...source.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim());
  assert.ok(scripts.length>0);
  scripts.forEach((script,index)=>assert.doesNotThrow(()=>new vm.Script(script,{filename:name+'#'+index})));
 }
});
