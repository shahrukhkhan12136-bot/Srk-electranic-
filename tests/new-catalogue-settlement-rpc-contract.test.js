"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261114280000_cancellation_fee_carry_forward_and_accounting.sql"), "utf8");
const payoutMigration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261114360000_new_category_electrician_payout_reconciliation.sql"), "utf8");

const extract = (name) => {
  const match = migration.match(new RegExp("create or replace function public\\." + name + "\\([\\s\\S]*?\\n\\$\\$;", "i"));
  return match?.[0] || "";
};

test("new Catalogue payment breakdown RPC is service-role-only and uses immutable labour bill", () => {
  const fn = extract("srk_service_role_get_booking_payment_breakdown");
  assert.ok(fn);
  assert.match(fn, /auth\\.jwt\\(\\)->>'role'\\)\\s*<>\\s*'service_role'/i);
  assert.match(fn, /from public\\.srk_booking_labour_bills[\\s\\S]*?where booking_id=p_booking_id/i);
  assert.match(fn, /where i\\.booking_id=p_booking_id and i\\.status='reserved'/i);
  assert.match(fn, /total_amount_paise/i);
  assert.match(migration, /revoke all on function public\\.srk_service_role_get_booking_payment_breakdown\\(uuid\\) from public,anon,authenticated/i);
  assert.match(migration, /grant execute on function public\\.srk_service_role_get_booking_payment_breakdown\\(uuid\\) to service_role/i);
});

test("new Catalogue online settlement RPC locks booking, checks exact order and amount, and is idempotent by payment ID", () => {
  const fn = extract("srk_service_role_record_online_booking_payment");
  assert.ok(fn);
  assert.match(fn, /auth\\.jwt\\(\\)->>'role'\\)\\s*<>\\s*'service_role'/i);
  assert.match(fn, /from public\\.service_bookings where id=p_booking_id for update/i);
  assert.match(fn, /p_amount_paise<>v_expected/i);
  assert.match(fn, /v_booking\\.razorpay_order_id<>p_order_id/i);
  assert.match(fn, /v_booking\\.payment_status='paid'[\\s\\S]*?v_booking\\.razorpay_payment_id=p_payment_id[\\s\\S]*?already_processed/i);
  assert.match(fn, /insert into public\\.srk_cancellation_fee_ledger[\\s\\S]*?on conflict\\(idempotency_key\\) do nothing/i);
  assert.match(migration, /revoke all on function public\\.srk_service_role_record_online_booking_payment\\(uuid,text,text,bigint\\) from public,anon,authenticated/i);
  assert.match(migration, /grant execute on function public\\.srk_service_role_record_online_booking_payment\\(uuid,text,text,bigint\\) to service_role/i);
});

test("new Catalogue Admin cash RPC is Main Admin-only, locks booking and records cash evidence before payment update", () => {
  const fn = extract("srk_admin_record_new_booking_cash_payment");
  assert.ok(fn);
  assert.match(fn, /public\\.is_srk_admin\\(\\)/i);
  assert.match(fn, /from public\\.service_bookings where id=p_booking_id for update/i);
  assert.match(fn, /payment_method[\\s\\S]*?like '%cash%'/i);
  const evidence = fn.indexOf("insert into public.srk_manual_payment_entries");
  const bookingUpdate = fn.indexOf("update public.service_bookings");
  assert.ok(evidence >= 0 && bookingUpdate > evidence);
  assert.match(fn, /cancel-fee:cash:srk-credit:/i);
  assert.match(fn, /cancel-fee:cash:electrician-debit:/i);
});

test("Catalogue payout trigger sources electrician labour only from immutable bill and excludes cancellation fees from payable", () => {
  assert.match(payoutMigration, /if new\\.selected_category is not null then[\\s\\S]*?from public\\.srk_booking_labour_bills/i);
  assert.match(payoutMigration, /v_service := round\\(v_bill\\.labour_amount,2\\)/i);
  assert.match(payoutMigration, /v_materials := 0/i);
  assert.match(payoutMigration, /round\\(v_service \\+ v_materials - v_commission,2\\)/i);
});
