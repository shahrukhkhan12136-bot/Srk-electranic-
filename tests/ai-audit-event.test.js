const test = require("node:test");
const assert = require("node:assert/strict");
const { buildAiAuditEvent } = require("../lib/ai-audit-event");

const valid = {
  module_key: "customer_support",
  action_key: "read_own_booking_status",
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

test("does not accept free-form error details as audit metadata", () => {
  assert.throws(() => buildAiAuditEvent({ ...valid, request_id: "Bearer-secret-token" }), /invalid_ai_audit_event_identifier/);
  const event = buildAiAuditEvent({ ...valid, error_message: "password=secret" });
  assert.equal(Object.hasOwn(event, "error_message"), false);
});
