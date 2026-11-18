"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { APP_MODULES_BY_ROLE, mountSrkAiAssistant } = require("../lib/ai-assistant-app");

test("app composition remains inert unless the post-launch flag is explicitly enabled", () => {
  assert.equal(mountSrkAiAssistant({ config: {} }), null);
  assert.equal(mountSrkAiAssistant({ config: { AI_ASSISTANT_ENABLED: false } }), null);
});

test("Customer and Electrician module permissions are separated", () => {
  assert.deepEqual(APP_MODULES_BY_ROLE.customer, ["customer_support", "booking_assistant"]);
  assert.deepEqual(APP_MODULES_BY_ROLE.electrician, ["electrician_assistant"]);
  assert.throws(() => mountSrkAiAssistant({
    config: { AI_ASSISTANT_ENABLED: true },
    appRole: "electrician", moduleKey: "customer_support"
  }), /ai_assistant_module_not_allowed_for_app/);
  assert.throws(() => mountSrkAiAssistant({
    config: { AI_ASSISTANT_ENABLED: true },
    appRole: "customer", moduleKey: "electrician_assistant"
  }), /ai_assistant_module_not_allowed_for_app/);
});

test("enabled mounting fails closed until the authenticated app dependencies exist", () => {
  assert.throws(() => mountSrkAiAssistant({
    config: { AI_ASSISTANT_ENABLED: true, AI_ASSISTANT_API_BASE_URL: "https://api.example.test" },
    appRole: "customer", moduleKey: "customer_support", container: {}
  }), /ai_assistant_app_dependencies_unavailable/);
});

test("enabled composition passes only the app module and Supabase session provider to the widget", async () => {
  const oldClient = globalThis.SrkAiAssistantClient;
  const oldWidget = globalThis.SrkAiAssistantWidget;
  let clientOptions, widgetOptions;
  try {
    globalThis.SrkAiAssistantClient = {
      createAiAssistantClient(options) {
        clientOptions = options;
        return { sendMessage() {}, createHandoff() {} };
      }
    };
    globalThis.SrkAiAssistantWidget = {
      createAiAssistantWidget(options) { widgetOptions = options; return { mounted: true }; }
    };
    const supabaseClient = { auth: { async getSession() {
      return { data: { session: { access_token: "verified-session-token" } }, error: null };
    } } };
    const result = mountSrkAiAssistant({
      container: {}, supabaseClient, appRole: "customer", moduleKey: "booking_assistant",
      config: { AI_ASSISTANT_ENABLED: true, AI_ASSISTANT_API_BASE_URL: "https://api.example.test" }
    });
    assert.deepEqual(result, { mounted: true });
    assert.equal(clientOptions.enabled, true);
    assert.equal(clientOptions.baseUrl, "https://api.example.test");
    assert.equal(widgetOptions.moduleKey, "booking_assistant");
    assert.equal(widgetOptions.enabled, true);
    assert.deepEqual(widgetOptions.getContext(), {});
    assert.equal((await widgetOptions.getSession()).access_token, "verified-session-token");
  } finally {
    if (oldClient === undefined) delete globalThis.SrkAiAssistantClient;
    else globalThis.SrkAiAssistantClient = oldClient;
    if (oldWidget === undefined) delete globalThis.SrkAiAssistantWidget;
    else globalThis.SrkAiAssistantWidget = oldWidget;
  }
});
