# GPT-2 Corrected Audit — New Catalogue Settlement RPCs

**Date:** 18 November 2026  
**Branch:** \`feat/ai-rate-management-foundation-20261118\`  
**Scope:** Static source inspection only. No SQL execution, DB connection, migration application, or deployment.

## Correction to the previous audit

The earlier note \`docs/GPT2_NEW_CATALOGUE_ONLINE_SETTLEMENT_RPC_GAP_HI.md\` incorrectly stated that the two online settlement RPC definitions were not found. They are defined in:

\`supabase/migrations/20261114280000_cancellation_fee_carry_forward_and_accounting.sql\`

The earlier "missing definitions" conclusion is withdrawn.

## Confirmed online RPCs

### \`srk_service_role_get_booking_payment_breakdown(uuid)\`

- \`SECURITY DEFINER\`, empty \`search_path\`.
- Explicitly checks JWT role equals \`service_role\`.
- Requires completed booking and online/Razorpay payment method.
- Reads the immutable labour bill and reserved cancellation-fee items.
- Returns labour, fee and total amounts in paise.
- Execution is revoked from PUBLIC/anon/authenticated and granted to service_role.

### \`srk_service_role_record_online_booking_payment(uuid,text,text,bigint)\`

- \`SECURITY DEFINER\`, empty \`search_path\`.
- Explicitly checks JWT role equals \`service_role\`.
- Locks the booking row with \`FOR UPDATE\`.
- Validates provider order/payment ID formats, exact amount, online payment method and exact stored order ID.
- Same payment ID replay after paid returns \`already_processed=true\`; a different payment is rejected.
- Updates booking payment fields and settles cancellation-fee ledger items with idempotency keys.
- Execution is revoked from PUBLIC/anon/authenticated and granted to service_role.

## Confirmed Admin cash settlement

The same migration defines \`srk_admin_record_new_booking_cash_payment(uuid,text,text)\`:

- Requires authenticated Main Admin via \`is_srk_admin()\`.
- Locks the booking row.
- Requires completed, assigned booking and cash payment method.
- Uses immutable labour bill plus reserved cancellation fees.
- Inserts manual cash evidence before updating booking to paid.
- Posts cancellation-fee recovery entries to SRK ledger and electrician wallet with idempotency keys.
- Execution is revoked from PUBLIC/anon and granted to authenticated; the function itself enforces Main Admin.

Therefore, new Catalogue cash settlement already exists. Do not duplicate it.

## Remaining review items (not yet runtime-proven)

1. Online settlement currently rejects \`paid\` and \`refunded\`, but source review does not show an explicit allow-list requiring the prior state to be exactly \`pending\` or \`unpaid\`. Review whether unexpected states should be rejected.
2. Review whether settlement should explicitly require \`selected_category IS NOT NULL\` and validate any existing \`razorpay_payment_id\` / \`amount_paid\` before the update, rather than relying on callers and current state.
3. The Admin cash RPC covers cash only. New Catalogue Admin-recorded UPI/bank-transfer settlement is not confirmed; the legacy UPI/bank RPC rejects new Catalogue bookings. Keep those methods blocked until a dedicated evidence-bound path is designed and tested.
4. Validate payout trigger ordering, cancellation-fee settlement, replay/concurrency and rollback against a real test database.
5. Inspect full dependency history and grants on a clean migration replay; static source presence is not proof that a deployed database has applied the migration.

## Static regression coverage added

\`tests/new-catalogue-settlement-rpc-contract.test.js\` checks:
- service-role-only online RPC grants and immutable bill source;
- booking lock, exact order/amount and same-payment idempotency;
- Main Admin-only cash settlement and evidence-before-booking-update ordering;
- payout based on immutable labour bill, excluding cancellation fees from electrician earnings.

The test file has been added but has **not** been executed. No CI or runtime DB result is claimed.

## Safety boundary

No Production Database change, migration application, deployment, paid DB branch, or expense was made.
