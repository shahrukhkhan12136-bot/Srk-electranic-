// Isolated synthetic regression tests for create-order and verify-payment.
// All Supabase and Razorpay HTTP calls are mocked; no external services or money.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");

process.env.SUPABASE_URL = "https://mock.supabase.test";
process.env.SUPABASE_SERVICE_ROLE_KEY = "mock-service-role";
process.env.RAZORPAY_KEY_ID = "rzp_test_SYNTHETIC";
process.env.RAZORPAY_KEY_SECRET = "synthetic-razorpay-secret";

let booking, user, razorpayOrder, razorpayPayment;
let orderApiStatus = 200, failPatch = false;
const calls = [];
const clone = x => x == null ? x : structuredClone(x);
global.fetch = async (input, init = {}) => {
  const url = new URL(input);
  const method = init.method || "GET";
  calls.push({ url: url.toString(), method });
  if (url.pathname === "/auth/v1/user") {
    if (!user) return new Response("unauthorized", { status: 401 });
    return Response.json(clone(user));
  }
  if (url.hostname === "api.razorpay.com" && url.pathname.startsWith("/v1/orders/")) {
    if (orderApiStatus !== 200) return Response.json({ error: { description: "mock provider error" } }, { status: orderApiStatus });
    if (!razorpayOrder) return Response.json({ error: { description: "not found" } }, { status: 404 });
    return Response.json(clone(razorpayOrder));
  }
  if (url.hostname === "api.razorpay.com" && url.pathname === "/v1/orders" && method === "POST") {
    razorpayOrder = { id: "order_SYNTHETIC123", amount: JSON.parse(init.body).amount, currency: "INR", status: "created" };
    return Response.json(clone(razorpayOrder));
  }
  if (url.hostname === "api.razorpay.com" && url.pathname.startsWith("/v1/payments/")) {
    return razorpayPayment ? Response.json(clone(razorpayPayment)) : Response.json({}, { status: 404 });
  }
  if (url.pathname === "/rest/v1/rpc/srk_claim_payment_order_lock" && method === "POST") return Response.json("mock-lock-token");
  if (url.pathname === "/rest/v1/rpc/srk_release_payment_order_lock" && method === "POST") return Response.json(null);
  if (url.pathname.startsWith("/rest/v1/service_bookings")) {
    if (method === "GET") {
      const orderFilter = url.searchParams.get("razorpay_order_id");
      if (orderFilter && booking.razorpay_order_id !== orderFilter.slice(3)) return Response.json([]);
      return Response.json(booking ? [clone(booking)] : []);
    }
    if (method === "PATCH") {
      if (failPatch || booking.payment_status === "paid") return Response.json([]);
      Object.assign(booking, JSON.parse(init.body));
      return Response.json([clone(booking)]);
    }
  }
  return new Response("Unexpected mock request: " + method + " " + url.pathname, { status: 500 });
};

const createOrder = require("../create-order.js").handler;
const verifyPayment = require("../verify-payment.js").handler;
const baseBooking = () => ({
  id: "11111111-1111-4111-8111-111111111111",
  phone: "+919876543210",
  customer_user_id: "customer-uuid-1",
  quoted_amount: 120, service_charge: 100, materials_amount: 20,
  payment_status: "unpaid", razorpay_order_id: null, razorpay_payment_id: null,
  status: "completed", quote_status: "approved"
});
const baseUser = () => ({ id: "customer-uuid-1", phone: "+919876543210", phone_confirmed_at: "2026-01-01T00:00:00Z" });
const reset = () => {
  booking = baseBooking(); user = baseUser(); razorpayOrder = null; razorpayPayment = null;
  orderApiStatus = 200; failPatch = false; calls.length = 0;
};
const req = (body = {}, headers = {}) => ({ httpMethod: "POST", headers: { authorization: "Bearer synthetic.jwt.token", ...headers }, body: JSON.stringify(body) });
const results = [];
const pass = name => results.push({ name, result: "PASS" });

