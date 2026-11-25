'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const technician=fs.readFileSync('electrician.html','utf8');
const admin=fs.readFileSync('admin.html','utf8');
test('Technician screen loads canonical Master wallet across categories',()=>{
 assert.match(technician,/sb\.rpc\('srk_master_wallet_summary'\)/);
 assert.match(technician,/earned_paise/);
 assert.match(technician,/pending_paise/);
 assert.match(technician,/requested_paise/);
 assert.match(technician,/paid_paise/);
});
test('Technician can submit an idempotent UPI or bank payout request',()=>{
 assert.match(technician,/function requestMasterTechnicianPayout\(\)/);
 assert.match(technician,/srk_technician_request_master_payout/);
 assert.match(technician,/p_destination_type:type/);
 assert.match(technician,/p_idempotency_key:key/);
});
test('Admin screen reviews canonical Worker payout requests and stores private transfer evidence',()=>{
 assert.match(admin,/from\('srk_worker_payout_requests'\)/);
 assert.match(admin,/srk_admin_review_worker_payout/);
 assert.match(admin,/srk_admin_attach_worker_payout_evidence/);
 assert.match(admin,/srk_admin_mark_worker_payout_paid/);
 assert.match(admin,/srk-worker-payout-evidence/);
 assert.match(admin,/p_storage_path:path/);
 assert.match(admin,/p_payment_reference:ref/);
});
test('Admin payout is blocked without Main Admin verified UPI and transfer evidence',()=>{
 assert.match(admin,/w\.payout_details_change_status==='approved'&&w\.upi_id/);
 assert.match(admin,/!\['upi','phonepe'\]\.includes\(method\)/);
 assert.match(admin,/file\.size>10\*1024\*1024/);
 assert.match(admin,/बैंक खाते के अंतिम 4 अंक से बैंक ट्रांसफर करना सुरक्षित नहीं है/);
});
test('Existing legacy wallet and payout UI remains present',()=>{
 assert.match(technician,/srk_get_my_wallet_summary/);
 assert.match(technician,/srk_electrician_payouts/);
 assert.match(admin,/srk_electrician_payouts/);
 assert.match(admin,/srk_admin_mark_electrician_payout_paid/);
});
test('Modified inline JavaScript parses',()=>{
 for(const [name,html] of [['electrician.html',technician],['admin.html',admin]]){
  const scripts=[...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim());
  assert.ok(scripts.length>0,name+' inline script exists');
  scripts.forEach((script,i)=>assert.doesNotThrow(()=>new vm.Script(script,{filename:name+'#'+i}),name+' script '+i+' syntax'));
 }
});
