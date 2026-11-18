# SRK ELECTRONIC — AI-Ready Foundation (Design Only)

**Status:** Source documentation only. No database objects, migrations, secrets, deployment, model provider, paid service, or runtime AI feature is enabled by this document.

## 1. Goals and rollout

Prepare five independently switchable modules for phased activation after launch:
1. Customer Support
2. Booking Assistant
3. Staff Assistant
4. Reports / Operations Assistant
5. Electrician Assistant

Default state for every module is OFF. Feature flags are controlled by an authorized release process. An unavailable AI service must not block existing booking, payment, support, or electrician workflows.

## 2. Trust boundaries

- Browser apps are untrusted clients. Never accept role, user ID, approval, amount, or ownership claims from client-supplied context as authorization.
- AI provider credentials and Supabase service-role credentials remain server-side secrets. Never expose them to browser code, prompts, logs, or model-visible tool output.
- AI calls a narrow allowlist of backend tools. No arbitrary SQL, PostgREST table access, shell, code execution, payment gateway administration, or generic privileged RPC tool.
- Every tool independently authenticates the caller, checks resource ownership, applies least privilege, validates inputs, and records an outcome.
- Treat user messages, uploaded content, retrieved records, and model output as untrusted data. Defend against prompt injection by keeping policy and authorization outside the model.

## 3. Identity and permission separation

Identity classes remain distinct:
- Customer: own account and own bookings only.
- Electrician: own profile and assigned/authorized job data only.
- Support Staff: existing active staff session plus explicit staff permission.
- Main Admin: existing Main Admin authorization.
- AI Agent: server-issued module identity with a narrow tool allowlist; never impersonates a human role.

An AI action must carry authenticated actor context established by the server, module_key, tool_key, target resource, correlation ID, and idempotency key. Do not trust those values if supplied by the model or browser.

For privileged operations, check public.is_srk_admin() explicitly where Main Admin-only authority is required. Do not use srk_has_admin_permission(text) as a substitute for Main Admin-only checks, because that helper also supports permitted active staff.

## 4. Proposed API contracts (not implemented)

Versioned routes:
- POST /api/v1/ai/assistant
- POST /api/v1/ai/actions
- GET /api/v1/ai/actions/:action_id
- POST /api/v1/ai/actions/:action_id/approve
- POST /api/v1/ai/actions/:action_id/reject
- POST /api/v1/ai/handoff

The assistant endpoint accepts a module key, message, optional conversation ID, and a small context reference. It must derive actor identity from a verified session and load only authorized context server-side.

Response shape (illustrative):
{
  "success": true,
  "conversation_id": "uuid",
  "reply": "Human-readable answer",
  "action": {
    "status": "none",
    "action_id": null,
    "approval_required": false
  },
  "handoff": {
    "required": false,
    "queue": null
  }
}

Action lifecycle: proposed -> pending_approval -> approved -> executing -> completed; terminal alternatives include rejected, expired, failed, and cancelled. Only server-side state transitions are authoritative.

## 5. Human approval

AI may draft a proposal, never approve its own proposal. Approval is bound to:
- action ID and action type;
- target record ID;
- canonical payload hash;
- requested amount/values where applicable;
- requesting AI module;
- approver's verified human user ID;
- approval time, expiry, and execution result.

Any payload or target change invalidates the approval and requires a new approval. Before execution, re-check authorization, resource state, approval expiry, payload hash, idempotency, and any business invariants in one transaction or equivalent atomic operation.

Sensitive actions requiring authorized human approval include payments, refunds, rate changes/publication, payouts, staff/admin permission changes, account activation, and other irreversible or financial actions. AI is denied direct execution even if a prompt asks it to do so.

## 6. Audit and privacy

Proposed append-only event categories: conversation access, tool invocation, action proposal, approval/rejection, handoff, execution outcome, denial, and safety failure.

Record actor class, module, tool, resource reference, correlation/idempotency IDs, decision, timestamps, and sanitized outcome. Do not log passwords, OTPs, access/refresh tokens, API keys, payment secrets, full payment credentials, or unnecessary private contact/address data. Apply retention and access rules before launch.

Audit write failures for sensitive operations fail closed. A user-facing response must not claim an action completed until the backend confirms it.

## 7. Database access pattern

Logical data domains (names are proposals, not existing tables):
- srk_ai_agents
- srk_ai_tool_permissions
- srk_ai_conversations
- srk_ai_action_requests
- srk_ai_approvals
- srk_ai_audit_events
- srk_ai_handoff_queue

No browser role receives direct access to AI control tables. AI has no direct database credentials. Backend uses dedicated, narrowly scoped operations; service-role access, if unavoidable in an existing server handler, must remain isolated server-side and be constrained by explicit per-request authorization. Prefer security-definer RPCs with fixed search_path, strict grants, explicit actor checks, and minimal return columns. Audit tables are append-only and protected from update/delete/truncate.

## 8. Module boundaries

- Customer Support: public service information and the authenticated customer's own booking/support status.
- Booking Assistant: prepare booking drafts and explain estimates; customer must confirm before booking creation. Existing booking API remains authoritative.
- Staff Assistant: internal knowledge and assigned support tasks within the staff member's existing permissions.
- Reports/Operations: aggregate, minimized, read-only reporting; no financial mutation.
- Electrician Assistant: assigned job details and procedural help; no reassignment, payout, customer-private data expansion, or status override.

Human handoff includes queue, reason, urgency, sanitized summary, conversation reference, and status. Staff sees only cases allowed by existing staff permissions.

## 9. Release gates

Before enabling any module: threat model, data minimization review, prompt-injection tests, permission matrix tests, ownership/isolation tests, audit immutability tests, rate limits, abuse controls, provider privacy/retention review, cost limits, kill switch, fallback UX, and human escalation tests. Launch one module at a time with feature flags and monitored rollback.

## 10. Explicit exclusions

This document does not create migrations, tables, RPCs, API routes, AI provider accounts, keys, paid services, or deployments. It does not alter the existing 15% platform commission, payment/refund logic, rate catalogue, booking snapshots, Staff RBAC, or any previous migration.
