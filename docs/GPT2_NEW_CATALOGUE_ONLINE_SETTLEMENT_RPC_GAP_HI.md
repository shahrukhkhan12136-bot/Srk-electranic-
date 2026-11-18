# GPT-2 Source Audit — New Catalogue Online Settlement RPC Dependency

**Date:** 18 November 2026  
**Branch:** `feat/ai-rate-management-foundation-20261118`  
**Scope:** Static source review only. No SQL execution, database access, migration application, or deployment.

## Confirmed handler dependencies

The following server handlers call both RPCs for `service_bookings.selected_category IS NOT NULL`:

- `create-order.js`: `srk_service_role_get_booking_payment_breakdown(p_booking_id)`
- `verify-payment.js`: calls the breakdown RPC, then `srk_service_role_record_online_booking_payment(p_booking_id,p_order_id,p_payment_id,p_amount_paise)`
- `razorpay-webhook.js`: calls the same two RPCs for webhook settlement.

All three use service-role authorization for the RPC calls. The handlers validate paise totals and payment/order amount consistency before settlement.

## Important unresolved dependency

A search of the visible migration inventory and targeted inspection of the payment, payout, webhook, and Catalogue migrations did not locate SQL definitions for either RPC:

- `public.srk_service_role_get_booking_payment_breakdown(uuid)`
- `public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)`

This does **not** prove that no definition exists anywhere (for example, it may exist in a non-migration deployment artifact or another branch), but these definitions and their grants are not currently evidenced by the inspected migration sources.

Therefore, do not describe new-Catalogue online settlement as database-ready. The handler calls alone do not prove that PostgREST can resolve the RPCs.

## Required before calling this path complete

1. Locate the authoritative SQL definitions or add reviewed migrations defining both RPCs.
2. Breakdown RPC must derive amount only from the immutable labour bill and valid cancellation-fee ledger; enforce booking ownership/state and reject missing or conflicting snapshots.
3. Settlement RPC must be service-role-only, lock the booking and relevant ledger rows, validate exact order/payment IDs, INR amount and captured evidence, be idempotent for the same payment, reject a different payment, and atomically write payment evidence, booking state, commission/payout and cancellation-fee ledger.
4. Revoke execution from PUBLIC/anon/authenticated and grant only to service_role; pin a safe search_path.
5. Add migration dependency/ACL tests and runtime DB tests for duplicate webhook, concurrent verify/webhook, wrong amount, wrong order, replay, rollback and payout reconciliation.

## Manual payment

The legacy `srk_admin_record_manual_payment(uuid,text,text,text)` explicitly rejects `selected_category IS NOT NULL`. Keep this guard. A separate Main-Admin-authorized manual settlement RPC for new Catalogue bookings remains unimplemented/unverified.

## Safety boundary

No Production Database changes, migration application, deployment, or expense were made.
