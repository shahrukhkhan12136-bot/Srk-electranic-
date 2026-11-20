"use strict";

// Server-only Vercel AI Gateway adapter. This module makes no request unless
// explicitly called with AI_GATEWAY_ENABLED=true and a server-side API key.
const GATEWAY_CHAT_URL = "https://ai-gateway.vercel.sh/v1/chat/completions";
const ALLOWED_ROLES = new Set(["system", "user", "assistant"]);

function safeInteger(value, fallback, min, max) {
  return Number.isInteger(value) && value >= min && value <= max ? value : fallback;
}

function validateMessages(messages) {
  if (!Array.isArray(messages) || messages.length < 1 || messages.length > 16) {
    throw new TypeError("invalid_ai_messages");
  }
  const normalized = messages.map(message => {
    if (!message || typeof message !== "object" ||
        !ALLOWED_ROLES.has(message.role) ||
        typeof message.content !== "string" ||
        !message.content.trim() || message.content.length > 4000) {
      throw new TypeError("invalid_ai_messages");
    }
    return { role: message.role, content: message.content };
  });
  if (normalized[normalized.length - 1].role !== "user") {
    throw new TypeError("invalid_ai_messages");
  }
  return normalized;
}

function createAiGatewayClient({
  env = process.env,
  fetchImpl = globalThis.fetch,
  timeoutMs = 15000
} = {}) {
  return {
    async generateReply({ messages, maxTokens = 400 } = {}) {
      if (env.AI_GATEWAY_ENABLED !== "true") {
        const error = new Error("ai_not_enabled");
        error.code = "ai_not_enabled";
        throw error;
      }
      const apiKey = env.AI_GATEWAY_API_KEY;
      const model = env.AI_GATEWAY_MODEL;
      if (typeof apiKey !== "string" || !apiKey.trim() ||
          typeof model !== "string" || !/^[A-Za-z0-9._:/-]{1,160}$/.test(model) ||
          typeof fetchImpl !== "function") {
        const error = new Error("ai_service_unavailable");
        error.code = "ai_service_unavailable";
        throw error;
      }

      let safeMessages;
      try {
        safeMessages = validateMessages(messages);
      } catch (_) {
        const error = new Error("invalid_ai_request");
        error.code = "invalid_ai_request";
        throw error;
      }

      const tokenLimit = safeInteger(maxTokens, 400, 1, 600);
      let response;
      try {
        response = await fetchImpl(GATEWAY_CHAT_URL, {
          method: "POST",
          headers: {
            Authorization: "Bearer " + apiKey,
            "Content-Type": "application/json",
            Accept: "application/json"
          },
          body: JSON.stringify({
            model,
            messages: safeMessages,
            max_tokens: tokenLimit,
            temperature: 0.2,
            stream: false
          }),
          signal: AbortSignal.timeout(safeInteger(timeoutMs, 15000, 1000, 30000)),
          cache: "no-store",
          redirect: "error"
        });
      } catch (_) {
        const error = new Error("ai_service_unavailable");
        error.code = "ai_service_unavailable";
        throw error;
      }

      if (!response || response.status === 429) {
        const error = new Error(response?.status === 429 ? "ai_rate_limited" : "ai_service_unavailable");
        error.code = response?.status === 429 ? "ai_rate_limited" : "ai_service_unavailable";
        throw error;
      }
      if (response.ok !== true || !Number.isInteger(response.status) ||
          response.status < 200 || response.status >= 300) {
        const error = new Error("ai_service_unavailable");
        error.code = "ai_service_unavailable";
        throw error;
      }

      let payload;
      try { payload = await response.json(); } catch (_) {
        const error = new Error("invalid_ai_response");
        error.code = "invalid_ai_response";
        throw error;
      }
      const reply = payload?.choices?.[0]?.message?.content;
      if (typeof reply !== "string" || !reply.trim() || reply.length > 12000) {
        const error = new Error("invalid_ai_response");
        error.code = "invalid_ai_response";
        throw error;
      }

      const usage = payload.usage && typeof payload.usage === "object"
        ? {
            promptTokens: safeInteger(payload.usage.prompt_tokens, 0, 0, 10000000),
            completionTokens: safeInteger(payload.usage.completion_tokens, 0, 0, 10000000),
            totalTokens: safeInteger(payload.usage.total_tokens, 0, 0, 20000000)
          }
        : null;
      return { reply: reply.trim(), usage };
    }
  };
}

module.exports = { GATEWAY_CHAT_URL, createAiGatewayClient, validateMessages };
