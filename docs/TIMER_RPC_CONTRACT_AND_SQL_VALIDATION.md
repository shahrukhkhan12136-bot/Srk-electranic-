# Timer RPC Contract and SQL Validation Checklist

Status: implementation contract, not executable RPC code.  
Branch: `feature/production-push-notifications`  
Date: 2026-11-11

This contract is the required behavior for the next SQL implementation. It intentionally does not create or alter database objects.

## Shared security contract

- Resolve the caller only from `auth.uid()`; reject NULL.
- Never accept a user ID, profile ID, role, Admin flag, start/stop timestamp, duration, billable minutes, hourly rate, or amount from the browser as authoritative.
- Resolve the booking with `SELECT ... FOR UPDATE` before checking or changing its state. This serializes competing timer transitions for the same booking.
- Customer authorization: `service_bookings.customer_user_id = auth.uid()`.
- Electrician authorization: an approved, active profile linked by `user_id = auth.uid()` OR `auth_user_id = auth.uid()`, and `service_bookings.assigned_electrician_id = electrician_profiles.id`.
- Admin authorization: call the established `public.is_srk_admin()` helper inside the function. Do not trust a client-supplied role.
- For any SECURITY DEFINER function: use `SET search_path = ''`, schema-qualify every object, revoke EXECUTE from PUBLIC/anon, and grant only to the minimum required role. The function must still perform its own identity and ownership checks.
- Use `clock_timestamp()` once per committed decision and store that exact database timestamp as the effective timestamp. Do not use client time.

## State transition contract

| Current state | Action | Actor | Result |
|---|---|---|---|
| not_requested | request start | assigned electrician | start_pending + one pending start decision |
| start_pending | approve start | booking customer | running + authoritative timer_started_at |
| start_pending | reject start | booking customer | not_requested + rejected decision |
| running | request stop | assigned electrician | stop_pending; timer continues |
| stop_pending | reject stop | booking customer | running; timer continues |
| stop_pending | approve stop | booking customer | stopped + authoritative timer_stopped_at + final labour bill in same transaction |
| stopped | any further start/stop | either party | reject; no second bill |

Arrival is a separate event and must be recorded before a start request. Arrival is not billable time.

Every request must carry a bounded, non-empty idempotency key. Same booking/action/key returns the original decision/request; it must not create a second pending request. Different keys must not bypass the booking state machine. Concurrent operations serialize on the booking row.

## Critical correction to elapsed-time calculation

The current foundation migration checks `elapsed_seconds` against `floor(extract(epoch ...))`. That silently discards fractional seconds. For example, 60.1 seconds becomes 60 seconds and incorrectly bills one minute, although the approved rule bills 1m01s as two whole minutes.

The RPC and final-bill constraint must calculate elapsed whole seconds with ceiling, not floor. This correction is now present in Feature Branch source only:

```sql
v_elapsed_seconds := greatest(
  0,
  ceil(extract(epoch FROM (v_stopped_at - v_started_at)))::bigint
);
v_billable_minutes := case
  when v_elapsed_seconds = 0 then 0
  else (v_elapsed_seconds + 59) / 60
end;
v_labour_amount := round(
  (v_hourly_rate::numeric * v_billable_minutes::numeric) / 60,
  2
);
```

The migration's final-bill elapsed check now uses CEIL. The migration has not been applied to any database. The rollback-only arithmetic test was executed by GitHub Actions on PostgreSQL 16 and passed (run 43007068617, commit 42d4316). This proves the arithmetic test script executes successfully; it does not prove the foundation migration applies cleanly or that the RPC/state machine is implemented.

## Bill creation transaction

On customer stop approval, in one database transaction:

1. Lock and re-check booking and pending stop decision.
2. Verify the caller is the booking customer and the timer is stop_pending.
3. Capture one database timestamp for stop approval/effective stop.
4. Compute elapsed seconds, ceiling billable minutes and labour amount from the booking's saved category/rate snapshot.
5. Insert exactly one labour-only final bill. Do not include material rows in labour.
6. Link the booking to the final bill and store the timer's stopped state and computed values.
7. Finalize the timer decision with the same actor/time/effective timestamp.
8. Commit; any failure rolls back all state changes.

A unique bill per booking and booking-row lock must prevent duplicate bill generation. Repeated approval with the same decision/request must return the existing bill, not create another.

## Material approval contract

- Material line creation must validate description, quantity, unit price, supplier, receipt reference, and server-calculated line total.
- Do not accept a client-supplied line total without recomputing and comparing it.
- Keep materials separate from labour and commission calculations.
- Approval must identify a specific bill/revision and be performed by the booking customer.
- Once a revision is approved, its lines and approval evidence are immutable. Changes require a new revision and fresh customer approval.
- If the customer buys materials independently, do not add an electrician-supplied materials charge for those items.

