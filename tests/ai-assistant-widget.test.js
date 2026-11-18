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
  assert.match(sendBlock, /pendingMessageKey = null;\\s*pendingMessageText = null/);
  assert.ok(sendBlock.indexOf("pendingMessageKey = null") < sendBlock.indexOf("} catch (error)"));
  assert.match(sendBlock, /} catch \(error\) \{[\\s\\S]*?if \(!destroyed\) showError\(error\)/);
  assert.doesNotMatch(sendBlock.slice(sendBlock.indexOf("} catch (error)")), /pendingMessageKey = null/);
});

test("widget preserves handoff idempotency key after failure and clears it only after confirmed success", () => {
  const source = fs.readFileSync(path.join(__dirname, "../lib/ai-assistant-widget.js"), "utf8");
  const start = source.indexOf("async function requestHandoff()");
  const end = source.indexOf("const onToggleClick", start);
  const block = source.slice(start, end);
  assert.match(block, /pendingHandoffKey = nextKey;\s*pendingHandoffSummary = summary/);
  assert.match(block, /pendingHandoffKey = null;\\s*pendingHandoffSummary = null/);
  assert.ok(block.indexOf("pendingHandoffKey = null") < block.indexOf("} catch (error)"));
  assert.match(block, /} catch \(error\) \{[\\s\\S]*?if \(!destroyed\) showError\(error\)/);
  assert.doesNotMatch(block.slice(block.indexOf("} catch (error)")), /pendingHandoffKey = null/);
});
