const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const migration = fs.readFileSync(path.join(root, "supabase/migrations/20261114140000_manual_labour_only_refund_workflow.sql"), "utf8");
const admin = fs.readFileSync(path.join(root, "admin.html"), "utf8");

test("manual refund workflow has a private durable intent with explicit lifecycle", () => {
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.srk_manual_refund_intents/);
  assert.match(migration, /'prepared','paid','processed','requires_reconciliation'/);
  assert.match(migration, /transfer_reference text/);
});

test("manual refund preparation is Admin-only and labour-bill exact", () => {
  assert.match(migration, /srk_admin_prepare_manual_booking_refund/);
  assert.match(migration, /public\.is_srk_admin\(\)/);
  assert.match(migration, /srk_booking_labour_bills/);
  assert.match(migration, /round\(v_req\.amount\*100\)::bigint<>v_bill\.labour_amount_paise/);
});

test("manual path excludes Razorpay and requires a verified manual payment entry", () => {
  assert.match(migration, /RAZORPAY_PAYMENT_MUST_USE_RAZORPAY_REFUND_WORKFLOW/);
  assert.match(migration, /srk_manual_payment_entries/);
  assert.match(migration, /VERIFIED_MANUAL_PAYMENT_ENTRY_REQUIRED/);
});

test("manual refund blocks payout and pooled cash-fee conflicts before preparation", () => {
  assert.match(migration, /payout_status='blocked'/);
  assert.match(migration, /cash_due_settlement/);
  assert.match(migration, /ELECTRICIAN_PAYOUT_ALREADY_PAID_ADMIN_RECONCILIATION_REQUIRED/);
});

test("actual transfer evidence is persisted in a separate RPC before finalization", () => {
  assert.match(migration, /srk_admin_record_manual_refund_transfer/);
  assert.match(migration, /status='paid',transfer_reference=v_ref/);
  assert.match(migration, /srk_admin_finalize_manual_booking_refund/);
  assert.ok(migration.indexOf("status='paid',transfer_reference=v_ref") < migration.indexOf("UPDATE public.service_bookings SET payment_status='refunded'"));
});

test("finalization restores only its own payout block marker and records manual audit", () => {
  assert.match(migration, /SRK_MANUAL_REFUND:/);
  assert.match(migration, /PAYOUT_BLOCK_MARKER_MISMATCH/);
  assert.match(migration, /INSERT INTO public\.srk_manual_refund_entries/);
});

test("Admin UI exposes preparation, transfer evidence, and ledger finalization separately", () => {
  assert.match(admin, /srk_admin_list_booking_refund_requests_v2/);
  assert.match(admin, /srk_admin_prepare_manual_booking_refund/);
  assert.match(admin, /srk_admin_record_manual_refund_transfer/);
  assert.match(admin, /srk_admin_finalize_manual_booking_refund/);
});
