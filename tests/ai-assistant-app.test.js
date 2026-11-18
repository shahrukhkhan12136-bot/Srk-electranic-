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

test("Customer and Electrician app shells prepare role-scoped mounts while preserving the default-off kill switch", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const customer = fs.readFileSync(path.join(__dirname, "../booking.html"), "utf8");
  const electrician = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");
  for (const source of [customer, electrician]) {
    assert.match(source, /\/lib\/ai-assistant-client\.js/);
    assert.match(source, /\/lib\/ai-assistant-widget\.js/);
    assert.match(source, /\/lib\/ai-assistant-app\.js/);
  }
  assert.match(customer, /id="customerAiAssistantMount"/);
  assert.match(customer, /id="customerBookingAssistantMount"/);
  assert.match(customer, /appRole:"customer",moduleKey:"customer_support"/);
  assert.match(customer, /appRole:"customer",moduleKey:"booking_assistant"/);
  assert.match(customer, /mountCustomerAiAssistant\(\);/);
  assert.match(customer, /destroyCustomerAiAssistant\(\);/);
  assert.match(customer, /customerBookingAiAssistantWidget\?\.destroy\?\.\(\)/);
  assert.match(electrician, /id="electricianAiAssistantMount"/);
  assert.match(electrician, /appRole:"electrician",moduleKey:"electrician_assistant"/);
  assert.match(electrician, /mountElectricianAiAssistant\(\);/);
  assert.match(electrician, /destroyElectricianAiAssistant\(\)/);
});


test("public browser config keeps the AI widget launch flag and API base URL unset by default", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const config = fs.readFileSync(path.join(__dirname, "../srk-config.js"), "utf8");
  assert.doesNotMatch(config, /AI_ASSISTANT_ENABLED/);
  assert.doesNotMatch(config, /AI_ASSISTANT_API_BASE_URL/);
});

test("Customer AI widget mounts only after a verified profile row is loaded", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const source = fs.readFileSync(path.join(__dirname, "../booking.html"), "utf8");
  assert.match(source, /async function loadCustomerProfile\(\)[\s\S]*?if\(!customerSb\)return false;/);
  assert.match(source, /setCustomerProfileStatus\('प्रोफ़ाइल लोड हो गई।'\);\s*return true;/);
  assert.match(source, /setCustomerProfileStatus\('नई प्रोफ़ाइल है। अपना नाम भरकर सेव करें।'\);\s*return false;/);
  assert.match(source, /catch\(e\)\{if\(isCurrent\(\)\)setCustomerProfileStatus\('प्रोफ़ाइल लोड नहीं हो सकी।[\s\S]*?return false;/);
  assert.match(source, /const customerProfileReady=await loadCustomerProfile\(\);if\(!isCurrent\(\)\)return;\s*if\(customerProfileReady\)mountCustomerAiAssistant\(\);\s*else destroyCustomerAiAssistant\(\);/);
  assert.match(source, /const profileReady=await loadCustomerProfile\(\);[\s\S]*?if\(profileReady&&document\.getElementById\('customer-dashboard'\)\?\.style\.display!=='none'\)mountCustomerAiAssistant\(\);\s*else destroyCustomerAiAssistant\(\);/);
});

test("Electrician AI widget mounts only after an active approved profile is verified", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const source = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");
  assert.match(source, /profile=p;\\s*if\\(p&&p\\.active===true&&p\\.verification_status==="approved"\\)mountElectricianAiAssistant\\(\\);else destroyElectricianAiAssistant\\(\\);/);
  assert.match(source, /function show\\(\\)[\\s\\S]*?if\\(user\\)\\{refresh\\(\\)\\}else destroyElectricianAiAssistant\\(\\)/);
  assert.match(source, /profile=null;destroyElectricianAiAssistant\\(\\);/);
  assert.match(source, /if\\(error\\)\\{destroyElectricianAiAssistant\\(\\);/);
  assert.match(source, /if\\(!p\\)\\{destroyElectricianAiAssistant\\(\\);/);
});


test("Electrician AI widget is destroyed immediately when the authenticated account view is cleared", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const source = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");
  assert.match(source, /function clearElectricianAccountView\\(\\)\\{\\s*destroyElectricianAiAssistant\\(\\);/);
});


test("Electrician profile refresh errors clear stale profile and live offer channel before returning", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const source = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");
  assert.match(source, /if\\(error\\)\\{profile=null;destroyElectricianAiAssistant\\(\\);if\\(offersChannel\\)\\{const oldChannel=offersChannel;offersChannel=null;Promise\\.resolve\\(sb\\.removeChannel\\(oldChannel\\)\\)\\.catch\\(\\(\\)=>\\{\\}\\);/);
});


test("Electrician profile refresh exceptions remove the stale live offer channel", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const source = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");
  assert.match(source, /catch\\(e\\)\\{if\\(!isCurrent\\(\\)\\)return;profile=null;destroyElectricianAiAssistant\\(\\);if\\(offersChannel\\)\\{const oldChannel=offersChannel;offersChannel=null;Promise\\.resolve\\(sb\\.removeChannel\\(oldChannel\\)\\)\\.catch\\(\\(\\)=>\\{\\}\\);/);
});


test("Customer AI widgets are destroyed when the session check is unavailable or fails", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const source = fs.readFileSync(path.join(__dirname, "../booking.html"), "utf8");
  assert.match(source, /if \\(!customerSb\\) \\{\\s*destroyCustomerAiAssistant\\(\\);/);
  assert.match(source, /catch \\(_\\) \\{\\s*if\\(!isCurrent\\(\\)\\)return;\\s*destroyCustomerAiAssistant\\(\\);/);
});
