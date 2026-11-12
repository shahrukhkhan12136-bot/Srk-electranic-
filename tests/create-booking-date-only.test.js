const test = require("node:test");
const assert = require("node:assert/strict");

process.env.SUPABASE_URL = "https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY = "test-service-role-key";
const { handler } = require("../create-booking.js");

const customer = {
  customer_name: "Test Customer",
  phone: "9000000001",
  state: "Uttar Pradesh",
  district: "Balrampur",
  pincode: "271861",
  address: "Test address",
  service_type: "Wiring",
  preferred_date: "2026-12-01",
  work_details: "Switch repair",
  service_category_code: "helper",
  duration_hours: 3,
  idempotency_key: "123e4567-e89b-42d3-a456-426614174000"
};

function response(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => JSON.stringify(body),
    json: async () => body
  };
}

function event(overrides = {}) {
  return {
    httpMethod: "POST",
    headers: {
      "x-nf-client-connection-ip": "203.0.113.10",
      authorization: "Bearer customer-access-token"
    },
    body: JSON.stringify(customer),
    ...overrides
  };
}

test("accepts a date-only customer booking and never forwards preferred_time", async (t) => {
  const originalFetch = global.fetch;
  t.after(() => { global.fetch = originalFetch; });
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url: String(url), options });
    if (String(url).includes("/rpc/srk_check_public_rate_limit")) return response(true);
    if (String(url).includes("/auth/v1/user")) {
      return response({ id: "30000000-0000-0000-0000-000000000001", phone: "+919000000001", phone_confirmed_at: "2026-01-01T00:00:00Z" });
    }
    if (String(url).includes("/rpc/srk_create_customer_booking")) {
      return response({ success: true, booking_id: "10000000-0000-0000-0000-000000000001", replayed: false, duration_hours: 3, estimated_labour_amount_snapshot: 337.13 });
    }
    if (String(url).includes("/service_bookings?")) return response([{ order_number: "SRK-ORD-000001" }]);
    if (String(url).includes("/job_offers?")) return response([]);
    throw new Error("Unexpected fetch: " + url);
  };

  const result = await handler(event());
  assert.equal(result.statusCode, 200);
  const body = JSON.parse(result.body);
  assert.equal(body.success, true);
  assert.equal(body.order_number, "SRK-ORD-000001");
  assert.equal(body.duration_hours, 3);
  assert.equal(body.estimated_labour_amount_snapshot, 337.13);

  const rpcCall = calls.find((call) => call.url.includes("/rpc/srk_create_customer_booking"));
  assert.ok(rpcCall, "customer booking RPC should be called");
  const payload = JSON.parse(rpcCall.options.body);
  assert.equal(payload.p_booking.preferred_date, "2026-12-01");
  assert.equal(payload.p_booking.duration_hours, 3);
  assert.equal(Object.hasOwn(payload.p_booking, "preferred_time"), false);
});

test("rejects an impossible calendar date before calling the booking RPC", async (t) => {
  const originalFetch = global.fetch;
  t.after(() => { global.fetch = originalFetch; });
  const calls = [];
  global.fetch = async (url) => {
    calls.push(String(url));
    if (String(url).includes("/rpc/srk_check_public_rate_limit")) return response(true);
    if (String(url).includes("/auth/v1/user")) {
      return response({ id: "30000000-0000-0000-0000-000000000001", phone: "+919000000001", phone_confirmed_at: "2026-01-01T00:00:00Z" });
    }
    throw new Error("Unexpected fetch: " + url);
  };

  const invalid = { ...customer, preferred_date: "2026-02-30" };
  const result = await handler(event({ body: JSON.stringify(invalid) }));
  assert.equal(result.statusCode, 400);
  assert.equal(JSON.parse(result.body).success, false);
  assert.equal(calls.some((url) => url.includes("/rpc/srk_create_customer_booking")), false);
});

test("rejects duration outside the 1-to-8-hour range before booking RPC", async (t) => {
  const originalFetch = global.fetch;
  t.after(() => { global.fetch = originalFetch; });
  const calls = [];
  global.fetch = async (url) => {
    calls.push(String(url));
    if (String(url).includes("/rpc/srk_check_public_rate_limit")) return response(true);
    throw new Error("Unexpected fetch: " + url);
  };
  for (const duration_hours of [0, 9, 1.5, "3", null]) {
    const result = await handler(event({ body: JSON.stringify({ ...customer, duration_hours }) }));
    assert.equal(result.statusCode, 400, "invalid duration should be rejected: " + String(duration_hours));
  }
  assert.equal(calls.some((url) => url.includes("/rpc/srk_create_customer_booking")), false);
});
