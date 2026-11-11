# Isolated Booking & Timer Database Test Environment

Status: discovery and safety gate only — no database was created or changed.
Branch: feature/production-push-notifications
Date: 2026-11-11

## Findings verified by read-only Supabase metadata

### Production project (schema metadata only)
- Project ref: gnqhoaqatmoiwwhgzkgm
- Public schema currently exposes 27 tables.
- Production migration history contains 68 recorded migration entries.
- public.service_bookings exists and has downstream foreign-key dependants in offers, refunds, payment-order locks, status history, Route transfers, payouts, manual payment/refund records, and complaints.
- Related identity and workflow tables include electrician_profiles, electrician_applications, job_offers, and srk_admin_users.
- This inspection read schema metadata only; no customer rows or credentials were queried.

### Existing TEST project
- Project ref: dvzmarekhstaubyuoeeh
- Public schema has only three tables: electrician_profiles, job_offers, and srk_push_subscriptions.
- Its recorded migrations are a small push-notification test sequence, not the production booking/payment migration history.
- It is therefore not a safe or representative target for the timer/billing migration.

### Feature Branch source coverage
- supabase/migrations/ currently contains 19 tracked SQL files.
- Production database records 68 migration versions.
- The repository does not currently contain a complete, self-sufficient migration history from an empty Supabase database. In addition, the repository has no supabase/config.toml or checked-in canonical baseline schema file.
- Consequently, the full Production schema cannot be reliably reconstructed by applying only the currently tracked migration files to an empty PostgreSQL database. Do not manufacture missing baseline DDL from table names or partial metadata.

## Decision: do not apply the timer foundation yet

Do not apply 202611110001_timer_billing_materials_foundation.sql to either shared project:
- not to Production, because the user has not approved a Production schema change;
- not to the existing TEST project, because its schema lacks the booking/payment dependency graph;
- not to a disposable database until a complete, reviewed baseline is available.

No Supabase project, branch database, or paid compute was created. No migration was applied. No deployment was performed.

## Required isolated integration environment

Preferred route: a local, disposable PostgreSQL 16/Supabase-compatible environment in CI, built from a complete schema-only snapshot (no customer data) and synthetic identities.

The schema source must be one of:
1. a reviewed, schema-only export from the current Production database, excluding all table data, secrets, auth identities, and storage objects; or
2. a complete, ordered migration history that reproduces the current schema from an empty database.

The export route must be generated read-only and reviewed before it is added to the repository. It must not contain auth.users rows, phone numbers, emails, payment references, API keys, JWT secrets, service-role keys, webhook payloads, or real booking/customer/electrician data. Replace auth users and all test records with deterministic synthetic fixtures.

## CI environment acceptance gates

1. Pin PostgreSQL 16 and required extensions/functions used by the schema.
2. Create only the minimum Supabase-compatible roles/schemas needed for the tests (anon, authenticated, service_role, auth, and an auth.uid() test shim); document any behavior not identical to hosted Supabase.
3. Load the reviewed baseline schema and confirm required dependencies exist before applying the timer migration.
4. Apply the timer migration once from a clean state; fail fast on any SQL error.
5. Apply it a second time only if the migration is explicitly designed and proven replay-safe; otherwise test migration-runner single-application behavior and separately test recovery from a deliberately aborted transaction.
6. Exercise the circular bill/booking foreign-key lifecycle: create booking, create bill, link bill, rollback at each failure point, and prove no orphan/duplicate bill remains.
7. Seed synthetic customer, assigned approved electrician, unrelated electrician/customer, and Admin identities. Test both electrician link columns (user_id and auth_user_id).
8. Verify RLS, grants, SECURITY DEFINER ownership/search_path, and unauthorized direct writes.
9. Add timer RPC state-machine and concurrency tests, final-bill uniqueness, material revision approval/immutability, cancellation fee truth table, cash confirmation, and payment-after-final-bill gating.
10. Keep this integration workflow separate from the already-passing arithmetic-only test. A passing arithmetic test is not evidence that migrations or RPCs integrate correctly.

## Known implementation issues to resolve before integration tests can pass

- Timer RPCs and scoped read RPCs are not yet implemented.
- Database-level append-only/immutability guards are not yet implemented.
- Direct client updates to timer/final-bill booking columns are not yet protected by a complete mutation model.
- The circular FK has not been tested with actual transaction scenarios.
- Legacy quote/payment flows and financial triggers still require the planned compatibility/cutover audit.
- The existing timer migration's catalog guards do not prove safe recovery from arbitrary partial or incompatible schema states.

## Current verified test status

