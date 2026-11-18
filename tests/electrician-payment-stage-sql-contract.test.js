"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migration = fs.readFileSync(
  path.join(__dirname, "../supabase/migrations/20261118030000_electrician_payment_stage_visibility.sql"),
  "utf8"
);

test("offer RPC returns electrician net, not customer gross estimate", () => {
  const offerFunction = migration.split("create function public.srk_get_my_offer_details()")[1].split("$function$;")[0];
  assert.match(offerFunction, /electrician_offer_paise bigint/);
  assert.doesNotMatch(offerFunction, /estimated_labour_paise bigint/);
  assert.match(offerFunction, /floor\(\(b\.estimated_labour_paise::numeric\*85\+50\)\/100\)::bigint/);
  assert.doesNotMatch(offerFunction, /\n\s*b\.estimated_labour_paise,?/);
});

test("offer quote and money fields are hidden until persisted checkout or verified payment", () => {
  const offerFunction = migration.split("create function public.srk_get_my_offer_details()")[1].split("$function$;")[0];
  assert.match(offerFunction, /b\.razorpay_order_id is not null and b\.payment_status='pending'/);
  assert.match(offerFunction, /b\.payment_status='paid' and b\.payment_verified_at is not null/);
  assert.match(offerFunction, /then b\.quoted_amount else null/);
  assert.match(offerFunction, /then b\.service_charge else null/);
  assert.match(offerFunction, /then b\.materials_amount else null/);
});

test("earnings RPC derives payment stage from persisted order and payment evidence", () => {
  const earningsFunction = migration.split("create function public.srk_get_my_earnings()")[1].split("$function$;")[0];
  assert.match(earningsFunction, /when b\.status='completed' and b\.razorpay_order_id is not null\s+and b\.payment_status='pending' then 'checkout_started'/);
  assert.match(earningsFunction, /b\.payment_verified_at is not null/);
  assert.match(earningsFunction, /b\.razorpay_payment_id is not null or exists\(/);
  assert.doesNotMatch(earningsFunction, /p_payment_stage|browser_payment_stage|client_payment_stage/i);
});

test("unpaid rows hide customer gross and company share but expose electrician net", () => {
  const earningsFunction = migration.split("create function public.srk_get_my_earnings()")[1].split("$function$;")[0];
  assert.match(earningsFunction, /then round\(floor\(\(bill\.labour_amount_paise\*85\+50\)\/100\)\/100,2\)/);
  assert.match(earningsFunction, /customer_labour_gross numeric/);
  assert.match(earningsFunction, /company_share numeric/);
  assert.match(earningsFunction, /and \(\(b\.razorpay_order_id is not null and b\.payment_status='pending'\) or/);
});

test("verified receipt and payout are returned only with verified evidence", () => {
  const earningsFunction = migration.split("create function public.srk_get_my_earnings()")[1].split("$function$;")[0];
  assert.match(earningsFunction, /then coalesce\(b\.amount_paid,0\)\s+else null/);
  assert.match(earningsFunction, /then coalesce\(payout\.payout_status,'not_recorded'\)/);
  assert.match(earningsFunction, /then payout\.electrician_payable\s+else null/);
});

test("migration does not rewrite legacy commission or payout calculation", () => {
  assert.doesNotMatch(migration, /update\s+public\.srk_electrician_payouts/i);
  assert.doesNotMatch(migration, /create or replace function public\.srk_create_electrician_payable/i);
  assert.doesNotMatch(migration, /set\s+commission_rate\s*=/i);
  assert.match(migration, /Existing commission_rate\/platform_commission and payout ledger are NOT changed/);
});
