# Duplicate 20261109 Migration Version — Scratch Runtime Evidence (18 Nov 2026)

## Scope
Read-only source review plus a disposable local Supabase scratch probe on branch `feat/ai-rate-management-foundation-20261118`.

No production/test hosted database connection, query, write, migration apply, merge, or deployment occurred. The scratch project used an isolated runner-local Supabase stack and was stopped after the probe.

## Source finding
The branch contains two different migration files with the same 8-digit version prefix:
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
- `20261109_allow_quote_approval_booking_states.sql`

The second file repeats the booking status and assignment CHECK-constraint replacement already present at the end of the first file. This is source-level redundancy; it does not establish which migration identities are present in any hosted migration ledger.

## Disposable runtime probe
- Workflow: `.github/workflows/supabase-duplicate-version-scratch.yml`
- Run: [44293579126](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44293579126)
- Commit under test: `8c94c40b87d848ddf6e6b5a385f16931e6997d0d`
- Pinned Supabase CLI: `3.0.0`
- Job conclusion: `success` (the probe intentionally captures the expected migration failure and uploads evidence)
- Artifact: `supabase-duplicate-version-scratch-evidence` (artifact ID `14420784794`)

Observed result:
- `supabase db reset --debug` exit code: `1`
- `scratch_duplicate_alpha`: present
- `scratch_duplicate_beta`: absent
- migration history contains version `20261109`
- CLI log: `ERROR: duplicate key value violates unique constraint "schema_migrations_pkey"`
- PostgreSQL detail: `Key (version)=(20261109) already exists.`

This confirms that, in this pinned local CLI/database setup, two migration files sharing the same version cannot both be recorded during reset. The first migration ran; the second was rejected when the migration ledger attempted to insert the duplicate version.

## CI status
Feature Branch Node tests run [44293578935](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44293578935) completed with conclusion `success` on the same commit.

## Gate / next action
The actual two migration files were not renamed, deleted, merged, reordered, or edited. The hosted Supabase migration history remains unknown. Before any migration-file reconciliation, obtain owner-authorized read-only authoritative migration-history evidence and reconcile it with the Git path/commit history. Until then, full migration replay remains blocked.

AI remains disabled. No hosted database or production state was changed.
