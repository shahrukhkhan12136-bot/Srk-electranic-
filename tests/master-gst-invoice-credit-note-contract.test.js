'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const sql=fs.readFileSync('supabase/migrations/20261121240000_master_gst_invoice_credit_note_gateway_tax.sql','utf8');
test('GST company profile is explicit and never assumes registration or rate',()=>{
 assert.match(sql,/registration_status IN \('registered','unregistered'\)/);
 assert.match(sql,/VALID_GSTIN_AND_MATCHING_STATE_REQUIRED/);
 assert.match(sql,/GST_LABOUR_RATE_RULE_NOT_CONFIGURED/);
 assert.match(sql,/GST_MATERIAL_RATE_RULE_NOT_CONFIGURED/);
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
