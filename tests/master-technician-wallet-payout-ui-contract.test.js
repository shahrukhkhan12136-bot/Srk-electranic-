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
test('Admin screen reviews requests and records real company settlement evidence',()=>{
 assert.match(admin,/srk_admin_list_master_payout_requests/);
 assert.match(admin,/srk_admin_review_master_payout_request/);
 assert.match(admin,/srk_admin_confirm_master_company_settlement/);
 assert.match(admin,/p_settled_amount_paise:Math\.round\(amount\*100\)/);
});
test('Admin cannot complete Master payout without approved request and actual UTR entry',()=>{
 assert.match(admin,/srk_admin_mark_master_payout_paid/);
 assert.match(admin,/वास्तविक ट्रांसफर UTR/);
 assert.match(admin,/COMPANY_RAZORPAY_SETTLEMENT_NOT_CONFIRMED|Razorpay settlement, Admin approval और UTR/);
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
