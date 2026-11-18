"use strict";

// Pure policy helper only. Backend must still authenticate the human/session,
// authorize the resource, and persist an audit event for every invocation.
const MODULE_TOOLS = Object.freeze({
  customer_support: Object.freeze(["read_public_service_info", "read_own_booking_status", "create_support_handoff"]),
  booking_assistant: Object.freeze(["read_public_service_info", "prepare_booking_draft", "create_support_handoff"]),
  staff_assistant: Object.freeze(["read_permitted_staff_knowledge", "read_assigned_support_case", "create_support_handoff"]),
  reports_operations: Object.freeze(["read_approved_aggregates", "create_support_handoff"]),
  electrician_assistant: Object.freeze(["read_assigned_job_summary", "read_work_guidance", "create_support_handoff"])
});

const HUMAN_APPROVAL_ACTIONS = Object.freeze([
  "payment",
  "refund",
  "rate_change",
  "rate_publish",
  "payout",
  "permission_change",
  "account_activation",
  "booking_cancellation_with_fee",
  "other_sensitive_write"
]);

function isToolAllowed(moduleKey, toolKey) {
  return Object.prototype.hasOwnProperty.call(MODULE_TOOLS, moduleKey) &&
    MODULE_TOOLS[moduleKey].includes(toolKey);
}

function requiresHumanApproval(actionType) {
  return HUMAN_APPROVAL_ACTIONS.includes(actionType) || ![
    "read_only",
    "prepare_booking_draft",
    "create_support_handoff"
  ].includes(actionType);
}

module.exports = { MODULE_TOOLS, HUMAN_APPROVAL_ACTIONS, isToolAllowed, requiresHumanApproval };