## Cancellation contract

- Cancellation request records requester identity and role from the authenticated session; role is derived by checking customer ownership or assigned electrician linkage.
- Only Admin can decide.
- Fee is exactly ₹99 only when requester is the customer, an arrival timestamp was already recorded, and Admin approves.
- No arrival or any other requester/decision combination means ₹0.
- Fee is not charged at request time. Preserve payment/refund controls for already-paid historical bookings.

## Immutability contract

The current foundation tables are RLS-protected from browser roles, but service_role still has table-level ALL privileges. RPC authorization alone is not sufficient to describe these rows as immutable.

Before production use, add database guards and a controlled mutation model:
- Timer decision: allow only pending -> approved/rejected once; reject edits/deletes after finalization. Ensure only the intended RPC owner can perform the pending-to-final transition.
- Final bill: reject UPDATE/DELETE. Corrections require a separate audited adjustment record; do not overwrite the bill.
- Material items: allow controlled draft creation before approval; reject mutation/deletion after the revision is approved.
- Material approval: reject UPDATE/DELETE.
- Cancellation: allow one pending -> final Admin decision; reject edits/deletes after decision.
- Protect `service_bookings` timer and bill columns from direct client updates; all state changes must flow through RPCs.

## Migration defects to fix before any application

1. The final-bill elapsed check now uses `ceil` in Feature Branch source; it has not been executed in a database.
2. Named booking constraints now use catalog-checked guards. This is a limited rerun safeguard, not proof that an arbitrarily partially applied or schema-drifted migration can be safely replayed.
3. The final-bill FK now uses a catalog existence guard. A clean apply, second-run, and partial-failure recovery test are still required.
4. The circular relationship (`service_bookings.final_bill_id` -> `srk_final_bills.id` and bill -> booking) requires an explicit transaction test, including rollback and unique booking behavior.
5. Table comments call the decision ledger append-only, but the current schema permits privileged updates/deletes. Do not claim append-only until database guards exist.
6. RLS enabled with no authenticated policies means browser clients cannot directly read these rows; implement carefully scoped read RPCs/policies before customer, electrician and Admin screens depend on them.

## Arithmetic regression test — executed

A standalone, rollback-only PostgreSQL test script is available at `supabase/tests/timer_billing_math.sql`. It covers 0s, whole and fractional minute boundaries, 8 hours, all four category rates, paise rounding, and the no-minimum-charge rule. GitHub Actions run `43007068617` completed successfully on PostgreSQL 16 at commit `42d4316ba95f0dbb0423231eae9643507429d0b9`. The test is arithmetic-only and rolls back; it does not apply migrations or write to Supabase.

The push-notifications Deno type-check workflow also has a later successful run (`42988409388`, commit `f4d6dfec29de84530114f8e4636600dd1c6850d0`). An earlier run failed at commit `c846804`; the later successful run supersedes that earlier result for the newer source revision.

## Mandatory SQL/API tests

- Caller NULL, wrong customer, unrelated customer, unassigned electrician, electrician linked only by `auth_user_id`, inactive/unapproved electrician, and non-Admin invoking Admin RPC.
- Start request before arrival; repeated request same key; repeated request new key; two concurrent start requests.
- Approve/reject start twice; approve stale request; wrong booking/request ID.
- Stop request while not running; pending stop duration must continue; reject stop then continue; approve stop twice.
- Concurrency: stop request vs customer approval, duplicate approval, competing Admin cancellation decisions.
- Durations: 0s, 1s, 59s, 59.1s, 60s, 60.1s, 61s, 119s, 119.1s, 120s, and 8h.
- All four category rates; final paise rounding; no minimum charge; tampered rate/amount/duration inputs.
- Duplicate final bill prevention and full transaction rollback.
- Material line arithmetic, supplier and receipt validation, approval revision, and mutation after approval.
- Cancellation fee truth table and preservation of historical paid/refunded bookings.
- RLS/direct table access and EXECUTE grants for every new function.

## Status

No timer RPC code is implemented by this document. No TEST or Production database was changed. The existing shared TEST Supabase project is not a representative integration target: its public schema currently contains only `electrician_profiles`, `job_offers`, and `srk_push_subscriptions`, and lacks `service_bookings` plus the booking/payment/history dependencies. Do not apply the migration there blindly. Before integration testing, build a disposable PostgreSQL/Supabase environment from the complete authoritative schema/migration history, with synthetic auth users, customer/electrician profiles, Admin identity, and representative booking/payment rows. Validate clean migration apply, second application, deliberate transaction rollback, circular FK insertion/linking, RLS/grants, and the RPC state machine in that isolated environment. Only then consider a separately approved shared TEST migration.


