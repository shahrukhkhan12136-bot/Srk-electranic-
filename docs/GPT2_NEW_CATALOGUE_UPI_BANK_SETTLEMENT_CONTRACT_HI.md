# GPT-2 — New Catalogue UPI / Bank Transfer Source Contract

**Date:** 18 November 2026  
**Scope:** Source-only implementation proposal landed as a feature-branch migration. No migration was applied and no runtime payment was recorded.

## Implemented in source

Migration: `20261118140000_add_catalogue_admin_manual_digital_settlement.sql`

RPC:
`public.srk_admin_record_new_booking_manual_digital_payment(uuid,text,text,text)`

Parameters:
- `p_booking_id`: completed new-Catalogue booking UUID.
- `p_method`: exactly `upi` or `bank_transfer`.
- `p_reference`: required UPI transaction reference / bank UTR, 4–120 characters.
- `p_note`: optional Admin note, maximum 250 characters.

Controls:
1. Authenticated Main Admin only (`auth.uid()` and `is_srk_admin()`).
2. Locks the booking row; requires completed, assigned, `selected_category IS NOT NULL`, and immutable labour bill.
3. Requires booking's preselected payment method to match the RPC method.
4. Requires payment state exactly `unpaid` or `pending`; rejects NULL and any existing paid evidence, Razorpay order/payment IDs.
5. Acquires a transaction advisory lock on the normalized reference and rejects an already-used manual payment reference.
6. Inserts manual payment evidence before updating booking payment fields. Booking method is stored as `UPI` or `Bank Transfer`, matching the evidence method under the existing case-insensitive method-equality trigger.
7. Uses the existing booking payment trigger chain to calculate commission and create/reconcile the electrician payout from the immutable labour bill.
8. Settles reserved cancellation-fee items as SRK-direct electronic collection entries. Unlike cash collected by the electrician, it does not debit the electrician wallet for a digital payment collected by SRK.
9. The RPC returns the labour, cancellation-fee, and total amounts in paise; it does not expose or change the 85% pre-payment offer contract.

The cash RPC remains separate. The legacy manual-payment RPC remains legacy-only and continues to reject new Catalogue bookings.

## Important evidence limitation

This RPC is an **Admin-recorded verification** workflow. It does not independently query a UPI/bank provider or verify a bank statement. The Admin must inspect the actual received transaction and enter the correct UPI reference / UTR. The reference is audit evidence, not proof by itself.

The advisory lock prevents concurrent duplicate references through this RPC. The source does not yet add a global unique index over all historical manual references; existing duplicate data and other insertion paths must be reviewed before such a constraint is safe.

## Regression test

Added source assertions in `tests/new-catalogue-settlement-rpc-contract.test.js` for method allow-list, Catalogue scope, strict payment state, no prior evidence, reference locking/reuse rejection, SRK fee-ledger credit, no electrician cash-wallet debit, and execute grants.

The tests have **not** been executed. SQL syntax, trigger interaction, transaction rollback, duplicate-reference concurrency, and runtime behaviour remain unverified until the approved test/DB environment is available.

## Deployment boundary

Feature-branch source only. No Production DB changes, migration application, deployment, paid DB branch, or expense.
