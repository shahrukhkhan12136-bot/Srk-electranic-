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
