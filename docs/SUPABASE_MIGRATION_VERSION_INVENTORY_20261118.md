# Supabase Migration Version Inventory — 18 Nov 2026

Branch: feat/ai-rate-management-foundation-20261118
Reviewed branch HEAD before this documentation update: a6f54f1b04a21bfcd5b8dff5a7377757c8ec0e1d

## Branch inventory
- SQL migration files under supabase/migrations/: 103
- Distinct numeric version prefixes: 102
- Duplicate version groups: 1
- Sole duplicate group: 20261109
  - 20261109_allow_quote_approval_booking_states.sql
  - 20261109_electrician_inspection_quotes_and_service_only_commission.sql

The two SQL files repeat the booking status/assignment CHECK-constraint statements at source level. A disposable local runtime probe reproduced the schema_migrations primary-key collision when the duplicate prefix is replayed; see docs/DUPLICATE_20261109_MIGRATION_SCRATCH_EVIDENCE_20261118_HI.md.

## Actual application migration history — read-only
The connected Supabase project Srk electranic was ACTIVE_HEALTHY. Its read-only migration listing returned 87 records.
- Exact numeric version overlap between branch and application ledger: 7.
- Application-ledger versions absent as exact prefixes in the branch: 80.
- Branch versions absent from the application ledger: 96.
- Same migration names ignoring version prefix: 16; only 7 of those also share the exact version, leaving 9 same-name/different-version pairs.

The application ledger contains these two distinct quote migrations:
- 20261109075837 — electrician_inspection_quotes_and_service_only_commission
- 20261109080400 — allow_quote_approval_booking_states

This confirms that the actual application's migration ledger has two distinct identities for the quote migrations; the duplicate 20261109 prefix exists in the current branch filenames. The listing returns only version/name metadata and does not prove exact SQL content previously applied.

The full reconciliation is documented in docs/ACTUAL_APP_MIGRATION_HISTORY_RECONCILIATION_20261118.md. The earlier test project's migration history is not authoritative for the application.

## Guard and safe next steps
The existing tests/database-migration-version-uniqueness.test.js guard rejects new duplicate migration prefixes while allowlisting only this known legacy pair. Keep that guard.

Before renaming or rewriting either legacy migration, reconcile all 87 application records against all 103 branch files, including changed versions and SQL contents. The amount_paid clean-replay ordering concern also remains open.

No hosted migration was applied and no hosted schema/data was changed. The application project was only queried for project status and migration metadata. AI remains disabled.