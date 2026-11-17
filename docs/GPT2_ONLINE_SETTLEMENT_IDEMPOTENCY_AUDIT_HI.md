# GPT-2 Online Settlement Idempotency Review — 17 November 2026

## Scope and source snapshot

Static review on branch `chore/pr8-replay-audit-20261116-v2`, HEAD `8f1cacab16184685a357f263155c26475d8fa32d`.

- Migration: `supabase/migrations/20261114280000_cancellation_fee_carry_forward_and_accounting.sql`
  - Blob SHA: `e8554d1b8c85810b8dc32eb9428697d9e29dc53a`
- Customer payment handler: `verify-payment.js`
  - Blob SHA: `d71966ea5371718c1c94a013c026584077817ad4`
- Accounting bridge test: `supabase/tests/database/admin_labour_bill_payment_accounting_bridge.test.sql`
  - Blob SHA: `7db3d4e5bec75100acc6f892bbcdfe7f29f0f3b7`
- Payout reconciliation test: `supabase/tests/database/electrician_payout_reconciliation.test.sql`
  - Blob SHA: `ad3bdeb8ce00596b3e588f6df47fdfea35794119`

## Confirmed static finding: fee-bearing online settlement retry is not idempotent inside the RPC

In `srk_service_role_record_online_booking_payment`, the function:

1. Locks and loads the booking.
2. Reads the immutable labour bill.
3. Sums only cancellation-fee items whose status is currently `reserved`.
4. Compares the supplied captured amount with labour plus that reserved-fee sum.
5. Only after the amount comparison, checks whether the booking is already paid with the same Razorpay payment ID.

On the first successful settlement, the function marks those fee items `settled`. A direct retry using the same payment ID and original captured paise amount therefore sees a smaller reserved-fee sum (normally zero) and can raise `CAPTURED_AMOUNT_DOES_NOT_MATCH_LABOUR_PLUS_CANCELLATION_FEES` before reaching the intended `already_processed` return.

This is a confirmed source-order/idempotency flaw for a fee-bearing booking. It is not a reproduced runtime failure.

## Existing handler mitigation

The customer-facing `verify-payment.js` handler checks the selected-category booking's paid state before calling the settlement RPC. If the stored Razorpay payment ID equals the incoming ID, it returns HTTP 200; a different ID returns HTTP 409. This protects the normal handler retry path, but does not make the service-role RPC itself idempotent for direct retries or other trusted callers.

## Existing test coverage boundary

- `admin_labour_bill_payment_accounting_bridge.test.sql` declares 19 assertions. It checks the Cash settlement RPC, accounting reconciliation, receipt, and earnings/report source contracts. It does not invoke the online settlement RPC with a real booking/fee fixture.
- `electrician_payout_reconciliation.test.sql` declares 52 assertions and contains rollback-oriented DML fixtures, but those fixtures explicitly use the legacy approved-quote path to avoid the Auth-user and immutable new-category labour-bill prerequisites. They do not establish the new-category online payment → fee ledger → payout end-to-end path.
- No dedicated online-settlement RPC retry fixture was found in the database test directory at this branch snapshot.

## Required regression scenarios

In an isolated PostgreSQL/pgTAP environment after the canonical baseline and ordered migration replay are approved:

1. Create a completed new-category booking with an immutable labour bill and at least one reserved cancellation-fee item.
2. Settle online payment once with the correct order ID, payment ID, and full labour-plus-fee amount in paise.
3. Call the RPC directly again with the same booking, order ID, payment ID, and original full amount. Expect successful idempotent response.
4. Verify the retry created no duplicate cancellation-fee ledger entry and did not change settled fee/debt state.
5. Retry with a different payment ID and expect rejection.
6. Include a no-cancellation-fee retry as a control.
7. Verify booking collection, accounting reconciliation, payout gross service, commission and payable remain unchanged after the idempotent retry.

## Safe correction direction (proposal only)

The paid/same-payment-ID branch should be evaluated before comparing the request amount against the *current reserved-fee* sum, while still validating booking identity, order/payment linkage, and the original captured amount against durable evidence. Do not simply return success for a matching ID without checking the durable amount/order evidence. An alternative is to persist an immutable settlement breakdown and use it for retry validation.

No source code or migration was changed in this review. No SQL, PostgreSQL, pgTAP, migration replay, Node tests, provider API, CI, deployment, merge, cherry-pick, or production setting was executed or changed.

GPT-2 checklist remains **27/39 = 69%**. This document records a regression requirement; it does not count as a completed runtime test.
