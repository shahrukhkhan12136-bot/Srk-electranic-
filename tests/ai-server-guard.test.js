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
  const electricianRows = electricianProfiles || (role === "electrician" ? [{
    id: UUID, user_id: authUser.id, auth_user_id: authUser.id,
    verification_status: "approved", active: true
  }] : []);
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
  const malformedBearer = event();
  malformedBearer.headers.authorization = "Bearer\\svalid-token";
  assert.equal((await handler(malformedBearer)).statusCode, 401);
  assert.equal(calls.length, 0, "malformed bearer headers must not reach Supabase");
  for (const malformedValue of ["Bearer valid-token\n", "Bearer valid-token\r\n", "Bearer\nvalid-token"]) {
    const malformedHeader = event();
    malformedHeader.headers.authorization = malformedValue;
    assert.equal((await handler(malformedHeader)).statusCode, 401);
  }
  assert.equal(calls.length, 0, "Bearer headers with trailing or embedded line breaks must not reach Supabase");
  const tabBearer = event({ body: { module_key: "customer_support", message: "hello" } });
  delete tabBearer.headers.authorization;
  tabBearer.headers.Authorization = "Bearer\tvalid-token";
  assert.equal((await handler(tabBearer)).statusCode, 503);
  assert.equal(JSON.parse((await handler(event({ body: { module_key: "customer_support", message: "hello" } }))).body).error, "ai_not_enabled");
  assert.equal(calls.length, 6);
});

