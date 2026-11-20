"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createAiStaffHandoffHandler } = require("../lib/ai-staff-handoff-api");

const USER = "123e4567-e89b-42d3-a456-426614174001";
const HANDOFF = "123e4567-e89b-42d3-a456-426614174002";
const STAFF = "123e4567-e89b-42d3-a456-426614174003";

function setup({ authStatus = 200, rpcStatus = 200, rpcResult = { state: "ok" } } = {}) {
  const calls = [];
  const handler = createAiStaffHandoffHandler({
    env: {
      SUPABASE_URL: "https://project.supabase.co",
      SUPABASE_ANON_KEY: "anon-test",
      SUPABASE_SERVICE_ROLE_KEY: "must-not-be-used"
    },
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith("/auth/v1/user")) {
        return { ok: authStatus >= 200 && authStatus < 300, status: authStatus, json: async () => ({ id: USER }) };
      }
      return {
        ok: rpcStatus >= 200 && rpcStatus < 300,
        status: rpcStatus,
        json: async () => rpcResult
      };
    }
  });
  return { handler, calls };
}
function event(body, token = "valid-token") {
  return {
    httpMethod: "POST",
    headers: token ? { authorization: "Bearer " + token } : {},
    body: JSON.stringify(body)
  };
}

test("Staff assigned queue uses the authenticated user's JWT and bounded RPC", async () => {
  const { handler, calls } = setup({ rpcResult: [{ handoff_id: HANDOFF }] });
  const response = await handler(event({ action: "list", limit: 20 }));
  assert.equal(response.statusCode, 200);
  assert.equal(JSON.parse(response.body).data[0].handoff_id, HANDOFF);
  assert.equal(calls.length, 2);
  assert.ok(calls[1].url.endsWith("/rpc/srk_staff_list_assigned_ai_handoffs"));
  assert.equal(calls[1].options.headers.Authorization, "Bearer valid-token");
  assert.equal(calls[1].options.headers.apikey, "anon-test");
  assert.deepEqual(JSON.parse(calls[1].options.body), { p_limit: 20 });
  assert.equal(calls[1].options.headers.Authorization.includes("must-not-be-used"), false);
});

test("Staff transcript, reply, and resolve call only their ownership-enforcing RPCs", async () => {
  for (const [body, rpc, expected] of [
    [{ action: "messages", handoff_id: HANDOFF }, "srk_staff_list_assigned_ai_handoff_messages", { p_handoff_id: HANDOFF, p_limit: 100 }],
    [{ action: "reply", handoff_id: HANDOFF, body: "I can help with this request." }, "srk_staff_reply_ai_handoff", { p_handoff_id: HANDOFF, p_body: "I can help with this request." }],
    [{ action: "resolve", handoff_id: HANDOFF }, "srk_staff_resolve_ai_handoff", { p_handoff_id: HANDOFF }]
  ]) {
    const { handler, calls } = setup();
    const response = await handler(event(body));
    assert.equal(response.statusCode, 200);
    assert.ok(calls[1].url.endsWith("/rpc/" + rpc));
    assert.deepEqual(JSON.parse(calls[1].options.body), expected);
  }
});

test("Main Admin assignment delegates authority and active Staff permission checks to database RPC", async () => {
  const { handler, calls } = setup();
  const response = await handler(event({
    action: "assign", handoff_id: HANDOFF, staff_user_id: STAFF, reason: "Assign to trained support staff"
  }));
  assert.equal(response.statusCode, 200);
  assert.ok(calls[1].url.endsWith("/rpc/srk_admin_assign_ai_handoff"));
  assert.deepEqual(JSON.parse(calls[1].options.body), {
    p_handoff_id: HANDOFF, p_staff_user_id: STAFF, p_reason: "Assign to trained support staff"
  });
});

test("Invalid payloads, methods, and unauthenticated requests never invoke privileged RPCs", async () => {
  const { handler, calls } = setup();
  assert.equal((await handler({ ...event({ action: "list" }), httpMethod: "GET" })).statusCode, 405);
  assert.equal((await handler(event({ action: "assign", handoff_id: "bad", staff_user_id: STAFF, reason: "valid reason" }))).statusCode, 400);
  assert.equal((await handler(event({ action: "reply", handoff_id: HANDOFF, body: " " }))).statusCode, 400);
  assert.equal((await handler(event({ action: "list", extra: "nope" }))).statusCode, 400);
  assert.equal((await handler(event({ action: "list" }, null))).statusCode, 401);
  assert.equal(calls.length, 0);
});

test("Auth and database permission failures fail closed without exposing database messages", async () => {
  const unauthenticated = setup({ authStatus: 401 });
  assert.equal((await unauthenticated.handler(event({ action: "list" }))).statusCode, 401);
  assert.equal(unauthenticated.calls.length, 1);

  const forbidden = setup({ rpcStatus: 403, rpcResult: { message: "internal permission detail" } });
  const denied = await forbidden.handler(event({ action: "list" }));
  assert.equal(denied.statusCode, 403);
  assert.equal(JSON.parse(denied.body).error, "permission_denied");
  assert.doesNotMatch(denied.body, /internal permission detail/);
});
