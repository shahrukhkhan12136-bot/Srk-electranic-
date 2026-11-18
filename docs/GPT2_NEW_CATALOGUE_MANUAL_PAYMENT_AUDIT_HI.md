# GPT-2 — New Catalogue Manual Payment Audit (UPI / Bank / Cash)

**Date:** 18 November 2026  
**Scope:** Source-only audit and hardening. No database execution, migration application, or deployment.

## Findings

### Existing legacy Admin manual-payment RPC

`srk_admin_record_manual_payment(uuid,text,text,text)` in `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` supports `cash`, `upi`, and `bank_transfer`, validates a receipt/reference, locks the booking, records evidence, updates payment state, and reconciles payout. It explicitly rejects every booking with `selected_category IS NOT NULL`. Do not remove this guard or route new Catalogue bookings through this legacy RPC.

### New Catalogue Admin cash RPC

`srk_admin_record_new_booking_cash_payment(uuid,text,text)` in `20261114280000_cancellation_fee_carry_forward_and_accounting.sql` is a separate Main-Admin-only cash path. It locks the booking, requires completed/assigned booking and immutable labour bill, records cash evidence before marking paid, and settles reserved cancellation-fee items with idempotent ledger keys.

Static review found its state gate rejected paid/refunded but did not explicitly require the allow-list `unpaid,pending`, nor reject all existing payment evidence. Added source-only migration:

`20261118130000_harden_catalogue_admin_cash_settlement.sql`

It now requires:
- `selected_category IS NOT NULL`;
- payment status exactly `unpaid` or `pending` (NULL rejected);
- no existing `payment_verified_at`, non-zero `amount_paid`, or Razorpay payment ID;
- same Main Admin authorization and existing cash evidence / ledger behaviour.

The migration uses `CREATE OR REPLACE FUNCTION` and preserves the RPC's authenticated execute grant with internal Main Admin enforcement.

### UPI / bank transfer for new Catalogue bookings

No dedicated new-Catalogue UPI or bank-transfer settlement RPC was found in the inspected migrations/source search. The legacy RPC expressly rejects new Catalogue bookings, while the new Catalogue RPC only accepts cash. Therefore new-Catalogue manual UPI/bank settlement is **not implemented or proven** by this audit.

Do not simply widen the cash RPC's method check: UPI/Bank settlement needs a separately defined Admin evidence contract (e.g. verified UTR/reference, amount, method, duplicate-reference handling, and who confirms receipt), plus its own atomic ledger/payout handling and tests. Until approved and implemented, keep manual UPI/bank settlement unavailable for new Catalogue bookings; online Razorpay remains its separate path.

## Regression assertions

Added cash-hardening assertions to `tests/new-catalogue-settlement-rpc-contract.test.js`. The test suite has not been executed. No CI pass, SQL parse, migration replay, or runtime DB evidence is claimed.

## Safety boundary

No Production Database changes, migrations applied, deployment, paid DB branch, or expense.
