const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118033000_gate_electrician_financial_visibility.sql"), "utf8");
const ui = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");

test("offer RPC returns a distinct electrician net field, never the gross estimate column", () => {
  assert.match(migration, /electrician_offer_paise bigint/);
  assert.match(migration, /estimated_labour_paise::numeric\*8500/);
  assert.doesNotMatch(migration, /estimated_labour_paise bigint,/);
});

test("offer RPC withholds quote and materials amounts until persisted checkout or verified payment", () => {
  assert.match(migration, /b\.razorpay_order_id IS NOT NULL/);
  assert.match(migration, /b\.payment_verified_at IS NOT NULL/);
  assert.match(migration, /THEN b\.service_charge ELSE NULL END/);
  assert.match(migration, /THEN b\.materials_amount ELSE NULL END/);
});

test("earnings RPC derives payment stage on server and verifies manual payment evidence", () => {
  assert.match(migration, /payment_stage text/);
  assert.match(migration, /b\.razorpay_order_id IS NOT NULL AND b\.payment_status IN \('pending','created'\)/);
  assert.match(migration, /lower\(btrim\(e\.payment_method\)\)=lower\(btrim\(b\.payment_method\)\)/);
  assert.match(migration, /b\.payment_verified_at IS NOT NULL/);
});

test("earnings RPC reads immutable labour bill and leaves payout ledger as actual payout source", () => {
  assert.match(migration, /srk_booking_labour_bills bill ON bill\.booking_id=b\.id/);
  assert.match(migration, /payout\.electrician_payable/);
  assert.match(migration, /payout\.booking_id=b\.id/);
  assert.match(migration, /DROP FUNCTION IF EXISTS public\.srk_get_my_earnings\(\)/);
});

test("browser renders backend net directly and stage-gates customer/company totals", () => {
  assert.match(ui, /o\.electrician_offer_paise/);
  assert.doesNotMatch(ui, /o\.estimated_labour_paise/);
  assert.match(ui, /x\.payment_stage==='payment_verified'/);
  assert.match(ui, /x\.payment_stage==='checkout_started'/);
  assert.match(ui, /x\.payment_stage==='completed_unpaid'/);
});

test("earnings RPC exposes checkout breakdown fields and separate payout status", () => {
  assert.match(migration, /customer_labour_gross numeric/);
  assert.match(migration, /company_share numeric/);
  assert.match(migration, /payout_amount numeric/);
  assert.match(migration, /payout_status text/);
  assert.match(migration, /checkout_reconciliation_required/);
  assert.match(ui, /x\.payment_stage==='checkout_reconciliation_required'/);
});

test("earnings calculations use the actual immutable labour_amount column, not a nonexistent paise column", () => {
  assert.match(migration, /bill\.labour_amount/);
  assert.doesNotMatch(migration, /bill\.labour_amount_paise/);
  assert.match(migration, /WHEN verified\.is_verified THEN coalesce\(b\.amount_paid,0\)\s+ELSE 0/);
});
