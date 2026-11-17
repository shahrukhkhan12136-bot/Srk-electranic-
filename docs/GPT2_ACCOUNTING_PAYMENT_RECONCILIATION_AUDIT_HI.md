# GPT-2 Accounting-to-Payment Reconciliation Review — 17 November 2026

## Reviewed source snapshot

Branch: `chore/pr8-replay-audit-20261116-v2`  
Reviewed HEAD: `7ca38be9db682c2bac71e2841b50bb0e24c087fd`

- `supabase/migrations/20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`
  - SHA: `68189051090a51bef26a98997caf103b62ed070c`
- `supabase/tests/database/admin_labour_bill_payment_accounting_bridge.test.sql`
  - SHA: `7db3d4e5bec75100acc6f892bbcdfe7f29f0f3b7`
  - Declared `plan(19)`
- `supabase/tests/database/electrician_payout_reconciliation.test.sql`
  - SHA: `ad3bdeb8ce00596b3e588f6df47fdfea35794119`
  - Declared `plan(52)`
- Online settlement migration:
  - `supabase/migrations/20261114280000_cancellation_fee_carry_forward_and_accounting.sql`
  - SHA: `e8554d1b8c85810b8dc32eb9428697d9e29dc53a`

## What the accounting reconciliation function checks

Static inspection of `srk_admin_get_booking_accounting_reconciliation(uuid)` shows that it produces a read-only per-booking reconciliation, including:

- verified customer collection and refund/net collection;
- immutable labour bill for new-category bookings, with materials excluded from that labour-only path;
- expected labour commission and electrician payable;
- payout row existence, electrician assignment, and gross/materials/commission/payable amounts;
- booking commission versus payout-ledger commission parity;
- cancellation-fee allocation, settled/reversed fee state, fee-ledger net balance, and source debt still open/reserved;
- posted wallet credit/debit totals and a dedicated cash cancellation-fee wallet-refund comparison;
- refund evidence and pending/final refund consistency;
- explicit exception strings and an `is_reconciled` boolean.

The source has a useful distinction between customer collection (`amount_paid`) and electrician payable (payout ledger). Cancellation-fee collection is not treated as electrician labour earnings.

## Static finding: aggregate reports can silently omit missing payout-ledger evidence

The same migration defines `srk_admin_commission_report()` and `srk_get_my_earnings()`.

Both use a LEFT JOIN from bookings to `srk_electrician_payouts`, then `coalesce(...,0)` for commission/payable values. The Admin report's `paid_completed` CTE selects completed, paid bookings without requiring a payout row. The electrician earnings function likewise returns a completed/paid booking even if its payout row is absent, with zero commission/payable due to the LEFT JOIN and COALESCE.

Consequences:
- a completed/paid booking with missing payout evidence can appear as zero electrician payable/commission in the aggregate report rather than being clearly marked as a reconciliation exception;
- the per-booking reconciliation function does flag `MISSING_PAYOUT_ROW` for completed, verified-paid bookings with an assigned electrician, but the aggregate report and earnings response do not surface that exception.

This is a **static reporting-completeness gap**, not proof that a missing payout row currently exists in production or that the payout trigger failed. Normal trigger operation is intended to create the payout row. The issue is that the aggregate report does not fail closed or expose missing-ledger status if that invariant is broken.

## Recommended follow-up

1. In an isolated database test, create a completed, verified-paid booking with an assigned electrician and deliberately absent payout row (or invoke the report against a controlled fixture before payout creation).
2. Confirm the per-booking reconciliation reports `MISSING_PAYOUT_ROW`.
3. Confirm whether Admin commission report and electrician earnings expose a missing-ledger exception rather than silently returning zero payout amounts.
4. Consider adding explicit missing-payout counts/booking IDs or excluding invalid rows while marking the report incomplete. Do not simply coalesce a missing payout row to zero without a warning.
5. Add a regression assertion for the Admin report and electrician earnings RPC.

## Test coverage assessment

- The 19-assertion accounting bridge test checks function definitions/source contracts for Cash settlement, immutable labour bill, receipt, reconciliation, report and earnings. It does not create a real new-category online settlement fixture or execute the reconciliation flow.
- The 52-assertion payout reconciliation test includes DML rollback fixtures, but those fixtures use the legacy approved-quote path and do not prove the new-category online payment → cancellation-fee ledger → accounting reconciliation → payout report path end-to-end.
- No test was executed in this review. The declared plans and SQL source were inspected only.

