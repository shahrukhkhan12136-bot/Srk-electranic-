"use strict";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MODULE_ROLES = Object.freeze({
  customer_support: ["customer"],
  booking_assistant: ["customer"],
  electrician_assistant: ["electrician"],
  staff_assistant: ["staff", "admin"],
  reports_operations: ["admin"]
});

function json(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
    body: JSON.stringify(body)
  };
}

function createAiServerGuard({ fetchImpl = globalThis.fetch, env = process.env } = {}) {
  return async function handler(event, mode = "assistant") {
    if (event.httpMethod !== "POST") {
      return json(405, { success: false, error: "method_not_allowed" });
    }

    const headers = event.headers || {};
    const authHeader = headers.authorization || headers.Authorization || "";
    const match = typeof authHeader === "string" && authHeader.match(/^Bearer\\s+(.+)$/i);
    if (!match || !match[1].trim()) {
      return json(401, { success: false, error: "authentication_required" });
    }

    const supabaseUrl = env.SUPABASE_URL;
    const anonKey = env.SUPABASE_ANON_KEY;
    if (typeof supabaseUrl !== "string" || typeof anonKey !== "string" ||
        typeof fetchImpl !== "function") {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }

    let authUrl;
    try {
      authUrl = new URL("/auth/v1/user", supabaseUrl);
      if (authUrl.protocol !== "https:" && authUrl.hostname !== "localhost") throw new Error("invalid_url");
    } catch (_) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }

    let userResponse;
    try {
      userResponse = await fetchImpl(authUrl.toString(), {
        method: "GET",
        headers: { apikey: anonKey, Authorization: "Bearer " + match[1].trim() },
        cache: "no-store",
        redirect: "error"
      });
    } catch (_) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }
    if (!userResponse || userResponse.status === 401 || userResponse.status === 403) {
      return json(401, { success: false, error: "authentication_required" });
    }
    if (!userResponse.ok) return json(503, { success: false, error: "ai_service_unavailable" });

    let user;
    try { user = await userResponse.json(); } catch (_) {
      return json(401, { success: false, error: "authentication_required" });
    }
    const role = user && user.app_metadata && user.app_metadata.role;
    if (typeof role !== "string" || !Object.values(MODULE_ROLES).some(roles => roles.includes(role))) {
      return json(403, { success: false, error: "ai_access_denied" });
    }

    let input;
    try { input = JSON.parse(event.body || ""); } catch (_) {
      return json(400, { success: false, error: "invalid_request" });
    }
    if (!input || typeof input !== "object" || Array.isArray(input) ||
        typeof input.module_key !== "string" ||
        !Object.prototype.hasOwnProperty.call(MODULE_ROLES, input.module_key) ||
        !MODULE_ROLES[input.module_key].includes(role)) {
      return json(403, { success: false, error: "ai_access_denied" });
    }

    const idempotencyKey = headers["idempotency-key"] || headers["Idempotency-Key"];
    if (typeof idempotencyKey !== "string" || !UUID.test(idempotencyKey)) {
      return json(400, { success: false, error: "invalid_idempotency_key" });
    }

    if (mode === "assistant") {
      if (typeof input.message !== "string" || !input.message.trim() || input.message.length > 4000) {
        return json(400, { success: false, error: "invalid_message" });
      }
      if (input.conversation_id != null && !UUID.test(input.conversation_id)) {
        return json(400, { success: false, error: "invalid_conversation_id" });
      }
      if (input.context != null && (typeof input.context !== "object" || Array.isArray(input.context) ||
          Object.keys(input.context).some(key => key !== "booking_id") ||
          (input.context.booking_id != null && !UUID.test(input.context.booking_id)))) {
        return json(400, { success: false, error: "invalid_context" });
      }
    } else if (mode === "handoff") {
      if (typeof input.conversation_id !== "string" || !UUID.test(input.conversation_id) ||
          (input.booking_id != null && !UUID.test(input.booking_id)) ||
          typeof input.reason_code !== "string" || !/^[a-z][a-z0-9_]{1,63}$/.test(input.reason_code) ||
          !["low", "normal", "high"].includes(input.urgency || "normal") ||
          (input.summary != null && (typeof input.summary !== "string" || input.summary.length > 1000))) {
        return json(400, { success: false, error: "invalid_handoff_request" });
      }
    } else {
      return json(404, { success: false, error: "not_found" });
    }

    // Deliberately fail closed until conversation persistence, idempotency storage,
    // audit logging, ownership checks, provider adapter and human handoff queue ship.
    return json(503, { success: false, error: "ai_not_enabled" });
  };
}

module.exports = { MODULE_ROLES, createAiServerGuard };
