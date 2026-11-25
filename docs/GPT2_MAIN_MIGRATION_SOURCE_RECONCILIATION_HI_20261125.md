# SRK ELECTRONIC — Main Supabase Migration History vs Git Source Audit

**Audit date:** 25 November 2026  
**Scope:** Read-only repository-tree comparison and previously recorded Main-project migration-history count  
**Target project:** Main Supabase project `gnqhoaqatmoiwwhgzkgm` only  
**Execution boundary:** No SQL, migration, database write, migration repair, merge, deployment, or payment operation was performed.

## 1. Evidence snapshot

The latest available Main-project inspection recorded **539 rows** in Supabase's migration history. The current Git source is split across several active/historical branches, and the number of checked-in SQL migration files differs by branch:

| Git ref inspected | SQL files under `supabase/migrations/` |
|---|---:|
| `main` | 22 |
| `work/admin-worker-payout-web-integration-20261125` | 105 |
| `work/mobile-customer-technician-integration-20261125` | 120 |
| `feat/ai-rate-management-foundation-20261118` | 127 |
| `feature/master-customer-workday-ui-20261121` | 110 |
| `feature/master-technician-payment-cycle-20261121` | 102 |
| `chore/pr8-replay-audit-20261116-v2` | 100 |

These are independent branch snapshots, **not additive counts**. A higher count does not establish that a branch is authoritative or that its migrations match the remote database.

## 2. What this establishes

1. The current `main` branch is not a complete source archive for the previously observed 539-row Main migration history.
2. The mobile integration branch has the largest currently relevant complete snapshot inspected in this audit (120 files), but it still does not account for the full recorded remote history.
3. The repository has known historical replay hazards documented in `docs/MIGRATION_REPLAY_MANIFEST_HI.md` and `docs/GPT2_CURRENT_HEAD_MIGRATION_REPLAY_GATES_20261116_HI.md`: duplicate legacy `20261109` version prefixes, unresolved provenance/order for `service_bookings.amount_paid`, and incomplete proof of the canonical baseline.
4. A branch's migration-file count cannot be compared directly with the remote history row count to name the missing migrations. The exact remote version list and the exact Git file-version list must be compared row by row; version identity and SQL body hash must both be checked.

## 3. What remains unproven

- The exact 539 remote version strings and their order have not been freshly exported in this audit.
- It has not been proven that the 539 history rows all correspond to distinct, currently intended migrations.
- It has not been proven that any one of the inspected branches contains the complete historical SQL source.
- No remote migration history row has been changed, repaired, deleted, or marked as applied.
- No migration has been replayed against Main or any other live project.

## 4. Safe reconciliation procedure

1. Obtain a **read-only, sanitized export** of the Main project's migration history with exact version, name (if available), and applied order. Do not include credentials, customer data, or payment data.
2. Export the complete filename/version inventory from the selected Git ref.
3. Compare exact version identities in three groups: remote-only, Git-only, and matching versions.
4. For every matching version, compare the deployed SQL body with the repository file using a trusted hash or exact content comparison. A matching filename alone is insufficient.
5. Recover remote-only SQL only from verified Git history, approved backups, or Supabase migration artifacts. Record source provenance and content hash. Never synthesize a missing migration from its filename or infer SQL from the current schema.
6. Review duplicate/legacy version identities and baseline dependencies separately. Do not rename, squash, reorder, replay, or edit the remote history until the owner approves a documented repair plan.
7. Perform any replay experiment only in a disposable local database after the canonical baseline and dependency order have been independently reviewed.

## 5. Decision

**Production migration replay and history repair remain BLOCKED.** The next required evidence is the exact sanitized Main migration-history export. This is a source-reconciliation blocker, not permission to run or repair migrations.

No production deployment, APK build, merge, live payment, or test-account creation was performed as part of this audit.
