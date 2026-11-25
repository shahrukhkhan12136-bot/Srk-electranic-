# Recovered Main Supabase migration SQL sources

**Source project:** `gnqhoaqatmoiwwhgzkgm` (Main — Srk electranic)  
**Archive source ref:** `work/mobile-customer-technician-integration-20261125`  
**Archive directory:** `docs/recovered-main-migrations/main_migration_source_001.json` … `main_migration_source_022.json`  
**Recovery branch:** `work/srk-migration-recovery-20261125`

## Recovery result

- 539/539 Main migration records reconstructed.
- One SQL source file per original Main migration version and name.
- Each archived migration had exactly one non-empty SQL statement item.
- Files are preserved under `supabase/migrations_recovered/`; the existing `supabase/migrations/` directory has not been overwritten.
- `manifest.csv` records original version, name, path and Git blob SHA.

## Comparison with the current mobile integration branch

- Existing `supabase/migrations/` files on that branch: 120.
- Exact version-string overlaps with Main: 22.
- Byte-identical Git blob matches among those overlaps: 6.
- Same-version files with different Git blob content: 16.
- The remaining feature-branch migrations are not automatically considered applied to Main.

## Safety / replay status

This directory is recovered source evidence, **not an approved execution order**. Do not apply these files to Main, edit Main migration history, or replace the canonical migration directory until:
1. Every existing Git file with a matching Main version is compared and reconciled.
2. Duplicate/short version prefixes and environment-specific statements are reviewed.
3. The true pre-migration baseline is reconstructed and dependencies are checked.
4. A disposable local PostgreSQL clean-room replay succeeds, including the required extensions, roles, Auth/Storage prerequisites and tests.

No Main database DDL, migration, history repair, production deployment, merge, test data or payment operation was performed by this recovery commit.
