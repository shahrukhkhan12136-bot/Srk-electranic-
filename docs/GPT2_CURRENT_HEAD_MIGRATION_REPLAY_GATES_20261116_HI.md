# GPT-2 — Current-head migration replay gate recheck — 16 Nov 2026

**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**Branch:** `feat/customer-login-first-dashboard-20261114`  
**PR:** #8 — OPEN / DRAFT / NOT MERGED  
**Audited head:** `9590d903c5bf960d9660187962eec8b85a1707e0`  
**Scope:** read-only source verification. No database connection/query, SQL execution, migration replay, DDL, workflow dispatch, merge, deployment, or Production operation.

## 1. Re-verified amount_paid order gate

Current source still shows:

- `SUPABASE_SCHEMA.sql` / starter `service_bookings` definition does not declare `amount_paid`.
- `20261109003000_secure_commission_reporting.sql` reads `amount_paid` in its report RPCs and executes the immediate column-level statement:
  `GRANT UPDATE (status, quoted_amount, amount_paid, payment_status) ON TABLE public.service_bookings TO authenticated;`
- `20261116200000_restore_service_bookings_amount_paid.sql` is the explicit source introduction and adds nullable `numeric(12,2)` plus a nonnegative CHECK marked `NOT VALID`.

A column-level GRANT cannot name a missing column. Therefore, **if the approved clean-install baseline omits amount_paid**, replay reaches an earlier consumer before the late ADD COLUMN migration. This is a source-level, high-confidence ordering blocker; no runtime reproduction was performed. The late migration does not by itself prove the historical deployed column definition or repair an earlier replay failure.

## 2. Admin helper bootstrap gate

The inspected setup SQL defines the legacy `public.srk_is_admin()` helper. The consolidated setup's later Admin compatibility section also defines `public.is_srk_admin()`, which is the name called by early branch migrations, including booking-read policy, GPS, commission-reporting and wallet migrations.

The current source documentation records no separate authoritative introducing migration for `public.is_srk_admin()`. These are distinct function names and must not be treated as aliases. A canonical baseline/replay plan must specify the approved helper definition and ensure it exists before dependent policies/functions execute.

## 3. Duplicate migration version gate

The current migration tree still contains two different SQL files with the same 8-digit `20261109` prefix:

