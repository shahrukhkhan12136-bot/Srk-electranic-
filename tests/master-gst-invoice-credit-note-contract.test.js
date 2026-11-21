'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const sql=fs.readFileSync('supabase/migrations/20261121240000_master_gst_invoice_credit_note_gateway_tax.sql','utf8');
const createOrder=fs.readFileSync('create-order.js','utf8');
const verify=fs.readFileSync('verify-payment.js','utf8');
const webhook=fs.readFileSync('razorpay-webhook.js','utf8');
const receipt=fs.readFileSync('supabase/migrations/20261121210000_master_customer_payment_receipt.sql','utf8');
const admin=fs.readFileSync('admin.html','utf8');
test('GST company profile is explicit and never assumes registration or rate',()=>{
 assert.match(sql,/registration_status IN \('registered','unregistered'\)/);
 assert.match(sql,/VALID_GSTIN_AND_MATCHING_STATE_REQUIRED/);
 assert.match(sql,/GST_LABOUR_RATE_RULE_NOT_CONFIGURED/);
 assert.match(sql,/GST_MATERIAL_RATE_RULE_NOT_CONFIGURED/);
 assert.match(sql,/c\\.registration_status:='unregistered'/);
 assert.match(sql,/c\\.version:=0/);
 assert.doesNotMatch(sql,/DEFAULT\s+18\s*\)/i);
});
test('Tax snapshots preserve taxable base and split CGST SGST IGST',()=>{
 for(const field of ['labour_taxable_value_paise','materials_taxable_value_paise','total_cgst_paise','total_sgst_paise','total_igst_paise','total_tax_paise','total_due_paise','tax_treatment'])assert.match(sql,new RegExp(field));
 assert.match(sql,/intra_state/);assert.match(sql,/inter_state/);
});
test('Invoices and full-refund credit notes are immutable',()=>{
 assert.match(sql,/srk_master_tax_invoices/);assert.match(sql,/srk_master_tax_credit_notes/);
 assert.match(sql,/srk_master_issue_tax_invoice/);assert.match(sql,/srk_master_issue_tax_credit_note/);
 assert.match(sql,/MASTER_TAX_DOCUMENTS_ARE_IMMUTABLE/);
});
test('Gateway fee GST and input-credit eligibility are separately auditable',()=>{
 assert.match(sql,/srk_master_gateway_fee_tax_entries/);
 assert.match(sql,/GATEWAY_FEE_GST_AMOUNT_MISMATCH/);
 assert.match(sql,/input_tax_credit_eligible/);
});
test('Admin configuration and GST reporting are authorization-gated',()=>{
 assert.match(sql,/public\.is_srk_admin\(\)/);
 assert.match(sql,/srk_admin_get_master_gst_summary/);
});
test('GST snapshot is required before payment invoice creation',()=>{
 assert.match(sql,/BOOKING_TAX_SNAPSHOT_REQUIRED/);
 assert.match(sql,/AFTER INSERT ON public\.srk_booking_final_bills/);
});
test('Migration SQL delimiters balance',()=>{
 assert.equal((sql.match(/\$\$/g)||[]).length%2,0);
});

test('Razorpay and manual payment paths use tax-inclusive immutable totals',()=>{
 assert.match(sql,/t\.total_due_paise<>p_amount_paise/);
 assert.match(sql,/VALUES\(p_booking_id,p_method,t\.total_due_paise\/100\.0/);
 assert.match(sql,/manual_recorded',t\.total_due_paise/);
 assert.match(createOrder,/srk_booking_tax_snapshots/);
 assert.match(verify,/srk_booking_tax_snapshots/);
 assert.match(webhook,/srk_booking_tax_snapshots/);
});
test('Customer receipt and Admin GST reporting expose invoice and tax details',()=>{
 assert.match(receipt,/invoice_number/);assert.match(receipt,/total_tax_paise/);
 assert.match(sql,/srk_customer_get_master_tax_invoice/);
 assert.match(admin,/srk_admin_get_master_gst_summary/);
});
test('GST migration and Admin inline JavaScript parse',()=>{
 assert.equal((sql.match(/\$\$/g)||[]).length%2,0);
 const scripts=[...admin.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim());
 assert.ok(scripts.length>0);scripts.forEach((s,i)=>assert.doesNotThrow(()=>new vm.Script(s,{filename:'admin.html#'+i})));
});
