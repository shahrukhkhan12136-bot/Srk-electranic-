const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const booking = fs.readFileSync(path.join(__dirname, '..', 'booking.html'), 'utf8');
const receiptMigration = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261125164000_service_only_customer_payment_receipt.sql'), 'utf8');
const archiveMigration = fs.readFileSync(path.join(__dirname, '..', 'supabase/migrations/20261115210000_legacy_manual_payment_and_itemized_receipt.sql'), 'utf8');

test('customer booking and receipt UI expose service amount without add-on itemization', () => {
  assert.match(booking, /const serviceAmount=data\.service_amount/);
  assert.match(booking, /serviceRow\+cancellationFeeRows/);
  assert.doesNotMatch(booking, /materials_amount|सामान \/ पार्ट्स|सामान\/पार्ट्स|अलग सामान बिल|Materials\/parts|Materials and parts/);
  assert.match(receiptMigration, /'service_amount',f\.labour_amount_paise/);
  assert.doesNotMatch(receiptMigration, /materials_amount|material_items|v_materials/);
});

test('new Master receipt reconciles service-only bill and preserves historical payment totals', () => {
  assert.match(receiptMigration, /f\.subtotal_paise<>f\.labour_amount_paise/);
  assert.match(receiptMigration, /round\(b\.amount_paid\*100\)::bigint<>p\.amount_paise/);
  assert.match(receiptMigration, /v_total:=round\(b\.amount_paid\*100\)::bigint/);
  assert.match(archiveMigration, /legacy_booking_financial_evidence/);
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
  assert.match(receiptMigration, /where id=p_booking_id and customer_user_id=v_uid/i);
  assert.match(receiptMigration, /b\.payment_status<>'paid'/);
  assert.match(receiptMigration, /b\.payment_verified_at IS NULL/);
  assert.match(receiptMigration, /ONLY_VERIFIED_PAID_BOOKINGS_HAVE_A_RECEIPT/);
  assert.match(receiptMigration, /revoke all on function public\.srk_customer_get_payment_receipt\(uuid\) from public,anon/i);
  assert.match(receiptMigration, /grant execute on function public\.srk_customer_get_payment_receipt\(uuid\) to authenticated/i);
});
