const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const receiptSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261115210000_legacy_manual_payment_and_itemized_receipt.sql'), 'utf8');
const accountingSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261117010000_reconcile_booking_commission_and_manual_payment_method.sql'), 'utf8');
const removalSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261118000000_remove_quotation_system_completely.sql'), 'utf8');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');

test('new-category receipt uses customer-owned immutable labour bill and settled fee ledger', () => {
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

test('historical paid receipt is read from the private archive, not live booking quote fields', () => {
  const start = receiptSql.indexOf('create or replace function public.srk_customer_get_payment_receipt');
  const fn = receiptSql.slice(start);
  assert.match(fn, /from srk_private\.legacy_booking_financial_evidence/);
  assert.match(fn, /v_legacy\.service_charge/);
  assert.match(fn, /v_legacy\.materials_amount/);
  assert.match(fn, /ऐतिहासिक सत्यापित भुगतान रसीद/);
  assert.doesNotMatch(fn, /v_booking\.(?:quoted_amount|quote_status|service_charge|materials_amount)/);
  assert.match(booking, /labourRow\+materialsRow\+cancellationFeeRows/);
});

test('new payout commission is calculated from immutable labour only; materials are zero', () => {
  assert.match(removalSql, /v_service:=round\(v_bill\.labour_amount_paise\/100\.0,2\)/);
  assert.match(removalSql, /v_materials:=0/);
  assert.match(removalSql, /v_commission:=round\(v_service\*v_rate\/100,2\)/);
});

test('accounting reconciliation uses immutable bill for new bookings and archive for historical bookings', () => {
  assert.match(accountingSql, /from srk_private\.legacy_booking_financial_evidence/);
  assert.match(accountingSql, /v_bill\.labour_amount_paise/);
  assert.doesNotMatch(accountingSql, /v_booking\.(?:quote_status|quoted_amount|service_charge|materials_amount)/);
});

test('refund and payout settlement use immutable bill/archive rather than quotation approval', () => {
  assert.match(removalSql, /v_booking\.selected_category IS NOT NULL/);
  assert.match(removalSql, /v_legacy\.quoted_amount/);
  assert.doesNotMatch(removalSql, /v_booking\.(?:quote_status|quoted_amount|service_charge|materials_amount)/);
  assert.doesNotMatch(removalSql, /APPROVED_QUOTE/);
});
