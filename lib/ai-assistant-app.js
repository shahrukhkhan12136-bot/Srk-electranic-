"use strict";

// Browser-side composition boundary for Customer/Electrician pages.
// It remains inert unless the product owner explicitly enables the post-launch
// flag and the verified backend base URL is configured.
function mountSrkAiAssistant({
  container, supabaseClient, moduleKey, config = globalThis.SRK_CONFIG || {},
  documentRef = globalThis.document
} = {}) {
  if (config.AI_ASSISTANT_ENABLED !== true) return null;
  if (!container || !supabaseClient?.auth?.getSession ||
      !globalThis.SrkAiAssistantClient?.createAiAssistantClient ||
      !globalThis.SrkAiAssistantWidget?.createAiAssistantWidget) {
    throw new TypeError("ai_assistant_app_dependencies_unavailable");
  }
  if (typeof config.AI_ASSISTANT_API_BASE_URL !== "string" ||
      !/^https:\/\//i.test(config.AI_ASSISTANT_API_BASE_URL)) {
    throw new TypeError("ai_assistant_api_base_url_required");
  }

  const client = globalThis.SrkAiAssistantClient.createAiAssistantClient({
    enabled: true,
    baseUrl: config.AI_ASSISTANT_API_BASE_URL
  });
  const widget = globalThis.SrkAiAssistantWidget.createAiAssistantWidget({
    container, client, moduleKey,
    enabled: true,
    documentRef,
    getSession: async () => {
      const { data, error } = await supabaseClient.auth.getSession();
      if (error) throw error;
      return data?.session || null;
    },
    getContext: () => ({})
  });
  return widget;
}

const srkAiAppExport = { mountSrkAiAssistant };
if (typeof module !== "undefined" && module.exports) module.exports = srkAiAppExport;
if (typeof globalThis !== "undefined") globalThis.SrkAiAssistantApp = srkAiAppExport;
