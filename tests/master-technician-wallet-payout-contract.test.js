import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const sql=fs.readFileSync('supabase/migrations/20261121230000_master_technician_wallet_payout_requests.sql','utf8');
test('Master wallet and payout migration exposes canonical technician RPCs',()=>{
 for(const name of ['srk_master_wallet_summary','srk_technician_request_master_payout','srk_admin_confirm_master_company_settlement','srk_admin_list_master_payout_requests','srk_admin_review_master_payout_request','srk_admin_mark_master_payout_paid']) assert.match(sql,new RegExp('FUNCTION public\\.'+name));
});
test('Payout request snapshots every payable and is idempotent',()=>{
 assert.match(sql,/UNIQUE\(technician_id,idempotency_key\)/);
 assert.match(sql,/PRIMARY KEY\(payout_request_id,payable_id\)/);
 assert.match(sql,/payout_status='requested'/);
 assert.match(sql,/PAYOUT_REQUEST_ALREADY_OPEN/);
});
test('Online payout is blocked until company settlement evidence exists',()=>{
 assert.match(sql,/COMPANY_RAZORPAY_SETTLEMENT_NOT_CONFIRMED/);
 assert.match(sql,/PAYOUT_REQUEST_NOT_PENDING_REVIEW/);
 assert.match(sql,/PAYOUT_REQUEST_MUST_BE_APPROVED_FIRST/);
 assert.match(sql,/m\.payment_method='razorpay'/);
 assert.match(sql,/srk_master_company_settlements/);
});
test('Paid state requires actual transfer reference and Admin identity',()=>{
 assert.match(sql,/INVALID_TRANSFER_EVIDENCE/);
 assert.match(sql,/p_transfer_reference/);
 assert.match(sql,/paid_by=auth\.uid\(\)/);
 assert.match(sql,/is_srk_admin\(\)/);
});
test('Existing legacy payout path is not overwritten',()=>{
 assert.doesNotMatch(sql,/DROP TABLE[^;]*srk_electrician_payouts/i);
 assert.doesNotMatch(sql,/CREATE OR REPLACE FUNCTION public\.srk_admin_mark_electrician_payout_paid/i);
});
test('SQL migration contains balanced function delimiters',()=>{
 assert.equal((sql.match(/\$\$/g)||[]).length%2,0);
});
