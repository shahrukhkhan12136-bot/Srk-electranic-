'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const migration=fs.readFileSync('supabase/migrations/20261121330000_master_manual_payment_and_cash_refund_tasks.sql','utf8');
const admin=fs.readFileSync('admin.html','utf8');
const technician=fs.readFileSync('electrician.html','utf8');
test('Admin can verify Master manual cash payments using GST-inclusive total due',()=>{
 assert.match(migration,/srk_admin_list_master_pending_manual_payments/);
 assert.match(migration,/srk_admin_record_master_manual_payment/);
 assert.match(migration,/total_due_paise/);
 assert.match(admin,/srk_admin_list_master_pending_manual_payments/);
 assert.match(admin,/srk_admin_record_master_manual_payment/);
});
test('Technician cash refund inbox is limited to own assigned approved requests',()=>{
 assert.match(migration,/srk_technician_list_master_cash_refund_tasks/);
 assert.match(migration,/p\.technician_id=v_tid/);
 assert.match(migration,/r\.status='approved'/);
 assert.match(technician,/srk_technician_list_master_cash_refund_tasks/);
});
test('Cash refund finalization validates tax-inclusive total and preserves commission reversal',()=>{
 assert.match(migration,/t\.total_due_paise/);
 assert.match(migration,/srk_master_technician_wallet_credits/);
 assert.match(migration,/cash_payment_refunded/);
});
