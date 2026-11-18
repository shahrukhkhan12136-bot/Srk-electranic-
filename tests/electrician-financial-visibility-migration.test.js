const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118033000_gate_electrician_financial_visibility.sql"), "utf8");
const ui = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");

test("offer RPC returns a distinct electrician net field, never the gross estimate column", () => {
  assert.match(migration, /electrician_offer_paise bigint/);
  assert.match(migration, /floor\(\(b\.estimated_labour_paise::numeric\*8500\+5000\)\/10000\)::bigint/);
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
  assert.ok(migration.includes("b.razorpay_order_id IS NOT NULL AND b.payment_status='pending'"));
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
  assert.doesNotMatch(migration, /\$\{net\}/);
  assert.match(migration, /bill\.labour_amount IS NOT NULL/);
  assert.match(migration, /WHEN verified\.is_verified THEN coalesce\(b\.amount_paid,0\)\s+ELSE 0/);
});

test("paid-but-unverified and refunded bookings never receive unpaid 85 percent earnings", () => {
  assert.match(migration, /payment_verification_required/);
  assert.match(migration, /payment_status IS DISTINCT FROM 'refunded'/);
  assert.match(migration, /payment_status IS DISTINCT FROM 'paid'/);
  assert.match(ui, /x\.payment_stage==='payment_verification_required'/);
});

test("85 percent is rounded in integer paise with the residual assigned to the company", () => {
  assert.match(migration, /floor\(\(round\(coalesce\(bill\.labour_amount,0\)\*100\)\*8500\+5000\)\/10000\)/);
  assert.match(migration, /round\(coalesce\(bill\.labour_amount,0\),2\)-\(floor\(/);
  assert.doesNotMatch(migration, /round\(coalesce\(bill\.labour_amount,0\)\*0\.15,2\)/);
});

const createOrder = fs.readFileSync(path.join(__dirname, "../create-order.js"), "utf8");
const verifyPayment = fs.readFileSync(path.join(__dirname, "../verify-payment.js"), "utf8");
const razorpayWebhook = fs.readFileSync(path.join(__dirname, "../razorpay-webhook.js"), "utf8");

test("Razorpay order amount comes from immutable server bill and persisted fee ledger", () => {
  assert.match(createOrder, /srk_service_role_get_booking_payment_breakdown/);
  assert.match(createOrder, /total!==labour\+fees/);
  assert.match(createOrder, /Number\.isSafeInteger\(total\)/);
  assert.doesNotMatch(createOrder, /b\.amount\s*\|\|/);
});

test("Razorpay order is persisted with pending state before checkout response", () => {
  assert.match(createOrder, /razorpay_order_id:order\.id,payment_status:"pending"/);
  assert.ok(createOrder.indexOf('body:JSON.stringify({razorpay_order_id:order.id,payment_status:"pending"})') < createOrder.indexOf('return json(200,{success:true,key_id:RAZORPAY_KEY_ID'));
});

test("customer payment verification checks HMAC, captured status, order, INR and exact amount", () => {
  assert.match(verifyPayment, /createHmac\("sha256",RAZORPAY_KEY_SECRET\)/);
  assert.match(verifyPayment, /p\.status!=="captured"/);
  assert.match(verifyPayment, /p\.order_id!==orderId/);
  assert.match(verifyPayment, /p\.currency!=="INR"/);
  assert.match(verifyPayment, /p\.amount!==expectedAmount/);
});

test("categorized online payment settles through the server-owned payment ledger RPC", () => {
  assert.match(verifyPayment, /srk_service_role_record_online_booking_payment/);
  assert.match(razorpayWebhook, /srk_service_role_record_online_booking_payment/);
  assert.match(razorpayWebhook, /payment\.status !== "captured"/);
});

test("checkout stage is derived from completed booking and persisted pending order", () => {
  assert.match(migration, /b\.status='completed' AND b\.razorpay_order_id IS NOT NULL AND b\.payment_status='pending'/);
  assert.match(migration, /WHEN b\.status='completed' AND checkout\.started THEN 'checkout_started'/);
});
