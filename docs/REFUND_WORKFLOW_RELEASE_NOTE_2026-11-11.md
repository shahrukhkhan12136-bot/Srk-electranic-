# SRK ELECTRONIC — Refund workflow release note (2026-11-11)

## Implemented on Feature Branch

- Customer dashboard shows a full-refund request button only for bookings with a verified paid amount. The customer submits a reason (20–1,000 characters); the RPC checks ownership and payment evidence, and prevents a duplicate open/completed refund request.
- Customer dashboard shows request status and Admin reply from the refund RPC.
- Admin dashboard has a Refunds shortcut and review section. Admin can move a request to review, approve, or reject it with a written reason.
- Razorpay refunds are initiated only by the serverless `/api/process-refund` endpoint after an authenticated Admin check, verified captured payment lookup, exact captured amount comparison, and database refund preparation. The same persisted idempotency key is used for safe retries. Provider results are reconciled through the service-role-only RPC and Razorpay webhook.
- Legacy manual-payment refunds can be recorded only after a real return of funds and a traceable UTR/receipt reference. Timer Cash refunds require the immutable confirmed Cash receipt, exact receipt/paid amount match, Admin approval, and UTR/reference. The timer Cash refund is recorded in a separate restricted audit table and changes the booking to `refunded`; the existing payout trigger then marks eligible unpaid commission/payout rows as refunded/not-applicable.
- The timer refund preparation RPC checks the immutable payable snapshot and matching captured Razorpay payment ledger. It blocks refunds when an electrician payout has already been paid or requires reconciliation.

## Main Production database status

- The base refund workflow migration `20261111153846_srk_booking_refund_requests_workflow` is already present in Main Production migration history.
- The existing refund request, Razorpay refund, manual payment and manual refund tables are RLS-enabled; `anon` and `authenticated` have no direct table SELECT access. Customer/Admin access is through scoped RPCs; provider reconciliation is service-role-only.
- Main Production does **not yet** have the timer payable snapshot / Cash receipt / Razorpay capture-ledger tables. Therefore migration `20261111160015_timer_snapshot_refund_support.sql` must not be applied by itself. It is sequenced after the timer billing migrations `20261111160000` through `20261111160014`.
- No test bookings, payment rows, refund rows, or synthetic customer data were inserted into Main Production during this work.

## Verification

- GitHub Actions run `43052368202` passed: isolated PostgreSQL fixture load, both refund migrations replayed twice, customer ownership and Admin approval flow, Razorpay ledger reconciliation, legacy manual UTR recording, timer snapshot refund, timer Cash receipt/UTR refund, and Node syntax checks.
- This is an isolated PostgreSQL integration fixture, not a live Supabase Auth/JWT browser test.
- Razorpay Test Mode refund and webhook E2E have not been run; no real refund has been issued.
- Customer/Admin browser E2E has not been run.
- The Feature Branch UI and Netlify function are not live until the consolidated release is approved and deployed.

## Operational rules

1. Never issue a refund solely because a customer pressed the request button. Admin must review and approve.
2. Never enter a manual refund UTR before funds have actually been returned.
3. If Razorpay reports a failed/uncertain refund, reconcile it in the Razorpay Dashboard before taking another action. Do not create a new refund record or change the idempotency key to bypass an unresolved attempt.
4. Do not apply the timer extension migration before its prerequisite timer schema migrations.
5. Full refunds only; partial refunds are not implemented.

## Additional Main Production catalog audit

- Latest recorded Main Production migration is `20261111153846 srk_booking_refund_requests_workflow`; no `20261111160000`–`20261111160015` migrations are recorded.
- The Production catalog currently has none of the timer-specific tables: `srk_booking_timer_decisions`, `srk_final_bills`, `srk_bill_material_items`, `srk_bill_material_approvals`, `srk_booking_payable_snapshots`, `srk_cash_receipts`, `srk_cash_payment_intents`, `srk_razorpay_orders`, `srk_razorpay_payments`, or `srk_timer_cash_refund_entries`. The existing refund, manual payment/refund, payout, booking, electrician profile and offer tables are present.
- Production `service_bookings.payment_status` already permits `refunded`; the booking `status` constraint does not, and the timer cash refund RPC changes only `payment_status`, not booking status. Production payout `payout_status` permits `refunded`.
- Production function signatures match the legacy functions replaced by migration 13, and the existing customer contact RPC wrapper/private implementation match migration 14's intended target. The existing `srk_admin_list_booking_refund_requests(integer)` has no catalog dependencies, so migration 15's return-shape replacement has no dependent database object to cascade.
- Main Production health advisor returned no findings. Security/performance advisor reports pre-existing warnings (including RLS-enabled tables with no policies but no direct client table grants, authenticated-executable SECURITY DEFINER RPCs protected by in-function Admin checks, and unused/missing-FK-index notices). These were not silently altered as part of the refund/timer work.
- Migration 15 was also included in the successful isolated refund workflow run `43052368202`; this still does not substitute for live Supabase JWT/RLS or browser testing.

## Release decision

The catalog audit found no direct table-name collision and confirmed the key payment/refund constraints, but the timer/payment schema has **not** been written to Main Production. The full 16-migration sequence (timer foundation through timer refund extension) remains a controlled production schema change. Keep it unapplied until the final live authentication, browser and Razorpay Test Mode checks are completed and the consolidated release is approved. No production deployment has been made.
