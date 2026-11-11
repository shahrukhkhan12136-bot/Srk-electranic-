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

The RPC must calculate elapsed whole seconds with ceiling, not floor:

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

The final bill constraint in the foundation migration currently encodes the floor behavior. Before applying that migration anywhere, replace that check with a definition consistent with the selected precision rule or store the authoritative elapsed seconds directly and validate it through a trusted trigger/RPC. Add tests for fractional-second boundaries (59.1s, 60.0s, 60.1s, 119.1s) as well as the whole-second cases.

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

1. The final-bill elapsed check uses `floor`, which conflicts with ceiling elapsed seconds for fractional timestamps.
2. The `ADD CONSTRAINT` statements are not guarded for reruns. Use a migration runner that guarantees atomic single application, or add catalog-checked idempotency. Do not rerun a partially applied file blindly.
3. The final-bill FK is also unguarded and needs a clean migration replay test.
4. The circular relationship (`service_bookings.final_bill_id` -> `srk_final_bills.id` and bill -> booking) requires an explicit transaction test, including rollback and unique booking behavior.
5. Table comments call the decision ledger append-only, but the current schema permits privileged updates/deletes. Do not claim append-only until database guards exist.
6. RLS enabled with no authenticated policies means browser clients cannot directly read these rows; implement carefully scoped read RPCs/policies before customer, electrician and Admin screens depend on them.

## Arithmetic regression test added

A standalone, rollback-only PostgreSQL test script is available at `supabase/tests/timer_billing_math.sql`. It covers 0s, whole and fractional minute boundaries, 8 hours, all four category rates, paise rounding, and the no-minimum-charge rule. It has not yet been executed against PostgreSQL; its existence is not evidence of a passing test.

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

No RPC code is implemented by this document. No TEST or Production database was changed. The next implementation must be tested against a disposable full schema before any shared database application.
