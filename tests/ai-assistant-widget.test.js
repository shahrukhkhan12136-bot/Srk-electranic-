"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { APP_MODULES, createAiAssistantWidget } = require("../lib/ai-assistant-widget");

test("Customer and Electrician module keys are explicitly limited", () => {
  assert.deepEqual(APP_MODULES, ["customer_support", "booking_assistant", "electrician_assistant"]);
});

test("widget is absent by default and does not require browser globals while disabled", () => {
  assert.equal(createAiAssistantWidget(), null);
  assert.equal(createAiAssistantWidget({ enabled: false }), null);
});

test("enabled widget requires explicit app container, client and verified-session provider", () => {
  assert.throws(() => createAiAssistantWidget({ enabled: true }), /invalid_ai_widget_configuration/);
  assert.throws(() => createAiAssistantWidget({
    enabled: true, moduleKey: "reports_operations", container: {},
    client: { sendMessage() {}, createHandoff() {} }, getSession() {}
  }), /invalid_ai_widget_configuration/);
});

test("widget source uses safe text rendering, accessible status regions and confirmed handoff", () => {
  const source = fs.readFileSync(path.join(__dirname, "../lib/ai-assistant-widget.js"), "utf8");
  assert.match(source, /span\.textContent = value/);
  assert.match(source, /aria-live/);
  assert.match(source, /Human handoff is an explicit user choice/);
  assert.match(source, /handoffSummary\.hidden = false;\s*handoff\.hidden = false;/);
  assert.doesNotMatch(source, /if \(result\.handoff\?\.required === true\)/);
  assert.match(source, /result\.case_reference \|\| result\.handoff_id/);
  assert.match(source, /pendingHandoffSummary !== summary/);
  assert.match(source, /pendingMessageText !== message/);
  assert.match(source, /globalThis\.SrkAiAssistantWidget = exported/);
  assert.match(source, /if \(!enabled\) return null/);
  assert.doesNotMatch(source, /localStorage|sessionStorage/);
});


test("browser global exposes the same safe widget factory as the CommonJS test export", () => {
  assert.equal(globalThis.SrkAiAssistantWidget.createAiAssistantWidget, createAiAssistantWidget);
});


test("widget starts closed, exposes an accessible entry point and Escape closes the panel", () => {
  const source = fs.readFileSync(path.join(__dirname, "../lib/ai-assistant-widget.js"), "utf8");
  assert.match(source, /toggle\.setAttribute\("aria-expanded", "false"\)/);
  assert.match(source, /panel\.hidden = true/);
  assert.match(source, /event\.key === "Escape" && panelOpen/);
  assert.match(source, /setPanelOpen\(false\)/);
  assert.match(source, /toggle\.focus\(\)/);
  assert.match(source, /toggle\.removeEventListener\("click", onToggleClick\)/);
});

test("widget checks teardown after session resolution before sending either request", () => {
  const source = fs.readFileSync(path.join(__dirname, "../lib/ai-assistant-widget.js"), "utf8");
  assert.match(source, /const accessToken = await credentials\(\);\s*if \(destroyed\) return;\s*const result = await client\.sendMessage/);
  assert.match(source, /const accessToken = await credentials\(\);\s*if \(destroyed\) return;\s*const result = await client\.createHandoff/);
});

