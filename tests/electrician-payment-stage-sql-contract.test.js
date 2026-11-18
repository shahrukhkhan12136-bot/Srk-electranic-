"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migration = fs.readFileSync(
  path.join(__dirname, "../supabase/migrations/20261118080000_align_offer_85_rate_and_payout_reconciliation.sql"),
  "utf8"
);
const roundingMigration = fs.readFileSync(
  path.join(__dirname, "../supabase/migrations/20261118110000_unify_electrician_rate_rounding.sql"),
  "utf8"
);

test("offer RPC returns electrician net, not customer gross estimate", () => {
  const offerFunction = (migration.match(/create(?: or replace)? function public\.srk_get_my_offer_details\(\)[\s\S]*?\$function\$;/i)||[])[0]||"";
  assert.match(offerFunction, /electrician_offer_paise bigint/);
  assert.doesNotMatch(offerFunction, /estimated_labour_paise bigint/);
  assert.match(roundingMigration, /b\.estimated_labour_paise - floor\(\(b\.estimated_labour_paise::numeric\*1500\/10000\)\+0\.5\)::bigint/);
  assert.doesNotMatch(offerFunction, /\n\s*b\.estimated_labour_paise,?/);
});

test("offer quote and money fields are hidden until persisted checkout or verified payment", () => {
  const offerFunction = (migration.match(/create(?: or replace)? function public\.srk_get_my_offer_details\(\)[\s\S]*?\$function\$;/i)||[])[0]||"";
  assert.match(offerFunction, /b\.razorpay_order_id is not null and b\.payment_status='pending'/i);
  assert.match(offerFunction, /b\.payment_status='paid' and b\.payment_verified_at is not null/i);
  assert.match(offerFunction, /then b\.quoted_amount else null/);
  assert.match(offerFunction, /then b\.service_charge else null/);
  assert.match(offerFunction, /then b\.materials_amount else null/);
});

test("earnings RPC derives payment stage from persisted order and payment evidence", () => {
  const earningsFunction = (migration.match(/create(?: or replace)? function public\.srk_get_my_earnings\(\)[\s\S]*?\$\$;/i)||[])[0]||"";
  assert.match(earningsFunction, /checkout\.started then 'checkout_started'/i);
  assert.match(earningsFunction, /b\.payment_verified_at is not null/i);
  assert.match(earningsFunction, /b\.razorpay_payment_id is not null or exists\(/i);
  assert.doesNotMatch(earningsFunction, /p_payment_stage|browser_payment_stage|client_payment_stage/i);
});

test("unpaid rows hide customer gross and company share but expose electrician net", () => {
  const earningsFunction = (migration.match(/create(?: or replace)? function public\.srk_get_my_earnings\(\)[\s\S]*?\$\$;/i)||[])[0]||"";
  assert.match(earningsFunction, /floor\(\(round\(coalesce\(bill\.labour_amount,0\)\*100\)\*1500\+5000\)\/10000\)/i);
  assert.match(earningsFunction, /customer_labour_gross numeric/);
  assert.match(earningsFunction, /company_share numeric/);
  assert.match(earningsFunction, /checkout\.started and b\.commission_rate=15/i);
});

test("verified receipt and payout are returned only with verified evidence", () => {
  const earningsFunction = (migration.match(/create(?: or replace)? function public\.srk_get_my_earnings\(\)[\s\S]*?\$\$;/i)||[])[0]||"";
  assert.match(earningsFunction, /when verified\.is_verified then coalesce\(b\.amount_paid,0\)\s+else 0/i);
  assert.match(earningsFunction, /CASE WHEN verified\.is_verified AND payout_check\.reconciliation_status='reconciled' THEN payout\.payout_status ELSE NULL END/i);
  assert.match(earningsFunction, /CASE WHEN verified\.is_verified AND payout_check\.reconciliation_status='reconciled' THEN payout\.electrician_payable ELSE NULL END/i);
});

test("migration does not rewrite legacy commission or payout calculation", () => {
  assert.doesNotMatch(migration, /update\s+public\.srk_electrician_payouts/i);
  assert.doesNotMatch(migration, /create or replace function public\.srk_create_electrician_payable/i);
  assert.doesNotMatch(migration, /set\s+commission_rate\s*=/i);
  assert.match(migration, /Existing booking snapshots, immutable labour bills, commission rules and[\s\S]*?payout-ledger rows are read-only in this migration/i);
});

const electricianHtml = fs.readFileSync(
  path.join(__dirname, "../electrician.html"),
  "utf8"
);

test("electrician offer UI renders only the net amount supplied by the RPC", () => {
  assert.match(electricianHtml, /o\.electrician_offer_paise/);
  assert.doesNotMatch(electricianHtml, /o\.estimated_labour_paise/);
  assert.doesNotMatch(electricianHtml, /estimated_labour_paise/);
});

test("earnings UI gates company and customer totals by server payment stage", () => {
  const earningsUi = electricianHtml.split("async function loadEarnings(){")[1].split("async function loadPartnerWallet(){")[0];
  assert.match(earningsUi, /x\.payment_stage==='completed_unpaid'/);
  assert.match(earningsUi, /x\.payment_stage==='checkout_started'/);
  assert.match(earningsUi, /x\.payment_stage==='payment_verified'/);
  assert.match(earningsUi, /verified\.reduce\(\(sum,x\)=>sum\+Number\(x\.amount_received/);
  assert.match(earningsUi, /\['checkout_started','payment_verified'\]/);
  assert.match(earningsUi, /srk_electrician_payouts/);
  assert.match(earningsUi, /अलग Electrician Payout Ledger/);
  assert.doesNotMatch(earningsUi, /commission_amount/);
});
