"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { APP_MODULES_BY_ROLE, mountSrkAiAssistant } = require("../lib/ai-assistant-app");

test("app composition remains inert unless the post-launch flag is explicitly enabled as an own config value", () => {
  assert.equal(mountSrkAiAssistant({ config: {} }), null);
  assert.equal(mountSrkAiAssistant({ config: { AI_ASSISTANT_ENABLED: false } }), null);
  assert.equal(mountSrkAiAssistant({ config: null }), null);
  assert.equal(mountSrkAiAssistant({ config: [] }), null);
  const inheritedFlag = Object.create({ AI_ASSISTANT_ENABLED: true });
  assert.equal(mountSrkAiAssistant({ config: inheritedFlag }), null);
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

test("enabled app composition rejects non-HTTPS API URLs before creating a client", () => {
  const oldClient = globalThis.SrkAiAssistantClient;
  let clientCreated = false;
  try {
    globalThis.SrkAiAssistantClient = {
      createAiAssistantClient() { clientCreated = true; return {}; }
    };
    assert.throws(() => mountSrkAiAssistant({
      container: {}, supabaseClient: { auth: { getSession() {} } },
      appRole: "customer", moduleKey: "customer_support",
      config: { AI_ASSISTANT_ENABLED: true, AI_ASSISTANT_API_BASE_URL: "http://api.example.test" }
    }), /ai_assistant_api_base_url_required/);
    assert.equal(clientCreated, false);
  } finally {
    if (oldClient === undefined) delete globalThis.SrkAiAssistantClient;
    else globalThis.SrkAiAssistantClient = oldClient;
  }
});

test("app session provider propagates Supabase auth errors instead of inventing a session", async () => {
  const oldClient = globalThis.SrkAiAssistantClient;
  const oldWidget = globalThis.SrkAiAssistantWidget;
  let widgetOptions;
  const authError = new Error("session refresh failed");
  try {
    globalThis.SrkAiAssistantClient = {
      createAiAssistantClient() { return { sendMessage() {}, createHandoff() {} }; }
    };
    globalThis.SrkAiAssistantWidget = {
      createAiAssistantWidget(options) { widgetOptions = options; return { mounted: true }; }
    };
    mountSrkAiAssistant({
      container: {}, supabaseClient: { auth: { async getSession() {
        return { data: { session: null }, error: authError };
      } } },
      appRole: "electrician", moduleKey: "electrician_assistant",
      config: { AI_ASSISTANT_ENABLED: true, AI_ASSISTANT_API_BASE_URL: "https://api.example.test" }
    });
    await assert.rejects(widgetOptions.getSession(), error => error === authError);
  } finally {
    if (oldClient === undefined) delete globalThis.SrkAiAssistantClient;
    else globalThis.SrkAiAssistantClient = oldClient;
    if (oldWidget === undefined) delete globalThis.SrkAiAssistantWidget;
    else globalThis.SrkAiAssistantWidget = oldWidget;
  }
});

test("enabled app composition rejects malformed HTTPS URLs and embedded credentials", () => {
  const oldClient = globalThis.SrkAiAssistantClient;
  let clientCreated = false;
  try {
    globalThis.SrkAiAssistantClient = {
      createAiAssistantClient() { clientCreated = true; return {}; }
    };
    const invalidUrls = [
      "https://",
      "https://user:secret@api.example.test",
      "https://api.example.test?token=secret",
      "https://api.example.test#fragment",
      " https://api.example.test",
      "https://api.example.test/prefix"
    ];
    for (const url of invalidUrls) {
      assert.throws(() => mountSrkAiAssistant({
        container: {}, supabaseClient: { auth: { getSession() {} } },
        appRole: "customer", moduleKey: "customer_support",
        config: { AI_ASSISTANT_ENABLED: true, AI_ASSISTANT_API_BASE_URL: url }
      }), /ai_assistant_api_base_url_required/);
    }
    assert.equal(clientCreated, false);
  } finally {
    if (oldClient === undefined) delete globalThis.SrkAiAssistantClient;
    else globalThis.SrkAiAssistantClient = oldClient;
  }
});

test("enabled composition rejects an inherited API base URL", () => {
  const oldValue = Object.getOwnPropertyDescriptor(Object.prototype, "AI_ASSISTANT_API_BASE_URL");
  try {
    Object.defineProperty(Object.prototype, "AI_ASSISTANT_API_BASE_URL", {
      configurable: true, value: "https://api.example.test"
    });
    assert.throws(() => mountSrkAiAssistant({
      config: { AI_ASSISTANT_ENABLED: true },
      appRole: "customer", moduleKey: "customer_support"
    }), /ai_assistant_api_base_url_required/);
  } finally {
    if (oldValue) Object.defineProperty(Object.prototype, "AI_ASSISTANT_API_BASE_URL", oldValue);
    else delete Object.prototype.AI_ASSISTANT_API_BASE_URL;
  }
});

test("app composition rejects inherited object-prototype names as app roles", () => {
  for (const appRole of ["__proto__", "constructor", "toString", "hasOwnProperty"]) {
    assert.throws(() => mountSrkAiAssistant({
      config: { AI_ASSISTANT_ENABLED: true },
      appRole, moduleKey: "customer_support"
    }), /ai_assistant_module_not_allowed_for_app/);
  }
});
