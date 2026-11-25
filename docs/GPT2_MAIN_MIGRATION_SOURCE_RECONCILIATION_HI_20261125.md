# SRK ELECTRONIC — Main Supabase Migration History vs Git Source Audit

**Audit date:** 25 November 2026  
**Target:** Main Supabase project `gnqhoaqatmoiwwhgzkgm`  
**Scope:** Read-only migration ledger, schema metadata and Git tree comparison.  
**Execution boundary:** No migration, DDL, history repair, merge, deploy, payment or test data operation.

## 1. Fresh Main migration-ledger evidence

Read-only `list_migrations` returned exactly **539 migration rows**, with **539 distinct version strings** and no duplicate versions.

The first recorded entries include:

- `20261108092928` — `harden_srk_rls_policy_performance`
- `20261108093725` — `add_atomic_payment_order_lock`
- `20261108093757` — `add_service_role_policy_payment_order_locks`
- `20261108094007` — `harden_security_definer_function_search_paths`
- `20261108095224` — `add_missing_foreign_key_indexes`
- `20261108095928` — `add_actual_paid_amount_commission_and_status_history`
- `20261108184815` — `protect_commission_columns_and_admin_report`

Thus the Main ledger has an early financial/paid-amount-related migration entry before the later commission-column protection entry. The ledger gives version/name, not the historical SQL body, so it does not alone prove every DDL statement in that earlier migration.

## 2. Fresh Main schema evidence for amount_paid

Read-only `information_schema.columns` inspection confirms:

- `public.service_bookings.amount_paid` exists.
- Type: `numeric(12,2)`.
- Nullable: YES.
- Default: NULL.

Read-only `pg_constraint` inspection confirms two validated constraints:

- `service_bookings_amount_paid_nonnegative`: `amount_paid IS NULL OR amount_paid >= 0`.
- `service_bookings_amount_paid_range`: `amount_paid IS NULL OR (amount_paid >= 0 AND amount_paid <= 10000000)`.

**Conclusion:** the live Main schema has the column and validated bounds. The candidate Git-only migration `20261109002500_restore_service_bookings_amount_paid_before_financial_grants.sql` is not needed as a live schema patch based on current evidence. Do not apply it: it is not in the Main migration ledger, and its differently named non-negative constraint could add a redundant third check.

## 3. Exact Git-version comparison

The following independent refs were inspected:

| Git ref | SQL migration files | Distinct filename versions |
|---|---:|---:|
| `main` | 22 | 21 |
| `work/mobile-customer-technician-integration-20261125` | 120 | 119 |
| `work/admin-worker-payout-web-integration-20261125` | 105 | 104 |
| `feat/ai-rate-management-foundation-20261118` | 127 | 126 |
| `feature/master-customer-workday-ui-20261121` | 110 | 109 |
| `feature/master-technician-payment-cycle-20261121` | 102 | 101 |

Across these six refs, the union contains **169 distinct filename versions**. Comparing that union with the live Main ledger:

- Main versions: **539**
- Versions present in both Main and at least one inspected Git ref: **25**
- Main-only versions (not found in any of those six refs): **514**
- Git-only versions (not present in the Main ledger): **144**

The 25 matching versions had matching filename stems/names in the inspected source. This is a version/name comparison only; it is **not** an SQL body/hash comparison. Branch inventories are independent snapshots and must not be added together.

## 4. Important interpretation

1. Main's current schema is more advanced than the checked-in migration history source available on the six inspected refs.
2. The 514 Main-only version entries are not necessarily missing SQL forever; their source may exist in older branches, commits, backups, or other refs not yet inspected. They are simply not found in this bounded six-ref comparison.
3. The isolated `20261109002500` candidate is Git-only (not present in Main's migration ledger). Preserve it as a historical branch artifact; do not cherry-pick or apply it without provenance review.
4. Existing replay hazards remain relevant to clean-room rebuilds: historical duplicate short version prefixes, baseline provenance and dependency order must be reviewed from source, not inferred from the current live schema.
5. A live schema query does not reveal the original SQL body of an applied migration. SQL-body provenance still requires approved backup, verified Git history, or another trusted artifact.

## 5. Next safe steps

1. Search older repository refs/commit history and approved backups for the 514 Main-only versions.
2. For each recovered source file, record exact version, filename, origin ref/commit, blob SHA and whether its body can be independently tied to the deployed migration artifact.
3. Investigate the 25 matching version/name pairs for exact SQL body equality where a trusted deployed artifact exists.
4. Build a migration manifest from the **actual Main order**, but do not replay it until the canonical starter schema and dependency order are independently verified.
5. Keep all source recovery and replay experiments separate from Main; no remote history repair is authorized by this audit.

## 6. Decision

**Main's live `amount_paid` column is present and validated. The migration-source archive is still incomplete: 514 Main ledger versions were not found across the six inspected Git refs. Clean-room replay and history repair remain BLOCKED.**

No Main database writes, migrations, merges, deployments, APK builds, test accounts or payment operations were performed.
