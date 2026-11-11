const assert = require("node:assert/strict");

process.env.SUPABASE_URL = "https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY = "service-role-test-key";
process.env.RAZORPAY_KEY_ID = "rzp_test_key";
process.env.RAZORPAY_KEY_SECRET = "rzp_test_secret";

const { handler } = require("../process-refund.js");

const requestId = "11111111-1111-4111-8111-111111111111";
const refundRecordId = "22222222-2222-4222-8222-222222222222";
const paymentId = "pay_TEST123";
const amountPaise = 125000;
let state;
let razorpayCalls;
let reconcileCalls;

function response(status, body) {
  return new Response(body === undefined ? "" : JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}

function setup({ admin = true, requestStatus = "approved", paymentStatus = "captured", paymentAmount = amountPaise, refundStatus = "processed" } = {}) {
  state = { admin, requestStatus, paymentStatus, paymentAmount, refundStatus };
  razorpayCalls = [];
  reconcileCalls = [];
  global.fetch = async (input, options = {}) => {
    const url = String(input);
    const method = options.method || "GET";
    if (url.endsWith("/auth/v1/user")) return response(200, { id: "admin-user-id" });
    if (url.endsWith("/rpc/is_srk_admin")) return response(200, state.admin);
    if (url.endsWith("/rpc/srk_admin_list_booking_refund_requests")) {
      return response(200, [{
        id: requestId,
        status: state.requestStatus,
        razorpay_payment_id: paymentId,
        amount: 1250
      }]);
    }
    if (url.endsWith("/rpc/srk_admin_prepare_booking_refund")) {
      return response(200, [{
        refund_record_id: refundRecordId,
        booking_id: "33333333-3333-4333-8333-333333333333",
        payment_id: paymentId,
        amount_paise: amountPaise,
        idempotency_key: "srk-refund-idempotency-001",
        status: "requested"
      }]);
    }
    if (url.endsWith("/rpc/srk_service_reconcile_booking_refund")) {
      reconcileCalls.push(JSON.parse(options.body));
      return response(200, { success: true });
    }
    if (url === "https://api.razorpay.com/v1/payments/" + paymentId && method === "GET") {
      razorpayCalls.push({ method, url });
      return response(200, {
        id: paymentId,
        status: state.paymentStatus,
        amount: state.paymentAmount,
        amount_refunded: 0,
        currency: "INR"
      });
    }
    if (url === "https://api.razorpay.com/v1/payments/" + paymentId + "/refund" && method === "POST") {
      razorpayCalls.push({ method, url, headers: options.headers, body: JSON.parse(options.body) });
      return response(200, {
        id: "rfnd_TEST123",
        payment_id: paymentId,
        amount: amountPaise,
        status: state.refundStatus
      });
    }
    throw new Error("Unexpected mocked fetch: " + method + " " + url);
  };
}

async function invoke({ method = "POST", authorization = "Bearer test.jwt.token", body = { request_id: requestId } } = {}) {
  return handler({
    httpMethod: method,
    headers: authorization ? { authorization } : {},
    body: JSON.stringify(body)
  });
}

(async () => {
  setup();
  assert.equal((await invoke({ method: "GET" })).statusCode, 405, "non-POST must be rejected");
  assert.equal((await invoke({ authorization: "" })).statusCode, 401, "missing session must be rejected");

  setup({ admin: false });
  assert.equal((await invoke()).statusCode, 403, "non-admin must not issue a refund");
  assert.equal(razorpayCalls.length, 0, "non-admin must not contact Razorpay");

  setup({ requestStatus: "requested" });
  assert.equal((await invoke()).statusCode, 409, "unapproved request must not issue a refund");
  assert.equal(razorpayCalls.length, 0, "unapproved request must not contact Razorpay");

  setup({ paymentStatus: "authorized" });
  assert.equal((await invoke()).statusCode, 409, "uncaptured payment must not be refunded");
  assert.equal(razorpayCalls.length, 1, "only payment status lookup should occur");

  setup({ paymentAmount: amountPaise + 100 });
  assert.equal((await invoke()).statusCode, 409, "captured amount mismatch must be rejected");
  assert.equal(razorpayCalls.length, 1, "amount mismatch must not create a refund");

  setup();
  const result = await invoke();
  assert.equal(result.statusCode, 200, "valid approved refund should reconcile");
  const payload = JSON.parse(result.body);
  assert.equal(payload.status, "processed");
  assert.equal(payload.refund_id, "rfnd_TEST123");
  assert.equal(razorpayCalls.length, 2, "payment is checked before one refund request");
  assert.equal(razorpayCalls[1].headers["X-Refund-Idempotency"], "srk-refund-idempotency-001");
  assert.equal(razorpayCalls[1].body.amount, amountPaise);
  assert.equal(reconcileCalls.length, 1, "provider result must reconcile to the ledger");
  assert.equal(reconcileCalls[0].p_provider_refund_id, "rfnd_TEST123");
  assert.equal(reconcileCalls[0].p_provider_status, "processed");

  setup({ refundStatus: "pending" });
  const pending = await invoke();
  assert.equal(pending.statusCode, 200);
  assert.equal(JSON.parse(pending.body).status, "pending");
  assert.equal(reconcileCalls[0].p_provider_status, "pending");

  console.log("Refund server handler tests passed (authorization, Admin gate, approval gate, captured amount, idempotency and reconciliation).");
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