test("AI route verifies bearer token and checks profile records before rejecting live operation", async () => {
  const { handler, calls } = setup();
  const response = await handler(event({ body: { module_key: "customer_support", message: "hello" } }));
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

test("handoff requires a non-empty bounded summary", async () => {
  const { handler } = setup();
  for (const summary of [undefined, "", "   ", 42, "x".repeat(1001)]) {
    const body = {
      module_key: "customer_support",
      conversation_id: UUID,
      reason_code: "needs_human_support",
      urgency: "normal"
    };
    if (summary !== undefined) body.summary = summary;
    const response = await handler(event({ body }), "handoff");
    assert.equal(response.statusCode, 400);
  }
});

test("malformed Supabase Auth JSON is rejected before any profile lookup", async () => {
  const calls = [];
  const handler = createAiServerGuard({
    env: {
      SUPABASE_URL: "https://project.supabase.co",
      SUPABASE_ANON_KEY: "anon-test",
      SUPABASE_SERVICE_ROLE_KEY: "service-role-test"
    },
    fetchImpl: async (url) => {
      calls.push(url);
      return {
        ok: true, status: 200,
        json: async () => { throw new Error("malformed auth response"); }
      };
    }
  });
  const response = await handler(event({
    body: { module_key: "customer_support", message: "hi" }
  }));
  assert.equal(response.statusCode, 401);
  assert.equal(JSON.parse(response.body).error, "authentication_required");
  assert.equal(calls.length, 1);
  assert.ok(calls[0].includes("/auth/v1/user"));
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
  assert.equal(query.searchParams.get("select"), "id,user_id,auth_user_id,verification_status,active");

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
    electricianProfiles: [{
      id: UUID, user_id: "123e4567-e89b-42d3-a456-426614174001",
      auth_user_id: "123e4567-e89b-42d3-a456-426614174001",
      verification_status: "approved", active: true
    }]
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


test("AI server rejects inconsistent successful flags on Auth and profile HTTP errors", async () => {
  const makeHandler = (profileResponse) => createAiServerGuard({
    env: { SUPABASE_URL: "https://project.supabase.co", SUPABASE_ANON_KEY: "anon-test", SUPABASE_SERVICE_ROLE_KEY: "service-role-test" },
    fetchImpl: async (url) => {
      if (url.includes("/auth/v1/user")) {
        return { ok: true, status: 503, json: async () => ({ id: "123e4567-e89b-42d3-a456-426614174001" }) };
      }
      return profileResponse(url);
    }
  });
  const authHandler = makeHandler(() => ({ ok: true, status: 200, json: async () => [] }));
  const authResponse = await authHandler(event({ body: { module_key: "customer_support", message: "hi" } }));
  assert.equal(authResponse.statusCode, 503);

  const profileHandler = createAiServerGuard({
    env: { SUPABASE_URL: "https://project.supabase.co", SUPABASE_ANON_KEY: "anon-test", SUPABASE_SERVICE_ROLE_KEY: "service-role-test" },
    fetchImpl: async (url) => {
      if (url.includes("/auth/v1/user")) {
        return { ok: true, status: 200, json: async () => ({ id: "123e4567-e89b-42d3-a456-426614174001" }) };
      }
      return { ok: true, status: 503, json: async () => [] };
    }
  });
  const profileResponse = await profileHandler(event({ body: { module_key: "customer_support", message: "hi" } }));
  assert.equal(profileResponse.statusCode, 503);
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


test("AI profile rows must match the authenticated user even when the query returns a row", async () => {
  const wrongCustomer = setup({
    role: "customer",
    customerProfiles: [{ user_id: "123e4567-e89b-42d3-a456-426614174099" }]
  });
  const customerResponse = await wrongCustomer.handler(event({
    body: { module_key: "customer_support", message: "hello" }
  }));
  assert.equal(customerResponse.statusCode, 403);
  assert.equal(JSON.parse(customerResponse.body).error, "ai_access_denied");

  const wrongElectrician = setup({
    role: "electrician",
    electricianProfiles: [{
      id: UUID,
      user_id: "123e4567-e89b-42d3-a456-426614174001",
      auth_user_id: "123e4567-e89b-42d3-a456-426614174099",
      verification_status: "approved",
      active: true
    }]
  });
  const electricianResponse = await wrongElectrician.handler(event({
    body: { module_key: "electrician_assistant", message: "hello" }
  }));
  assert.equal(electricianResponse.statusCode, 403);
  assert.equal(JSON.parse(electricianResponse.body).error, "ai_access_denied");
});

test("AI electrician profile must be approved and active in returned data", async () => {
  for (const profile of [
    { id: UUID, user_id: "123e4567-e89b-42d3-a456-426614174001", auth_user_id: "123e4567-e89b-42d3-a456-426614174001", verification_status: "pending", active: true },
    { id: UUID, user_id: "123e4567-e89b-42d3-a456-426614174001", auth_user_id: "123e4567-e89b-42d3-a456-426614174001", verification_status: "approved", active: false }
  ]) {
    const denied = setup({ role: "electrician", electricianProfiles: [profile] });
    const response = await denied.handler(event({
      body: { module_key: "electrician_assistant", message: "hello" }
    }));
    assert.equal(response.statusCode, 403);
    assert.equal(JSON.parse(response.body).error, "ai_access_denied");
  }
});


test("AI authorization and idempotency headers are matched case-insensitively", async () => {
  const { handler, calls } = setup();
  const request = event({ body: { module_key: "customer_support", message: "hello" } });
  delete request.headers.authorization;
  delete request.headers["idempotency-key"];
  request.headers.aUtHoRiZaTiOn = "Bearer valid-token";
  request.headers["iDeMpOtEnCy-KeY"] = UUID;
  const response = await handler(request);
  assert.equal(response.statusCode, 503);
  assert.equal(JSON.parse(response.body).error, "ai_not_enabled");
  assert.equal(calls.filter(call => call.url.includes("/auth/v1/user")).length, 1);
});


test("AI guard rejects duplicate case-variant Authorization and idempotency headers", async () => {
  const authSetup = setup();
  const duplicateAuth = event({ body: { module_key: "customer_support", message: "hello" } });
  duplicateAuth.headers.Authorization = "Bearer another-token";
  assert.equal((await authSetup.handler(duplicateAuth)).statusCode, 401);
  assert.equal(authSetup.calls.length, 0, "ambiguous Authorization must not reach Supabase");

  const keySetup = setup();
  const duplicateKey = event({ body: { module_key: "customer_support", message: "hello" } });
  duplicateKey.headers["Idempotency-Key"] = "123e4567-e89b-42d3-a456-426614174099";
  const response = await keySetup.handler(duplicateKey);
  assert.equal(response.statusCode, 400);
  assert.equal(JSON.parse(response.body).error, "invalid_idempotency_key");
});

test("AI server rejects bearer tokens with whitespace, controls, or excessive length before Supabase", async () => {
  const { handler, calls } = setup();
  for (const token of [
    " " + "valid-token", "valid-token ", "token with spaces",
    "token\\r\\nInjected: yes", "token\\u00a0with-space",
    "token\\u2003with-space", "token\\u0085with-control",
    "x".repeat(8193)
  ]) {
    const request = event();
    request.headers.authorization = "Bearer " + token;
    assert.equal((await handler(request)).statusCode, 401);
  }
  assert.equal(calls.length, 0);
});


test("AI guard rejects UUID values with trailing line terminators", async () => {
  const malformedKey = setup();
  const request = event({ body: { module_key: "customer_support", message: "hello" } });
  request.headers["idempotency-key"] = UUID + "\n";
  const keyResponse = await malformedKey.handler(request);
  assert.equal(keyResponse.statusCode, 400);
  assert.equal(JSON.parse(keyResponse.body).error, "invalid_idempotency_key");

  const malformedIdentity = setup({
    user: { id: "123e4567-e89b-42d3-a456-426614174001\n" }
  });
  const identityResponse = await malformedIdentity.handler(event({
    body: { module_key: "customer_support", message: "hello" }
  }));
  assert.equal(identityResponse.statusCode, 403);
  assert.equal(malformedIdentity.calls.length, 1, "invalid Auth UUID must not trigger profile reads");
});


test("AI guard rejects malformed and non-object JSON before upstream requests", async () => {
  for (const body of ["{", "null", "[]", '"text"', "42"]) {
    const { handler, calls } = setup();
    const request = event();
    request.body = body;
    const response = await handler(request);
    assert.equal(response.statusCode, 400, "invalid JSON shape must be rejected");
    assert.equal(JSON.parse(response.body).error, "invalid_request");
    assert.equal(calls.length, 0, "invalid JSON must not trigger Supabase calls");
  }
});


test("AI guard rejects unsupported route modes before authentication or profile lookups", async () => {
  const { handler, calls } = setup();
  const response = await handler(event(), "unexpected-mode");
  assert.equal(response.statusCode, 404);
  assert.equal(JSON.parse(response.body).error, "not_found");
  assert.equal(calls.length, 0);
});


test("AI guard rejects unknown module keys before Supabase authentication", async () => {
  for (const moduleKey of ["", "admin_console", "staff_support", "unknown_module"]) {
    const { handler, calls } = setup();
    const response = await handler(event({
      body: { module_key: moduleKey, message: "hello" }
    }));
    assert.equal(response.statusCode, 403);
    assert.equal(JSON.parse(response.body).error, "ai_access_denied");
    assert.equal(calls.length, 0);
  }
});


test("AI guard rejects ambiguous duplicate authorization and idempotency headers", async () => {
  const duplicateAuthorization = setup();
  const authRequest = event({ body: { module_key: "customer_support", message: "hello" } });
  authRequest.headers.Authorization = "Bearer another-token";
  assert.equal((await duplicateAuthorization.handler(authRequest)).statusCode, 401);
  assert.equal(duplicateAuthorization.calls.length, 0);

  const duplicateIdempotency = setup();
  const keyRequest = event({ body: { module_key: "customer_support", message: "hello" } });
  keyRequest.headers["Idempotency-Key"] = UUID;
  const keyResponse = await duplicateIdempotency.handler(keyRequest);
  assert.equal(keyResponse.statusCode, 400);
  assert.equal(JSON.parse(keyResponse.body).error, "invalid_idempotency_key");
  assert.equal(duplicateIdempotency.calls.length, 3);
});


test("AI guard rejects unexpected top-level request fields before Supabase calls", async () => {
  const assistant = setup();
  const assistantResponse = await assistant.handler(event({
    body: { module_key: "customer_support", message: "hello", actor_role: "admin" }
  }));
  assert.equal(assistantResponse.statusCode, 400);
  assert.equal(JSON.parse(assistantResponse.body).error, "invalid_request");
  assert.equal(assistant.calls.length, 0);

  const handoff = setup();
  const handoffResponse = await handoff.handler(event({
    body: {
      module_key: "customer_support",
      conversation_id: UUID,
      reason_code: "needs_human_support",
      actor_user_id: UUID
    }
  }), "handoff");
  assert.equal(handoffResponse.statusCode, 400);
  assert.equal(JSON.parse(handoffResponse.body).error, "invalid_request");
  assert.equal(handoff.calls.length, 0);
});