- PostgreSQL 16 arithmetic-only GitHub Actions workflow passed at commit 42d4316ba95f0dbb0423231eae9643507429d0b9 (run 43007068617).
- That workflow runs the rollback-only math test, not the migration or application integration suite.
- No integration test environment exists yet.

## Next safe step

Obtain and review a schema-only baseline snapshot (or restore the complete missing migration history), then build the disposable CI database. Do not use a paid Supabase branch or create a new hosted project unless its cost is disclosed and the user explicitly approves it.

## Additional read-only dependency inventory (Production metadata)

A second catalog-only query checked foreign keys, triggers, and RLS policies around the booking workflow. It did not read booking rows or modify the database.

### Booking foreign-key graph
- `job_offers.booking_id` -> `service_bookings.id` (ON DELETE CASCADE).
- `service_booking_status_history.booking_id` -> `service_bookings.id` (ON DELETE CASCADE).
- `service_bookings.customer_user_id` -> `auth.users.id` (ON DELETE SET NULL).
- Complaint, electrician payout, manual payment, manual refund, Razorpay refund, and Route transfer records reference bookings with ON DELETE RESTRICT.
- Payment-order locks reference bookings with ON DELETE CASCADE.

Implication: integration tests must prove booking deletion behavior does not erase financial/audit evidence unexpectedly. Financial and complaint references intentionally restrict deletion; the test harness must cover those restrictions. Cascading history/offers and payment-order locks need explicit retention-policy review before any future schema redesign.

### Existing booking triggers
Current Production metadata reports these trigger functions on `service_bookings`:
- `guard_new_booking()` BEFORE INSERT.
- `broadcast_booking_job()` AFTER INSERT.
- `srk_capture_admin_audit_event()` AFTER INSERT/UPDATE/DELETE.
- `srk_calculate_booking_commission()` BEFORE INSERT/UPDATE.
- `srk_cancel_booking_job_offers()` AFTER UPDATE.
- `srk_log_service_booking_status()` AFTER INSERT/UPDATE.
- `srk_create_electrician_payable()` AFTER INSERT/UPDATE.

The disposable harness cannot blindly invoke production side-effect functions. It must either load their reviewed definitions and stub external integrations safely, or explicitly disable/replace only external side-effect triggers in the isolated test copy while retaining the database integrity, audit, commission, and payable logic under test. Record each substitution. Never copy production secrets or send real push notifications.

### Current RLS policy metadata
- `service_bookings`: authenticated SELECT is Admin or owning customer; UPDATE is Admin-only.
- `service_booking_status_history`: Admin SELECT; service_role ALL.
- `electrician_profiles`: authenticated SELECT allows linked user via `auth_user_id` or `user_id`, or Admin; writes are Admin-only.
- `job_offers`: authenticated SELECT allows Admin or the active, approved electrician linked by either `user_id` or `auth_user_id`.
- `srk_admin_users`: user can SELECT their own admin record.

Harness must test the policies under distinct synthetic identities, not only as database owner/superuser (which bypasses RLS). Also verify the SECURITY DEFINER helpers called by policies, especially `is_srk_admin()`, are safely defined and have hardened search paths.

### Further integration hazards
1. Booking creation currently has BEFORE INSERT guards and AFTER INSERT broadcast/audit/status/finance triggers. A new booking-flow implementation must account for all of them; tests should prove a no-payment booking does not accidentally create a payable, commission, or payment order.
2. Legacy commission and electrician-payable triggers fire on both INSERT and UPDATE. Their old quote/payment assumptions and material-inclusive payable basis must be reconciled before enabling the new labour-only final bill flow.
3. Status history is trigger-driven on INSERT/UPDATE; verify it cannot be spoofed or duplicated through direct client writes.
4. A test database loaded as a superuser alone is not sufficient evidence for RLS, grants, or role-scoped RPC behavior.


### Trigger/helper function security metadata (read-only)
Catalog metadata for the seven booking trigger functions and `is_srk_admin()` shows all have an explicit `search_path` setting beginning with `pg_catalog` and placing `pg_temp` last. The following are SECURITY DEFINER: `broadcast_booking_job()`, `is_srk_admin()`, `srk_cancel_booking_job_offers()`, `srk_capture_admin_audit_event()`, `srk_create_electrician_payable()`, and `srk_log_service_booking_status()`. `guard_new_booking()` and `srk_calculate_booking_commission()` are not SECURITY DEFINER.

This is metadata evidence only, not a full function-body security review. The isolated baseline must preserve function owners, grants, SECURITY DEFINER status, and search_path settings. Each SECURITY DEFINER function still needs a code-level review for authorization checks, dynamic SQL, object qualification, and safe external side effects.
