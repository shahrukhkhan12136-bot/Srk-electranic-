const test = require("node:test");
const assert = require("node:assert/strict");
const { isApprovalBoundToAction, mayExecuteAiAction } = require("../lib/ai-action-approval");

const action = {
  action_id: "act-1", action_type: "rate_publish", target_id: "catalogue-1",
  payload_hash: "sha256:abc", module_key: "booking_assistant"
};
const approval = {
  status: "approved", action_id: "act-1", action_type: "rate_publish",
  target_id: "catalogue-1", payload_hash: "sha256:abc",
  requesting_module: "booking_assistant", approver_user_id: "admin-1",
  expires_at: "2026-11-19T00:00:00Z"
};

test("approval is bound to the exact action, target, payload and module", () => {
  assert.equal(isApprovalBoundToAction({ action, approval, nowMs: Date.parse("2026-11-18T12:00:00Z") }), true);
  assert.equal(isApprovalBoundToAction({ action, approval: { ...approval, payload_hash: "sha256:changed" }, nowMs: Date.parse("2026-11-18T12:00:00Z") }), false);
  assert.equal(isApprovalBoundToAction({ action, approval: { ...approval, target_id: "other" }, nowMs: Date.parse("2026-11-18T12:00:00Z") }), false);
});

test("expired or unapproved approvals cannot authorize execution", () => {
  assert.equal(isApprovalBoundToAction({ action, approval: { ...approval, expires_at: "2026-11-18T11:00:00Z" }, nowMs: Date.parse("2026-11-18T12:00:00Z") }), false);
  assert.equal(isApprovalBoundToAction({ action, approval: { ...approval, status: "pending" }, nowMs: Date.parse("2026-11-18T12:00:00Z") }), false);
});

test("AI cannot execute an unlisted tool or sensitive action without matching approval", () => {
  assert.deepEqual(mayExecuteAiAction({
    moduleKey: "booking_assistant", toolKey: "execute_sql", actionType: "read_only"
  }), { allowed: false, reason: "tool_not_allowlisted" });
  assert.deepEqual(mayExecuteAiAction({
    moduleKey: "booking_assistant", toolKey: "prepare_booking_draft", actionType: "rate_publish",
    action, approval: null, nowMs: Date.parse("2026-11-18T12:00:00Z")
  }), { allowed: false, reason: "matching_human_approval_required" });
  assert.deepEqual(mayExecuteAiAction({
    moduleKey: "booking_assistant", toolKey: "prepare_booking_draft", actionType: "rate_publish",
    action, approval, nowMs: Date.parse("2026-11-18T12:00:00Z")
  }), { allowed: true, reason: "policy_checks_passed" });
});
