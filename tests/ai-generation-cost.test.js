"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");

test("accepts an explicit USD zero cost without confusing missing cost with zero", async () => {
  const { extractReportedUsd } = await import("../lib/ai-generation-cost.mjs");
  assert.equal(extractReportedUsd({ data: { id: "gen_abc", total_cost: 0 } }, "gen_abc"), "0");
  assert.equal(extractReportedUsd({ data: { id: "gen_abc", total_cost: "0.0000001200" } }, "gen_abc"), "0.0000001200");
});

test("accepts documented camel-case SDK cost when present", async () => {
  const { extractReportedUsd } = await import("../lib/ai-generation-cost.mjs");
  assert.equal(extractReportedUsd({ data: { id: "gen_abc", totalCost: 0.0123 } }, "gen_abc"), "0.0123");
});

test("does not invent zero when Gateway cost is absent", async () => {
  const { extractReportedUsd } = await import("../lib/ai-generation-cost.mjs");
  assert.equal(extractReportedUsd({ data: { id: "gen_abc", prompt_tokens: 20 } }, "gen_abc"), null);
  assert.equal(extractReportedUsd({ data: { id: "gen_abc" } }, "gen_abc"), null);
});

test("rejects mismatched generation IDs and invalid or out-of-range costs", async () => {
  const { extractReportedUsd } = await import("../lib/ai-generation-cost.mjs");
  assert.equal(extractReportedUsd({ data: { id: "gen_other", total_cost: 1 } }, "gen_abc"), null);
  assert.equal(extractReportedUsd({ data: { id: "gen_abc", total_cost: -1 } }, "gen_abc"), null);
  assert.equal(extractReportedUsd({ data: { id: "gen_abc", total_cost: "1e-8" } }, "gen_abc"), null);
  assert.equal(extractReportedUsd({ data: { id: "gen_abc", total_cost: "10000000000" } }, "gen_abc"), null);
  assert.equal(extractReportedUsd(null, "gen_abc"), null);
});
