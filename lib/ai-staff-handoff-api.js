"use strict";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}(?![\\s\\S])/i;

function json(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
    body: JSON.stringify(body)
  };
}

function getHeader(headers, name) {
  const keys = Object.keys(headers || {}).filter(key => key.toLowerCase() === name.toLowerCase());
  return keys.length === 1 ? headers[keys[0]] : undefined;
}

function createAiStaffHandoffHandler({ fetchImpl = globalThis.fetch, env = process.env } = {}) {
  return async function handler(event) {
    if (event.httpMethod !== "POST") return json(405, { success: false, error: "method_not_allowed" });
    if (typeof event.body !== "string" || Buffer.byteLength(event.body, "utf8") > 8192) {
      return json(413, { success: false, error: "request_too_large" });
    }

    let input;
    try { input = JSON.parse(event.body); } catch (_) {
      return json(400, { success: false, error: "invalid_request" });
    }
    if (!input || typeof input !== "object" || Array.isArray(input) ||
        typeof input.action !== "string") {
      return json(400, { success: false, error: "invalid_request" });
    }

    const schemas = {
      list: ["action", "limit"],
      messages: ["action", "handoff_id", "limit"],
      reply: ["action", "handoff_id", "body"],
      resolve: ["action", "handoff_id"],
      assign: ["action", "handoff_id", "staff_user_id", "reason"]
    };
    const allowed = schemas[input.action];
    if (!allowed || Object.keys(input).some(key => !allowed.includes(key))) {
      return json(400, { success: false, error: "invalid_request" });
    }

    const limit = input.limit == null ? (input.action === "messages" ? 100 : 50) : input.limit;
    if (["list", "messages"].includes(input.action) &&
        (!Number.isInteger(limit) || limit < 1 || limit > (input.action === "messages" ? 200 : 100))) {
      return json(400, { success: false, error: "invalid_limit" });
    }
    if (["messages", "reply", "resolve", "assign"].includes(input.action) &&
        (typeof input.handoff_id !== "string" || !UUID.test(input.handoff_id))) {
      return json(400, { success: false, error: "invalid_handoff_id" });
    }
    if (input.action === "assign" &&
        (typeof input.staff_user_id !== "string" || !UUID.test(input.staff_user_id) ||
         typeof input.reason !== "string" || input.reason.trim().length < 5 || input.reason.length > 500)) {
      return json(400, { success: false, error: "invalid_assignment" });
    }
    if (input.action === "reply" &&
        (typeof input.body !== "string" || !input.body.trim() || input.body.length > 4000)) {
      return json(400, { success: false, error: "invalid_reply" });
    }

    const authHeader = getHeader(event.headers, "authorization");
    const match = typeof authHeader === "string" &&
      authHeader.match(/^Bearer[ \t]([A-Za-z0-9._~-]+=*)$/i);
    const token = match && match[0] === authHeader ? match[1] : null;
    if (!token || token.length > 8192) return json(401, { success: false, error: "authentication_required" });

    const baseUrl = env.SUPABASE_URL;
    const anonKey = env.SUPABASE_ANON_KEY;
    if (typeof baseUrl !== "string" || typeof anonKey !== "string" || typeof fetchImpl !== "function") {
      return json(503, { success: false, error: "service_unavailable" });
    }

    let authUrl;
    try {
      authUrl = new URL("/auth/v1/user", baseUrl);
      if (authUrl.protocol !== "https:" && authUrl.hostname !== "localhost") throw new Error("invalid_url");
    } catch (_) {
      return json(503, { success: false, error: "service_unavailable" });
    }

    let authResponse;
    try {
      authResponse = await fetchImpl(authUrl.toString(), {
        method: "GET",
        headers: { apikey: anonKey, Authorization: "Bearer " + token },
        cache: "no-store",
        redirect: "error"
      });
    } catch (_) {
      return json(503, { success: false, error: "service_unavailable" });
    }
    if (!authResponse || authResponse.status === 401 || authResponse.status === 403) {
      return json(401, { success: false, error: "authentication_required" });
    }
    if (authResponse.ok !== true || !Number.isInteger(authResponse.status) ||
        authResponse.status < 200 || authResponse.status >= 300) {
      return json(503, { success: false, error: "service_unavailable" });
    }
    let user;
    try { user = await authResponse.json(); } catch (_) {
      return json(401, { success: false, error: "authentication_required" });
    }
    if (!user || typeof user.id !== "string" || !UUID.test(user.id)) {
      return json(401, { success: false, error: "authentication_required" });
    }

    const rpcByAction = {
      list: ["srk_staff_list_assigned_ai_handoffs", { p_limit: limit }],
      messages: ["srk_staff_list_assigned_ai_handoff_messages", { p_handoff_id: input.handoff_id, p_limit: limit }],
      reply: ["srk_staff_reply_ai_handoff", { p_handoff_id: input.handoff_id, p_body: input.body }],
      resolve: ["srk_staff_resolve_ai_handoff", { p_handoff_id: input.handoff_id }],
      assign: ["srk_admin_assign_ai_handoff", {
        p_handoff_id: input.handoff_id, p_staff_user_id: input.staff_user_id, p_reason: input.reason
      }]
    };
    const [rpcName, rpcBody] = rpcByAction[input.action];
    let rpcUrl;
    try {
      rpcUrl = new URL("/rest/v1/rpc/" + rpcName, baseUrl);
      if (rpcUrl.protocol !== "https:" && rpcUrl.hostname !== "localhost") throw new Error("invalid_url");
    } catch (_) {
      return json(503, { success: false, error: "service_unavailable" });
    }

    let rpcResponse;
    try {
      rpcResponse = await fetchImpl(rpcUrl.toString(), {
        method: "POST",
        headers: {
          apikey: anonKey,
          Authorization: "Bearer " + token,
          "Content-Type": "application/json",
          Accept: "application/json"
        },
        body: JSON.stringify(rpcBody),
        cache: "no-store",
        redirect: "error"
      });
    } catch (_) {
      return json(503, { success: false, error: "service_unavailable" });
    }
    if (!rpcResponse || !Number.isInteger(rpcResponse.status)) {
      return json(503, { success: false, error: "service_unavailable" });
    }
    if (rpcResponse.status === 401 || rpcResponse.status === 403) {
      return json(403, { success: false, error: "permission_denied" });
    }
    if (rpcResponse.status < 200 || rpcResponse.status >= 300 || rpcResponse.ok !== true) {
      return json(503, { success: false, error: "handoff_operation_unavailable" });
    }
    let result;
    try { result = await rpcResponse.json(); } catch (_) {
      return json(503, { success: false, error: "handoff_operation_unavailable" });
    }
    return json(200, { success: true, data: result });
  };
}

module.exports = { createAiStaffHandoffHandler };
