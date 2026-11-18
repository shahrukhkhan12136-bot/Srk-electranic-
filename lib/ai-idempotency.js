"use strict";

const { createHash } = require("node:crypto");

function canonicalJson(value) {
  if (value === null || typeof value === "string" || typeof value === "boolean") {
    return JSON.stringify(value);
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new TypeError("AI request contains a non-finite number");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return "[" + value.map(canonicalJson).join(",") + "]";
  }
  if (typeof value === "object") {
    const keys = Object.keys(value).sort();
    return "{" + keys.map(key => JSON.stringify(key) + ":" + canonicalJson(value[key])).join(",") + "}";
  }
  throw new TypeError("AI request contains a non-JSON value");
}

/**
 * Build the SHA-256 fingerprint stored beside an actor-scoped idempotency key.
 * The raw message/context is never returned or written to the idempotency row.
 * The key itself is deliberately excluded: the database uniqueness scope is
 * (actor_user_id, idempotency_key), while this digest detects key reuse with a
 * different logical request.
 */
function createAiRequestDigest({ actorUserId, mode, input }) {
  if (typeof actorUserId !== "string" || !actorUserId ||
      !["assistant", "handoff"].includes(mode) ||
      !input || typeof input !== "object" || Array.isArray(input)) {
    throw new TypeError("Invalid AI idempotency digest input");
  }
  const payload = canonicalJson({ actor_user_id: actorUserId, mode, input });
  return createHash("sha256").update(payload, "utf8").digest();
}

module.exports = { canonicalJson, createAiRequestDigest };
