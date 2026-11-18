# Supabase Migration Version Inventory — 18 Nov 2026

Branch: `feat/ai-rate-management-foundation-20261118`
Reviewed tree commit: `4fde1185f713fded84962f8c2d10eaf8cfb9ffb0`

## Inventory result
- SQL migration files under `supabase/migrations/`: **103**
- Distinct numeric version prefixes: **102**
- Duplicate version groups: **1**
- Newly discovered duplicate groups beyond the known legacy pair: **0**

The sole duplicate group is:
- Version `20261109`
  - `20261109_allow_quote_approval_booking_states.sql`
  - `20261109_electrician_inspection_quotes_and_service_only_commission.sql`

The two files have the same numeric version prefix and therefore cannot both be recorded as separate migration versions by Supabase migration history. A disposable local runtime probe already reproduced the schema_migrations primary-key collision; see `docs/DUPLICATE_20261109_MIGRATION_SCRATCH_EVIDENCE_20261118_HI.md`.

## Existing automated guard
`tests/database-migration-version-uniqueness.test.js` already:
- scans all `.sql` files in `supabase/migrations/`;
- validates each version prefix format;
- fails on any new duplicate version group;
- explicitly allowlists only the known `20261109` legacy pair and documents that it remains blocked pending production-history reconciliation.

This guard prevents additional collisions but intentionally does not resolve the legacy collision.

## Important limitation
This is a Git tree inventory only. It does not reveal which migration version(s) are recorded in any hosted Supabase `schema_migrations` table, nor whether either duplicate file was previously applied through a manual or alternate deployment path.

## Safe next steps
1. Keep the existing duplicate-pair guard in place.
2. Obtain owner-authorized, read-only authoritative hosted migration-history evidence before changing either legacy file.
3. Continue dependency validation in disposable local Supabase. The separate `amount_paid` ordering concern remains open.
4. Do not run hosted migrations or modify any hosted project as part of this review.

No migration file was changed. No hosted database was queried or changed. AI remains disabled.
