const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const read=p=>fs.readFileSync(path.resolve(__dirname,'..',p),'utf8');

const migration=read('supabase/migrations/20261121190000_master_payment_collection_and_technician_payables.sql');
const refundMigration=read('supabase/migrations/20261121200000_master_refund_final_bill_integration.sql');
const createOrder=read('create-order.js');
const verifyPayment=read('verify-payment.js');
const webhook=read('razorpay-webhook.js');

test('Master payment collection is tied to immutable final bill and verified provider evidence',()=>{
 assert.match(migration,/srk_master_booking_payments/);
 assert.match(migration,/final_bill_id uuid NOT NULL UNIQUE/);
 assert.match(migration,/p_amount_paise<100/);
 assert.match(migration,/f\.subtotal_paise<>p_amount_paise/);
 assert.match(migration,/b\.razorpay_order_id IS DISTINCT FROM p_order_id/);
 assert.match(migration,/payment_status='paid'/);
});

test('Master Technician payables allocate labour commission and approved material reimbursement per Technician',()=>{
 assert.match(migration,/srk_master_technician_payables/);
 assert.match(migration,/GROUP BY technician_id ORDER BY technician_id/);
 assert.match(migration,/f\.company_commission_paise\/f\.labour_amount_paise/);
 assert.match(migration,/v_materials_owner/);
 assert.match(migration,/UNIQUE\(booking_id,technician_id\)/);
});

test('Admin manual payment is restricted and records payment evidence before paid state',()=>{
 assert.match(migration,/srk_admin_record_master_manual_payment/);
 assert.match(migration,/public\.is_srk_admin\(\)/);
 assert.match(migration,/VALID_MANUAL_PAYMENT_EVIDENCE/);
 assert.match(migration,/srk_manual_payment_entries/);
});

test('Master refund uses final bill rather than legacy quote and blocks Technician payables',()=>{
 assert.match(refundMigration,/PAID_AMOUNT_DOES_NOT_MATCH_MASTER_FINAL_BILL/);
 assert.match(refundMigration,/srk_master_technician_payables/);
 assert.match(refundMigration,/MASTER_TECHNICIAN_PAYOUT_ALREADY_PAID_RECOVERY_REQUIRED/);
 assert.match(refundMigration,/srk_master_refund_payable_state_sync/);
});

test('Razorpay order creation uses Master final bill subtotal, not quote fields',()=>{
 assert.match(createOrder,/srk_booking_final_bills\?select=subtotal_paise,labour_amount_paise,materials_amount_paise/);
 assert.match(createOrder,/booking\.srk_service_category_code/);
 assert.match(createOrder,/selected_category,srk_service_category_code/);
 assert.match(createOrder,/status,quote_status,selected_category,srk_service_category_code&id=eq/);
});

test('Customer payment verification records captured Master payment through service-only RPC',()=>{
 assert.match(verifyPayment,/srk_service_role_record_master_online_payment/);
 assert.match(verifyPayment,/booking\.srk_service_category_code/);
 assert.match(verifyPayment,/p_amount_paise:p\.amount/);
});

test('Razorpay webhook reconciles Master payment from signed captured event and final bill',()=>{
 assert.match(webhook,/srk_service_role_record_master_online_payment/);
 assert.match(webhook,/booking\.srk_service_category_code/);
 assert.match(webhook,/payment\.amount !== expectedAmount/);
});

test('Master customer receipt reads only the immutable final bill and verified payment ledger',()=>{
 const receipt=read('supabase/migrations/20261121210000_master_customer_payment_receipt.sql');
 assert.match(receipt,/srk_master_booking_payments/);
 assert.match(receipt,/srk_booking_final_bills/);
 assert.match(receipt,/material_items/);
 assert.match(receipt,/MASTER_FINAL_BILL_PAYMENT_RECONCILIATION_FAILED/);
 assert.match(receipt,/Preserve the historical single-Electrician and quote-era receipt contracts/);
});
