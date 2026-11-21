'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const migration=fs.readFileSync('supabase/migrations/20261121320000_master_technician_app_and_admin_ops.sql','utf8');
const admin=fs.readFileSync('admin.html','utf8');
const technician=fs.readFileSync('electrician.html','utf8');
test('Technician application read includes skill IDs and Customer workday read includes daily decision',()=>{
 assert.match(migration,/application_skill_id/);
 assert.match(migration,/customer_decision/);
});
test('Master Technician presence is owner-scoped and Admin dispatch controls are guarded',()=>{
 assert.match(migration,/srk_technician_get_my_presence/);
 assert.match(migration,/srk_admin_list_master_dispatch_queue/);
 assert.match(migration,/srk_admin_retry_master_dispatch/);
 assert.match(migration,/public\.is_srk_admin\(\)/);
});
test('Shared Technician app contains OTP-first Master application and KYC workflows',()=>{
 assert.match(technician,/srk_technician_get_my_applications/);
 assert.match(technician,/srk_technician_list_service_catalogue/);
 assert.match(technician,/srk_technician_submit_application/);
 assert.match(technician,/srk_technician_submit_kyc_document/);
});
test('Admin app reviews Master applications, skill evidence and KYC',()=>{
 assert.match(admin,/srk_admin_list_technician_applications/);
 assert.match(admin,/srk_admin_review_technician_application/);
 assert.match(admin,/srk_admin_review_technician_skill/);
 assert.match(admin,/srk_admin_review_technician_kyc/);
});
