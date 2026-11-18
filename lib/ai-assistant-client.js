"use strict";

// Pre-launch client adapter for the proposed AI API contract.
// Disabled by default. Do not enable until GPT-2 has deployed and verified
// the authenticated routes, persistence, ownership checks, audit and kill switch.
const MODULE_KEYS = Object.freeze([
  "customer_support",
  "booking_assistant",
  "electrician_assistant"
]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

class AiAssistantClientError extends Error {
  constructor(code, status = 0) {
    super(code);
    this.name = "AiAssistantClientError";
    this.code = code;
    this.status = status;
  }
}

function validateCommon({ moduleKey, message, accessToken, idempotencyKey }) {
  if (!MODULE_KEYS.includes(moduleKey)) throw new AiAssistantClientError("invalid_module");
  if (typeof message !== "string" || !message.trim() || message.length > 4000) {
    throw new AiAssistantClientError("invalid_message");
  }
  if (typeof accessToken !== "string" || !accessToken.trim()) {
    throw new AiAssistantClientError("authentication_required", 401);
  }
  if (typeof idempotencyKey !== "string" || !UUID.test(idempotencyKey)) {
    throw new AiAssistantClientError("invalid_idempotency_key");
  }
}

function safeContext(context) {
  if (context == null) return {};
  if (typeof context !== "object" || Array.isArray(context)) {
    throw new AiAssistantClientError("invalid_context");
  }
  const keys = Object.keys(context);
  if (keys.some(key => key !== "booking_id")) {
    throw new AiAssistantClientError("unsupported_context");
  }
  if (context.booking_id != null && (typeof context.booking_id !== "string" || !UUID.test(context.booking_id))) {
    throw new AiAssistantClientError("invalid_context");
  }
  return context.booking_id ? { booking_id: context.booking_id } : {};
}

function createAiAssistantClient({
  enabled = false,
  baseUrl = "",
  fetchImpl = globalThis.fetch
} = {}) {
  async function post(path, body, { accessToken, idempotencyKey }) {
    if (!enabled) throw new AiAssistantClientError("ai_not_enabled");
    if (typeof baseUrl !== "string" || !/^https:\/\//i.test(baseUrl)) {
      throw new AiAssistantClientError("ai_service_unavailable", 503);
    }
    if (typeof fetchImpl !== "function") throw new AiAssistantClientError("ai_service_unavailable", 503);

    let response;
    try {
      response = await fetchImpl(new URL(path, baseUrl).toString(), {
        method: "POST",
        headers: {
          "Authorization": "Bearer " + accessToken,
          "Content-Type": "application/json",
          "Idempotency-Key": idempotencyKey
        },
        body: JSON.stringify(body),
        cache: "no-store",
        credentials: "omit",
        redirect: "error"
      });
    } catch (_) {
      throw new AiAssistantClientError("ai_service_unavailable", 503);
    }

    let data;
    try { data = await response.json(); } catch (_) {
      throw new AiAssistantClientError("invalid_ai_response", response.status);
    }
    if (!response.ok || !data || data.success !== true) {
      const status = Number.isInteger(response.status) ? response.status : 0;
      const code = status === 401 ? "authentication_required"
        : status === 403 ? "ai_access_denied"
        : status === 429 ? "ai_rate_limited"
        : status >= 500 ? "ai_service_unavailable"
        : "ai_request_rejected";
      throw new AiAssistantClientError(code, status);
    }
    return data;
  }

  return Object.freeze({
    async sendMessage(input = {}) {
      validateCommon(input);
      const context = safeContext(input.context);
      const conversationId = input.conversationId == null ? null : input.conversationId;
      if (conversationId !== null && (typeof conversationId !== "string" || !UUID.test(conversationId))) {
        throw new AiAssistantClientError("invalid_conversation_id");
      }
      const data = await post("/api/v1/ai/assistant", {
        module_key: input.moduleKey,
        message: input.message.trim(),
        conversation_id: conversationId,
        context
      }, input);
      if (typeof data.reply !== "string" || !data.reply.trim() ||
          data.module_key !== input.moduleKey ||
          typeof data.conversation_id !== "string" || !UUID.test(data.conversation_id) ||
          !data.action || !data.handoff) {
        throw new AiAssistantClientError("invalid_ai_response");
      }
      return Object.freeze({
        request_id: typeof data.request_id === "string" ? data.request_id : null,
        conversation_id: data.conversation_id,
        module_key: data.module_key,
        reply: data.reply,
        action: data.action,
        handoff: data.handoff
      });
    },

    async createHandoff(input = {}) {
      validateCommon({ ...input, message: "handoff" });
      if (input.moduleKey === "booking_assistant" && input.context?.booking_id == null) {
        // Booking reference is optional for a general support request.
      }
      const context = safeContext(input.context);
      const conversationId = input.conversationId;
      if (typeof conversationId !== "string" || !UUID.test(conversationId)) {
        throw new AiAssistantClientError("invalid_conversation_id");
      }
      const reasonCode = input.reasonCode || "needs_human_support";
      if (typeof reasonCode !== "string" || !/^[a-z][a-z0-9_]{1,63}$/.test(reasonCode)) {
        throw new AiAssistantClientError("invalid_handoff_reason");
      }
      const urgency = input.urgency || "normal";
      if (!["low", "normal", "high"].includes(urgency)) {
        throw new AiAssistantClientError("invalid_handoff_urgency");
      }
      const summary = typeof input.summary === "string" ? input.summary.trim() : "";
      if (!summary || summary.length > 1000) throw new AiAssistantClientError("invalid_handoff_summary");
      const data = await post("/api/v1/ai/handoff", {
        module_key: input.moduleKey,
        conversation_id: conversationId,
        booking_id: context.booking_id || null,
        reason_code: reasonCode,
        urgency,
        summary
      }, input);
      if (typeof data.handoff_id !== "string" || !UUID.test(data.handoff_id) ||
          typeof data.status !== "string" ||
          !["queued", "assigned", "in_progress", "resolved"].includes(data.status)) {
        throw new AiAssistantClientError("invalid_ai_response");
      }
      return Object.freeze({
        handoff_id: data.handoff_id,
        case_reference: typeof data.case_reference === "string" ? data.case_reference : null,
        queue: typeof data.queue === "string" ? data.queue : null,
        status: data.status,
        urgency: data.urgency || urgency,
        created_at: typeof data.created_at === "string" ? data.created_at : null
      });
    }
  });
}

const exported = { MODULE_KEYS, AiAssistantClientError, createAiAssistantClient };
if (typeof module !== "undefined" && module.exports) module.exports = exported;
if (typeof globalThis !== "undefined") globalThis.SrkAiAssistantClient = exported;
