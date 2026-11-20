"use strict";

// Keep these allowlists aligned with the database CHECK constraints on
// srk_ai_audit_events.module_key, action_key and outcome.
const MODULE_KEYS = Object.freeze([
  "customer_support", "booking_assistant", "electrician_assistant"
]);
const ACTION_KEYS = Object.freeze([
  "conversation_created", "message_recorded", "handoff_requested",
  "handoff_assigned", "handoff_resolved", "request_rejected"
]);
const OUTCOMES = Object.freeze(["accepted", "completed", "rejected", "failed"]);
const SAFE_ID = /^[A-Za-z0-9._:-]{1,128}$/;

// Produces metadata only. Never pass prompts, tokens, credentials, payment data,
// free-form error messages, or raw tool payloads to this audit DTO.
function buildAiAuditEvent(input) {
  if (!input || !MODULE_KEYS.includes(input.module_key) ||
      typeof input.action_key !== "string" || !ACTION_KEYS.includes(input.action_key) ||
      typeof input.actor_id !== "string" || !SAFE_ID.test(input.actor_id) ||
      typeof input.occurred_at !== "string" || !Number.isFinite(Date.parse(input.occurred_at)) ||
      !OUTCOMES.includes(input.outcome)) {
    throw new TypeError("invalid_ai_audit_event");
  }
  for (const key of ["record_id", "approval_id", "request_id"]) {
    if (input[key] !== undefined && input[key] !== null &&
        (typeof input[key] !== "string" || !SAFE_ID.test(input[key]))) {
      throw new TypeError("invalid_ai_audit_event_identifier");
    }
  }
  return Object.freeze({
    module_key: input.module_key,
    action_key: input.action_key,
    actor_id: input.actor_id,
    record_id: input.record_id ?? null,
    approval_id: input.approval_id ?? null,
    request_id: input.request_id ?? null,
    occurred_at: new Date(input.occurred_at).toISOString(),
    outcome: input.outcome
  });
}

module.exports = { OUTCOMES, buildAiAuditEvent };
