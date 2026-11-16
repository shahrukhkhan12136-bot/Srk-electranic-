const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const booking = fs.readFileSync(path.join(__dirname, '..', 'booking.html'), 'utf8');
const receiptMigration = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261115210000_legacy_manual_payment_and_itemized_receipt.sql'), 'utf8');

test('customer receipt displays approved legacy labour and materials as separate line items', () => {
  assert.match(booking, /const materialsAmount=Number\(data\.materials_amount\|\|0\)/);
  assert.match(booking, /सामान \/ पार्ट्स/);
  assert.match(booking, /labourRow\+materialsRow\+cancellationFeeRows/);
  assert.match(receiptMigration, /'materials_amount',v_materials_paise\/100\.0/);
});

test('customer receipt RPC reconciles legacy payment to approved labour plus materials', () => {
  assert.match(receiptMigration, /v_labour_paise:=round\(coalesce\(v_booking\.service_charge,0\)\*100\)::bigint/);
  assert.match(receiptMigration, /v_materials_paise:=round\(coalesce\(v_booking\.materials_amount,0\)\*100\)::bigint/);
  assert.match(receiptMigration, /round\(v_booking\.amount_paid\*100\)::bigint<>v_total_paise/);
});

test('customer payment receipt uses the owner-scoped receipt RPC and validates its document type', () => {
  const start = booking.indexOf('async function customerPrintPaymentReceipt(');
  const end = booking.indexOf('\nasync function ', start + 1);
  const fn = booking.slice(start, end < 0 ? booking.length : end);
  assert.match(fn, /customerSb\.rpc\('srk_customer_get_payment_receipt',\{p_booking_id:bookingId\}\)/);
  assert.match(fn, /data\.document_type!=='payment_receipt'/);
  assert.match(fn, /catch\(error\)\{\s*printWindow\.close\(\)/);
  assert.match(fn, /रसीद उपलब्ध नहीं हो सकी/);
});

test('customer payment receipt HTML escapes every server-provided text field', () => {
  const start = booking.indexOf('async function customerPrintPaymentReceipt(');
  const end = booking.indexOf('\nasync function ', start + 1);
  const fn = booking.slice(start, end < 0 ? booking.length : end);
  for (const pattern of [
    /customerEsc\(data\.receipt_reference\)/,
    /customerEsc\(data\.booking_id\)/,
    /customerEsc\(data\.customer_name\)/,
    /customerEsc\(data\.service_type\)/,
    /customerEsc\(address\|\|R\(/,
    /customerEsc\(paymentDate\)/,
    /customerEsc\(bookingDate\)/,
    /customerEsc\(String\(item\.source_booking_id\|\|''\)\.slice/
  ]) assert.match(fn, pattern);
  assert.match(booking, /function customerEsc\(value\)[\s\S]*?replace\(\/\[&<>"'\]\/g/);
});

test('receipt RPC refuses unpaid bookings and scopes receipt lookup to the authenticated customer', () => {
  assert.match(receiptMigration, /where id=p_booking_id and customer_user_id=v_uid/);
  assert.match(receiptMigration, /v_booking\.payment_status<>'paid'/);
  assert.match(receiptMigration, /v_booking\.payment_verified_at is null/);
  assert.match(receiptMigration, /Only verified paid bookings have a payment receipt/);
  assert.match(receiptMigration, /revoke all on function public\.srk_customer_get_payment_receipt\(uuid\) from public,anon/);
  assert.match(receiptMigration, /grant execute on function public\.srk_customer_get_payment_receipt\(uuid\) to authenticated/);
});