## Cross-layer compatibility audit (2026-11-11, Feature Branch source)

The current booking and Razorpay handlers were compared against the approved timer-first workflow and the proposed foundation schema. This is a source-code review only; no runtime payment calls or database writes were made.

### Confirmed blockers before timer billing can be enabled

1. `create-booking.js` still defaults a missing `payment_method` to Cash, accepts Cash/Razorpay as a booking-time choice, parses and validates browser-supplied `quoted_amount`, then inserts both fields. This directly conflicts with the approved no-payment-choice/no-quote-at-booking flow. The approved category/rate snapshot is also not yet written.
2. `create-order.js` still requires `status = completed` AND `quote_status = approved`, and calculates payment from `service_charge + materials_amount` cross-checked against `quoted_amount`. It does not require a customer-approved stopped timer or a server-generated final bill.
3. `verify-payment.js` repeats the legacy quote gate and amount calculation. It verifies the Razorpay signature and retrieves captured payment details, but the final amount source remains the legacy quote/material fields.
4. `razorpay-webhook.js` repeats the legacy quote gate and amount calculation, then directly PATCHes `service_bookings` using the service-role REST key. It does not reconcile against `srk_final_bills` or a bill revision, and the shown code does not persist a webhook event ledger/idempotency record.
5. The booking API, order API, verify API, and webhook all use privileged service-role REST access. Once timer/bill columns exist, client-facing APIs must not be allowed to set those protected fields through generic PATCH paths. Payment state transitions should be moved behind narrow transactional database RPCs with server-side authorization and idempotency.
6. `findReusableOrder()` currently compares the Razorpay order amount against `quoted_amount`, while order creation computes `service_charge + materials_amount`. This inconsistency is a legacy reconciliation hazard that must be removed during the final-bill cutover.
7. Existing browser screens contain legacy payment-choice UI and quote-related behavior. A server-only change would leave confusing or unsafe paths visible; customer, electrician, and Admin interfaces must be migrated as one coordinated release.

### Required target payment contract

- Order creation may start only after the booking has a customer-approved stopped timer and a persisted final bill.
- Amount must be derived from the authoritative final-bill total plus only separately approved material revisions. Never accept an amount from browser input or legacy `quoted_amount`.
- Labour commission/payable calculations must use labour-only final-bill amount; material amounts remain separate and are not silently included in electrician labour or commission.
- Webhook handling must verify the provider signature, persist/claim the event idempotently, lock/reconcile the booking and bill, compare order/payment amount and currency, and atomically record payment evidence through a narrow trusted operation.
- The browser verification endpoint may report status but must not be an alternate path that can mark a booking paid outside the same idempotent reconciliation operation.
- Cash confirmation must also require a generated final bill and a separate electrician receipt-confirmation action.

### Safe sequencing decision

Do not edit these live payment handlers in isolation yet. First finish the database contract (timer RPCs, final bill/material revision model, immutable audit evidence, protected booking-column writes, scoped reads, and role/grant design), then implement all payment handlers and all three dashboards together. Until then, the new migration remains unapplied and the existing payment behavior remains legacy behavior; no claim is made that the approved timer-first flow is implemented.


### Dashboard/UI source scan — confirmed legacy surfaces

A source scan of `index.html`, `electrician.html`, and `admin.html` found the following legacy dependencies:

- Customer `index.html`: booking history still selects and displays `payment_method`, `quoted_amount`, `service_charge`, `materials_amount`, and `quote_status`; it renders quote approval/rejection controls and Cash-payment UI gated by quote approval; booking submission still sends `payment_method` and `quoted_amount`; Razorpay create-order and verify-payment endpoints remain wired into the page.
- Electrician `electrician.html`: job cards still display `quoted_amount` as an estimated amount; cash receipt confirmation still displays an amount derived from `quoted_amount`. No approved timer start/stop approval workflow is evidenced by this scan; timer-related text matches in the file are mostly OTP cooldown variables, not the new work timer.
- Admin `admin.html`: booking queries still select `payment_method` and `quoted_amount`; Admin controls can update `status` and `quoted_amount` directly from the browser, and the screen includes payment-status/manual-payment controls. These paths need a reviewed RPC replacement before the new workflow is enabled.

This confirms the cutover is not just a server-handler task. The customer, electrician, and Admin pages all require coordinated changes. The source scan is static inspection, not an end-to-end browser test.
