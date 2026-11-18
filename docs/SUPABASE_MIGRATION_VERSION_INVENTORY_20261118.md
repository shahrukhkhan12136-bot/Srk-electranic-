# Supabase Migration Version Inventory — 18 Nov 2026

Branch: `feat/ai-rate-management-foundation-20261118`
Reviewed tree commit: `2ef5263ec23b94869ce2203254860c9fc6324a62`

## Inventory result
- SQL migration files under `supabase/migrations/`: **103**
- Distinct numeric version prefixes: **102**
- Duplicate version groups: **1**
- Newly discovered duplicate groups beyond the known legacy pair: **0**

The sole duplicate group is:
- Version `20261109`
  - `20261109_allow_quote_approval_booking_states.sql`
  - `20261109_electrician_inspection_quotes_and_service_only_commission.sql`

The second file repeats the four booking status/assignment CHECK-constraint statements already present at the end of the first file. This confirms source-level redundancy but does not establish which migration identity, if either, is recorded in the actual application's hosted migration ledger.

A disposable local runtime probe reproduced the `schema_migrations` primary-key collision; see `docs/DUPLICATE_20261109_MIGRATION_SCRATCH_EVIDENCE_20261118_HI.md`.

## Existing automated guard
`tests/database-migration-version-uniqueness.test.js` already:
- scans all `.sql` files in `supabase/migrations/`;
- validates each version prefix format;
- fails on any new duplicate version group;
- explicitly allowlists only the known `20261109` legacy pair and documents that it remains blocked pending migration-history reconciliation.

This guard prevents additional collisions but intentionally does not resolve the legacy collision.

## Test-project history check
The read-only migration list for the Supabase project named `SRK ELECTRONIC TEST` returned seven push-notification test migrations (versions `20261110201406` through `20261111071759`). None matches the 103 version prefixes in this feature branch. This is a separate test project's ledger, not the application's authoritative hosted migration history.

## Important limitation
The Git tree inventory and test-project history do not reveal which migration version(s) are recorded in the actual application project's `schema_migrations` table, nor whether either duplicate file was previously applied through a manual or alternate deployment path.

## Safe next steps
1. Keep the existing duplicate-pair guard in place.
2. Obtain owner-authorized, read-only authoritative migration-history evidence for the actual application project before changing either legacy file.
3. Continue dependency validation in disposable local Supabase. The separate `amount_paid` ordering concern remains open.
4. Do not run hosted migrations or modify any hosted project as part of this review.

No migration file was changed. The test-project history query was read-only. No hosted schema/data was changed. AI remains disabled.
