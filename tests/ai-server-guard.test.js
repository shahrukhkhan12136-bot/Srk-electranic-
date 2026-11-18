"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { createAiServerGuard } = require("../lib/ai-server-guard");

const UUID = "123e4567-e89b-42d3-a456-426614174000";
function event({ method = "POST", token = "valid-token", key = UUID, body = {} } = {}) {
  return {
    httpMethod: method,
    headers: {
      ...(token ? { authorization: "Bearer " + token } : {}),
      ...(key ? { "idempotency-key": key } : {})
    },
    body: JSON.stringify(body)
  };
}
function setup({ role = "customer", status = 200, user = null, env = null, customerProfiles = null, electricianProfiles = null } = {}) {
  const calls = [];
  const authUser = user || { id: "123e4567-e89b-42d3-a456-426614174001", app_metadata: { role } };
  const customerRows = customerProfiles || (role === "customer" ? [{ user_id: authUser.id }] : []);
  const electricianRows = electricianProfiles || (role === "electrician" ? [{ id: UUID }] : []);
  const fetchImpl = async (url, options) => {
    calls.push({ url, options });
    if (url.includes("/auth/v1/user")) {
      return {
        ok: status >= 200 && status < 300,
        status,
        json: async () => authUser
      };
    }
    if (url.includes("/rest/v1/srk_customer_profiles")) {
      return { ok: true, status: 200, json: async () => customerRows };
    }
    if (url.includes("/rest/v1/electrician_profiles")) {
      return { ok: true, status: 200, json: async () => electricianRows };
    }
    throw new Error("Unexpected URL");
  };
  return {
    calls,
    handler: createAiServerGuard({
      fetchImpl,
      env: env || {
        SUPABASE_URL: "https://example.supabase.co",
        SUPABASE_ANON_KEY: "anon-test",
        SUPABASE_SERVICE_ROLE_KEY: "service-role-test"
      }
    })
  };
}

test("AI routes require POST and bearer authentication before processing", async () => {
  const { handler, calls } = setup();
  assert.equal((await handler(event({ method: "GET" }))).statusCode, 405);
  assert.equal((await handler(event({ token: null }))).statusCode, 401);
  assert.equal(calls.length, 0);
});

test("AI route verifies bearer token and checks profile records before rejecting live operation", async () => {
  const { handler, calls } = setup();
  const response = await handler(event({ body: { module_key: "customer_support", message: "hello", role: "admin", user_id: "fake" } }));
  assert.equal(response.statusCode, 503);
  assert.equal(JSON.parse(response.body).error, "ai_not_enabled");
  assert.match(calls[0].url, /\/auth\/v1\/user$/);
  assert.equal(calls[0].options.headers.Authorization, "Bearer valid-token");
  assert.equal(calls[0].options.headers.apikey, "anon-test");
  assert.equal(calls[0].options.cache, "no-store");
  assert.equal(calls.length, 3);
  assert.ok(calls[1].url.includes("/rest/v1/srk_customer_profiles"));
  assert.ok(calls[2].url.includes("/rest/v1/electrician_profiles"));
  assert.equal(calls[1].options.headers.Authorization, "Bearer service-role-test");
});

test("oversized request bodies and malformed authenticated identities fail closed", async () => {
  const { handler, calls } = setup();
  const large = { ...event({ body: { module_key: "customer_support", message: "hi" } }), body: "x".repeat(8193) };
  assert.equal((await handler(large)).statusCode, 413);
  assert.equal(calls.length, 0);
  const malformed = setup({ user: { id: "not-a-uuid", app_metadata: { role: "customer" } } });
  assert.equal((await malformed.handler(event({ body: { module_key: "customer_support", message: "hi" } }))).statusCode, 403);
});

test("module authorization is derived from application profile records, not app_metadata", async () => {
  const customer = setup({ role: "customer", user: { id: "123e4567-e89b-42d3-a456-426614174001", app_metadata: { role: "electrician" } } });
  assert.equal((await customer.handler(event({ body: { module_key: "customer_support", message: "hi" } }))).statusCode, 503);
  assert.equal((await customer.handler(event({ body: { module_key: "electrician_assistant", message: "hi" } }))).statusCode, 403);
  const forged = setup({ user: { id: "user-1", user_metadata: { role: "admin" }, app_metadata: { role: "admin" } } });
  assert.equal((await forged.handler(event({ body: { module_key: "reports_operations", message: "hi" } }))).statusCode, 403);
});

test("staff and reports modules remain denied until database-backed RBAC is implemented", async () => {
  const staff = setup({ role: "staff" });
  const admin = setup({ role: "admin" });
  assert.equal((await staff.handler(event({ body: { module_key: "staff_assistant", message: "hi" } }))).statusCode, 403);
  assert.equal((await admin.handler(event({ body: { module_key: "reports_operations", message: "hi" } }))).statusCode, 403);
});

test("malformed assistant requests and missing idempotency keys are rejected", async () => {
  const { handler } = setup();
  assert.equal((await handler(event({ key: null, body: { module_key: "customer_support", message: "hi" } }))).statusCode, 400);
  assert.equal((await handler(event({ body: { module_key: "customer_support", message: " " } }))).statusCode, 400);
  assert.equal((await handler(event({ body: { module_key: "customer_support", message: "hi", context: { owner_id: UUID } } }))).statusCode, 400);
});

test("handoff requests are validated and remain disabled until persistence and audit exist", async () => {
  const { handler } = setup();
  const bad = await handler(event({ body: { module_key: "customer_support", conversation_id: "bad", reason_code: "needs_human_support" } }), "handoff");
  assert.equal(bad.statusCode, 400);
  const good = await handler(event({ body: {
    module_key: "customer_support",
    conversation_id: UUID,
    reason_code: "needs_human_support",
    urgency: "normal",
    summary: "Please connect me to support"
  } }), "handoff");
  assert.equal(good.statusCode, 503);
  assert.equal(JSON.parse(good.body).error, "ai_not_enabled");
});