test("widget catches idempotency key failures, validates UUIDs and regenerates missing retry keys", () => {
  const source = fs.readFileSync(path.join(__dirname, "../lib/ai-assistant-widget.js"), "utf8");
  assert.match(source, /pendingMessageText !== message \|\| !pendingMessageKey/);
  assert.match(source, /pendingHandoffSummary !== summary \|\| !pendingHandoffKey/);
  assert.match(source, /const nextKey = createId\(\)/);
  assert.match(source, /typeof nextKey !== "string" \|\| !\/\^\[0-9a-f\]/);
  assert.equal((source.match(/\(\?!\[\\s\\S\]\)/g) || []).length, 2, "both generated UUID checks must enforce the absolute end of input");
  assert.match(source, /pendingMessageKey = nextKey;\s*pendingMessageText = message/);
  assert.match(source, /pendingHandoffKey = nextKey;\s*pendingHandoffSummary = summary/);
  assert.match(source, /finally \{\s*busy = false;/);
  assert.match(source, /if \(!destroyed\) send\.disabled = false/);
});

test("widget preserves the same message idempotency key after request failure", () => {
  const source = fs.readFileSync(path.join(__dirname, "../lib/ai-assistant-widget.js"), "utf8");
  const sendStart = source.indexOf("async function sendMessage()");
  const handoffStart = source.indexOf("async function requestHandoff()");
  const sendBlock = source.slice(sendStart, handoffStart);
  assert.match(sendBlock, /pendingMessageKey = nextKey;\s*pendingMessageText = message/);
  assert.match(sendBlock, /pendingMessageKey = null;\s*pendingMessageText = null/);
  assert.ok(sendBlock.indexOf("pendingMessageKey = null") < sendBlock.indexOf("} catch (error)"));
  assert.match(sendBlock, /} catch \(error\) \{[\s\\S]*?if \(!destroyed\) showError\(error\)/);
  assert.doesNotMatch(sendBlock.slice(sendBlock.indexOf("} catch (error)")), /pendingMessageKey = null/);
});

test("widget preserves handoff idempotency key after failure and clears it only after confirmed success", () => {
  const source = fs.readFileSync(path.join(__dirname, "../lib/ai-assistant-widget.js"), "utf8");
  const start = source.indexOf("async function requestHandoff()");
  const end = source.indexOf("const onToggleClick", start);
  const block = source.slice(start, end);
  assert.match(block, /pendingHandoffKey = nextKey;\s*pendingHandoffSummary = summary/);
  assert.match(block, /pendingHandoffKey = null;\s*pendingHandoffSummary = null/);
  assert.ok(block.indexOf("pendingHandoffKey = null") < block.indexOf("} catch (error)"));
  assert.match(block, /} catch \(error\) \{[\s\\S]*?if \(!destroyed\) showError\(error\)/);
  assert.doesNotMatch(block.slice(block.indexOf("} catch (error)")), /pendingHandoffKey = null/);
});

function createFakeDocument() {
  class FakeElement {
    constructor(tagName) {
      this.tagName = tagName;
      this.children = [];
      this.listeners = {};
      this.attributes = {};
      this.hidden = false;
      this.disabled = false;
      this.value = "";
      this.textContent = "";
    }
    setAttribute(name, value) { this.attributes[name] = value; }
    append(...items) { this.children.push(...items); }
    addEventListener(name, callback) { this.listeners[name] = callback; }
    removeEventListener(name) { delete this.listeners[name]; }
    focus() {}
    remove() { this.removed = true; }
    find(tagName) {
      if (this.tagName === tagName) return this;
      for (const child of this.children) {
        const found = child.find?.(tagName);
        if (found) return found;
      }
      return null;
    }
  }
  return { createElement: tagName => new FakeElement(tagName) };
}

test("Customer and Electrician widgets show login guidance and never send without a live session", async () => {
  for (const moduleKey of ["customer_support", "electrician_assistant"]) {
    const documentRef = createFakeDocument();
    const container = documentRef.createElement("main");
    let sendCalls = 0;
    const widget = createAiAssistantWidget({
      enabled: true, moduleKey, container, documentRef,
      client: {
        async sendMessage() { sendCalls++; },
        async createHandoff() { throw new Error("handoff must not run"); }
      },
      async getSession() { return null; },
      createId: () => "123e4567-e89b-42d3-a456-426614174000"
    });
    const toggle = widget.element.find("button");
    const panel = widget.element.find("div");
    const input = widget.element.find("textarea");
    const buttons = [];
    const collect = node => {
      if (node.tagName === "button") buttons.push(node);
      for (const child of node.children) collect(child);
    };
    collect(widget.element);
    const send = buttons[1];
    toggle.listeners.click();
    input.value = "मेरी बुकिंग का स्टेटस बताइए";
    await send.listeners.click();
    assert.equal(sendCalls, 0, moduleKey + " must not send without a session");
    const status = panel.children.find(child => child.attributes.role === "status");
    assert.equal(status.textContent, "कृपया दोबारा लॉगिन करें।");
    widget.destroy();
  }
});


test("Human handoff sends the conversation and booking context, then locks after confirmed queue success", async () => {
  const documentRef = createFakeDocument();
  const container = documentRef.createElement("main");
  const sent = [];
  const handedOff = [];
  const widget = createAiAssistantWidget({
    enabled: true, moduleKey: "customer_support", container, documentRef,
    client: {
      async sendMessage(payload) {
        sent.push(payload);
        return {
          conversation_id: "123e4567-e89b-42d3-a456-426614174001",
          reply: "मैं कर्मचारी की सहायता उपलब्ध करा सकता हूँ।",
          handoff: { required: true }
        };
      },
      async createHandoff(payload) {
        handedOff.push(payload);
        return {
          handoff_id: "123e4567-e89b-42d3-a456-426614174002",
          case_reference: "CASE-42",
          status: "queued"
        };
      }
    },
    async getSession() { return { access_token: "live-session-token" }; },
    getContext: () => ({ booking_id: "123e4567-e89b-42d3-a456-426614174003" }),
    createId: () => "123e4567-e89b-42d3-a456-426614174004"
  });
  const buttons = [];
  const collect = node => {
    if (node.tagName === "button") buttons.push(node);
    for (const child of node.children) collect(child);
  };
  collect(widget.element);
  const input = widget.element.find("textarea");
  buttons[0].listeners.click();
  input.value = "मेरी बुकिंग में समस्या है";
  await buttons[1].listeners.click();
  const panel = widget.element.find("div");
  const summary = panel.children[6];
  const handoffButton = buttons[2];
  assert.equal(summary.hidden, false);
  summary.value = "बुकिंग की समस्या के लिए कर्मचारी से संपर्क चाहिए";
  await handoffButton.listeners.click();

  assert.equal(sent.length, 1);
  assert.equal(sent[0].context.booking_id, "123e4567-e89b-42d3-a456-426614174003");
  assert.equal(handedOff.length, 1);
  assert.equal(handedOff[0].conversationId, "123e4567-e89b-42d3-a456-426614174001");
  assert.equal(handedOff[0].context.booking_id, "123e4567-e89b-42d3-a456-426614174003");
  assert.equal(handedOff[0].summary, summary.value);
  assert.equal(handedOff[0].reasonCode, "needs_human_support");
  assert.equal(handedOff[0].urgency, "normal");
  assert.equal(handoffButton.disabled, true);
  assert.equal(summary.disabled, true);
  const status = panel.children[5];
  assert.equal(status.textContent, "आपका सहायता अनुरोध दर्ज हो गया है।");
  assert.ok(panel.children[2].children.some(item => item.children?.[1]?.textContent?.includes("CASE-42")));
  widget.destroy();
});

test("Human handoff retries with the same idempotency key after a failed request", async () => {
  const documentRef = createFakeDocument();
  const container = documentRef.createElement("main");
  const handoffCalls = [];
  let attempt = 0;
  const generatedIds = [
    "123e4567-e89b-42d3-a456-426614174010",
    "123e4567-e89b-42d3-a456-426614174011"
  ];
  const widget = createAiAssistantWidget({
    enabled: true, moduleKey: "electrician_assistant", container, documentRef,
    client: {
      async sendMessage() {
        return {
          conversation_id: "123e4567-e89b-42d3-a456-426614174012",
          reply: "सपोर्ट टीम सहायता कर सकती है।",
          handoff: { required: true }
        };
      },
      async createHandoff(payload) {
        handoffCalls.push(payload);
        attempt++;
        if (attempt === 1) {
          const error = new Error("temporary failure");
          error.code = "ai_service_unavailable";
          throw error;
        }
        return {
          handoff_id: "123e4567-e89b-42d3-a456-426614174013",
          status: "queued"
        };
      }
    },
    async getSession() { return { access_token: "live-session-token" }; },
    createId: () => generatedIds.shift()
  });
  const buttons = [];
  const collect = node => {
    if (node.tagName === "button") buttons.push(node);
    for (const child of node.children) collect(child);
  };
  collect(widget.element);
  buttons[0].listeners.click();
  widget.element.find("textarea").value = "सुरक्षा संबंधी समस्या";
  await buttons[1].listeners.click();
  const panel = widget.element.find("div");
  const summary = panel.children[6];
  summary.value = "कर्मचारी से तकनीकी सहायता चाहिए";
  const handoffButton = buttons[2];
  await handoffButton.listeners.click();
  assert.equal(handoffButton.disabled, false);
  assert.equal(summary.disabled, false);
  await handoffButton.listeners.click();

  assert.equal(handoffCalls.length, 2);
  assert.equal(handoffCalls[0].idempotencyKey, "123e4567-e89b-42d3-a456-426614174011");
  assert.equal(handoffCalls[1].idempotencyKey, handoffCalls[0].idempotencyKey);
  assert.equal(handoffButton.disabled, true);
  assert.equal(summary.disabled, true);
  widget.destroy();
});