- `20261109_allow_quote_approval_booking_states.sql`
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql`

Repository source history does not establish the authoritative remote Supabase migration-ledger identity/order. No rename, delete, merge, resequence, or remote history repair is authorized by this audit.

## 4. Safe decision

A clean disposable replay is **BLOCKED** until all of the following are established:

1. Approved canonical starter baseline and provenance.
2. An approved placement for `public.is_srk_admin()` before its earliest consumer.
3. A baseline/order that makes `service_bookings.amount_paid` exist before the earlier column-level GRANT and other consumers.
4. Owner/DBA-supplied sanitized evidence resolving duplicate `20261109` migration history.
5. A pinned, isolated local PostgreSQL/Supabase + pgTAP harness.

Do not use the existing remote-schema-export workflow as a substitute for a disposable local replay. Do not connect a test job to Production or use live customer/payment data.

## 5. Checklist and execution status

- GPT-2 checklist remains **27/39 = 69%**; this audit documents blockers and does not close an implementation item.
- PostgreSQL/pgTAP: **NOT RUN**.
- Production schema/history: **NOT ACCESSED in this audit**.
- PR #8 remains **OPEN / DRAFT / UNMERGED**.
- No application source, numbered SQL migration, CI workflow, database, payment provider, or deployment was changed.


## 6. Current-branch CI/runtime harness recheck — 16 Nov 2026

Current repository configuration was checked again at the audited PR head:

- `package.json` maps `npm test` to `node --test tests/*.test.js`; this is the Node/source-contract suite, not a PostgreSQL test runner.
- `supabase/config.toml` is absent from the branch tree, so this checkout is not currently a configured local Supabase project.
- The repository has `.github/workflows/supabase-schema-ci.yml`, but it is not a safe GPT-2 local-only harness:
  - it runs only by `workflow_dispatch`;
  - its job guard accepts `feature/platform-fee-cash-online-cycle`, not the current `feat/customer-login-first-dashboard-20261114` branch;
  - it requires `SUPABASE_DB_URL` and exports schema from the hosted database before starting a local stack;
  - it applies only five hard-coded legacy fee/payment migrations and does not run `supabase test db` or the GPT-2 pgTAP suite.
- `tests/database-pgtap-plan-counts.test.js` checks declared pgTAP plan counts against assertion-call counts. It does not execute SQL or validate PostgreSQL behavior.

**Decision:** do not dispatch or repurpose that workflow for this branch. Its hosted-schema export dependency and incomplete migration list do not meet the approved isolated/no-Production-credential test boundary. Do not add a new replay workflow until the canonical baseline, helper/column ordering and duplicate-version gates above have an approved resolution.

- Node CI at the latest audited head is a separate source-contract signal; latest verified run in this workstream: `43859192973`, **384/384 PASS**.
- PostgreSQL migration replay and pgTAP remain **NOT RUN**.
- No workflow was dispatched or modified; no database connection, schema export, SQL execution, or Production access was made in this recheck.


## 7. Consolidated setup cross-check — 16 Nov 2026

A second candidate bootstrap file, `COMPLETE_DATABASE_SETUP.sql`, was inspected directly at the current branch:

- It **does define** `public.is_srk_admin()` in its later Admin compatibility section, while its earlier setup section defines the distinct legacy `public.srk_is_admin()`. This means the helper definition exists in a consolidated manual setup artifact; the narrower unresolved question is its authoritative placement/provenance in the numbered migration lineage and whether that consolidated file is the approved canonical replay baseline.
- It does **not** define `service_bookings.amount_paid` in its table creation. The separate `SUPABASE_SCHEMA.sql` starter definition also omits that column.
- Therefore the amount-column ordering blocker remains independently confirmed against both checked-in setup candidates. The helper gate is refined, not cleared: a manual setup script contains the required helper, but the numbered migration sequence still has no verified introducing migration before early consumers.

No setup SQL or numbered migration was edited. No SQL was executed and no database was accessed.


## 8. Concrete dependency map for a future isolated replay — 16 Nov 2026

| Earliest inspected consumer / operation | Required object | Source introduction currently visible | Replay implication |
|---|---|---|---|
| `20261108234000_combine_booking_read_policy.sql` | `public.is_srk_admin()` | `COMPLETE_DATABASE_SETUP.sql` manual consolidated setup contains it; no earlier numbered migration introducing it was identified | Baseline/helper bootstrap must precede this policy migration |
| `20261109001000_add_google_maps_location_support.sql` | `public.is_srk_admin()` | Same manual setup artifact; function is called by an Admin RPC | Must be present before function creation/execution path is used |
| `20261109003000_secure_commission_reporting.sql` | `service_bookings.amount_paid` and `public.is_srk_admin()` | `amount_paid` is added by later `20261116200000_restore_service_bookings_amount_paid.sql`; helper is in consolidated manual setup | Definite source-order conflict: column-level GRANT and report RPC reference amount_paid before the late ADD COLUMN file |
| `20261109_electrician_inspection_quotes_and_service_only_commission.sql` | quote columns/status and `amount_paid` in trigger logic | This migration itself adds quote fields, but its trigger references `amount_paid`; same-prefix peer exists | Must resolve base payment column before trigger creation; duplicate version prefix needs authoritative history/order |
| `20261114125844_restore_financial_audit_core_schema.sql` | `amount_paid`, quote fields, helper | Existing prior migrations/manual setup; references financial booking fields in audit snapshots | Must only be placed after all required booking columns and helper exist |
| `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` | `amount_paid`, quote fields, payout/receipt tables, helper | Prior financial-core and booking migrations | Later consumer; not a candidate bootstrap fix |

### Replay order conclusion

A source-only safe *candidate* sequence can be stated, but cannot be approved as the canonical deployed history from repository files alone:

1. Confirm the authoritative starter schema and its provenance; do not assume either setup SQL file equals the deployed database or migration ledger.
2. Ensure the approved bootstrap creates `srk_admin_users` and `is_srk_admin()` before `20261108234000` (and any earlier consumer).
3. Ensure `service_bookings.amount_paid` exists in the starter baseline or in a numbered migration strictly before `20261109003000` and before the quote migration's trigger references it. Do not rely on the late `20261116200000` repair for a clean replay.
4. Resolve the two `20261109` files against a sanitized authoritative migration-ledger export; preserve both source files until that evidence exists.
5. Only then pin a local PostgreSQL/Supabase CLI version, create disposable fixture data, replay in a fresh local project, and execute both pgTAP suites (18 legacy payment/receipt + 15 accounting bridge assertions).

The `20261110140000_restore_missing_customer_booking_quote_columns.sql` migration adds only `customer_suggested_amount` and `electrician_quote_kind`; it does not restore the legacy quote fields or `amount_paid`. Quote fields are introduced by the same-prefix `20261109_electrician_inspection_quotes_and_service_only_commission.sql` migration. This distinction matters when preparing fixtures and checking the dependency graph.

No numbered migration was edited or reordered. This is a dependency analysis, not a runtime replay. Remote migration history remains unverified.


## 9. Existing CI harness safety review — 16 Nov 2026

Inspected `.github/workflows/supabase-schema-ci.yml` at the current feature branch. It is **not suitable to run for this Master Checklist replay**:

- It is gated to `refs/heads/feature/platform-fee-cash-online-cycle`, not this current feature branch.
- It requires `SUPABASE_DB_URL` and exports schema from a remote Supabase database before creating its local stack. Even though the export step requests schema-only/read-only access and checks a restricted role, this still makes a remote database a prerequisite and does not satisfy the requested fully local, no-remote replay.
- It pins Supabase CLI 3.0.0, but its migration array contains five older, feature-specific migration paths that are not the current branch's complete migration chain. It does not apply the current 20261108–20261116 sequence or the two target pgTAP suites.
- It does not run `supabase test db` or invoke the 18-assertion legacy payment/receipt suite and 15-assertion accounting bridge suite.
- The current repository has no checked-in `supabase/config.toml`; `package.json` exposes only Node tests and declares no local PostgreSQL/pgTAP runner.

**Safety decision:** Do not dispatch this workflow, do not provide a production database URL/secret, and do not adapt its remote export step as the starting point. No secrets were read, no remote DB was contacted, and no workflow was executed or changed.

### Local-only harness acceptance gates

A future dedicated workflow must (1) use a pinned Supabase CLI and container/runtime versions, (2) create a disposable local stack from a reviewed canonical baseline committed in this repository, (3) apply the complete ordered current migration chain without remote URLs or secrets, (4) seed synthetic-only identities and bookings, (5) run both named pgTAP suites plus schema lint, (6) stop and destroy the local stack even on failure, and (7) run on this branch's push/PR without deploying. Do not add that workflow until the canonical baseline and duplicate timestamp provenance are resolved; otherwise CI would merely automate an untrusted replay order.
