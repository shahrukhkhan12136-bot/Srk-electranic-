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
