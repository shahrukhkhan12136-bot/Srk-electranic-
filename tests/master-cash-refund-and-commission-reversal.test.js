const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const cashRefund = fs.readFileSync(path.join(root, 'supabase/migrations/20261121270000_master_cash_refund_and_commission_reversal.sql'), 'utf8');
const payoutCredits = fs.readFileSync(path.join(root, 'supabase/migrations/20261121271000_master_cash_refund_wallet_payout_integration.sql'), 'utf8');
const masterRefund = fs.readFileSync(path.join(root, 'supabase/migrations/20261121200000_master_refund_final_bill_integration.sql'), 'utf8');

test('Master cash refund requires Technician evidence and approved full Customer refund', () => {
  assert.match(cashRefund, /srk_technician_submit_master_cash_refund_evidence/);
  assert.match(cashRefund, /MAIN_ADMIN_APPROVED_CUSTOMER_REFUND_REQUEST_REQUIRED/);
  assert.match(cashRefund, /TECHNICIAN_REFUND_EVIDENCE_MUST_EQUAL_FULL_CUSTOMER_REFUND/);
  assert.match(cashRefund, /srk_booking_refund_requests[\s\S]*?status='approved'/);
  assert.match(cashRefund, /v_final_bill\.subtotal_paise<>v_payment\.amount_paise/);
});

test('cash refund uses compatibility audit evidence before booking refund trigger', () => {
  assert.match(cashRefund, /INSERT INTO public\.srk_manual_refund_entries/);
  assert.match(cashRefund, /UPDATE public\.service_bookings SET payment_status='refunded'/);
  assert.match(cashRefund, /cash_collected/);
  assert.match(masterRefund, /srk_master_refund_payable_state_sync/);
});

test('only previously recovered 15 percent commission becomes a separate Technician credit', () => {
  assert.match(cashRefund, /commission_recovered_paise>0/);
  assert.match(cashRefund, /srk_master_technician_wallet_credits/);
  assert.match(cashRefund, /commission_due_paise-d\.commission_recovered_paise/);
  assert.match(cashRefund, /cash_payment_refunded/);
});

test('commission refund credits join the existing payout request and UTR lifecycle', () => {
  assert.match(payoutCredits, /srk_master_payout_request_credits/);
  assert.match(payoutCredits, /commission_refund_credit_available_paise/);
  assert.match(payoutCredits, /srk_admin_mark_master_payout_paid/);
  assert.match(payoutCredits, /payout_reference=btrim\(p_transfer_reference\)/);
  assert.match(payoutCredits, /status='available'/);
});

test('Razorpay refund workflow remains a separate path', () => {
  assert.match(masterRefund, /srk_admin_prepare_razorpay_refund/);
  assert.match(cashRefund, /payment_method<>'cash'/);
});
