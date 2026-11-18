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
function setup({ role = "customer", status = 200, user = null, env = null } = {}) {
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({ url, options });
    return {
      ok: status >= 200 && status < 300,
      status,
      json: async () => user || { id: "user-1", app_metadata: { role } }
    };
  };
  return {
    calls,
    handler: createAiServerGuard({
      fetchImpl,
      env: env || { SUPABASE_URL: "https://example.supabase.co", SUPABASE_ANON_KEY: "anon-test" }
    })
  };
}

test("AI routes require POST and bearer authentication before processing", async () => {
  const { handler, calls } = setup();
  assert.equal((await handler(event({ method: "GET" }))).statusCode, 405);
  assert.equal((await handler(event({ token: null }))).statusCode, 401);
  assert.equal(calls.length, 0);
});

test("AI route verifies bearer token with Supabase Auth and never trusts body actor/role", async () => {
  const { handler, calls } = setup();
  const response = await handler(event({ body: { module_key: "customer_support", message: "hello", role: "admin", user_id: "fake" } }));
  assert.equal(response.statusCode, 503);
  assert.equal(JSON.parse(response.body).error, "ai_not_enabled");
  assert.match(calls[0].url, /\/auth\/v1\/user$/);
  assert.equal(calls[0].options.headers.Authorization, "Bearer valid-token");
  assert.equal(calls[0].options.headers.apikey, "anon-test");
  assert.equal(calls[0].options.cache, "no-store");
});

test("oversized request bodies and malformed authenticated identities fail closed", async () => {
  const { handler, calls } = setup();
  const large = { ...event({ body: { module_key: "customer_support", message: "hi" } }), body: "x".repeat(8193) };
  assert.equal((await handler(large)).statusCode, 413);
  assert.equal(calls.length, 0);
  const malformed = setup({ user: { id: "not-a-uuid", app_metadata: { role: "customer" } } });
  assert.equal((await malformed.handler(event({ body: { module_key: "customer_support", message: "hi" } }))).statusCode, 403);
});

test("module authorization is derived only from trusted app_metadata role", async () => {
  const customer = setup({ role: "customer" });
  assert.equal((await customer.handler(event({ body: { module_key: "electrician_assistant", message: "hi" } }))).statusCode, 403);
  const forged = setup({ user: { id: "user-1", user_metadata: { role: "admin" }, app_metadata: {} } });
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
