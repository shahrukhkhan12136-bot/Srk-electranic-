"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const read = (name) => fs.readFileSync(path.join(__dirname, "..", name), "utf8");

const roundingMigration = read("supabase/migrations/20261118110000_unify_electrician_rate_rounding.sql");
const earningsMigration = read("supabase/migrations/20261118080000_align_offer_85_rate_and_payout_reconciliation.sql");
const rateHelper = read("lib/electrician-net-rate.js");

test("Electrician Rate List and Offer use the existing 15 percent rounded commission formula", () => {
  assert.match(roundingMigration, /i\.customer_rate_paise - floor\(\(i\.customer_rate_paise::numeric\*1500\/10000\)\+0\.5\)::bigint/);
  assert.match(roundingMigration, /b\.estimated_labour_paise - floor\(\(b\.estimated_labour_paise::numeric\*1500\/10000\)\+0\.5\)::bigint/);
  assert.match(rateHelper, /return calculateElectricianNetPaise\(customerLabourPaise\)/);
});

test("verified earnings never convert a missing payout row into zero electrician earnings", () => {
  assert.match(earningsMigration, /WHEN verified\.is_verified AND payout_check\.reconciliation_status='reconciled' THEN payout\.electrician_payable\s+WHEN verified\.is_verified THEN NULL\s+WHEN b\.status='completed'/);
  assert.match(earningsMigration, /WHEN payout\.booking_id IS NULL THEN 'missing'/);
  assert.match(earningsMigration, /payout_reconciliation_status text/);
  assert.match(earningsMigration, /payout_check\.reconciliation_status AS payout_reconciliation_status/);
  assert.match(earningsMigration, /CASE WHEN verified\.is_verified AND payout_check\.reconciliation_status='reconciled' THEN payout\.payout_status ELSE NULL END AS payout_status/);
});
