# SRK ELECTRONIC — Follow-up: amount_paid source and live Main verification

**Audit date:** 25 November 2026  
**Target:** Main Supabase project `gnqhoaqatmoiwwhgzkgm`  
**Scope:** Read-only Git and Main schema/ledger inspection. No database write or migration execution.

## 1. Isolated Git candidate

A candidate file exists on one isolated Git branch:

- Branch: `feat/ai-rate-management-foundation-20261118`
- File: `supabase/migrations/20261109002500_restore_service_bookings_amount_paid_before_financial_grants.sql`
- Blob SHA: `d65b814dfdf85b3ef38dd054f35d9e66b161f8cc`
- Introducing commit: `a1c8ccdb9d8051031816de2b2f392836d80db606`
- Commit message: `Add amount_paid before financial column grant`
- Commit date: 18 November 2026
- Commit signature: unsigned (`verified: false`).

It adds `amount_paid numeric(12,2)` if absent and conditionally adds a check named `service_bookings_amount_paid_nonnegative_check`.

The file is absent from the inspected `main`, mobile integration, admin integration, master customer-workday and master GST refs.

## 2. New read-only Main evidence changes the interpretation

The fresh Main migration ledger has 539 unique version rows. It contains:

- `20261108095928` — `add_actual_paid_amount_commission_and_status_history`
- `20261108184815` — `protect_commission_columns_and_admin_report`

The first of these entries precedes the latter in the actual migration ledger. The ledger exposes only version/name, not the original SQL body.

Live Main schema inspection confirms `service_bookings.amount_paid` exists as nullable `numeric(12,2)`, default NULL. Two related constraints are already present and validated:

- `service_bookings_amount_paid_nonnegative`
- `service_bookings_amount_paid_range` (0 through 10,000,000)

The candidate file's version `20261109002500` is **not present** in the Main migration ledger. It is therefore a Git-only artifact in the inspected evidence, not the source version recorded by Main. Applying it to Main is neither required by the current schema nor authorized; it could add a redundant check with a different name.

## 3. Corrected conclusion

- The live Main `amount_paid` column is present and has validated non-negative/range checks. The earlier concern that Main currently lacks this column is disproven.
- Main's historical source archive remains unresolved: the exact body of `20261108095928` has not been recovered/compared, so its original DDL provenance is not proven.
- The isolated `20261109002500` file may have been an attempted clean-replay repair on a separate branch, but it is not the migration version recorded in Main. Do not copy, cherry-pick or apply it to Main.
- Clean-room replay remains blocked by the wider migration-source gap and baseline/dependency uncertainty.

## 4. Evidence and boundary

Read-only checks only: migration list, information_schema column metadata, pg_constraint definitions/validation flags, and Git file/tree/commit metadata.

No SQL migration, DDL, history repair, cherry-pick, merge, deployment, APK build, test account, live payment or Main database write was performed.


## 5. Definitive Main migration-body check

The stored Main migration body for version `20261108095928` was read from `supabase_migrations.schema_migrations.statements` (read-only). It explicitly:

- adds `public.service_bookings.amount_paid numeric(12,2)` if absent;
- adds the validated-in-Main nonnegative check `service_bookings_amount_paid_nonnegative`;
- defines the commission trigger and service-booking status-history objects.

This exact Main migration version is earlier than `20261108184815_protect_commission_columns_and_admin_report`. Therefore the Main replay order for this column is supported by the actual stored migration SQL body.

The original Main statements for all 539 migration entries have now been preserved in the JSON source archive at `docs/recovered-main-migrations/` on the mobile integration branch. See its README for capture and verification boundaries.

**Final corrected result:** the live Main `amount_paid` column and its source migration are verified. The separate Git-only `20261109002500` candidate is not needed and must not be applied to Main.
