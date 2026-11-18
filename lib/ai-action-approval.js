"use strict";

// Checks a server-created approval against the exact proposed action.
// Call only after authenticating the human actor and loading approval server-side.
function isApprovalBoundToAction({ action, approval, nowMs = Date.now() }) {
  if (!action || !approval || approval.status !== "approved") return false;
  if (!Number.isFinite(nowMs) || !Number.isFinite(Date.parse(approval.expires_at))) return false;
  return approval.action_id === action.action_id &&
    approval.action_type === action.action_type &&
    approval.target_id === action.target_id &&
    approval.payload_hash === action.payload_hash &&
    approval.requesting_module === action.module_key &&
    typeof approval.approver_user_id === "string" && approval.approver_user_id.length > 0 &&
    Date.parse(approval.expires_at) > nowMs;
}

function mayExecuteAiAction({ moduleKey, toolKey, actionType, action, approval, nowMs }) {
  const { isToolAllowed, requiresHumanApproval } = require("./ai-policy");
  if (!isToolAllowed(moduleKey, toolKey)) return { allowed: false, reason: "tool_not_allowlisted" };
  if (requiresHumanApproval(actionType) && !isApprovalBoundToAction({ action, approval, nowMs })) {
    return { allowed: false, reason: "matching_human_approval_required" };
  }
  return { allowed: true, reason: "policy_checks_passed" };
}

module.exports = { isApprovalBoundToAction, mayExecuteAiAction };