## Limits and action boundary

Static source review only. No source SQL or test was edited. No SQL, PostgreSQL query, migration replay, pgTAP, Node test, provider API, CI, deployment, merge, cherry-pick, or production setting was run or changed.

GPT-2 checklist remains **27/39 = 69%**. This review records a reporting gap and a test requirement; it is not runtime acceptance evidence.


## Recheck — 17 November 2026, current audit branch

- Current Admin report migration `20261117180000_reconcile_admin_commission_report_to_payout_ledger.sql` SHA `e3eaa21836628c459e757461a5598aa51ea8b66c` confirms customer collections remain separately visible in `total_collected`; commission/payable and partner earnings are sourced from payout rows. Partner `paid_completed_jobs` uses `count(pc.booking_id)`, so a missing/mismatched payout row is not counted as a payout-backed job.
- Current Electrician earnings migration `20261117190000_reconcile_electrician_earnings_to_payout_ledger.sql` SHA `f12d41362dcb230bfe606aa43e47ba6ee3f6c444` correctly sources commission/payable from the canonical payout ledger, but it still LEFT JOINs the payout table and COALESCEs missing payout values to zero while returning the booking row.
- Therefore the earlier source correction fixes the cancellation-fee earnings formula, but **does not fully close the missing-payout reporting-completeness gap**: Admin aggregate has no explicit missing-ledger count/exception field; Electrician earnings can display zero commission/earning without distinguishing “legitimate zero” from “missing payout row”.
- Safe follow-up is to add an explicit reconciliation exception signal/count without changing the existing UI return contract until the caller/owner approves the exact display contract; alternatively use the existing per-booking Admin reconciliation RPC as the authoritative exception surface. No new UI feature or RPC return-shape change was made in this pass.
- Static source evidence only. No fixture execution, PostgreSQL/pgTAP, Node tests, database query, provider action, deployment or merge. Official GPT-2 progress remains 27/39 = 69%; Runtime Acceptance 60/60 Pending.


## Follow-up — Missing payout exception path and regression contract (17 Nov 2026)

- Rechecked the current Main Admin per-booking RPC source in `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`: for a completed booking with verified payment and an assigned electrician, no payout row appends `MISSING_PAYOUT_ROW` to `exceptions`.
- Rechecked `admin.html`: the existing read-only Booking Accounting Reconciliation panel renders the RPC's exception list and separately states when no payout record exists. Thus the missing-row case is already available through the per-booking Admin reconciliation surface; the aggregate commission card remains a summary and is not the authoritative exception surface.
- Added one source contract assertion to `supabase/tests/database/accounting_reconciliation_readonly_contract.test.sql`: declared plan and verified `SELECT ok` calls are now both 76; the new assertion checks the exception token and its completed + verified + assigned-electrician guard.
- Final fetched test SHA: `eebcc4523feba1e4af608c9b9b725f5c3f86d783`.
- This is a source-contract addition only. pgTAP was not run, so SQL syntax/runtime and the real missing-row fixture are not proven. No UI, RPC return shape, database, CI, deployment or merge changed. Official GPT-2 remains 27/39 = 69%; Runtime Acceptance 60/60 Pending.


## Webhook acknowledgement timing — 17 Nov 2026

- Current `razorpay-webhook.js` awaits claim, downstream lookup/reconciliation, and completion RPC before returning HTTP 200. Each outbound call has a 15-second timeout; the whole handler has no single five-second deadline.
- Razorpay's current webhook guidance says receivers should return within five seconds; late/non-2xx deliveries are retried. This source shape therefore carries an acknowledgement-latency/redelivery risk even though event claims, fencing tokens and business-level idempotency protect against duplicate effects.
- Required architectural resolution is durable asynchronous processing: commit the verified event, acknowledge promptly, then process via a durable worker/outbox. Returning 2xx before durable receipt or relying on unawaited serverless work is not safe. No new queue/worker or architecture change made without owner approval.
- Refund executor recheck: stable stored receipt plus `X-Refund-Idempotency` and identical request payload are used on retry; network timeout is explicitly treated as ambiguous and does not create a fresh refund key.
- Static source review only; no tests or provider/DB calls.
