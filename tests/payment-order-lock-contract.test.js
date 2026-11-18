"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const sql = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118040000_atomic_electrician_payment_order_link.sql"), "utf8");

test("payment order lock is service-role-only and expires after a short lease", () => {
  assert.match(sql, /lock_token uuid not null/);
  assert.match(sql, /expires_at timestamptz not null/);
  assert.match(sql, /coalesce\(auth\.jwt\(\)->>'role',''\) <> 'service_role'/);
  assert.match(sql, /now\(\)\+interval '2 minutes'/);
  assert.match(sql, /where private\.srk_payment_order_locks\.expires_at <= now\(\)/);
  assert.match(sql, /grant execute on function public\.srk_claim_payment_order_lock\(uuid\) to service_role/i);
  assert.match(sql, /grant execute on function public\.srk_release_payment_order_lock\(uuid,uuid\) to service_role/i);
});

test("order linking locks booking and lock rows, validates token expiry and exact amount", () => {
  assert.match(sql, /from public\.service_bookings\s+where id=p_booking_id\s+for update/i);
  assert.match(sql, /from private\.srk_payment_order_locks\s+where booking_id=p_booking_id\s+for update/i);
  assert.match(sql, /v_lock\.lock_token is distinct from p_lock_token/);
  assert.match(sql, /v_lock\.expires_at <= now\(\)/);
  assert.match(sql, /v_expected <> p_amount_paise/);
  assert.match(sql, /set razorpay_order_id=p_order_id,payment_status='pending'/);
});

test("order linking validates new-catalogue breakdown or legacy approved quote", () => {
  assert.match(sql, /if v_booking\.selected_category is not null then/i);
  assert.match(sql, /srk_service_role_get_booking_payment_breakdown/);
  assert.match(sql, /if v_booking\.quote_status <> 'approved' then/i);
  assert.match(sql, /RAZORPAY_ORDER_AMOUNT_MISMATCH/);
});
