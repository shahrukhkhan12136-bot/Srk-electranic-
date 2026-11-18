"use strict";

// Checks a server-created approval against the exact proposed action.
// Call only after authenticating the human actor and loading approval server-side.
function isApprovalBoundToAction({ action, approval, nowMs = Date.now() }) {
  if (!action || typeof action !== "object" || !approval || typeof approval !== "object" || approval.status !== "approved") return false;
  const requiredStrings = ["action_id", "action_type", "target_id", "payload_hash", "module_key"];
  if (requiredStrings.some(key => typeof action[key] !== "string" || action[key].trim().length === 0)) return false;
  if (requiredStrings.slice(0, 4).some(key => typeof approval[key] !== "string" || approval[key].trim().length === 0)) return false;
  if (typeof approval.requesting_module !== "string" || approval.requesting_module.trim().length === 0) return false;
  if (typeof approval.approver_user_id !== "string" || approval.approver_user_id.trim().length === 0) return false;
  if (typeof approval.expires_at !== "string" || !Number.isFinite(Date.parse(approval.expires_at))) return false;
  if (!Number.isFinite(nowMs)) return false;
  return approval.action_id === action.action_id &&
    approval.action_type === action.action_type &&
    approval.target_id === action.target_id &&
    approval.payload_hash === action.payload_hash &&
    approval.requesting_module === action.module_key &&
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
