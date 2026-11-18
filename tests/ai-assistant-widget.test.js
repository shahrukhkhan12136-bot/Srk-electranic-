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
  assert.match(source, /result\.handoff\?\.required === true/);
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
