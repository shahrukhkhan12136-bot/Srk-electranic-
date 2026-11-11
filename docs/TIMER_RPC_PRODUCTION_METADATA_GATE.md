# Timer RPC implementation gate — production metadata review

Date: 2026-11-11
Branch: `feature/production-push-notifications`

This is a read-only metadata review of the current Production schema and function catalog. No database object or row was changed. It is a safety gate for writing the timer RPC migration; it is not the RPC implementation.

## Verified Production facts

### Booking and electrician identity

- `service_bookings.id` is UUID.
- `service_bookings.customer_user_id` is nullable UUID.
- `service_bookings.assigned_electrician_id` is nullable UUID and references the electrician profile identity used by the booking flow.
- `electrician_profiles.id` is UUID.
- `electrician_profiles.user_id` and `auth_user_id` are nullable UUID identity links.
- `electrician_profiles.active` is boolean, default false.
- `electrician_profiles.verification_status` is text, default `pending`.
- `service_bookings.status` is text, default `new`.
- `service_bookings.work_started_at` is a legacy timestamp; it must not be treated as the new customer-approved timer's authoritative start.
- Current legacy payment/quote columns remain present, including NOT NULL `payment_method` default `Cash`, `quoted_amount`, `quote_status`, `service_charge`, and `materials_amount`. Preserve historical data while cutover is developed.

### Existing Admin helper and legacy work-status function

- `public.is_srk_admin()` exists, is SECURITY DEFINER, and checks `public.srk_admin_users.user_id = auth.uid()`.
- Its current function configuration is `search_path = pg_catalog, public, auth, pg_temp`. A new SECURITY DEFINER RPC must not inherit this configuration pattern: use an empty search path and schema-qualify every object.
- `public.srk_update_booking_work_status(uuid,text)` exists as SECURITY DEFINER and is executable by authenticated users. Its callers and side effects must be audited before replacing or revoking it.
- Legacy quote functions `srk_submit_booking_quote` and `srk_customer_respond_booking_quote` also remain SECURITY DEFINER and executable by authenticated users. Do not revoke until all UI/API callers have been replaced and regression-tested.

## RPC implementation invariants

1. Resolve identity only through `auth.uid()`; reject NULL.
2. Lock the booking row with `FOR UPDATE` before state validation and mutation.
3. Electrician must match `assigned_electrician_id`, be active, be approved, and be linked by `user_id` OR `auth_user_id` to the caller.
4. Customer must match `customer_user_id`; only that customer can approve/reject timer decisions.
5. Arrival must be recorded independently before the start request. Do not infer arrival from booking status or legacy `work_started_at`.
6. Start and stop effective timestamps must be generated once with database `clock_timestamp()`; never accept client timestamps.
7. Every request has a bounded non-empty idempotency key. Same key returns the original decision; a new key cannot bypass the state machine.
8. Stop approval must atomically finalize the timer, calculate billable duration using CEIL, create exactly one labour-only final bill, link it to the booking, and finalize the decision.
9. Reject duplicate/stale/wrong-booking decisions and all unauthorized actor combinations.
10. SECURITY DEFINER functions use `SET search_path = ''`, schema-qualified references, revoked PUBLIC/anon EXECUTE, and least-privilege grants. Authorization remains inside every RPC.
11. Browser roles cannot directly mutate timer/bill columns or directly write decision/bill ledgers. Add explicit guards against privileged generic service-role update paths; RPC-only policy must be enforced at the database boundary.
12. Legacy work-status/quote RPCs and generic Admin update routes must be retired only after the full caller and trigger audit plus coordinated UI/API migration.

## Critical unresolved checks before executable RPC SQL

- Retrieve and review the complete `srk_update_booking_work_status` function body and all dependent triggers/functions.
- Confirm the exact booking acceptance status and any assignment/offer transition rules; do not assume `assigned` or `confirmed` alone proves acceptance.
- Confirm all FK definitions for `assigned_electrician_id`, `customer_user_id`, and electrician identity links from the authoritative catalog.
- Review trigger side effects on `service_bookings` UPDATE, especially status history, payable/commission, job-offer cancellation, and audit triggers. Timer-only updates must not accidentally invoke legacy quote/payment financial behavior.
- Inspect table owners, grants, RLS policies, and SECURITY DEFINER function ownership for the new migration's intended owner.
- Build synthetic auth identities and profile/booking fixtures in the isolated PostgreSQL harness; test actual RPC calls as authenticated identities, not only as postgres/superuser.
- Add race tests using two concurrent sessions for duplicate start requests, stop request vs approval, duplicate stop approval, and competing decisions.
- Add explicit immutable-ledger guards and direct-update denial tests before describing timer decisions/final bills as immutable.

## Validation status

- Metadata queries were read-only against Production project `gnqhoaqatmoiwwhgzkgm`.
- No customer records were selected.
- No SQL DDL, DML, migration, or function call that mutates data was run.
- No shared TEST or Production database was changed.
- No timer RPC is implemented by this document.
- No Production deployment was made.

The next safe implementation step is a full read-only audit of the legacy work-status function and its trigger graph, followed by a new additive RPC migration and authenticated-identity integration tests in a disposable, representative database.