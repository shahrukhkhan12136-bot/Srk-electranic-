"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261115210000_legacy_manual_payment_and_itemized_receipt.sql"), "utf8");
const commissionMigration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261117010000_reconcile_booking_commission_and_manual_payment_method.sql"), "utf8");
const payoutMigration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118100000_align_manual_payment_method_payout_trigger.sql"), "utf8");

const extract = (source, name) => {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = source.match(new RegExp("create or replace function public\\." + escaped + "\\([\\s\\S]*?\\n\\$function\\$;", "i"));
  return match?.[0] || "";
};

test("legacy manual-payment RPC is Main Admin-only and locks the booking", () => {
  const fn = extract(migration, "srk_admin_record_manual_payment");
  assert.ok(fn);
  assert.match(fn, /public\.is_srk_admin\(\)/);
  assert.match(fn, /from public\.service_bookings[\s\S]*?for update/i);
  assert.match(fn, /payment_status[\s\S]*?payment_verified_at[\s\S]*?amount_paid/);
  assert.match(fn, /razorpay_order_id[\s\S]*?razorpay_payment_id/);
});

test("manual payment evidence is inserted before booking payment state changes", () => {
  const fn = extract(migration, "srk_admin_record_manual_payment");
  const evidence = fn.indexOf("insert into public.srk_manual_payment_entries");
  const bookingUpdate = fn.indexOf("update public.service_bookings");
  const payoutInsert = fn.indexOf("insert into public.srk_electrician_payouts");
  assert.ok(evidence >= 0 && bookingUpdate > evidence && payoutInsert > bookingUpdate);
  assert.match(fn, /payment_method=p_method/);
  assert.match(fn, /payment_verified_at=clock_timestamp\(\)/);
  assert.match(fn, /exception 'BOOKING_PAYMENT_STATE_CHANGED'/i);
});

test("manual payment payout is checked against the exact labour, materials and commission split", () => {
  const fn = extract(migration, "srk_admin_record_manual_payment");
  for (const field of ["gross_service_amount", "materials_amount", "platform_commission", "electrician_payable"]) {
    assert.ok(fn.includes(field), "expected payout field " + field);
  }
  assert.match(fn, /commission_paise:=round\(v_service_paise::numeric\*v_booking\.commission_rate\/100\)/i);
  assert.match(fn, /existing_payout_does_not_match_verified_manual_payment/i);
  assert.match(fn, /on conflict \(booking_id\) do nothing/i);
});

test("commission and payout triggers observe manual payment method updates", () => {
  assert.match(commissionMigration, /before insert or update of[\s\S]*?payment_method[\s\S]*?on public\.service_bookings/i);
  assert.match(commissionMigration, /after insert or update of[\s\S]*?payment_method[\s\S]*?on public\.service_bookings/i);
  assert.match(payoutMigration, /after insert or update of[\s\S]*?payment_method[\s\S]*?on public\.service_bookings/i);
  assert.match(payoutMigration, /lower\(btrim\(e\.payment_method\)\) = lower\(btrim\(new\.payment_method\)\)/i);
});

test("manual payment RPC excludes catalogue bookings until a dedicated settlement path exists", () => {
  const fn = extract(migration, "srk_admin_record_manual_payment");
  assert.match(fn, /selected_category is not null[\s\S]*?new_category_booking_uses_dedicated_settlement/i);
});