test("Supabase authentication failures fail closed", async () => {
  const { handler } = setup({ status: 401 });
  const response = await handler(event({ body: { module_key: "customer_support", message: "hello" } }));
  assert.equal(response.statusCode, 401);
});


test("electrician access requires one active approved profile with both identity columns matching Auth", async () => {
  const valid = setup({ role: "electrician" });
  assert.equal((await valid.handler(event({ body: { module_key: "electrician_assistant", message: "hi" } }))).statusCode, 503);
  const query = new URL(valid.calls[2].url);
  assert.equal(query.searchParams.get("user_id"), "eq.123e4567-e89b-42d3-a456-426614174001");
  assert.equal(query.searchParams.get("auth_user_id"), "eq.123e4567-e89b-42d3-a456-426614174001");
  assert.equal(query.searchParams.get("verification_status"), "eq.approved");
  assert.equal(query.searchParams.get("active"), "eq.true");

  const mismatched = setup({ role: "electrician", electricianProfiles: [] });
  assert.equal((await mismatched.handler(event({ body: { module_key: "electrician_assistant", message: "hi" } }))).statusCode, 403);
});

test("AI profile lookup fails closed when server service-role credentials are missing", async () => {
  const noServiceKey = setup({ env: { SUPABASE_URL: "https://example.supabase.co", SUPABASE_ANON_KEY: "anon-test" } });
  assert.equal((await noServiceKey.handler(event({ body: { module_key: "customer_support", message: "hi" } }))).statusCode, 503);
  assert.equal(noServiceKey.calls.length, 1);
});

test("customer without an optional saved profile row is denied rather than assigned a guessed role", async () => {
  const noProfile = setup({ role: "customer", customerProfiles: [] });
  const response = await noProfile.handler(event({
    body: { module_key: "customer_support", message: "hello" }
  }));
  assert.equal(response.statusCode, 403);
  assert.equal(JSON.parse(response.body).error, "ai_access_denied");
});


test("customer and approved electrician modules are independently authorized for dual-profile accounts", async () => {
  const dual = setup({
    role: "customer",
    customerProfiles: [{ user_id: "123e4567-e89b-42d3-a456-426614174001" }],
    electricianProfiles: [{ id: UUID }]
  });
  const customer = await dual.handler(event({
    body: { module_key: "customer_support", message: "hello" }
  }));
  assert.equal(customer.statusCode, 503);
  assert.equal(JSON.parse(customer.body).error, "ai_not_enabled");

  const electrician = await dual.handler(event({
    body: { module_key: "electrician_assistant", message: "hello" }
  }));
  assert.equal(electrician.statusCode, 503);
  assert.equal(JSON.parse(electrician.body).error, "ai_not_enabled");

  const wrongModule = await dual.handler(event({
    body: { module_key: "reports_operations", message: "hello" }
  }));
  assert.equal(wrongModule.statusCode, 403);
});


test("duplicate Customer or Electrician profile rows fail closed instead of choosing an arbitrary identity", async () => {
  const duplicateCustomer = setup({
    role: "customer",
    customerProfiles: [
      { user_id: "123e4567-e89b-42d3-a456-426614174001" },
      { user_id: "123e4567-e89b-42d3-a456-426614174001" }
    ]
  });
  const customerResponse = await duplicateCustomer.handler(event({
    body: { module_key: "customer_support", message: "hello" }
  }));
  assert.equal(customerResponse.statusCode, 403);
  assert.equal(JSON.parse(customerResponse.body).error, "ai_access_denied");

  const duplicateElectrician = setup({
    role: "electrician",
    electricianProfiles: [{ id: UUID }, { id: "123e4567-e89b-42d3-a456-426614174002" }]
  });
  const electricianResponse = await duplicateElectrician.handler(event({
    body: { module_key: "electrician_assistant", message: "hello" }
  }));
  assert.equal(electricianResponse.statusCode, 403);
  assert.equal(JSON.parse(electricianResponse.body).error, "ai_access_denied");
});


test("AI profile lookup HTTP errors and malformed profile payloads fail closed", async () => {
  const baseEnv = {
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_ANON_KEY: "anon-test",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-test"
  };
  const makeHandler = (profileResponse) => createAiServerGuard({
    env: baseEnv,
    fetchImpl: async (url) => {
      if (url.includes("/auth/v1/user")) {
        return { ok: true, status: 200, json: async () => ({ id: "123e4567-e89b-42d3-a456-426614174001" }) };
      }
      return profileResponse(url);
    }
  });
  const request = event({ body: { module_key: "customer_support", message: "hello" } });

  const unavailable = makeHandler(async (url) => ({
    ok: !url.includes("/srk_customer_profiles"),
    status: url.includes("/srk_customer_profiles") ? 500 : 200,
    json: async () => []
  }));
  const unavailableResponse = await unavailable(request);
  assert.equal(unavailableResponse.statusCode, 503);
  assert.equal(JSON.parse(unavailableResponse.body).error, "ai_service_unavailable");

  const malformed = makeHandler(async (url) => ({
    ok: true,
    status: 200,
    json: async () => url.includes("/srk_customer_profiles") ? { user_id: "123e4567-e89b-42d3-a456-426614174001" } : []
  }));
  const malformedResponse = await malformed(request);
  assert.equal(malformedResponse.statusCode, 503);
  assert.equal(JSON.parse(malformedResponse.body).error, "ai_service_unavailable");
});
