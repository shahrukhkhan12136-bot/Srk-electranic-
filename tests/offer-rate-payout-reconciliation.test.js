"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118080000_align_offer_85_rate_and_payout_reconciliation.sql"), "utf8");
const rateView = fs.readFileSync(path.join(__dirname, "../lib/electrician-rate-view.js"), "utf8");
const netRate = require("../lib/electrician-net-rate");
const bookingApi = fs.readFileSync(path.join(__dirname, "../create-booking.js"), "utf8");
const snapshotGuard = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118090000_enforce_booking_rate_snapshot_immutability.sql"), "utf8");
const electricianUi = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");

test("electrician rate-list builder calls the direct 85 percent half-up helper", () => {
  assert.match(rateView, /calculateElectricianRateListPaise/);
  assert.doesNotMatch(rateView, /calculateElectricianNetPaise/);
});

test("SQL offer RPC uses the exact direct 85 percent integer-paise half-up expression", () => {
  assert.match(migration, /floor\(\(b\.estimated_labour_paise::numeric\*8500\/10000\)\+0\.5\)::bigint/);
  assert.doesNotMatch(migration, /b\.estimated_labour_paise-floor\(\(b\.estimated_labour_paise::numeric\*1500\+5000\)\/10000\)/);
  assert.match(migration, /estimate_rate_card_version text/);
  assert.match(migration, /b\.estimate_rate_card_version,/);
  assert.match(migration, /b\.estimate_rate_card_version IS NOT NULL AND b\.estimated_labour_paise>0/);
});

test("SQL and JavaScript direct 85 percent half-up arithmetic agree on 10, 30, 50 and 70 paise ties", () => {
  const tieCases = [[10,9],[30,26],[50,43],[70,60]];
  for (const [gross, expected] of tieCases) {
    assert.equal(netRate.calculateElectricianRateListPaise(gross), expected);
    // SQL floor((gross * 8500 / 10000) + 0.5) uses the same positive-number half-up rule.
    const sqlEquivalent = Number((BigInt(gross) * 8500n + 5000n) / 10000n);
    assert.equal(sqlEquivalent, expected);
  }
});

test("payment verification and payout-ledger reconciliation are separate states", () => {
  assert.match(migration, /payout_reconciliation_status text/);
  assert.ok(migration.includes("b.commission_rate IS DISTINCT FROM 15"));
  assert.match(migration, /WHEN payout\.booking_id IS NULL THEN 'missing'/);
  assert.match(migration, /THEN 'reconciled'/);
  assert.match(migration, /WHEN verified\.is_verified THEN 'payment_verified'/);
  assert.match(migration, /WHEN verified\.is_verified AND payout_check\.reconciliation_status='reconciled' THEN payout\.electrician_payable/);
  assert.match(migration, /WHEN verified\.is_verified THEN NULL/);
  assert.match(migration, /AS payout_reconciliation_status/);
  assert.ok(migration.includes("CASE WHEN verified.is_verified AND payout_check.reconciliation_status='reconciled' THEN payout.payout_status ELSE NULL END AS payout_status"));
  assert.ok(migration.includes("WHEN verified.is_verified THEN NULL"));
  assert.ok(migration.includes("WHEN verified.is_verified AND payout_check.reconciliation_status='reconciled' THEN payout.platform_commission"));
});

test("payout reconciliation checks immutable labour bill, electrician, commission and ledger arithmetic", () => {
  assert.match(migration, /payout\.electrician_profile_id IS DISTINCT FROM b\.assigned_electrician_id/);
  assert.match(migration, /bill\.booking_id IS NULL/);
  assert.ok(migration.includes("payout.razorpay_payment_id IS DISTINCT FROM b.razorpay_payment_id"));
  assert.doesNotMatch(migration, /b\.razorpay_payment_id IS NOT NULL\s+AND payout\.razorpay_payment_id IS DISTINCT FROM/);
  assert.ok(migration.includes("round(payout.gross_service_amount*b.commission_rate/100,2)"));
  assert.match(migration, /payout\.gross_service_amount,2\) IS DISTINCT FROM round\(bill\.labour_amount,2\)/);
  assert.match(migration, /payout\.platform_commission,2\) IS DISTINCT FROM round\(b\.commission_amount,2\)/);
  assert.match(migration, /payout\.electrician_payable,2\) IS DISTINCT FROM/);
  assert.ok(migration.includes("WHEN b.status IS DISTINCT FROM 'completed' THEN 'booking_status_mismatch'"));
  assert.ok(migration.includes("coalesce(payout.materials_amount,0) IS DISTINCT FROM 0"));
  assert.ok(migration.includes("THEN 'category_materials_mismatch'"));
});

test("new source migration does not rewrite historical bookings, bills or payout ledger rows", () => {
  assert.doesNotMatch(migration, /UPDATE\s+public\.service_bookings/i);
  assert.doesNotMatch(migration, /UPDATE\s+public\.srk_booking_labour_bills/i);
  assert.doesNotMatch(migration, /INSERT\s+INTO\s+public\.srk_electrician_payouts/i);
  assert.doesNotMatch(migration, /UPDATE\s+public\.srk_electrician_payouts/i);
  assert.doesNotMatch(migration, /DELETE\s+FROM\s+public\.srk_electrician_payouts/i);
});

test("booking API saves the selected published catalogue version as the immutable booking snapshot", () => {
  assert.match(bookingApi, /srk_get_current_customer_rate_catalogue/);
  assert.match(bookingApi, /estimate_rate_card_version/);
  assert.match(bookingApi, /estimated_labour_paise/);
  assert.match(bookingApi, /loadSnapshotRate8h/);
});


test("booking commercial rate snapshot fields are write-once after booking creation", () => {
  assert.match(snapshotGuard, /srk_guard_booking_rate_snapshot_immutable/);
  assert.match(snapshotGuard, /OLD\.estimated_labour_paise IS DISTINCT FROM NEW\.estimated_labour_paise/);
  assert.match(snapshotGuard, /OLD\.estimate_rate_card_version IS DISTINCT FROM NEW\.estimate_rate_card_version/);
  assert.match(snapshotGuard, /OLD\.selected_rate_tier IS DISTINCT FROM NEW\.selected_rate_tier/);
  assert.match(snapshotGuard, /BOOKING_RATE_SNAPSHOT_IS_IMMUTABLE/);
  assert.match(snapshotGuard, /BEFORE UPDATE OF selected_category,selected_duration_hours,selected_rate_tier/);
  assert.doesNotMatch(snapshotGuard, /UPDATE\s+public\.service_bookings/i);
});

test("electrician UI does not render an unreconciled company share as zero", () => {
  assert.match(electricianUi, /x\.company_share==null\?' • कंपनी कमीशन Payout Ledger मिलान के बाद दिखेगा'/);
  assert.match(electricianUi, /ग्राहक भुगतान सत्यापित है, लेकिन Payout Ledger मिलान स्थिति/);
});
