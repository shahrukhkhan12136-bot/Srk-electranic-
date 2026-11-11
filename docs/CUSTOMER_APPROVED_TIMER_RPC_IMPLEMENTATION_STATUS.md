# Customer-Approved Timer RPC Implementation Status

Date: 2026-11-11  
Branch: `feature/production-push-notifications`  
Status: SQL implementation and isolated PostgreSQL 16 CI tests pass; application cutover is NOT complete.

## Implemented in Feature Branch

### Migration 003 — `202611110003_customer_approved_timer_rpcs.sql`

- One pending start request and one pending stop request per booking, enforced by partial unique index.
- Bounded idempotency keys (8–128 characters, safe character set).
- Idempotency records are bound to the original requester; a different actor cannot replay another user's key.
- Arrival recording by the exact assigned, active, approved electrician profile.
- Arrival and timer actions require an accepted `job_offers` row for the same booking and electrician.
- Electrician start request requires arrival and `timer_state = not_requested`.
- Customer start approval/rejection is restricted to `customer_user_id = auth.uid()`.
- Electrician stop request moves the state to `stop_pending`; it does not stop the timer.
- Customer stop rejection returns the timer to `running`.
- Customer stop approval captures one server timestamp, computes CEIL elapsed seconds and whole billable minutes, calculates labour from the booking's saved hourly-rate snapshot, inserts one labour-only final bill and links it in the same transaction.
- Retries of the same final decision return the existing bill; no second bill is inserted.
- SECURITY DEFINER functions use an empty search_path, fully qualified object names, explicit auth/ownership checks and minimum authenticated EXECUTE grants.

### Migration 004 — `202611110004_scoped_timer_bill_read_rpc.sql`

- Adds `srk_get_booking_timer_bill_details(uuid)`.
- Returns timer state, request/decision history, final labour bill, material revisions and lines, payable snapshots, and cash receipt evidence.
- Access is restricted to the booking customer, the assigned active/approved electrician with accepted-offer evidence, or Admin.
- Workflow tables remain unavailable for direct browser SELECT.

## Test coverage and result

GitHub Actions run:
- Run ID: `43012383376`
- Commit: `a64cc887425cd18c9eb07ce427ef8a945d39dc2b`
- Result: **success**
- PostgreSQL 16 disposable synthetic harness.
- All four migrations applied and replayed successfully.
- Timer lifecycle test passed: arrival, start request, start approval, stop request remains pending, stop approval, bill generation, retry/idempotency, scoped customer/electrician reads, unrelated-user denial and single-bill assertion.
- Existing integrity assertions and arithmetic tests also passed.

The earlier CI failures were corrected:
- First timer test had a PL/pgSQL CASE-expression syntax error; fixed and rerun successfully.
- A subsequent test ran before the scoped-read migration due to workflow ordering; workflow order was corrected and the complete run above passed.

## Explicit limitations — not production-ready

1. The existing booking creation API still inserts directly through service-role REST, accepts legacy payment method and client quote fields, and does not populate the category/rate snapshot. The new timer RPCs correctly reject bookings with no server-saved rate snapshot.
2. The customer UI does not yet collect one of the approved category codes (`helper`, `ordinary`, `skilled`, `master`) and display its 8-hour/hourly rate.
3. Electrician UI still calls `srk_update_booking_work_status`; the legacy function remains executable by authenticated users in Production. It must not be revoked until all callers are migrated and tested.
4. Customer, electrician and Admin dashboards are not yet wired to the new scoped read RPC or timer decision RPCs.
5. Materials revision submission/decision RPCs, booking cancellation RPCs, payable snapshot creation, Razorpay order binding/reconciliation, webhook ledger processing and cash receipt RPC are not yet implemented.
6. No production-equivalent complete schema/trigger harness exists yet. The current CI harness is intentionally synthetic and does not prove Production compatibility.
7. No migration has been applied to shared TEST or Production; no live application deployment occurred.

## Next required sequence

1. Add a server-side booking creation/rate-snapshot RPC and change the booking API + customer UI together. Remove payment method and client quote/amount acceptance at booking creation while preserving current offer-broadcast behavior.
2. Add scoped timer decision UI for customer and arrival/start/stop UI for electrician.
3. Migrate Admin booking updates so timer/rate/bill/payment fields cannot be changed through generic updates.
4. Add material revision submission/approval and payable snapshot creation/eligibility.
5. Coordinate payment API, Razorpay webhook, cash receipt and legacy commission/payout transition.
6. Audit all source callers, then retire the legacy work-status/quote/payment paths.
7. Build a complete Production-equivalent isolated schema/trigger harness and run end-to-end tests.
8. Only after all gates pass, request separate explicit approval for shared TEST writes and later Production deployment.

No shared database or deployed website was changed by this work.
