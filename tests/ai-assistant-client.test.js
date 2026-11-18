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

test("assistant response rejects malformed nested action and handoff fields", async () => {
  for (const malformed of [
    { action: "none", handoff: {} },
    { action: {}, handoff: "not-required" },
    { action: [], handoff: {} },
    { action: {}, handoff: [] },
    { action: { status: "none", action_id: null, approval_required: "false" }, handoff: { required: false } },
    { action: { status: "none", action_id: "not-a-uuid", approval_required: false }, handoff: { required: false } },
    { action: { status: "none", action_id: null, approval_required: false }, handoff: { required: "false" } },
    { action: { status: "none", action_id: null, approval_required: false }, handoff: { required: false, handoff_id: "not-a-uuid" } },
    { action: { status: "none", action_id: null, approval_required: false }, handoff: { required: false, queue: [] } }
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

test("AI client rejects malformed HTTPS base URLs before making a request", async () => {
  let calls = 0;
  const invalidUrls = [
    "https://",
    "https://user:secret@api.example.test",
    "https://api.example.test?token=secret",
    "https://api.example.test#fragment",
    " https://api.example.test",
    "https://api.example.test/prefix"
  ];
  for (const baseUrl of invalidUrls) {
    const client = createAiAssistantClient({
      enabled: true, baseUrl,
      fetchImpl: async () => { calls++; return jsonResponse({}); }
    });
    await assert.rejects(
      client.sendMessage({
        moduleKey: "customer_support", message: "status",
        accessToken: TOKEN, idempotencyKey: KEY
      }),
      error => error.code === "ai_service_unavailable"
    );
  }
  assert.equal(calls, 0);
});

test("AI transport rejects malformed and array response envelopes safely", async () => {
  for (const response of [
    null,
    {},
    { ok: true, status: 200, json: async () => [] },
    { ok: true, status: 200, json: async () => "success" },
    { ok: true, status: 200, json: async () => null }
  ]) {
    const client = createAiAssistantClient({
      enabled: true, baseUrl: "https://api.example.test",
      fetchImpl: async () => response
    });
    await assert.rejects(
      client.sendMessage({
        moduleKey: "customer_support", message: "status",
        accessToken: TOKEN, idempotencyKey: KEY
      }),
      error => error.code === "ai_request_rejected" || error.code === "invalid_ai_response"
    );
  }
});

test("AI transport maps non-success HTTP status without parsing an error body", async () => {
  let parsed = false;
  const client = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async () => ({
      ok: false, status: 403,
      json: async () => { parsed = true; return { success: false }; }
    })
  });
  await assert.rejects(
    client.sendMessage({
      moduleKey: "customer_support", message: "status",
      accessToken: TOKEN, idempotencyKey: KEY
    }),
    error => error.code === "ai_access_denied" && error.status === 403
  );
  assert.equal(parsed, false);
});


test("AI client rejects non-object requests and inherited context references", async () => {
  let calls = 0;
  const client = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async () => { calls++; return jsonResponse({}); }
  });
  await assert.rejects(client.sendMessage(null), error => error.code === "invalid_request");
  const inherited = Object.create({ booking_id: BOOKING });
  await assert.rejects(
    client.sendMessage({
      moduleKey: "customer_support", message: "status",
      context: inherited, accessToken: TOKEN, idempotencyKey: KEY
    }),
    error => error.code === "invalid_context"
  );
  const customPrototype = Object.create({ trusted: true });
  await assert.rejects(
    client.sendMessage({
      moduleKey: "customer_support", message: "status",
      context: customPrototype, accessToken: TOKEN, idempotencyKey: KEY
    }),
    error => error.code === "invalid_context"
  );
  assert.equal(calls, 0);
});


test("AI handoff rejects null, array and primitive request shapes before fetch", async () => {
  let calls = 0;
  const client = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async () => { calls++; return jsonResponse({}); }
  });
  for (const malformed of [null, [], "handoff", 7]) {
    await assert.rejects(
      client.createHandoff(malformed),
      error => error.code === "invalid_request"
    );
  }
  assert.equal(calls, 0);
});

test("AI client rejects inherited request credentials and custom request prototypes", async () => {
  let calls = 0;
  const client = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async () => { calls++; return jsonResponse({}); }
  });
  const inherited = Object.create({
    moduleKey: "customer_support", message: "status",
    accessToken: TOKEN, idempotencyKey: KEY
  });
  await assert.rejects(
    client.sendMessage(inherited),
    error => error.code === "invalid_request"
  );
  const partial = Object.create(null);
  partial.moduleKey = "customer_support";
  partial.message = "status";
  partial.accessToken = TOKEN;
  await assert.rejects(
    client.sendMessage(Object.assign(Object.create({ idempotencyKey: KEY }), partial)),
    error => error.code === "invalid_request"
  );
  assert.equal(calls, 0);
});

