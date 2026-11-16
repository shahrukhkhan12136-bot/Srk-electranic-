# PR #8 — Disposable PostgreSQL replay preparation

**Status:** Source preparation only. No SQL has been executed.

## Files prepared
- `supabase/replay-prep/PR8_DISPOSABLE_REPLAY_PREREQUISITES.sql`: local-only prerequisite script. It refuses to run unless the session explicitly sets `app.srk_replay_environment=disposable_local`.

## Why this file exists
Static source inspection found three prerequisites that are referenced before their current branch definitions:
1. `service_bookings.amount_paid numeric(12,2)` is used by the commission/earnings SQL before the late restore migration `20261116200000_restore_service_bookings_amount_paid.sql`.
2. `public.is_srk_admin()` is called by `20261109001000_add_google_maps_location_support.sql` and `20261109003000_secure_commission_reporting.sql`.
3. `public.srk_is_admin()` is called by `20261109001500_unique_electrician_admin_identity_linking.sql`.

The setup SQL contains both Admin function names, but it is a manual setup script, not a numbered migration. The two names are not interchangeable.

## Important limitation
This is deliberately **not** in `supabase/migrations/`. The current branch has malformed duplicate 8-digit `20261109` migration filenames, and the remote migration history has already-used 14-digit versions. Inserting a backdated migration or renaming historical files without an approved remote-history reconciliation can make incremental deployment fail.

## Local-only use gate
A disposable harness must first create the authoritative baseline and set this session variable before executing the SQL file:

```sql
SET app.srk_replay_environment = 'disposable_local';
```

The script checks for the baseline tables and fails closed if they are absent. It adds the missing payment amount column and constraints, then defines both Admin predicate functions. It does not create the baseline tables, users, or roles. The session marker is only an accidental-run guard; it is **not** proof that the server is local. Never use hosted Production/staging credentials or run this file against hosted databases.

## Still not proven
- This script has not been run in PostgreSQL.
- `NOT VALID` constraints still enforce new writes but require a separate validation pass for existing rows.
- The exact baseline schema, grants/RLS parity, full migration order, duplicate-version reconciliation, and all trigger/function dependencies remain to be validated.
- No Production, staging, deployment, payment, or merge operation is authorized or performed.
