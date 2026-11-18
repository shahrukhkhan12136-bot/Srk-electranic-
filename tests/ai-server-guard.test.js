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
function setup({ role = "customer", status = 200, user = null, env = null, customerProfiles = null, electricianProfiles = null, bookingRows = [] } = {}) {
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
    if (url.includes("/rest/v1/srk_ai_conversations")) {
      const query = new URL(url);
      const conversationId = query.searchParams.get("id")?.slice(3);
      const moduleKey = query.searchParams.get("module_key")?.slice(3);
      return { ok: true, status: 200, json: async () => [{
        id: conversationId, owner_user_id: authUser.id, module_key: moduleKey, status: "open"
      }] };
    }
    if (url.includes("/rest/v1/service_bookings")) {
      return { ok: true, status: 200, json: async () => bookingRows };
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
  assert.equal((await handler(event({ token: null, body: { module_key: "customer_support", message: "hello" } }))).statusCode, 401);
  const malformedBearer = event({ body: { module_key: "customer_support", message: "hello" } });
  malformedBearer.headers.authorization = "Bearer\\svalid-token";
  assert.equal((await handler(malformedBearer)).statusCode, 401);
  assert.equal(calls.length, 0, "malformed bearer headers must not reach Supabase");
  for (const malformedValue of ["Bearer valid-token\n", "Bearer valid-token\r\n", "Bearer\nvalid-token"]) {
    const malformedHeader = event({ body: { module_key: "customer_support", message: "hello" } });
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
  const { handler, calls } = setup();
  const missingKey = await handler(event({ key: null, body: { module_key: "customer_support", message: "hi" } }));
  assert.equal(missingKey.statusCode, 400);
  assert.equal(JSON.parse(missingKey.body).error, "invalid_idempotency_key");
  assert.equal(calls.length, 0, "missing idempotency key must be rejected before Supabase calls");
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

test("handoff reason codes match the persistence schema allowlist", async () => {
  const { handler } = setup();
  for (const reason_code of ["needs_human_support", "safety_concern", "account_issue", "billing_question", "other"]) {
    const response = await handler(event({ body: {
      module_key: "customer_support",
      conversation_id: UUID,
      reason_code,
      urgency: "normal",
      summary: "Please connect me to support"
    } }), "handoff");
    assert.equal(response.statusCode, 503, reason_code);
    assert.equal(JSON.parse(response.body).error, "ai_not_enabled");
  }
  const invalid = await handler(event({ body: {
    module_key: "customer_support",
    conversation_id: UUID,
    reason_code: "arbitrary_unrecognized_reason",
    urgency: "normal",
    summary: "Please connect me to support"
  } }), "handoff");
  assert.equal(invalid.statusCode, 400);
  assert.equal(JSON.parse(invalid.body).error, "invalid_handoff_request");
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
  assert.equal(keySetup.calls.length, 0, "invalid idempotency key must be rejected before Supabase calls");
});

test("AI server rejects bearer tokens with whitespace, controls, or excessive length before Supabase", async () => {
  const { handler, calls } = setup();
  for (const token of [
    " " + "valid-token", "valid-token ", "token with spaces",
    "token\r\nInjected: yes", "token\u00a0with-space",
    "token\u2003with-space", "token\u0085with-control",
    "token\twith-tab", "token\u0000with-null", "token\u007fwith-delete",
    "token\u200bwith-zero-width", "token\ufeffwith-bom", "token😀with-emoji",
    "x".repeat(8193)
  ]) {
    const request = event({ body: { module_key: "customer_support", message: "hello" } });
    request.headers.authorization = "Bearer " + token;
    assert.equal((await handler(request)).statusCode, 401, `invalid bearer token must be rejected before Supabase: ${JSON.stringify(token)}`);
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
  assert.equal(duplicateIdempotency.calls.length, 0, "duplicate idempotency headers must be rejected before Supabase calls");
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


test("booking context is checked against the authenticated customer's exact booking", async () => {
  const userId = "123e4567-e89b-42d3-a456-426614174001";
  const bookingId = "123e4567-e89b-42d3-a456-426614174099";
  const own = setup({ bookingRows: [{ id: bookingId, customer_user_id: userId, assigned_electrician_id: null }] });
  const response = await own.handler(event({ body: {
    module_key: "booking_assistant", message: "status?", context: { booking_id: bookingId }
  } }));
  assert.equal(response.statusCode, 503);
  assert.equal(JSON.parse(response.body).error, "ai_not_enabled");
  const bookingCall = own.calls.find(call => call.url.includes("/rest/v1/service_bookings"));
  assert.ok(bookingCall);
  const query = new URL(bookingCall.url);
  assert.equal(query.searchParams.get("id"), "eq." + bookingId);
  assert.equal(query.searchParams.get("select"), "id,customer_user_id,assigned_electrician_id");
  assert.equal(bookingCall.options.headers.Authorization, "Bearer service-role-test");

  const other = setup({ bookingRows: [{ id: bookingId, customer_user_id: "123e4567-e89b-42d3-a456-426614174088", assigned_electrician_id: null }] });
  const denied = await other.handler(event({ body: {
    module_key: "booking_assistant", message: "status?", context: { booking_id: bookingId }
  } }));
  assert.equal(denied.statusCode, 403);
  assert.equal(JSON.parse(denied.body).error, "ai_booking_access_denied");
});

test("electrician booking context requires exact assigned electrician profile ownership", async () => {
  const bookingId = "123e4567-e89b-42d3-a456-426614174099";
  const own = setup({ role: "electrician", bookingRows: [{
    id: bookingId, customer_user_id: null, assigned_electrician_id: UUID
  }] });
  const response = await own.handler(event({ body: {
    module_key: "electrician_assistant", message: "job details", context: { booking_id: bookingId }
  } }));
  assert.equal(response.statusCode, 503);
  assert.equal(JSON.parse(response.body).error, "ai_not_enabled");

  for (const assignedId of [null, "123e4567-e89b-42d3-a456-426614174088"]) {
    const other = setup({ role: "electrician", bookingRows: [{
      id: bookingId, customer_user_id: null, assigned_electrician_id: assignedId
    }] });
    const denied = await other.handler(event({ body: {
      module_key: "electrician_assistant", message: "job details", context: { booking_id: bookingId }
    } }));
    assert.equal(denied.statusCode, 403);
    assert.equal(JSON.parse(denied.body).error, "ai_booking_access_denied");
  }
});

test("booking ownership lookup fails closed for missing, duplicate, mismatched, or unavailable rows", async () => {
  const bookingId = "123e4567-e89b-42d3-a456-426614174099";
  for (const rows of [[], [
    { id: bookingId, customer_user_id: "123e4567-e89b-42d3-a456-426614174001" },
    { id: bookingId, customer_user_id: "123e4567-e89b-42d3-a456-426614174001" }
  ], [{ id: "123e4567-e89b-42d3-a456-426614174088", customer_user_id: "123e4567-e89b-42d3-a456-426614174001" }]]) {
    const denied = setup({ bookingRows: rows });
    const response = await denied.handler(event({ body: {
      module_key: "customer_support", message: "help", context: { booking_id: bookingId }
    } }));
    assert.equal(response.statusCode, 403);
    assert.equal(JSON.parse(response.body).error, "ai_booking_access_denied");
  }

  const unavailable = createAiServerGuard({
    env: {
      SUPABASE_URL: "https://example.supabase.co",
      SUPABASE_ANON_KEY: "anon-test",
      SUPABASE_SERVICE_ROLE_KEY: "service-role-test"
    },
    fetchImpl: async url => {
      if (url.includes("/auth/v1/user")) return { ok: true, status: 200, json: async () => ({
        id: "123e4567-e89b-42d3-a456-426614174001"
      }) };
      if (url.includes("/srk_customer_profiles")) return { ok: true, status: 200, json: async () => [
        { user_id: "123e4567-e89b-42d3-a456-426614174001" }
      ] };
      if (url.includes("/electrician_profiles")) return { ok: true, status: 200, json: async () => [] };
      return { ok: false, status: 500, json: async () => [] };
    }
  });
  const failed = await unavailable(event({ body: {
    module_key: "customer_support", message: "help", context: { booking_id: bookingId }
  } }));
  assert.equal(failed.statusCode, 503);
  assert.equal(JSON.parse(failed.body).error, "ai_service_unavailable");
});


test("handoff booking references enforce the same customer ownership and electrician assignment checks", async () => {
  const bookingId = "123e4567-e89b-42d3-a456-426614174099";
  const customerId = "123e4567-e89b-42d3-a456-426614174001";
  const handoffBody = module_key => ({
    module_key,
    conversation_id: UUID,
    booking_id: bookingId,
    reason_code: "needs_human_support",
    urgency: "normal",
    summary: "Please connect me to support"
  });

  const ownCustomer = setup({ bookingRows: [{
    id: bookingId, customer_user_id: customerId, assigned_electrician_id: null
  }] });
  const customerOk = await ownCustomer.handler(event({ body: handoffBody("customer_support") }), "handoff");
  assert.equal(customerOk.statusCode, 503);
  assert.equal(JSON.parse(customerOk.body).error, "ai_not_enabled");

  const otherCustomer = setup({ bookingRows: [{
    id: bookingId, customer_user_id: "123e4567-e89b-42d3-a456-426614174088", assigned_electrician_id: null
  }] });
  const customerDenied = await otherCustomer.handler(event({ body: handoffBody("customer_support") }), "handoff");
  assert.equal(customerDenied.statusCode, 403);
  assert.equal(JSON.parse(customerDenied.body).error, "ai_booking_access_denied");

  const ownElectrician = setup({ role: "electrician", bookingRows: [{
    id: bookingId, customer_user_id: customerId, assigned_electrician_id: UUID
  }] });
  const electricianOk = await ownElectrician.handler(event({ body: handoffBody("electrician_assistant") }), "handoff");
  assert.equal(electricianOk.statusCode, 503);
  assert.equal(JSON.parse(electricianOk.body).error, "ai_not_enabled");

  const otherElectrician = setup({ role: "electrician", bookingRows: [{
    id: bookingId, customer_user_id: customerId, assigned_electrician_id: "123e4567-e89b-42d3-a456-426614174088"
  }] });
  const electricianDenied = await otherElectrician.handler(event({ body: handoffBody("electrician_assistant") }), "handoff");
  assert.equal(electricianDenied.statusCode, 403);
  assert.equal(JSON.parse(electricianDenied.body).error, "ai_booking_access_denied");
});


test("existing conversation IDs require an exact owner, module, and open status match", async () => {
  const conversationId = "123e4567-e89b-42d3-a456-426614174099";
  const ownerId = "123e4567-e89b-42d3-a456-426614174001";
  const make = rows => {
    const calls = [];
    const handler = createAiServerGuard({
      env: { SUPABASE_URL: "https://example.supabase.co", SUPABASE_ANON_KEY: "anon-test", SUPABASE_SERVICE_ROLE_KEY: "service-role-test" },
      fetchImpl: async url => {
        calls.push(url);
        if (url.includes("/auth/v1/user")) return { ok: true, status: 200, json: async () => ({ id: ownerId }) };
        if (url.includes("/srk_customer_profiles")) return { ok: true, status: 200, json: async () => [{ user_id: ownerId }] };
        if (url.includes("/electrician_profiles")) return { ok: true, status: 200, json: async () => [] };
        if (url.includes("/srk_ai_conversations")) return { ok: true, status: 200, json: async () => rows };
        throw new Error("unexpected URL");
      }
    });
    return { handler, calls };
  };
  const body = { module_key: "customer_support", message: "hello", conversation_id: conversationId };
  const own = make([{ id: conversationId, owner_user_id: ownerId, module_key: "customer_support", status: "open" }]);
  const allowed = await own.handler(event({ body }));
  assert.equal(allowed.statusCode, 503);
  assert.equal(JSON.parse(allowed.body).error, "ai_not_enabled");

  // Assistant appends are rejected after handoff is requested because the
  // persistence append RPC accepts messages only while the conversation is open.
  const handoffRequested = make([{
    id: conversationId, owner_user_id: ownerId,
    module_key: "customer_support", status: "handoff_requested"
  }]);
  const assistantAfterHandoff = await handoffRequested.handler(event({ body }));
  assert.equal(assistantAfterHandoff.statusCode, 403);
  assert.equal(JSON.parse(assistantAfterHandoff.body).error, "ai_conversation_access_denied");

  // A repeated handoff request may still reach the idempotent handoff RPC.
  const handoffBody = {
    module_key: "customer_support", conversation_id: conversationId,
    reason_code: "needs_human_support", urgency: "normal", summary: "Please help"
  };
  const repeatedHandoff = await handoffRequested.handler(event({ body: handoffBody }), "handoff");
  assert.equal(repeatedHandoff.statusCode, 503);
  assert.equal(JSON.parse(repeatedHandoff.body).error, "ai_not_enabled");

  const url = new URL(own.calls.find(value => value.includes("/srk_ai_conversations")));
  assert.equal(url.searchParams.get("id"), "eq." + conversationId);
  assert.equal(url.searchParams.get("owner_user_id"), "eq." + ownerId);
  assert.equal(url.searchParams.get("module_key"), "eq.customer_support");
  assert.equal(url.searchParams.get("status"), "neq.closed");

  for (const rows of [
    [],
    [{ id: conversationId, owner_user_id: "123e4567-e89b-42d3-a456-426614174088", module_key: "customer_support", status: "open" }],
    [{ id: conversationId, owner_user_id: ownerId, module_key: "electrician_assistant", status: "open" }],
    [{ id: conversationId, owner_user_id: ownerId, module_key: "customer_support", status: "closed" }],
    [
      { id: conversationId, owner_user_id: ownerId, module_key: "customer_support", status: "open" },
      { id: conversationId, owner_user_id: ownerId, module_key: "customer_support", status: "open" }
    ]
  ]) {
    const denied = make(rows);
    const response = await denied.handler(event({ body }));
    assert.equal(response.statusCode, 403);
    assert.equal(JSON.parse(response.body).error, "ai_conversation_access_denied");
  }
});

test("handoff cannot create a queue item for a missing or foreign conversation", async () => {
  const conversationId = "123e4567-e89b-42d3-a456-426614174099";
  const ownerId = "123e4567-e89b-42d3-a456-426614174001";
  for (const rows of [[], [{ id: conversationId, owner_user_id: "123e4567-e89b-42d3-a456-426614174088", module_key: "customer_support", status: "open" }]]) {
    const handler = createAiServerGuard({
      env: { SUPABASE_URL: "https://example.supabase.co", SUPABASE_ANON_KEY: "anon-test", SUPABASE_SERVICE_ROLE_KEY: "service-role-test" },
      fetchImpl: async url => {
        if (url.includes("/auth/v1/user")) return { ok: true, status: 200, json: async () => ({ id: ownerId }) };
        if (url.includes("/srk_customer_profiles")) return { ok: true, status: 200, json: async () => [{ user_id: ownerId }] };
        if (url.includes("/electrician_profiles")) return { ok: true, status: 200, json: async () => [] };
        if (url.includes("/srk_ai_conversations")) return { ok: true, status: 200, json: async () => rows };
        throw new Error("unexpected URL");
      }
    });
    const response = await handler(event({ body: {
      module_key: "customer_support", conversation_id: conversationId,
      reason_code: "needs_human_support", summary: "Please connect me to support"
    } }), "handoff");
    assert.equal(response.statusCode, 403);
    assert.equal(JSON.parse(response.body).error, "ai_conversation_access_denied");
  }
});


test("pre-launch AI OFF gate performs authorization reads only and never writes or calls a provider", async () => {
  for (const mode of ["assistant", "handoff"]) {
    const { handler, calls } = setup();
    const body = mode === "assistant" ? {
      module_key: "customer_support",
      message: "Please help with my booking"
    } : {
      module_key: "customer_support",
      conversation_id: UUID,
      reason_code: "needs_human_support",
      urgency: "normal",
      summary: "Please connect me to support"
    };
    const response = await handler(event({ body }), mode);
    assert.equal(response.statusCode, 503);
    assert.equal(JSON.parse(response.body).error, "ai_not_enabled");
    assert.ok(calls.length >= 3);
    assert.ok(calls.every(call => call.options.method === "GET" || call.options.method === undefined),
      "pre-launch AI gate must not perform database writes");
    assert.ok(calls.every(call => !/\/rpc\//.test(call.url)),
      "pre-launch AI gate must not invoke persistence or handoff RPCs");
    assert.ok(calls.every(call => !/openai|anthropic|gemini|ai-gateway/i.test(call.url)),
      "pre-launch AI gate must not call an AI provider");
  }
});