test("AI client ignores inherited optional context and conversation fields", async () => {
  const oldContext = Object.getOwnPropertyDescriptor(Object.prototype, "context");
  const oldConversation = Object.getOwnPropertyDescriptor(Object.prototype, "conversationId");
  let sentBody;
  try {
    Object.defineProperty(Object.prototype, "context", {
      configurable: true, value: { booking_id: BOOKING }
    });
    Object.defineProperty(Object.prototype, "conversationId", {
      configurable: true, value: CONVERSATION
    });
    const client = createAiAssistantClient({
      enabled: true, baseUrl: "https://api.example.test",
      fetchImpl: async (_url, options) => {
        sentBody = JSON.parse(options.body);
        return jsonResponse({
          success: true, conversation_id: CONVERSATION,
          module_key: "customer_support", reply: "उत्तर",
          action: { status: "none", action_id: null, approval_required: false },
          handoff: { required: false, handoff_id: null, queue: null, status: "not_required" }
        });
      }
    });
    await client.sendMessage({
      moduleKey: "customer_support", message: "status",
      accessToken: TOKEN, idempotencyKey: KEY
    });
    assert.equal(sentBody.conversation_id, null);
    assert.deepEqual(sentBody.context, {});
  } finally {
    if (oldContext) Object.defineProperty(Object.prototype, "context", oldContext);
    else delete Object.prototype.context;
    if (oldConversation) Object.defineProperty(Object.prototype, "conversationId", oldConversation);
    else delete Object.prototype.conversationId;
  }
});

test("AI handoff rejects custom prototypes and ignores inherited optional fields", async () => {
  let calls = 0;
  const client = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async (_url, options) => {
      calls++;
      const body = JSON.parse(options.body);
      assert.equal(body.reason_code, "needs_human_support");
      assert.equal(body.urgency, "normal");
      assert.equal(body.booking_id, null);
      assert.equal(Object.prototype.hasOwnProperty.call(body, "context"), false);
      return jsonResponse({
        success: true, handoff_id: CONVERSATION, status: "queued",
        urgency: "normal"
      });
    }
  });
  const custom = Object.assign(Object.create({ trusted: true }), {
    moduleKey: "customer_support", accessToken: TOKEN,
    idempotencyKey: KEY, conversationId: CONVERSATION,
    summary: "कृपया सहायता दें"
  });
  await assert.rejects(
    client.createHandoff(custom),
    error => error.code === "invalid_request"
  );

  const oldContext = Object.getOwnPropertyDescriptor(Object.prototype, "context");
  const oldReason = Object.getOwnPropertyDescriptor(Object.prototype, "reasonCode");
  const oldUrgency = Object.getOwnPropertyDescriptor(Object.prototype, "urgency");
  try {
    Object.defineProperty(Object.prototype, "context", {
      configurable: true, value: { booking_id: BOOKING }
    });
    Object.defineProperty(Object.prototype, "reasonCode", {
      configurable: true, value: "privileged_override"
    });
    Object.defineProperty(Object.prototype, "urgency", {
      configurable: true, value: "high"
    });
    await client.createHandoff({
      moduleKey: "customer_support", accessToken: TOKEN,
      idempotencyKey: KEY, conversationId: CONVERSATION,
      summary: "कृपया सहायता दें"
    });
  } finally {
    for (const [key, descriptor] of [
      ["context", oldContext], ["reasonCode", oldReason], ["urgency", oldUrgency]
    ]) {
      if (descriptor) Object.defineProperty(Object.prototype, key, descriptor);
      else delete Object.prototype[key];
    }
  }
  assert.equal(calls, 1);
});


test("AI client rejects bearer tokens with whitespace, control characters, or excessive length before fetch", async () => {
  let calls = 0;
  const client = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async () => { calls++; return jsonResponse({}); }
  });
  const base = {
    moduleKey: "customer_support", message: "status",
    accessToken: TOKEN, idempotencyKey: KEY
  };
  for (const accessToken of [
    " " + TOKEN, TOKEN + " ", "token with spaces",
    "token\r\nInjected: yes", "token\u00a0with-space", "token\u2003with-space", "token\u0085with-control", "x".repeat(8193)
  ]) {
    await assert.rejects(
      client.sendMessage({ ...base, accessToken }),
      error => error.code === "authentication_required"
    );
  }
  assert.equal(calls, 0);
});


test("AI client rejects UUID inputs with trailing line terminators before fetch", async () => {
  let calls = 0;
  const client = createAiAssistantClient({
    enabled: true, baseUrl: "https://api.example.test",
    fetchImpl: async () => { calls++; return jsonResponse({}); }
  });
  await assert.rejects(
    client.sendMessage({
      moduleKey: "customer_support", message: "status",
      accessToken: TOKEN, idempotencyKey: KEY + "\\n"
    }),
    error => error.code === "invalid_idempotency_key"
  );
  await assert.rejects(
    client.sendMessage({
      moduleKey: "customer_support", message: "status",
      accessToken: TOKEN, idempotencyKey: KEY,
      conversationId: CONVERSATION + "\\n"
    }),
    error => error.code === "invalid_conversation_id"
  );
  await assert.rejects(
    client.sendMessage({
      moduleKey: "customer_support", message: "status",
      accessToken: TOKEN, idempotencyKey: KEY,
      context: { booking_id: BOOKING + "\\n" }
    }),
    error => error.code === "invalid_context"
  );
  assert.equal(calls, 0);
});
