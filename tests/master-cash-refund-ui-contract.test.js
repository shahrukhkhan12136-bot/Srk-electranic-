'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const technician=fs.readFileSync('electrician.html','utf8');
const admin=fs.readFileSync('admin.html','utf8');

test('Technician can submit actual Master cash refund evidence through the secured RPC',()=>{
 assert.match(technician,/id="masterCashRefundEvidenceCard"/);
 assert.match(technician,/function submitMasterCashRefundEvidence\(\)/);
 assert.match(technician,/srk_technician_submit_master_cash_refund_evidence/);
 assert.match(technician,/p_booking_id:bookingId/);
 assert.match(technician,/p_amount_paise:Math\.round\(amount\*100\)/);
 assert.match(technician,/p_refund_reference:reference/);
 assert.match(technician,/आपने Customer को जितनी राशि वास्तव में लौटाई है/);
 assert.match(technician,/Admin की जाँच और अंतिम पुष्टि बाकी है/);
});

test('Technician cash refund evidence UI validates booking, amount and reference before RPC',()=>{
 assert.match(technician,/Math\.round\(amount\*100\)!==amount\*100/);
 assert.match(technician,/reference\.length<4\|\|reference\.length>120/);
 assert.match(technician,/masterCashRefundEvidenceBusy/);
 assert.match(technician,/Customer को वास्तव में लौटा दी है/);
});

test('Admin can inspect per-Technician cash refund evidence and finalize only a fully matched approved refund',()=>{
 assert.match(admin,/id="adminMasterCashRefundCard"/);
 assert.match(admin,/srk_admin_list_master_cash_refunds/);
 assert.match(admin,/srk_admin_finalize_master_cash_refund/);
 assert.match(admin,/r\.refund_request_status==='approved'/);
 assert.match(admin,/submitted===Number\(r\.amount_paise\|\|0\)/);
 assert.match(admin,/e\.status==='submitted'/);
 assert.match(admin,/सभी प्रमाण जाँचकर Refund अंतिम करें/);
});

test('Admin finalization requires explicit human confirmation and refreshes related financial panels',()=>{
 assert.match(admin,/क्या आपने Technician के वास्तविक Cash Refund प्रमाण जाँच लिए हैं/);
 assert.match(admin,/loadAdminMasterCashRefunds\(\),loadMasterPayouts\(\),loadAdminRefundRequests\(\)/);
});

test('Cash refund UI changes only the existing Master cash-refund RPC workflow',()=>{
 assert.match(technician,/srk_technician_submit_master_cash_refund_evidence/);
 assert.match(admin,/srk_admin_finalize_master_cash_refund/);
 assert.doesNotMatch(technician,/srk_technician_submit_master_cash_refund_evidence[^\n]*razorpay/);
});

test('Modified inline JavaScript parses',()=>{
 for(const [name,html] of [['electrician.html',technician],['admin.html',admin]]){
  const scripts=[...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim());
  assert.ok(scripts.length>0,name+' inline script exists');
  scripts.forEach((script,i)=>assert.doesNotThrow(()=>new vm.Script(script,{filename:name+'#'+i}),name+' script '+i+' syntax'));
 }
});
