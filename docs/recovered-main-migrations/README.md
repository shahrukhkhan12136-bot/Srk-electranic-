# Recovered Main Supabase Migration Source Archive

**Source project:** Main SRK ELECTRONIC Supabase project `gnqhoaqatmoiwwhgzkgm`  
**Source table:** `supabase_migrations.schema_migrations`  
**Captured:** 25 November 2026  
**Method:** Read-only SQL SELECTs, ordered by `version`, in 22 batches.  
**Status:** Source archive only — NOT an executable migration directory.

## Contents

The 22 JSON files `main_migration_source_001.json` through `main_migration_source_022.json` preserve the Main database's migration `version`, `name`, and `statements` array.

- Total migration rows: **539**
- Rows with NULL statements: **0**
- Rows with empty statements arrays: **0**
- Total statement items: **539** (one per migration)
- Approximate SQL characters: **2,073,329**
- Largest single migration SQL body: **30,848 characters**
- Names outside the expected lowercase underscore pattern: **0**
- Basic scan for common Razorpay live-key / service-role-key / JWT token patterns: **0 matches**

Chunk ranges:

| Chunk | Rows | Offset |
|---|---:|---:|
| 001–021 | 25 each | 0 through 500 in steps of 25 |
| 022 | 14 | 525 |

## Important handling rules

1. These JSON files are a source recovery snapshot, not ready-to-run SQL files.
2. Preserve each version/name exactly. Do not rename, squash, reorder, or edit remote migration history.
3. Before materializing any SQL into `supabase/migrations/`, compare the statements against existing Git files and verify version/name identity. Do not create duplicate version files.
4. Inspect statements for environment-specific assumptions, extensions, roles, grants, secrets, and dependencies. The basic secret-pattern scan above is not a complete secret audit.
5. A database's stored migration statements are evidence of what its migration system recorded, but do not by themselves prove that the original source repository or deployment artifact was byte-for-byte identical.
6. No SQL in this archive has been replayed. No Main schema or migration history was changed during capture.

## Verification

The repository tree contains all 22 expected JSON chunk paths. Chunk 001, 011, and 022 were fetched back from GitHub and parsed successfully; their embedded row counts and first/last versions match the capture. The chunk creation responses recorded the intended row counts for every batch, totaling 539.
