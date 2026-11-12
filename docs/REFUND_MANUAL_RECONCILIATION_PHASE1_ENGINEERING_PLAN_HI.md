# Refund Manual Reconciliation — Safe Phase 1 Engineering Plan

Date: 2026-11-12  
Branch: `feature/production-push-notifications`  
Status: design only; no migration, UI, provider call, or Production change in this commit.

## Findings from the current feature-branch schema

1. `srk_booking_refund_requests` is a customer request/approval workflow. It has no provider-evidence or independent-review fields.
2. `srk_razorpay_refunds` is the money-movement ledger. Its `status`, `provider_status`, `refund_id`, `processed_at`, and booking payment status must not be directly editable by the new evidence UI.
3. `srk_admin_finalize_manual_booking_refund` is for manual/cash refund receipt recording through `srk_admin_record_manual_refund`. It is not a provider reconciliation mechanism and must not be reused for Razorpay evidence.
4. The existing service reconciliation RPC is service-role-only. The hardened feature-branch version intentionally blocks failed-to-processed transitions. Do not weaken it or expose it to authenticated Admin clients.
5. Existing refund request and refund-ledger tables grant table access only to service_role; Admin access is mediated by guarded RPCs. New objects must preserve this pattern.

## Safe Phase 1 scope

Implement an Admin evidence-and-review workspace that can collect and inspect evidence while making **no financial state transition**.

- Admin can open a case for an existing refund ledger row in a reviewable state.
- Evidence is append-only and records: refund record ID, provider name, provider refund ID (if any), provider payment ID, amount in paise, currency, provider status, provider timestamps, evidence reference/notes, submitter user ID, and server timestamp.
- Do not store card/bank account details, credentials, API secrets, or unrestricted sensitive screenshots. Store a constrained evidence reference and sanitized factual fields only.
- A second Admin can record a review decision against a specific evidence version. The submitting Admin cannot review their own evidence.
- Review outcomes are advisory only: `verified_match`, `pending_confirmation`, `mismatch_blocked`, or `escalate`. None of these outcomes changes the refund ledger, booking payment status, customer-visible refund status, payout, or provider.
- Repeated submission/review requests must be idempotent. Use stable evidence/review IDs and database uniqueness constraints; concurrent reviewers must serialize on the case.
- Record every case creation, evidence submission, review, and rejected attempt in append-only audit history. Never update or delete prior evidence to make a mismatch disappear.
- Access is via narrow SECURITY DEFINER RPCs with fixed empty search_path, explicit `auth.uid()` and `is_srk_admin()` checks, and execute grants only to authenticated. No direct table grants to anon/authenticated.
- Any SECURITY DEFINER routine must schema-qualify every object and be covered by explicit privilege tests. Do not use user-editable JWT user_metadata for authorization.

## Phase 2 — separately gated financial reconciliation

A later, separately approved operation may reconcile a provider-confirmed terminal conflict. It must require:
- explicit owner policy approval for failed-to-processed manual resolution;
- exact payment ID, provider refund ID, amount, currency, and provider status match;
- independent second Admin reviewer (not the evidence submitter or case initiator);
- row-level locking and one-time action ID to prevent concurrent or replayed transitions;
- immutable audit event capturing before/after state, evidence IDs, both Admin identities, and reason;
- a narrowly scoped RPC that atomically validates and changes the refund ledger, request, and booking state;
- a separate disposable Production-parity PostgreSQL replay and adversarial tests before any Production consideration.

Until those gates are met, **no manual evidence review may mark a refund processed**.

## Required database tests before Phase 1 implementation

- anon and non-admin cannot read, create, submit, or review cases.
- Admin can access only cases backed by a real refund record.
- Submitter cannot approve/review their own evidence.
- Reviewer must be a distinct authorized Admin.
- Evidence and audit history cannot be updated/deleted by client roles.
- Amount, currency, payment ID, refund ID, and provider status mismatches produce a blocked/advisory outcome only.
- Duplicate evidence/review action IDs replay the original result without duplicate rows.
- Two concurrent review attempts produce one durable review result.
- All Phase 1 actions leave `srk_razorpay_refunds`, `srk_booking_refund_requests`, `service_bookings.payment_status`, payout rows, and provider-call counts unchanged.

## Release gates

- Recover the 39 unresolved Production migration-history entries and investigate the 26 version mismatches; do not infer missing SQL from filenames.
- Build and test against a disposable Production-parity database, not the live Production project.
- Run migration replay twice and full refund + webhook + Timer integrated regression suites.
- Review the existing Admin UI/RPC response contract and verify no route accidentally invokes the cash/manual refund RPC.
- No Production migration, live Razorpay API call, real-money test, paid provider activation, or deployment without separate explicit approval.

## Supabase platform compatibility note

The Supabase 2026-10-30 Data API change means new public-schema tables are not automatically exposed by default. This plan intentionally does not grant client table access; all access remains through explicit RPC grants and server-side authorization. Verify the actual project's Data API exposure settings during parity testing rather than assuming table exposure from schema placement.


## Phase 1 implementation progress — 2026-11-12

- Feature-branch migration `20261112210000_refund_manual_reconciliation_evidence.sql` adds Admin reconciliation cases, append-only provider evidence, independent review records, and append-only audit history.
- Narrow Admin RPCs provide case creation, evidence submission, independent review, and read-only case retrieval. Direct table grants remain revoked for client roles.
- Review outcomes are advisory only. Even `verified_match` does not update refund ledger status, refund request status, booking payment status, payouts, or call Razorpay.
- Case-row locking serializes evidence/review actions; stable action IDs support idempotent replay. The evidence submitter and case opener cannot review.
- Test file `supabase/tests/refund_manual_reconciliation_assertions.sql` checks Admin authorization, non-Admin rejection, independent reviewer, self-review rejection, exact-match validation, mismatch blocking, idempotent review replay, audit row count, and no financial-state mutation.
- Refund Workflow CI run `43180209579` SUCCESS at commit `4bf3482a4163cd61372fa9db4f3bdf305b6342e1`. The migration replayed twice in isolated PostgreSQL 16; the new evidence/review assertions and existing refund, webhook, handler and syntax tests passed.
- This is backend Phase 1 only. Admin dashboard UI integration, browser/device validation, disposable Production-parity validation, migration archive recovery, and owner approval for any future financial-state transition remain outstanding.
- No Production database changes, Razorpay provider calls, real-money activity, or deployment occurred.
