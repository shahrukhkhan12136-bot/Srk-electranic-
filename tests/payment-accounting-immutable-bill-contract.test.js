const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const receiptSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261115210000_legacy_manual_payment_and_itemized_receipt.sql'), 'utf8');
const accountingSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261115150000_admin_readonly_booking_accounting_reconciliation.sql'), 'utf8');
const payoutSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114360000_new_category_electrician_payout_reconciliation.sql'), 'utf8');
const refundSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql'), 'utf8');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');

test('new-category receipt is grounded in the immutable customer-owned labour bill and settled fee ledger', () => {
  const start = receiptSql.indexOf('create or replace function public.srk_customer_get_payment_receipt');
  const fn = receiptSql.slice(start);
  assert.match(fn, /if v_booking\.selected_category is not null then/);
  assert.match(fn, /where booking_id=p_booking_id and customer_user_id=v_uid/);
  assert.match(fn, /where i\.booking_id=p_booking_id and i\.status='settled'/);
  assert.match(fn, /v_total_paise:=v_bill\.labour_amount_paise\+v_fee_paise/);
  assert.match(fn, /'materials_amount',0/);
  assert.match(fn, /'cancellation_fee_amount',v_fee_paise\/100\.0/);
  assert.match(fn, /round\(v_booking\.amount_paid\*100\)::bigint<>v_total_paise/);
});

test('legacy receipt keeps approved labour and materials itemized on the same payment receipt', () => {
  const start = receiptSql.indexOf('create or replace function public.srk_customer_get_payment_receipt');
  const fn = receiptSql.slice(start);
  assert.match(fn, /v_labour_paise:=round\(coalesce\(v_booking\.service_charge,0\)\*100\)::bigint/);
  assert.match(fn, /v_materials_paise:=round\(coalesce\(v_booking\.materials_amount,0\)\*100\)::bigint/);
  assert.match(fn, /round\(coalesce\(v_booking\.quoted_amount,0\)\*100\)::bigint<>v_total_paise/);
  assert.match(fn, /'materials_amount',v_materials_paise\/100\.0/);
  assert.match(booking, /labourRow\+materialsRow\+cancellationFeeRows/);
});

test('legacy manual payment is excluded from new-category bookings and commissions only labour', () => {
  assert.match(receiptSql, /if v_booking\.selected_category is not null then\s+raise exception 'NEW_CATEGORY_BOOKING_USES_DEDICATED_SETTLEMENT'/);
  assert.match(receiptSql, /v_booking\.quote_status is distinct from 'approved'/);
  assert.match(receiptSql, /v_commission_paise:=round\(v_service_paise::numeric\*v_booking\.commission_rate\/100\)::bigint/);
  assert.match(receiptSql, /v_payable_paise:=v_total_paise-v_commission_paise/);
});

test('new-category payout and read-only accounting use immutable labour, zero materials and settled fee reconciliation', () => {
  assert.match(payoutSql, /v_service := round\(v_bill\.labour_amount,2\)/);
  assert.match(payoutSql, /v_materials := 0/);
  assert.match(payoutSql, /v_bill\.labour_amount \+ coalesce\(/);
  assert.match(accountingSql, /if v_booking\.selected_category is not null then/);
  assert.match(accountingSql, /v_materials_paise := 0/);
  assert.match(accountingSql, /v_collection_paise is distinct from \(v_labour_paise\+v_fee_captured_paise\)/);
  assert.match(accountingSql, /elsif v_booking\.selected_category is null and v_payment_verified/);
});

test('refund flow preserves immutable-bill path for new bookings and approved-quote path for legacy bookings', () => {
  assert.match(refundSql, /if v_booking\.selected_category is not null then/);
  assert.match(refundSql, /IMMUTABLE_LABOUR_BILL_REQUIRED/);
  assert.match(refundSql, /v_booking\.quote_status<>'approved'/);
  assert.match(refundSql, /PAID_AMOUNT_DOES_NOT_MATCH_APPROVED_QUOTE/);
});
