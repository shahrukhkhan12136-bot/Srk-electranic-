"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const { canonicalJson, createAiRequestDigest } = require("../lib/ai-idempotency");

test("AI request digest is deterministic across JSON object key ordering", () => {
  const actorUserId = "123e4567-e89b-42d3-a456-426614174001";
  const first = createAiRequestDigest({
    actorUserId, mode: "assistant",
    input: { module_key: "customer_support", message: "hello", context: { booking_id: null, locale: "hi" } }
  });
  const reordered = createAiRequestDigest({
    actorUserId, mode: "assistant",
    input: { context: { locale: "hi", booking_id: null }, message: "hello", module_key: "customer_support" }
  });
  assert.ok(Buffer.isBuffer(first));
  assert.equal(first.length, 32);
  assert.deepEqual(first, reordered);
  assert.deepEqual(first, createHash("sha256").update(
    canonicalJson({
      actor_user_id: actorUserId,
      mode: "assistant",
      input: { module_key: "customer_support", message: "hello", context: { booking_id: null, locale: "hi" } }
    }), "utf8"
  ).digest());
});

test("AI request digest changes for actor, mode, or payload changes", () => {
  const base = {
    actorUserId: "123e4567-e89b-42d3-a456-426614174001",
    mode: "assistant",
    input: { module_key: "customer_support", message: "hello" }
  };
  const digest = createAiRequestDigest(base);
  assert.notDeepEqual(digest, createAiRequestDigest({ ...base, actorUserId: "123e4567-e89b-42d3-a456-426614174002" }));
  assert.notDeepEqual(digest, createAiRequestDigest({ ...base, mode: "handoff" }));
  assert.notDeepEqual(digest, createAiRequestDigest({ ...base, input: { ...base.input, message: "different" } }));
});

test("canonical JSON preserves array order while sorting nested object keys", () => {
  assert.equal(
    canonicalJson({ z: [{ b: 2, a: 1 }, "x"], a: true }),
    '{"a":true,"z":[{"a":1,"b":2},"x"]}'
  );
});

test("AI request digest rejects invalid inputs and non-JSON values", () => {
  assert.throws(() => createAiRequestDigest({ actorUserId: "", mode: "assistant", input: {} }), TypeError);
  assert.throws(() => createAiRequestDigest({ actorUserId: "actor", mode: "unknown", input: {} }), TypeError);
  assert.throws(() => createAiRequestDigest({ actorUserId: "actor", mode: "assistant", input: null }), TypeError);
  assert.throws(() => canonicalJson({ value: undefined }), TypeError);
  assert.throws(() => canonicalJson({ value: Infinity }), TypeError);
});
