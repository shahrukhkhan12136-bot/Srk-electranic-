const test = require("node:test");
const assert = require("node:assert/strict");
const { buildAiAuditEvent } = require("../lib/ai-audit-event");

const valid = {
  module_key: "customer_support",
  action_key: "message_recorded",
  actor_id: "user-123",
  record_id: "booking-456",
  approval_id: null,
  request_id: "req-789",
  occurred_at: "2026-11-18T02:00:00Z",
  outcome: "completed"
};

test("builds a frozen metadata-only audit event", () => {
  const event = buildAiAuditEvent(valid);
  assert.equal(event.module_key, "customer_support");
  assert.equal(event.record_id, "booking-456");
  assert.equal(event.occurred_at, "2026-11-18T02:00:00.000Z");
  assert.equal(Object.isFrozen(event), true);
  assert.equal(Object.hasOwn(event, "prompt"), false);
  assert.equal(Object.hasOwn(event, "tool_payload"), false);
});

test("rejects unknown modules, malformed identifiers and unsupported outcomes", () => {
  assert.throws(() => buildAiAuditEvent({ ...valid, module_key: "root_admin" }), /invalid_ai_audit_event/);
  assert.throws(() => buildAiAuditEvent({ ...valid, actor_id: "bad actor" }), /invalid_ai_audit_event/);
  assert.throws(() => buildAiAuditEvent({ ...valid, record_id: "secret\nvalue" }), /invalid_ai_audit_event_identifier/);
  assert.throws(() => buildAiAuditEvent({ ...valid, outcome: "maybe" }), /invalid_ai_audit_event/);
});

test("audit modules and action keys match the persisted database allowlists", () => {
  for (const module_key of ["customer_support", "booking_assistant", "electrician_assistant"]) {
    assert.equal(buildAiAuditEvent({ ...valid, module_key }).module_key, module_key);
  }
  for (const module_key of ["staff_assistant", "reports_operations", "root_admin"]) {
    assert.throws(
      () => buildAiAuditEvent({ ...valid, module_key }),
      /invalid_ai_audit_event/
    );
  }
  for (const action_key of [
    "conversation_created", "message_recorded", "handoff_requested",
    "handoff_assigned", "handoff_resolved", "request_rejected"
  ]) {
    assert.equal(buildAiAuditEvent({ ...valid, action_key }).action_key, action_key);
  }
  for (const action_key of ["read_own_booking_status", "unknown_action", "root_admin"]) {
    assert.throws(
      () => buildAiAuditEvent({ ...valid, action_key }),
      /invalid_ai_audit_event/
    );
  }
});

test("audit outcomes match the persisted database outcome allowlist", () => {
  for (const outcome of ["accepted", "completed", "rejected", "failed"]) {
    assert.equal(buildAiAuditEvent({ ...valid, outcome }).outcome, outcome);
  }
  for (const outcome of ["allowed", "denied", "approval_required", "pending", "maybe"]) {
    assert.throws(
      () => buildAiAuditEvent({ ...valid, outcome }),
      /invalid_ai_audit_event/
    );
  }
});

test("does not accept free-form error details as audit metadata", () => {
  const event = buildAiAuditEvent({ ...valid, error_message: "password=secret" });
  assert.equal(Object.hasOwn(event, "error_message"), false);
});
