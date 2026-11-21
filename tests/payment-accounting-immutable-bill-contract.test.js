const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
const archive=read('supabase/migrations/20261115210000_legacy_manual_payment_and_itemized_receipt.sql');
const payout=read('supabase/migrations/20261114360000_new_category_electrician_payout_reconciliation.sql');
const commission=read('supabase/migrations/20261117010000_reconcile_booking_commission_and_manual_payment_method.sql');
const refund=read('supabase/migrations/20261121200000_master_refund_final_bill_integration.sql');
const receipt=read('supabase/migrations/20261121210000_master_customer_payment_receipt.sql');
const booking=read('booking.html');

test('Historical quote-era financial values are copied to a private archive before live fields are retired',()=>{
 assert.match(archive,/CREATE TABLE IF NOT EXISTS srk_private\.legacy_booking_financial_evidence/);
 assert.match(archive,/INSERT INTO srk_private\.legacy_booking_financial_evidence/);
 assert.match(archive,/ON CONFLICT \(booking_id\) DO NOTHING/);
 assert.match(archive,/DROP FUNCTION IF EXISTS public\.srk_admin_record_manual_payment/);
 assert.match(archive,/v_legacy\.service_charge/);
 assert.doesNotMatch(archive,/v_booking\.(?:quote_status|quoted_amount|service_charge|materials_amount)/);
});

test('New-category payout and commission are based only on immutable labour bill',()=>{
 assert.match(payout,/v_service := round\(v_bill\.labour_amount,2\)/);
 assert.match(payout,/v_materials := 0/);
 assert.match(payout,/Legacy quote-era bookings never enter the new payout creation path/);
 assert.match(commission,/Quote-era bookings are historical only/);
 assert.match(commission,/legacy_booking_financial_evidence/);
 assert.doesNotMatch(commission,/v_booking\.(?:quote_status|quoted_amount|service_charge|materials_amount)/);
});

test('Refund and receipt retain old verified records from archive, not live quote columns',()=>{
 assert.match(refund,/legacy_booking_financial_evidence/);
 assert.match(refund,/PAID_AMOUNT_DOES_NOT_MATCH_ARCHIVED_HISTORICAL_EVIDENCE/);
 assert.doesNotMatch(refund,/v_booking\.(?:quote_status|quoted_amount|service_charge|materials_amount)/);
 assert.match(receipt,/legacy_booking_financial_evidence/);
 assert.match(receipt,/ARCHIVED_HISTORICAL_RECEIPT_RECONCILIATION_FAILED/);
 assert.doesNotMatch(receipt,/\bb\.(?:quote_status|quoted_amount|service_charge|materials_amount)/);
 assert.match(booking,/labourRow\+materialsRow\+cancellationFeeRows/);
});
