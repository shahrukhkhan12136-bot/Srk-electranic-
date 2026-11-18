const test = require("node:test");
const assert = require("node:assert/strict");
const { MODULE_TOOLS, isToolAllowed, requiresHumanApproval } = require("../lib/ai-policy");

test("each planned AI module has a narrow allowlist", () => {
  assert.deepEqual(Object.keys(MODULE_TOOLS).sort(), [
    "booking_assistant", "customer_support", "electrician_assistant", "reports_operations", "staff_assistant"
  ]);
  for (const moduleKey of Object.keys(MODULE_TOOLS)) {
    assert.equal(isToolAllowed(moduleKey, "execute_sql"), false);
    assert.equal(isToolAllowed(moduleKey, "issue_refund"), false);
    assert.equal(isToolAllowed(moduleKey, "publish_rate"), false);
  }
});

test("only explicitly allowlisted tools are accepted", () => {
  assert.equal(isToolAllowed("customer_support", "read_own_booking_status"), true);
  assert.equal(isToolAllowed("customer_support", "read_another_customer_booking"), false);
  assert.equal(isToolAllowed("unknown_module", "read_public_service_info"), false);
});

test("sensitive and unknown write actions require human approval", () => {
  for (const action of ["payment", "refund", "rate_change", "rate_publish", "payout", "permission_change", "other_sensitive_write"]) {
    assert.equal(requiresHumanApproval(action), true);
  }
  assert.equal(requiresHumanApproval("unlisted_destructive_action"), true);
  assert.equal(requiresHumanApproval("read_only"), false);
});
