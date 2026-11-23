const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const handler = fs.readFileSync(path.join(root, "razorpay-refund.js"), "utf8");
const migration = fs.readFileSync(path.join(root, "supabase/migrations/20261123090000_align_razorpay_refund_preparation_with_final_bill_snapshot.sql"), "utf8");

test("refund executor authenticates Admin session and uses the current Admin preparation RPC", () => {
  assert.match(handler, /auth\/v1\/user/);
  assert.match(handler, /srk_admin_prepare_booking_refund/);
  assert.match(handler, /},match\[1\]\)/);
  assert.doesNotMatch(handler, /srk_admin_claim_razorpay_refund/);
});

test("refund preparation binds the refund to the paid Razorpay order and exact Final Bill revision", () => {
  assert.match(migration, /srk_razorpay_payment_orders/);
  assert.match(migration, /v_order\.status<>'paid'/);
  assert.match(migration, /final_bill_id/);
  assert.match(migration, /final_bill_revision/);
  assert.match(migration, /srk_booking_final_bills/);
  assert.match(migration, /v_bill\.revision_no<>v_order\.final_bill_revision/);
  assert.match(migration, /round\(v_bill\.total_amount\*100\)::bigint<>v_order\.amount_paise/);
  const nullGuard = fs.readFileSync(path.join(root, "supabase/migrations/20261123093000_harden_refund_booking_order_null_comparison.sql"), "utf8");
  assert.match(nullGuard, /v_booking\.razorpay_order_id is distinct from v_order\.razorpay_order_id/);
  assert.match(nullGuard, /v_bill\.revision_no is distinct from v_order\.final_bill_revision/);
  assert.doesNotMatch(migration, /quote_status/);
});

test("current refund policy requires the approved full Booking amount; partial refund is not silently inferred", () => {
  assert.match(migration, /REFUND_AMOUNT_MUST_EQUAL_FULL_PAID_BOOKING_AMOUNT/);
  assert.match(handler, /payment\.amount!==record\.amount_paise/);
  assert.match(handler, /amount:record\.amount_paise/);
});

test("refund provider outcome is reconciled through the service-role-only current RPC", () => {
  assert.match(handler, /srk_service_reconcile_booking_refund/);
  assert.match(handler, /p_refund_record_id/);
  assert.match(handler, /p_provider_status/);
  assert.doesNotMatch(handler, /srk_service_record_razorpay_refund_result/);
  assert.doesNotMatch(handler, /srk_service_finalize_razorpay_refund/);
});

test("refund webhook verifies HMAC and deduplicates through the private webhook inbox", () => {
  assert.match(handler, /timingSafeEqual/);
  assert.match(handler, /x-razorpay-event-id/);
  assert.match(handler, /srk_razorpay_webhook_events\?on_conflict=event_id/);
  assert.match(handler, /razorpay_refund_id:refund\.id/);
  assert.match(handler, /processing_status:"reconciled"/);
  assert.doesNotMatch(handler, /srk_service_capture_razorpay_refund_event/);
});

test("provider failure and pending outcomes remain distinct and do not falsely mark the booking refunded", () => {
  assert.match(handler, /\["pending","processed","failed"\]/);
  assert.match(migration, /srk_booking_refund_requests/);
  assert.match(handler, /state\.status==="processed"/);
  assert.match(handler, /state\.status==="failed"/);
});

test("Admin refund queue exposes provider state and the UI never retries provider-confirmed failures", () => {
  const admin = fs.readFileSync(path.join(root, "admin.html"), "utf8");
  assert.match(admin, /srk_admin_list_booking_refund_requests_v3/);
  assert.match(admin, /provider_refund_status/);
  assert.match(admin, /Razorpay ने Refund अस्वीकार किया/);
  assert.match(admin, /Provider स्थिति की पुष्टि उपलब्ध नहीं/);
  assert.match(admin, /\['processing','unknown'\]\.includes\(x\.provider_refund_status\)/);
});
