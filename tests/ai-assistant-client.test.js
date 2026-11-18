"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { AiAssistantClientError, createAiAssistantClient } = require("../lib/ai-assistant-client");

const TOKEN = "verified-session-token";
const KEY = "123e4567-e89b-42d3-a456-426614174000";
const BOOKING = "123e4567-e89b-42d3-a456-426614174001";
const CONVERSATION = "123e4567-e89b-42d3-a456-426614174002";
const HANDOFF = "123e4567-e89b-42d3-a456-426614174003";

function jsonResponse(body, status = 200) {
  return { ok: status >= 200 && status < 300, status, json: async () => body };
}

test("AI client is disabled by default and makes no network request", async () => {
  let calls = 0;
  const client = createAiAssistantClient({ fetchImpl: async () => { calls++; } });
  await assert.rejects(
    client.sendMessage({ moduleKey: "customer_support", message: "मेरा स्टेटस", accessToken: TOKEN, idempotencyKey: KEY }),
    error => error instanceof AiAssistantClientError && error.code === "ai_not_enabled"
  );
  assert.equal(calls, 0);
});

test("assistant request uses verified session token and only the documented context reference", async () => {
  let captured;
  const client = createAiAssistantClient({
    enabled: true,
    baseUrl: "https://api.example.test",
    fetchImpl: async (url, options) => {
      captured = { url, options };
      return jsonResponse({
        success: true, request_id: "req-1", conversation_id: CONVERSATION,
        module_key: "customer_support", reply: "आपकी बुकिंग की स्थिति जाँची जा रही है।",
        action: { status: "none", action_id: null, approval_required: false },
        handoff: { required: false, handoff_id: null, queue: null, status: "not_required" }
      });
    }
  });
  const result = await client.sendMessage({
    moduleKey: "customer_support", message: "  मेरी बुकिंग बताइए  ",
    conversationId: null, context: { booking_id: BOOKING },
    accessToken: TOKEN, idempotencyKey: KEY
  });
  assert.equal(captured.url, "https://api.example.test/api/v1/ai/assistant");
  assert.equal(captured.options.headers.Authorization, "Bearer " + TOKEN);
  assert.equal(captured.options.headers["Idempotency-Key"], KEY);
  assert.equal(captured.options.credentials, "omit");
  assert.equal(captured.options.cache, "no-store");
  assert.deepEqual(JSON.parse(captured.options.body), {
    module_key: "customer_support", message: "मेरी बुकिंग बताइए",
    conversation_id: null, context: { booking_id: BOOKING }
  });
  assert.equal(result.reply, "आपकी बुकिंग की स्थिति जाँची जा रही है।");
});

test("client rejects forged actor/role context and malformed identifiers before fetch", async () => {
  let calls = 0;
  const client = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async () => { calls++; return jsonResponse({}); }
  });
  const base = { moduleKey: "customer_support", message: "status", accessToken: TOKEN, idempotencyKey: KEY };
  await assert.rejects(client.sendMessage({ ...base, context: { actor_id: "other-user" } }), /unsupported_context/);
  await assert.rejects(client.sendMessage({ ...base, context: { booking_id: "not-a-uuid" } }), /invalid_context/);
  await assert.rejects(client.sendMessage({ ...base, moduleKey: "reports_operations" }), /invalid_module/);
  assert.equal(calls, 0);
});

test("unavailable API and invalid responses fail closed without leaking server text", async () => {
  const unavailable = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async () => { throw new Error("secret provider detail"); }
  });
  await assert.rejects(
    unavailable.sendMessage({ moduleKey: "customer_support", message: "status", accessToken: TOKEN, idempotencyKey: KEY }),
    error => error.code === "ai_service_unavailable" && !error.message.includes("secret")
  );
  const forbidden = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async () => jsonResponse({ success: false, error: { message: "private detail" } }, 403)
  });
  await assert.rejects(
    forbidden.sendMessage({ moduleKey: "customer_support", message: "status", accessToken: TOKEN, idempotencyKey: KEY }),
    error => error.code === "ai_access_denied" && !error.message.includes("private")
  );
});

test("human handoff sends only the documented fields and validates persisted status", async () => {
  let captured;
  const client = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async (url, options) => {
      captured = { url, options };
      return jsonResponse({
        success: true, handoff_id: HANDOFF, case_reference: "SRK-42",
        queue: "customer_support", status: "queued", urgency: "normal",
        created_at: "2026-11-18T10:00:00Z"
      });
    }
  });
  const result = await client.createHandoff({
    moduleKey: "customer_support", conversationId: CONVERSATION,
    booking_id: BOOKING, context: { booking_id: BOOKING },
    reasonCode: "needs_human_support", urgency: "normal",
    summary: "उपयोगकर्ता को सहायता चाहिए।",
    accessToken: TOKEN, idempotencyKey: KEY
  });
  assert.equal(captured.url, "https://api.example.test/api/v1/ai/handoff");
  assert.deepEqual(JSON.parse(captured.options.body), {
    module_key: "customer_support", conversation_id: CONVERSATION,
    booking_id: BOOKING, reason_code: "needs_human_support",
    urgency: "normal", summary: "उपयोगकर्ता को सहायता चाहिए।"
  });
  assert.equal(result.handoff_id, HANDOFF);
  assert.equal(result.status, "queued");
});

test("handoff rejects unknown status rather than claiming a ticket was created", async () => {
  const client = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async () => jsonResponse({ success: true, handoff_id: HANDOFF, status: "done" })
  });
  await assert.rejects(
    client.createHandoff({
      moduleKey: "electrician_assistant", conversationId: CONVERSATION,
      reasonCode: "needs_human_support", summary: "मानव सहायता चाहिए।",
      accessToken: TOKEN, idempotencyKey: KEY
    }),
    error => error.code === "invalid_ai_response"
  );
});

test("assistant response rejects non-object action and handoff payloads", async () => {
  for (const malformed of [
    { action: "none", handoff: {} },
    { action: {}, handoff: "not-required" },
    { action: [], handoff: {} },
    { action: {}, handoff: [] }
  ]) {
    const client = createAiAssistantClient({
      enabled: true, baseUrl: "https://api.example.test",
      fetchImpl: async () => jsonResponse({
        success: true, conversation_id: CONVERSATION,
        module_key: "customer_support", reply: "उत्तर",
        action: malformed.action, handoff: malformed.handoff
      })
    });
    await assert.rejects(
      client.sendMessage({
        moduleKey: "customer_support", message: "स्थिति",
        accessToken: TOKEN, idempotencyKey: KEY
      }),
      error => error.code === "invalid_ai_response"
    );
  }
});
