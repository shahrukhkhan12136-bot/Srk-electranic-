"use strict";

// Pre-launch client adapter for the proposed AI API contract.
// Disabled by default. Do not enable until GPT-2 has deployed and verified
// the authenticated routes, persistence, ownership checks, audit and kill switch.
const MODULE_KEYS = Object.freeze([
  "customer_support",
  "booking_assistant",
  "electrician_assistant"
]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}(?![\\s\\S])/i;

class AiAssistantClientError extends Error {
  constructor(code, status = 0) {
    super(code);
    this.name = "AiAssistantClientError";
    this.code = code;
    this.status = status;
  }
}

function validateCommon(input) {
  if (!input || typeof input !== "object" || Array.isArray(input) ||
      ![Object.prototype, null].includes(Object.getPrototypeOf(input))) {
    throw new AiAssistantClientError("invalid_request");
  }
  const requiredKeys = ["moduleKey", "message", "accessToken", "idempotencyKey"];
  if (requiredKeys.some(key => !Object.prototype.hasOwnProperty.call(input, key))) {
    throw new AiAssistantClientError("invalid_request");
  }
  const { moduleKey, message, accessToken, idempotencyKey } = input;
  if (!MODULE_KEYS.includes(moduleKey)) throw new AiAssistantClientError("invalid_module");
  if (typeof message !== "string" || !message.trim() || message.length > 4000) {
    throw new AiAssistantClientError("invalid_message");
  }
  if (typeof accessToken !== "string" || !accessToken ||
      accessToken.length > 8192 || accessToken.trim() !== accessToken ||
      /[\s\u0000-\u001f\u007f-\u009f]/u.test(accessToken)) {
    throw new AiAssistantClientError("authentication_required", 401);
  }
  if (typeof idempotencyKey !== "string" || !UUID.test(idempotencyKey)) {
    throw new AiAssistantClientError("invalid_idempotency_key");
  }
}

function ownValue(input, key) {
  return Object.prototype.hasOwnProperty.call(input, key) ? input[key] : undefined;
}

function safeContext(context) {
  if (context == null) return {};
  if (typeof context !== "object" || Array.isArray(context) ||
      ![Object.prototype, null].includes(Object.getPrototypeOf(context))) {
    throw new AiAssistantClientError("invalid_context");
  }
  const keys = Object.keys(context);
  if (keys.some(key => key !== "booking_id")) {
    throw new AiAssistantClientError("unsupported_context");
  }
  const bookingId = Object.prototype.hasOwnProperty.call(context, "booking_id")
    ? context.booking_id : null;
  if (bookingId != null && (typeof bookingId !== "string" || !UUID.test(bookingId))) {
    throw new AiAssistantClientError("invalid_context");
  }
  return bookingId ? { booking_id: bookingId } : {};
}

function isSafeHttpsBaseUrl(value) {
  if (typeof value !== "string" || value.trim() !== value) return false;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" && Boolean(parsed.hostname) &&
      !parsed.username && !parsed.password && !parsed.search && !parsed.hash && parsed.pathname === "/";
  } catch {
    return false;
  }
}

function createAiAssistantClient({
  enabled = false,
  baseUrl = "",
  fetchImpl = globalThis.fetch
} = {}) {
  async function post(path, body, { accessToken, idempotencyKey }) {
    if (!enabled) throw new AiAssistantClientError("ai_not_enabled");
    if (!isSafeHttpsBaseUrl(baseUrl)) {
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

    const status = response && Number.isInteger(response.status) ? response.status : 0;
    if (!response || typeof response.ok !== "boolean" ||
        typeof response.json !== "function" || !response.ok) {
      const code = status === 401 ? "authentication_required"
        : status === 403 ? "ai_access_denied"
        : status === 429 ? "ai_rate_limited"
        : status >= 500 ? "ai_service_unavailable"
        : "ai_request_rejected";
      throw new AiAssistantClientError(code, status);
    }

    let data;
    try { data = await response.json(); } catch (_) {
      throw new AiAssistantClientError("invalid_ai_response", status);
    }
    if (!data || typeof data !== "object" || Array.isArray(data) || data.success !== true) {
      throw new AiAssistantClientError("ai_request_rejected", status);
    }
    return data;
  }

  return Object.freeze({
    async sendMessage(input = {}) {
      validateCommon(input);
      const context = safeContext(ownValue(input, "context"));
      const suppliedConversationId = ownValue(input, "conversationId");
      const conversationId = suppliedConversationId == null ? null : suppliedConversationId;
      if (conversationId !== null && (typeof conversationId !== "string" || !UUID.test(conversationId))) {
        throw new AiAssistantClientError("invalid_conversation_id");
      }
      const data = await post("/api/v1/ai/assistant", {
        module_key: input.moduleKey,
        message: input.message.trim(),
        conversation_id: conversationId,
        context
      }, input);
      const action = data.action;
      const handoff = data.handoff;
      const validAction = action && typeof action === "object" && !Array.isArray(action) &&
        typeof action.status === "string" && action.status.length > 0 &&
        (action.action_id == null || (typeof action.action_id === "string" && UUID.test(action.action_id))) &&
        typeof action.approval_required === "boolean";
      const validHandoff = handoff && typeof handoff === "object" && !Array.isArray(handoff) &&
        typeof handoff.required === "boolean" &&
        (handoff.handoff_id == null || (typeof handoff.handoff_id === "string" && UUID.test(handoff.handoff_id))) &&
        (handoff.queue == null || typeof handoff.queue === "string") &&
        (handoff.status == null || typeof handoff.status === "string");
      if (typeof data.reply !== "string" || !data.reply.trim() ||
          data.module_key !== input.moduleKey ||
          typeof data.conversation_id !== "string" || !UUID.test(data.conversation_id) ||
          !validAction || !validHandoff) {
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
      if (!input || typeof input !== "object" || Array.isArray(input) ||
          ![Object.prototype, null].includes(Object.getPrototypeOf(input))) {
        throw new AiAssistantClientError("invalid_request");
      }
      validateCommon({ ...input, message: "handoff" });
      const context = safeContext(ownValue(input, "context"));
      const conversationId = ownValue(input, "conversationId");
      if (typeof conversationId !== "string" || !UUID.test(conversationId)) {
        throw new AiAssistantClientError("invalid_conversation_id");
      }
      const reasonCode = ownValue(input, "reasonCode") || "needs_human_support";
      if (typeof reasonCode !== "string" || !/^[a-z][a-z0-9_]{1,63}$/.test(reasonCode)) {
        throw new AiAssistantClientError("invalid_handoff_reason");
      }
      const urgency = ownValue(input, "urgency") || "normal";
      if (!["low", "normal", "high"].includes(urgency)) {
        throw new AiAssistantClientError("invalid_handoff_urgency");
      }
      const suppliedSummary = ownValue(input, "summary");
      const summary = typeof suppliedSummary === "string" ? suppliedSummary.trim() : "";
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

const exported = { MODULE_KEYS, AiAssistantClientError, isSafeHttpsBaseUrl, createAiAssistantClient };
if (typeof module !== "undefined" && module.exports) module.exports = exported;
if (typeof globalThis !== "undefined") globalThis.SrkAiAssistantClient = exported;
