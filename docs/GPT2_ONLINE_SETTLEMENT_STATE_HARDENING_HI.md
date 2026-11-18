# GPT-2 — Online Settlement State Hardening

**Date:** 18 November 2026  
**Scope:** Source-only review and migration authoring. No database execution or deployment.

## Finding

The existing `srk_service_role_record_online_booking_payment` RPC in `20261114280000_cancellation_fee_carry_forward_and_accounting.sql` checked for refunded/paid states, but it did not require the unpaid/pending allow-list for all other states. It also returned an idempotent success for the same payment ID before checking that the supplied order ID matched the booking's stored order ID.

That meant an unexpected non-paid state could proceed, and a same-payment replay carrying a different order ID could be acknowledged as already processed.

## Source-only correction

Added `supabase/migrations/20261118120000_harden_online_payment_settlement_state.sql` using `CREATE OR REPLACE FUNCTION`:

1. Requires `selected_category IS NOT NULL` so this service-role settlement endpoint is explicitly limited to new Catalogue bookings.
2. Checks the exact stored Razorpay order ID before duplicate-payment replay handling.
3. Allows new settlement only when payment status is exactly `unpaid` or `pending`; NULL and all other states are rejected.
4. Rejects unexpected existing payment ID, verification timestamp, or non-zero amount before settlement.
5. Preserves same-order/same-payment idempotency and service-role-only grants.
6. Leaves the existing payout trigger and payout calculation unchanged.

Added assertions to `tests/new-catalogue-settlement-rpc-contract.test.js` for the new guards.

## Remaining

- New Catalogue cash RPC exists. Dedicated new Catalogue UPI/bank-transfer manual settlement is not confirmed; legacy manual RPC blocks new Catalogue bookings. Keep those payment methods unavailable for manual settlement until a separate evidence-bound path is designed.
- Verify online handler and webhook concurrency, duplicate delivery, wrong order/payment, unexpected states, payout-trigger atomicity, cancellation-fee ledger idempotency, and transaction rollback in a real test database.
- Run the complete source test suite and clean migration replay in the approved test environment.

## Status

The migration and test assertions are committed to the feature branch, but tests have not been executed and no runtime/database result is claimed. No Production Database changes, migrations applied, deployment, paid DB branch, or expense.
