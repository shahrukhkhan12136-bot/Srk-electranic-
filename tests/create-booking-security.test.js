const test = require("node:test");
const assert = require("node:assert/strict");

process.env.SUPABASE_URL = "https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY = "test-service-role-key";
const { handler } = require("../create-booking.js");

function response(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => JSON.stringify(body),
    json: async () => body
  };
}

function baseEvent(overrides = {}) {
  return {
    httpMethod: "POST",
    headers: {
      "x-nf-client-connection-ip": "203.0.113.11",
      authorization: "Bearer customer-access-token"
    },
    body: JSON.stringify({
      customer_name: "Test Customer",
      phone: "9000000001",
      state: "Uttar Pradesh",
      district: "Balrampur",
      pincode: "271861",
      address: "Test address",
      service_type: "Wiring",
      preferred_date: "2026-12-01",
      service_category_code: "helper",
      idempotency_key: "123e4567-e89b-42d3-a456-426614174000"
    }),
    ...overrides
  };
}

test("rejects non-POST methods without contacting Supabase", async (t) => {
  const originalFetch = global.fetch;
  t.after(() => { global.fetch = originalFetch; });
  let calls = 0;
  global.fetch = async () => { calls++; throw new Error("fetch must not run"); };
  const result = await handler(baseEvent({ httpMethod: "GET" }));
  assert.equal(result.statusCode, 405);
  assert.equal(calls, 0);
});

test("fails closed when trusted client IP is unavailable", async (t) => {
  const originalFetch = global.fetch;
  t.after(() => { global.fetch = originalFetch; });
  let calls = 0;
  global.fetch = async () => { calls++; throw new Error("fetch must not run"); };
  const result = await handler(baseEvent({ headers: { authorization: "Bearer customer-access-token" } }));
  assert.equal(result.statusCode, 503);
  assert.equal(calls, 0);
});

test("rejects invalid customer sessions before booking RPC", async (t) => {
  const originalFetch = global.fetch;
  t.after(() => { global.fetch = originalFetch; });
  const calls = [];
  global.fetch = async (url) => {
    calls.push(String(url));
    if (String(url).includes("/rpc/srk_check_public_rate_limit")) return response(true);
    if (String(url).includes("/auth/v1/user")) return response({ message: "invalid token" }, 401);
    throw new Error("Unexpected fetch: " + url);
  };
  const result = await handler(baseEvent());
  assert.equal(result.statusCode, 401);
  assert.equal(calls.some(url => url.includes("/rpc/srk_create_customer_booking")), false);
});

test("rejects a verified account whose phone does not match booking phone", async (t) => {
  const originalFetch = global.fetch;
  t.after(() => { global.fetch = originalFetch; });
  const calls = [];
  global.fetch = async (url) => {
    calls.push(String(url));
    if (String(url).includes("/rpc/srk_check_public_rate_limit")) return response(true);
    if (String(url).includes("/auth/v1/user")) {
      return response({ id: "30000000-0000-0000-0000-000000000011", phone: "+919000000099", phone_confirmed_at: "2026-01-01T00:00:00Z" });
    }
    throw new Error("Unexpected fetch: " + url);
  };
  const result = await handler(baseEvent());
  assert.equal(result.statusCode, 403);
  assert.match(JSON.parse(result.body).error, /मोबाइल/);
  assert.equal(calls.some(url => url.includes("/rpc/srk_create_customer_booking")), false);
});
