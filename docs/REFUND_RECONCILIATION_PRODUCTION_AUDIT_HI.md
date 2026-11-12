# Refund Provider Reconciliation — Production Read-only Audit

**Date:** 2026-11-12  
**Production Supabase project:** `gnqhoaqatmoiwwhgzkgm`  
**Feature branch:** `feature/production-push-notifications`

## Confirmed Production behavior

Read-only catalog inspection confirmed that Production currently has:
- `public.srk_razorpay_refunds`
- `public.srk_booking_refund_requests`
- `public.srk_service_reconcile_booking_refund(uuid,text,text,text)`
- the refund request/admin preparation/manual refund RPCs.

Read-only `pg_get_functiondef` inspection of the Production reconciliation RPC confirmed the currently installed implementation:

1. It accepts a provider refund ID matching the `rfnd_...` format.
2. It returns early when the existing refund row is already `processed`.
3. Otherwise it assigns `refund_id = coalesce(incoming_provider_refund_id, existing_refund_id)`, so a different non-null provider refund ID can overwrite the previously bound ID.
4. It maps provider `pending` to internal `processing` without guarding an already `failed` refund row, so an out-of-order pending event can downgrade the failed state.
5. It updates the linked refund request status from the incoming event without terminal-state protection.

This confirms the two risks identified in the feature-branch source audit are present in the currently installed Production RPC. The inspection was read-only; no Production function, schema or data was changed.

## Feature-branch forward fix

New forward-only migration:
`supabase/migrations/20261112190000_harden_refund_provider_reconciliation.sql`

It:
- rejects a conflicting non-null provider refund ID with SQLSTATE `23505`;
- keeps `processed` terminal and idempotent;
- ignores stale `pending` after `failed`, without changing refund/provider status;
- rejects a contradictory `processed` event after a failed terminal state for the same refund ID, requiring manual reconciliation;
- retains service-role-only execution.

Regression tests cover:
- conflicting provider refund ID against an already processed refund;
- failed → stale pending, asserting state and provider_status remain failed;
- failed → processed, asserting terminal conflict is raised.

## CI evidence

GitHub Actions run `43171211161` completed **SUCCESS** at commit `69ad1262b35bcc4766385b27eb0ad93a0875aab7`.

The run applied the new migration twice on an isolated PostgreSQL 16 fixture, then passed refund assertions, webhook-ledger lease/access tests, Node syntax checks, refund handler tests and snapshot/webhook contract tests.

## Release status

**Production remains NO-GO.**

The forward migration is committed only to the feature branch and has not been applied to Production. Do not run real-money refunds or live webhook replay as a substitute for the approved Razorpay Test Mode validation. A separate explicit owner approval is required before any Production migration or payment activity.


## 2026-11-12 — completed-refund replay ordering correction

A code-path review found that `process-refund.js` previously fetched the Razorpay payment and rejected any `amount_refunded > 0` **before** calling the Admin prepare RPC. This was safe against a second refund POST, but it also blocked a harmless retry for a refund already marked `processed` in SRK's ledger: Razorpay correctly reports the payment as already refunded, while SRK already has the terminal result.

Feature-branch correction:
- Call `srk_admin_prepare_booking_refund` first. Its row lock and booking-level unique ledger row serialize the business refund operation.
- Validate the returned ledger row and return HTTP 200 immediately if its status is `processed`; do not contact Razorpay again.
- Only unresolved/non-terminal ledger rows proceed to Razorpay payment verification and the prior-refund guard.
- The payment amount comparison now uses the prepared ledger's immutable `amount_paise`, rather than recalculating from the request-list amount.

Added a handler regression case where Razorpay payment has `amount_refunded = full amount` and the ledger already says `processed`: expected HTTP 200 and zero Razorpay API calls. Existing prior-partial-refund test remains: expected HTTP 409 and no refund POST.

GitHub Actions runs for the handler and workflow are in progress at the time this note was written; do not treat the new test as passed until the run completes successfully.

This change does **not** resolve an ambiguous timeout where the provider may have accepted a refund but SRK still has `requested/processing/unknown`. That path remains fail-closed for manual reconciliation when Razorpay reports any prior refunded amount. Before automatic retry/recovery is enabled, implement exact provider refund lookup and immutable correlation (refund ID / stored receipt or notes), reject zero or multiple ambiguous matches, and use the same persisted `X-Refund-Idempotency` key plus byte-equivalent request only under the verified Razorpay API contract. Do not retry with a new key. No provider API calls were made for this audit.

Official Razorpay documentation checked: Normal/Instant Refund APIs support `X-Refund-Idempotency` and require the same key and identical request for retries; payment objects expose `amount_refunded` and `refund_status`. This is provider documentation review only, not a live/Test Mode API exercise.


### CI result for completed-refund replay correction
- Latest regression workflow **43178494303 — SUCCESS** on commit `7839f9af8fa6eeba446630d9866a255886c13752`.
- The handler test, snapshot/payment/webhook contract, refund webhook ledger contract, ambiguous-match handler, and Netlify refund handler syntax checks all passed.
- Earlier run **43178482734 — SUCCESS** also verified the handler flow correction before the dedicated replay regression was added.
