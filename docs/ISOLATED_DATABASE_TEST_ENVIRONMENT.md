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