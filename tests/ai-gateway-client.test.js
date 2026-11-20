"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { GATEWAY_CHAT_URL, createAiGatewayClient } = require("../lib/ai-gateway-client");

const messages = [
  { role: "system", content: "You are a helpful support assistant." },
  { role: "user", content: "नमस्ते" }
];
function enabledEnv(overrides = {}) {
  return {
    AI_GATEWAY_ENABLED: "true",
    AI_GATEWAY_API_KEY: "server-secret-test",
    AI_GATEWAY_MODEL: "provider/model-test",
    ...overrides
  };
}

test("Gateway adapter stays disabled by default and makes no network request", async () => {
  let calls = 0;
  const client = createAiGatewayClient({ env: {}, fetchImpl: async () => { calls++; } });
  await assert.rejects(client.generateReply({ messages }), error => error.code === "ai_not_enabled");
  assert.equal(calls, 0);
});

test("Gateway adapter sends a bounded non-streaming request to the fixed HTTPS endpoint", async () => {
  let request;
  const client = createAiGatewayClient({
    env: enabledEnv(),
    fetchImpl: async (url, options) => {
      request = { url, options };
      return {
        ok: true, status: 200,
        json: async () => ({
          id: "gen_test_001",
          choices: [{ message: { content: " नमस्ते! " } }],
          usage: { prompt_tokens: 12, completion_tokens: 8, total_tokens: 20 }
        })
      };
    }
  });
  const result = await client.generateReply({ messages, maxTokens: 9000 });
  assert.equal(request.url, GATEWAY_CHAT_URL);
  assert.equal(request.options.method, "POST");
  assert.equal(request.options.headers.Authorization, "Bearer server-secret-test");
  assert.equal(request.options.cache, "no-store");
  assert.equal(request.options.redirect, "error");
  const body = JSON.parse(request.options.body);
  assert.equal(body.model, "provider/model-test");
  assert.equal(body.max_tokens, 400, "invalid token limits fall back to the safe default");
  assert.equal(body.stream, false);
  assert.equal(result.reply, "नमस्ते!");
  assert.equal(result.generationId, "gen_test_001");
  assert.deepEqual(result.usage, { promptTokens: 12, completionTokens: 8, totalTokens: 20 });
});

test("missing credentials or model fail closed without a provider request", async () => {
  let calls = 0;
  for (const env of [
    enabledEnv({ AI_GATEWAY_API_KEY: "" }),
    enabledEnv({ AI_GATEWAY_MODEL: "" })
  ]) {
    const client = createAiGatewayClient({ env, fetchImpl: async () => { calls++; } });
    await assert.rejects(client.generateReply({ messages }), error => error.code === "ai_service_unavailable");
  }
  assert.equal(calls, 0);
});

test("invalid message structures are rejected before network access", async () => {
  let calls = 0;
  const client = createAiGatewayClient({ env: enabledEnv(), fetchImpl: async () => { calls++; } });
  await assert.rejects(
    client.generateReply({ messages: [{ role: "user", content: "hi" }, { role: "tool", content: "unsafe" }] }),
    error => error.code === "invalid_ai_request"
  );
  await assert.rejects(
    client.generateReply({ messages: [{ role: "assistant", content: "not a final user turn" }] }),
    error => error.code === "invalid_ai_request"
  );
  assert.equal(calls, 0);
});

test("provider throttling, network errors and malformed replies return safe error codes", async () => {
  const throttled = createAiGatewayClient({
    env: enabledEnv(),
    fetchImpl: async () => ({ status: 429, ok: false })
  });
  await assert.rejects(throttled.generateReply({ messages }), error => error.code === "ai_rate_limited");

  const offline = createAiGatewayClient({
    env: enabledEnv(),
    fetchImpl: async () => { throw new Error("private transport detail"); }
  });
  await assert.rejects(offline.generateReply({ messages }), error => error.code === "ai_service_unavailable");

  const malformed = createAiGatewayClient({
    env: enabledEnv(),
    fetchImpl: async () => ({ status: 200, ok: true, json: async () => ({ choices: [] }) })
  });
  await assert.rejects(malformed.generateReply({ messages }), error => error.code === "invalid_ai_response");
});

test("malformed or incomplete provider usage is unavailable, never fabricated as zero", async () => {
  for (const usage of [
    { prompt_tokens: "12", completion_tokens: 8, total_tokens: 20 },
    { prompt_tokens: 12, completion_tokens: 8 },
    { prompt_tokens: -1, completion_tokens: 8, total_tokens: 7 },
    { prompt_tokens: 12, completion_tokens: 8, total_tokens: 10 }
  ]) {
    const client = createAiGatewayClient({
      env: enabledEnv(),
      fetchImpl: async () => ({
        ok: true, status: 200,
        json: async () => ({
          choices: [{ message: { content: "उत्तर" } }],
          usage
        })
      })
    });
    const result = await client.generateReply({ messages });
    assert.equal(result.usage, null);
  }
});
