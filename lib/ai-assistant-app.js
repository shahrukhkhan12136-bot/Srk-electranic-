"use strict";
const APP_MODULES_BY_ROLE = Object.freeze({
  customer: Object.freeze(["customer_support", "booking_assistant"]),
  electrician: Object.freeze(["electrician_assistant"])
});

function isSafeHttpsBaseUrl(value) {
  if (typeof value !== "string" || value.trim() !== value) return false;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" &&
      Boolean(parsed.hostname) &&
      !parsed.username &&
      !parsed.password &&
      !parsed.search &&
      !parsed.hash && parsed.pathname === "/";
  } catch {
    return false;
  }
}

function mountSrkAiAssistant({
  container, supabaseClient, appRole, moduleKey,
  config = globalThis.SRK_CONFIG || {},
  documentRef = globalThis.document
} = {}) {
  if (config.AI_ASSISTANT_ENABLED !== true) return null;
  if (!APP_MODULES_BY_ROLE[appRole]?.includes(moduleKey)) {
    throw new TypeError("ai_assistant_module_not_allowed_for_app");
  }
  if (!isSafeHttpsBaseUrl(config.AI_ASSISTANT_API_BASE_URL)) {
    throw new TypeError("ai_assistant_api_base_url_required");
  }
  if (!container || !supabaseClient?.auth?.getSession ||
      !globalThis.SrkAiAssistantClient?.createAiAssistantClient ||
      !globalThis.SrkAiAssistantWidget?.createAiAssistantWidget) {
    throw new TypeError("ai_assistant_app_dependencies_unavailable");
  }
  const client = globalThis.SrkAiAssistantClient.createAiAssistantClient({
    enabled: true, baseUrl: config.AI_ASSISTANT_API_BASE_URL
  });
  return globalThis.SrkAiAssistantWidget.createAiAssistantWidget({
    container, client, moduleKey, enabled: true, documentRef,
    getSession: async () => {
      const { data, error } = await supabaseClient.auth.getSession();
      if (error) throw error;
      return data?.session || null;
    },
    getContext: () => ({})
  });
}
const exported = { APP_MODULES_BY_ROLE, isSafeHttpsBaseUrl, mountSrkAiAssistant };
if (typeof module !== "undefined" && module.exports) module.exports = exported;
if (typeof globalThis !== "undefined") globalThis.SrkAiAssistantApp = exported;