(async () => {
  reset();
  let r = await createOrder({ httpMethod: "GET", headers: {}, body: "" });
  assert.equal(r.statusCode, 405); pass("create-order rejects non-POST");

  reset();
  r = await createOrder(req({ booking_id: "not-a-uuid" }));
  assert.equal(r.statusCode, 400);
  pass("create-order rejects malformed booking UUID");

  reset(); user = null;
  r = await createOrder(req({ booking_id: booking.id }));
  assert.equal(r.statusCode, 401); pass("create-order requires a valid customer session");

  reset(); user.id = "another-customer";
  r = await createOrder(req({ booking_id: booking.id }));
  assert.equal(r.statusCode, 403); pass("create-order rejects booking owned by another customer");

  reset(); booking.status = "in_progress";
  r = await createOrder(req({ booking_id: booking.id }));
  assert.equal(r.statusCode, 409); pass("create-order rejects incomplete work");

  reset();
  r = await createOrder(req({ booking_id: booking.id }));
  assert.equal(r.statusCode, 200);
  assert.equal(JSON.parse(r.body).amount, 12000);
  assert.equal(booking.payment_status, "pending");
  assert.equal(booking.razorpay_order_id, "order_SYNTHETIC123");
  pass("create-order creates exact INR paise order and stores pending state");

  reset(); booking.razorpay_order_id = "order_OLD123"; orderApiStatus = 503;
  r = await createOrder(req({ booking_id: booking.id }));
  assert.equal(r.statusCode, 502);
  assert.equal(calls.some(c => c.url.endsWith("/v1/orders") && c.method === "POST"), false);
  pass("create-order does not create a second order when prior order lookup is uncertain");

  reset();
  r = await verifyPayment({ httpMethod: "GET", headers: {}, body: "" });
  assert.equal(r.statusCode, 405); pass("verify-payment rejects non-POST");

  reset();
  r = await verifyPayment(req({ razorpay_payment_id: "pay_SYNTHETIC123", razorpay_order_id: "order_SYNTHETIC123", razorpay_signature: "0".repeat(64) }));
  assert.equal(r.statusCode, 400); pass("verify-payment rejects invalid signature before provider lookup");

  reset(); booking.razorpay_order_id = "order_SYNTHETIC123";
  const payId = "pay_SYNTHETIC123";
  const signature = crypto.createHmac("sha256", process.env.RAZORPAY_KEY_SECRET).update("order_SYNTHETIC123|" + payId).digest("hex");
  razorpayPayment = { id: payId, order_id: "order_SYNTHETIC123", status: "captured", amount: 12000, currency: "INR" };
  r = await verifyPayment(req({ razorpay_payment_id: payId, razorpay_order_id: "order_SYNTHETIC123", razorpay_signature: signature }));
  assert.equal(r.statusCode, 200); assert.equal(booking.payment_status, "paid"); assert.equal(booking.razorpay_payment_id, payId);
  pass("verify-payment accepts captured payment with exact order and amount");

  r = await verifyPayment(req({ razorpay_payment_id: payId, razorpay_order_id: "order_SYNTHETIC123", razorpay_signature: signature }));
  assert.equal(r.statusCode, 200); pass("verify-payment is idempotent for the same already-verified payment");

  reset(); booking.razorpay_order_id = "order_SYNTHETIC123";
  razorpayPayment = { id: payId, order_id: "order_SYNTHETIC123", status: "captured", amount: 11999, currency: "INR" };
  r = await verifyPayment(req({ razorpay_payment_id: payId, razorpay_order_id: "order_SYNTHETIC123", razorpay_signature: signature }));
  assert.equal(r.statusCode, 409); assert.equal(booking.payment_status, "unpaid");
  pass("verify-payment rejects amount mismatch without marking booking paid");

  reset(); booking.razorpay_order_id = "order_SYNTHETIC123";
  booking.payment_status = "paid"; booking.razorpay_payment_id = "pay_OTHER123";
  r = await verifyPayment(req({ razorpay_payment_id: payId, razorpay_order_id: "order_SYNTHETIC123", razorpay_signature: signature }));
  assert.equal(r.statusCode, 409); pass("verify-payment flags a different payment ID on an already-paid booking");

  console.log(JSON.stringify({ tests: results, passed: results.length, realSupabaseCalls: 0, realRazorpayCalls: 0 }, null, 2));
})().catch(error => { console.error(error); process.exitCode = 1; });

// Syntax and regression checks run in GitHub Actions with fully mocked HTTP.
