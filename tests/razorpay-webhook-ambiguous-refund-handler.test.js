const assert = require("node:assert/strict");
const crypto = require("node:crypto");

process.env.SUPABASE_URL = "https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY = "test-service-role-key";
process.env.RAZORPAY_WEBHOOK_SECRET = "test-webhook-secret";

const { handler } = require("../razorpay-webhook.js");

(async () => {
  const payload = {
    event: "refund.processed",
    payload: {
      refund: {
        entity: {
          id: "rfnd_test123",
          payment_id: "pay_test123",
          status: "processed"
        }
      }
    }
  };
  const raw = Buffer.from(JSON.stringify(payload));
  const signature = crypto.createHmac("sha256", process.env.RAZORPAY_WEBHOOK_SECRET)
    .update(raw).digest("hex");

  let fetchCalls = 0;
  global.fetch = async (url, options) => {
    fetchCalls += 1;
    assert.equal(options?.method || "GET", "GET", "ambiguous lookup must not write");
    const parsed = new URL(url);
    assert.equal(parsed.pathname, "/rest/v1/srk_razorpay_refunds");
    assert.equal(parsed.searchParams.get("payment_id"), "eq.pay_test123");
    assert.equal(parsed.searchParams.get("limit"), "2");
    return {
      ok: true,
      json: async () => [
        { id: "refund-row-1", refund_id: null, status: "pending" },
        { id: "refund-row-2", refund_id: null, status: "pending" }
      ]
    };
  };

  const response = await handler({
    httpMethod: "POST",
    headers: { "x-razorpay-signature": signature },
    body: raw.toString("utf8"),
    isBase64Encoded: false
  });

  assert.equal(response.statusCode, 500);
  const body = JSON.parse(response.body);
  assert.equal(body.retry, true);
  assert.equal(body.error, "ambiguous_refund_ledger_match");
  assert.equal(fetchCalls, 1, "must stop after ambiguous lookup; no event claim or reconciliation writes");
  console.log("Razorpay ambiguous refund handler runtime test passed.");
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
