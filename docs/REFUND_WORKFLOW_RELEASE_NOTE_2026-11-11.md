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