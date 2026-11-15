const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const receiptSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114190000_customer_receipt_immutable_labour_amount.sql'), 'utf8');
const earningsSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261109003000_secure_commission_reporting.sql'), 'utf8');

test('Customer payment history loads on Payments tab entry, login, manual refresh and paginated continuation', () => {
  assert.match(customer, /if\(name==='Payments'\)\{loadCustomerPaymentHistory\(true\);loadCustomerRefundHistory\(\);\}/);
  assert.match(customer, /await loadCustomerPaymentHistory\(true\);/);
  assert.match(customer, /customerPaymentHistoryRefresh'\)\.addEventListener\('click',\(\)=>loadCustomerPaymentHistory\(true\)\)/);
  assert.match(customer, /customerPaymentHistoryMore'\)\.addEventListener\('click',\(\)=>loadCustomerPaymentHistory\(false\)\)/);
  assert.match(customer, /p_limit:25,p_offset:customerPaymentHistoryOffset/);
  assert.match(customer, /customerPaymentHistoryOffset\+=rows\.length/);
});

test('Customer receipts are offered only for payment events and the RPC requires verified owner-paid booking', () => {
  assert.match(customer, /\['payment','manual_payment'\]\.includes\(row\.event_type\)&&row\.booking_id/);
  assert.match(customer, /srk_customer_get_payment_history/);
  assert.match(receiptSql, /customer_user_id = v_uid/);
  assert.match(receiptSql, /payment_status <> 'paid'/);
  assert.match(receiptSql, /payment_verified_at is null/);
  assert.match(receiptSql, /v_bill\.labour_amount_paise = round\(v_booking\.amount_paid \* 100\)::bigint/);
  assert.match(receiptSql, /'labour_amount', v_labour_amount/);
  assert.match(receiptSql, /'amount_paid', round\(v_booking\.amount_paid,2\)/);
});

test('Electrician earnings and Admin bank payout remain distinct and UI never initiates withdrawal', () => {
  assert.match(earningsSql, /where p\.user_id=auth\.uid\(\) and p\.verification_status='approved'/);
  assert.match(electrician, /sb\.rpc\('srk_get_my_earnings'\)/);
  assert.match(electrician, /srk_electrician_payouts/);
  assert.match(electrician, /ग्राहक का भुगतान और Admin द्वारा आपके बैंक\/UPI में किया गया भुगतान अलग-अलग रिकॉर्ड हैं/);
  assert.match(electrician, /यह ऐप का आंतरिक लेजर बैलेंस है/);
  assert.match(electrician, /बैंक खाता जोड़ना और निकासी अभी बंद है/);
  assert.doesNotMatch(electrician, /srk_wallet_withdraw|srk_create_withdrawal|create_bank_transfer|razorpay_route_transfer/i);
});
