# PR #8 — Replay Risk Matrix (Source Evidence, 2026-11-16)

**Audited SQL source ref:** `41b4b1ecc84f5ba3b753c6940ccbfe3c3ffd68d7` (the five commits added afterward to PR #8 changed only booking/electrician UI and contract tests; the SQL migration files audited here were unchanged through PR head `dc8b4f723ac7ae896eeb516336dd4b28577390b5`).  
**Purpose:** Convert confirmed source dependencies into explicit replay gates. Static inspection only.

| Gate | Source evidence | Clean replay risk | Required resolution |
|---|---|---|---|
| Base schema | `COMPLETE_DATABASE_SETUP.sql` creates service_bookings, electrician_applications, electrician_profiles, job_offers and srk_admin_users | Numbered migrations assume these objects already exist | Approve exact baseline provenance and schema contract |
| Auth schema | Base setup references `auth.users`; migrations add Auth-user FKs and read phone verification fields | Plain PostgreSQL without Supabase Auth objects will fail | Use isolated local Supabase, not bare PostgreSQL |
| Admin helper | `20261108234000_combine_booking_read_policy.sql` calls `is_srk_admin()`; `20261109001000` calls it; `20261109001500` calls `srk_is_admin()` | Missing helper at first reference causes function/policy creation failure | Establish exact definitions and grants before first dependent migration |
| Customer ownership | `20261108121115_add_customer_account_booking_access.sql` adds `customer_user_id`; combined read policy consumes it | Combined policy fails if ownership column migration is later or omitted | Preserve customer ownership migration before combined read policy |
| Electrician identity | `20261109000500_harden_electrician_profile_identity_linking.sql` adds/synchronizes `auth_user_id`; GPS migration writes both identity fields | GPS migration can fail if identity column does not exist | Identity hardening must precede GPS migration |
| GPS and offer RPC | `20261109001000` adds coordinate columns and Admin approval RPC; `20261109001500` replaces approval RPC; `20261109002000` creates map-pin offer RPC | Function replacement depends on prior signatures and columns | Keep the source-established order and validate signatures |
| Quote RPC | `20261109_electrician_inspection_quotes_and_service_only_commission.sql` reads customer_user_id, location columns, and quote fields; replaces `srk_get_my_offer_details()` | Missing earlier ownership/GPS/base columns or wrong return signature causes failure | Verify full predecessor chain and RPC return-type compatibility |
| Quote status migration duplication | The quote workflow file itself ends by replacing `service_bookings_status_check` and adding assignment-state constraint; `20261109_allow_quote_approval_booking_states.sql` repeats that status/assignment-constraint work | Running both may be redundant; exact duplicate constraint DDL may fail or cause confusing lineage | Compare both complete files and remote migration history; do not delete or rename either without approval |
| Commission prerequisites (corrected after ledger check) | Production ledger records `20261108095928 add_actual_paid_amount_commission_and_status_history` before the quote workflow; live `service_bookings.amount_paid` exists with a nonnegative check. The matching historical migration file is absent from the audited PR source tree; branch instead contains a new `20261116200000_restore_service_bookings_amount_paid.sql` | Clean replay from branch source cannot reproduce the deployed introduction at its original point. The late restore file may mask missing history but does not reconstruct the exact historical chain | Recover/restore the original migration source from authoritative history; compare its full DDL before deciding whether the new late restore is redundant or retained only as a forward repair |
| Migration versions | Two files start with `20261109_` rather than 14 digits | CLI migration parser / ledger cannot reliably order them | Resolve intended versions against authoritative remote ledger |
| Local config | No `supabase/config.toml` at audited PR head | Local Supabase CLI workflow not yet reproducible | Add reviewed local configuration before claiming harness readiness |

## Authoritative Production ledger reconciliation (read-only)

The Supabase Production migration ledger was read without executing SQL changes. It reports the following relevant order:

- `20261108095928 add_actual_paid_amount_commission_and_status_history`
- `20261108121115 add_customer_account_booking_access`
- `20261108183027 add_google_maps_location_support`
- `20261108183324 expose_assigned_booking_map_pin`
- `20261109075837 electrician_inspection_quotes_and_service_only_commission`
- `20261109080400 allow_quote_approval_booking_states`

The current Production `public.service_bookings` schema also exposes `amount_paid numeric` with a nonnegative check constraint. This confirms that the earlier claim that Production first introduced `amount_paid` only after its consumers was incorrect. The verified problem is instead a **source-history gap**: the audited branch has no migration file matching the ledger's `20261108095928` introduction, while it does contain a later `20261116200000_restore_service_bookings_amount_paid.sql`.

The two quote-state blocks were compared line by line: both drop and recreate `service_bookings_status_check` with the same allowed-state list, and drop and recreate `service_bookings_assignment_status_requires_electrician` with the same assignment predicate. This is an exact repeated constraint operation in the branch source. Production ledger order places the quote workflow at `075837` and the separate state migration at `080400`, but the ledger exposes names/versions, not historical SQL bodies; it therefore confirms the deployed order, not that the Production SQL bodies were byte-identical.

The GPS and Map Pin migration source commits were recovered from Git history: `23fcdc2a95fcafd4ec321be02f091d0eed28802c` (GPS) and `6f6182221f41b0e13c45a1f99fcd11641a01bc17` (Map Pin). Their commit timestamps are 2026-11-08 18:30:22Z and 18:33:21Z; Production ledger entries are 18:30:27 and 18:33:24 respectively. This is strong evidence that the deployed GPS/Map migrations are those source changes, with a few seconds of ledger timing difference. The branch's current filenames `20261109001000` and `20261109002000` do not encode those ledger versions, so the version mapping still needs careful reconciliation before replay. The recovered commit patches also confirm the Map Pin migration creates the initial `srk_get_my_offer_details()` return shape; the quote migration later replaces that function with additional quote fields.

The original `amount_paid` migration remains unresolved. The current migration directory contains the later `20261116200000_restore_service_bookings_amount_paid.sql`, but no file named for Production ledger version `20261108095928`. GitHub commit search for the exact migration name and `amount_paid` did not locate its original DDL. This search is not proof that no historical copy exists on another branch or in an unavailable artifact; the next useful source is the original commit/PR or a schema-history export containing the DDL.

## Important additional finding: quote-state DDL is duplicated

The quote workflow migration includes the same high-level status and assignment constraint replacement as the separate `20261109_allow_quote_approval_booking_states.sql` file. This is a separate issue from the malformed version names. A source diff and authoritative ledger check are required to decide whether one file is historical duplication, an intentional idempotent repeat, or an incomplete split.

## Safe next actions

1. Obtain an authoritative schema-only export and migration ledger from the owner-approved environment.
2. Compare the two quote-state DDL blocks and their exact constraints/expressions.
3. Establish the earliest intended version for `amount_paid` based on source history and remote ledger.
4. Resolve malformed migration filenames only after ledger comparison.
5. Build and run the disposable local Supabase harness after these gates are closed.

## Safety boundary

Production was accessed only through read-only project, migration-ledger, and table-schema inspection. No SQL was executed against Production. No migration was applied, renamed, deleted, or reordered. No test is represented as passed.


### 2026-11-16 follow-up: repository-wide source recovery attempt

A follow-up read-only search checked the `supabase/migrations` directory on all 22 repository branches returned by GitHub's branch API, including `main`, the PR #8 source branch, the replay-prep branches, and the payment/refund feature branches. None contained a migration filename matching `20261108095928`, `actual_paid`, `amount_paid`, or `status_history`. The GitHub commit-history endpoint queried for the exact expected path `supabase/migrations/20261108095928_add_actual_paid_amount_commission_and_status_history.sql` returned an empty list. Repository-scoped code searches for `actual_paid_amount`, `status_history commission_rate`, and the exact ledger migration name returned no matching source file.

The repository commit search for `amount_paid` surfaced two relevant consumer-code commits, not the missing DDL: `d7c7fc9800141195023453c7781d34b7e03bdc41` (“Record verified Razorpay amount paid”) and `1983b7334dfcd138ecc3dcf0f920b81ddfe671ee` (“Record webhook captured amount paid”). Their presence shows application code consuming/storing the field, but does not establish the SQL that originally created the column, commission fields, or status history.

**Updated conclusion:** the original migration source was not recovered from any of the 22 currently listed branches, the queried exact-path history, or the repository-scoped searches performed in this audit. This is stronger negative evidence than the earlier PR-head-only search, but it is not proof that no source exists in deleted refs, inaccessible forks, local backups, Supabase migration artifacts, or owner-held exports. Do not recreate or backdate the original migration from inference. Request the original SQL/commit artifact or an owner-approved schema-only historical export and compare its complete DDL to the live schema before deciding how to reconcile the source tree.


### 2026-11-16 follow-up: Production current-schema evidence (read-only)

Read-only catalog queries were run against the Production project `gnqhoaqatmoiwwhgzkgm`; no DDL or data writes were issued.

- `public.service_bookings` currently has `amount_paid numeric`, `commission_amount numeric`, and `commission_rate numeric`.
- `amount_paid` currently has two CHECK constraints: `service_bookings_amount_paid_nonnegative` (NULL or >= 0) and `service_bookings_amount_paid_range` (NULL or between 0 and 10,000,000). Both are present simultaneously.
- The current `service_bookings` trigger set includes `srk_calculate_booking_commission` (BEFORE INSERT or UPDATE OF status, payment_status, amount_paid, commission_rate) and `srk_log_service_booking_status` (AFTER INSERT OR UPDATE OF status).
- `public.service_booking_status_history` currently exists with columns `id uuid`, `booking_id uuid`, `old_status text`, `new_status text`, `note text`, `changed_by uuid`, and `changed_at timestamptz`; its primary key is `id`, and `booking_id` references `service_bookings(id) ON DELETE CASCADE`.
- The live `srk_calculate_booking_commission()` function validates nonnegative `amount_paid`, validates `commission_rate` in 0..100, and calculates `commission_amount` from `service_charge * commission_rate / 100` only when status is completed, payment_status is paid, and amount_paid/service_charge are non-NULL.
- The live `srk_log_service_booking_status()` function inserts an initial history row on booking creation and records status transitions, using `auth.uid()` as `changed_by`.

These are **current-state catalog facts only**. They do not reveal the original migration's exact SQL, the historical order in which these objects were introduced, or whether all current definitions match the body recorded under ledger version `20261108095928`.

The branch's later `20261116200000_restore_service_bookings_amount_paid.sql` was also inspected. It only conditionally adds `service_bookings.amount_paid numeric(12,2)` and the two amount-paid CHECK constraints above. It does not create `commission_amount`, `commission_rate`, `service_booking_status_history`, or either trigger/function. Therefore it is not a replacement for the missing historical migration and cannot by itself make the original ledger entry reproducible.

**Replay decision remains blocked:** obtain the exact original SQL artifact or an owner-approved historical schema/migration export. Do not treat a present-day schema reconstruction as the original migration; do not alter Production or backdate a migration.


### 2026-11-16 follow-up: separate TEST project checked (read-only)

The separate Supabase project `SRK ELECTRONIC TEST` (project ref `dvzmarekhstaubyuoeeh`) was checked before treating it as a possible source for the missing historical DDL. The project is `ACTIVE_HEALTHY`, but its migration ledger contains only seven push-notification test migrations dated 2026-11-10/11 (`20261110201406` through `20261111071759`). Its current public tables are `srk_push_subscriptions`, `electrician_profiles`, and `job_offers`; the inspected public schema does not contain `service_bookings` or `service_booking_status_history`.

**Conclusion:** this TEST project is a push-notification test environment, not a historical database snapshot or source for the missing `20261108095928` migration. It does not resolve the original DDL gap. Both project metadata, migration ledger, and table listing were read-only; no SQL or schema changes were made.


### 2026-11-16 follow-up: Production Supabase development branches

The Production Supabase project `gnqhoaqatmoiwwhgzkgm` was checked for Supabase-managed development branches. The read-only branch listing returned an empty list (`branches: []`). Therefore, no existing Supabase development branch was available to inspect as an alternate migration-history or schema source.

This does not rule out external backups, deleted branches, or owner-held exports. It only confirms that the Production project currently exposes no managed development branches through the branch listing. No branch was created, reset, rebased, merged, or deleted.


### 2026-11-16 follow-up: Supabase account inventory and project notebooks

The connected Supabase account's project inventory was read. It contains exactly the two projects already checked in this investigation: Production `Srk electranic` (`gnqhoaqatmoiwwhgzkgm`) and `SRK ELECTRONIC TEST` (`dvzmarekhstaubyuoeeh`). No third staging/archive project is exposed in this account inventory. The Production project's saved-notebook listing was also checked and returned an empty list.

**Conclusion:** no additional connected Supabase project or saved Production notebook is available as an alternate source for the missing original migration. This only covers projects/notebooks visible to the current connected account; it does not rule out another owner's account, external backups, or exported artifacts. All checks were metadata/listing reads; no schema, data, migration, or project state was changed.


### 2026-11-16 follow-up: repository-wide definition and commit searches

A further read-only GitHub code search on the repository's default branch looked for the exact identifiers `service_booking_status_history`, `srk_log_service_booking_status`, `service_bookings_amount_paid_range`, and `srk_calculate_booking_commission`. The first three returned no matching source files; the commission function search found only `20261109_electrician_inspection_quotes_and_service_only_commission.sql`, which contains the consumer/replacement function but is not the missing historical migration. A separate repository-scoped commit search for “actual paid amount commission status history”, “amount_paid commission status history”, and “service booking status history” returned no matching commits.

**Conclusion:** these additional default-branch code and commit searches did not recover the original DDL. The one matching commission-function migration does not establish the original definitions for `amount_paid`, `commission_rate`, `commission_amount`, or `service_booking_status_history`. The previously stated replay block remains unchanged. This search is limited to GitHub's indexed default-branch code and searchable commit messages; it does not cover unavailable historical refs, private forks, local copies, or owner-held backups.


### 2026-11-16 follow-up: refreshed PR #8 head and CI status

The live PR metadata was re-read after the previous audit update. PR #8 remains **open, Draft, and unmerged**; GitHub currently reports it as mergeable. Its current head is `d01dc805d6d9ab5a9efcc53109cc5921ab27bfa7` on `feat/customer-login-first-dashboard-20261114`. This differs from the earlier audited PR head `dc8b4f723ac7ae896eeb516336dd4b28577390b5`.

The current PR head has a successful GitHub Actions run: run `43897251465`, job “Node test suite (no secrets, no deployment)”. The job completed successfully, including checkout, Node.js 22 setup, dependency installation, and “Run repository Node tests”. This is **Node test CI only**; it does not execute PostgreSQL migrations or pgTAP, and must not be interpreted as a database replay pass.

The current PR head and this audit branch have diverged from their common ancestor `dc8b4f723ac7ae896eeb516336dd4b28577390b5`. The compare endpoint reports six commits ahead on the current PR head and nine commits behind relative to the audit branch; the reported file changes are `booking.html` and `tests/customer-booking-idempotency.test.js`. Therefore, the migration-source findings in this matrix remain valid only to the extent the current PR changes did not alter the audited SQL migration files; this compare reports no SQL migration file among the changed paths.

No PR merge, production deployment, migration execution, or Production write was performed during this follow-up.


### 2026-11-16 follow-up: current PR-head migration inventory

The recursive Git tree for the current PR head `d01dc805d6d9ab5a9efcc53109cc5921ab27bfa7` was inspected (complete tree response; not truncated). It contains **87 SQL migration files**: 85 filenames with valid 14-digit version prefixes and the same two malformed filenames, `20261109_allow_quote_approval_booking_states.sql` and `20261109_electrician_inspection_quotes_and_service_only_commission.sql`. No duplicate valid 14-digit version prefixes were found. The exact Production ledger migration `20261108095928_add_actual_paid_amount_commission_and_status_history.sql` is still absent, while `20261116200000_restore_service_bookings_amount_paid.sql` is present.

This confirms the earlier migration-inventory findings still apply to the refreshed PR head. It does not make the chain replayable: the missing historical source and malformed version filenames remain unresolved. No migration files were edited or executed.


### 2026-11-16 critical follow-up: exact Production ledger ↔ current PR-head version comparison

A fresh read-only comparison was performed between the Production Supabase migration ledger (87 entries; latest `20261115092149`) and the complete SQL migration tree at current PR #8 head `d01dc805d6d9ab5a9efcc53109cc5921ab27bfa7` (87 SQL files; 85 valid 14-digit filename prefixes).

Exact version-prefix intersection is only **7**:
`20261108120608`, `20261108120658`, `20261108121115`, `20261109103038`, `20261109103143`, `20261115091906`, `20261115092149`.

Consequently:
- **80 of 87 Production ledger version IDs** have no exact same-version filename in the current PR-head migration directory.
- **78 of 85 valid PR-head migration version IDs** do not appear in the Production ledger.
- These are exact filename/version comparisons only. They do **not** prove that all 80 Production migration bodies are absent: some may have been renamed, renumbered, consolidated, or represented by differently named source files. Such equivalence requires per-migration SQL and dependency comparison; it must not be assumed.
- This substantially confirms that the current PR-head migration directory is not a direct filename/version mirror of the Production ledger. The missing original `20261108095928` remains among the unmatched Production versions.

**Decision:** do not replay the current PR migration directory against Production, and do not “fix” this by bulk renaming/backdating. First build a reviewed one-to-one reconciliation map from every Production ledger entry to an exact source migration (or documented equivalent), inspect SQL bodies and ordering, then test the reconciled chain in an isolated disposable PostgreSQL/Supabase environment. This comparison was read-only; no Production writes or migration execution occurred.


### 2026-11-16 follow-up: filename-level candidate reconciliation

A second pass compared normalized migration names and inspected the SQL text of the strongest apparent PR-head candidates. **14 Production ledger names have an exact normalized name match** in the branch even though most filenames use different version prefixes. The other 73 ledger names do not have an exact normalized-name match.

Examples of strong *candidate* correspondences (not yet proven historical equivalents):
| Production ledger entry | PR-head candidate file | Evidence / limitation |
|---|---|---|
| `20261108181453 restrict_public_form_inserts_to_server_functions` | `20261108233500_restrict_public_form_inserts.sql` | SQL text revokes direct anon/authenticated inserts and grants service_role inserts; body-level intent appears aligned. |
| `20261108181538 combine_admin_customer_booking_read_policy` | `20261108234000_combine_booking_read_policy.sql` | SQL text combines admin/customer booking SELECT policy. |
| `20261109075837 electrician_inspection_quotes_and_service_only_commission` | `20261109_electrician_inspection_quotes_and_service_only_commission.sql` | Same normalized name; inspected body adds quote columns and commission trigger logic. |
| `20261109080400 allow_quote_approval_booking_states` | `20261109_allow_quote_approval_booking_states.sql` | Same normalized name; inspected body changes booking status and assignment constraints. |
| `20261114193300 admin_approved_electrician_relocation_20261114220000` | `20261114220000_admin_approved_electrician_relocation.sql` | Name strongly aligns; branch file body defines admin-approved area-change workflow. |

These examples show why version-only comparison overstates *definite missing SQL bodies*: some entries may have been renamed or renumbered. Conversely, similar names and apparent intent are not proof of byte-for-byte or behaviorally equivalent SQL, nor do they establish the original execution order. Production migration bodies are not available from the migration ledger response used here.

**Next required evidence:** obtain the original SQL bodies (or trusted source commit/export) for all Production ledger versions, then compare each candidate with exact DDL, grants, policies, triggers, functions, and dependencies. Do not mark a candidate “reconciled” until that comparison is complete. No database changes or replay occurred.


### 2026-11-16 critical evidence recovery: original Production SQL bodies are available in the migration ledger

A read-only query of `supabase_migrations.schema_migrations` exposed the stored `statements` array. This is stronger evidence than the migration-name ledger alone: original SQL bodies can be retrieved directly from the Production migration history. No writes were made.

#### Direct body comparisons against current PR #8 head

Compared Production SQL with the apparent PR-head candidate after removing SQL comments and normalizing whitespace/case:

| Production version | PR-head candidate | Result |
|---|---|---|
| `20261108095928` amount-paid/commission/status-history | `20261116200000_restore_service_bookings_amount_paid.sql` | **NOT EQUIVALENT.** Production body is 3,554 chars; branch restore is 720 chars. Production creates the commission trigger/function, status-history table/index/RLS/policies/grants, and status logging trigger/function. Branch restore only adds `amount_paid` and its two range/nonnegative constraints. |
| `20261108181453` restrict public form inserts | `20261108233500_restrict_public_form_inserts.sql` | Normalized SQL matches. |
| `20261108181538` combine admin/customer booking read policy | `20261108234000_combine_booking_read_policy.sql` | Normalized SQL matches. |
| `20261109075837` quote workflow | `20261109_electrician_inspection_quotes_and_service_only_commission.sql` | **NOT an exact normalized-body match.** Production body is 8,521 chars; branch body is 9,568 chars. Branch candidate includes additional revokes and status-constraint DDL, while some function-body statements differ in the direct statement comparison. Treat as a possible consolidation/modified successor, not proven identical. |
| `20261109080400` quote approval booking states | `20261109_allow_quote_approval_booking_states.sql` | Normalized SQL matches. |
| `20261114193300` admin-approved electrician relocation | `20261114220000_admin_approved_electrician_relocation.sql` | Normalized SQL matches. |

#### Revised conclusion

The earlier statement that the original `20261108095928` SQL body could not be located is superseded: **the exact original body is recoverable from Production's migration ledger**. It still is not present as an equivalent complete migration in the current PR-head tree. The later `restore_service_bookings_amount_paid` file is only a partial column/constraint repair and cannot substitute for the original migration.

This provides a concrete recovery path: export all 87 stored Production migration bodies read-only, reconcile each against the PR-head files (including consolidated/successor candidates), and produce a versioned mapping with body-level results. Do not copy/backdate the recovered original migration into a replay chain without first designing the correct baseline/replay strategy: Production already records that version as applied, and blindly reapplying it can conflict with existing objects.

No migration was applied, no Production schema/data changed, and no PR was merged.


### 2026-11-16 body-level reconciliation tranche: all 14 normalized-name candidates checked

The Production ledger's stored SQL `statements` were compared against all 14 PR-head files whose normalized migration names match a Production ledger name. SQL comments and whitespace were normalized before comparison; dollar-quote delimiters were also normalized in a separate check for the four differing candidates.

**Result: 10 exact normalized SQL-body matches; 4 body differences.**

| Production version | Production migration | PR-head candidate | Body result |
|---|---|---|---|
| `20261108120608` | add_public_api_rate_limiting | `20261108120608_add_public_api_rate_limiting.sql` | Exact normalized body |
| `20261108120658` | enable_rls_public_api_rate_limits | `20261108120658_enable_rls_public_api_rate_limits.sql` | Exact normalized body |
| `20261108121115` | add_customer_account_booking_access | `20261108121115_add_customer_account_booking_access.sql` | Exact normalized body |
| `20261108183027` | add_google_maps_location_support | `20261109001000_add_google_maps_location_support.sql` | **Different**; branch adds constraint validation statements |
| `20261108183324` | expose_assigned_booking_map_pin | `20261109002000_expose_assigned_booking_map_pin.sql` | Exact normalized body |
| `20261108190047` | create_secure_wallet_ledger_foundation | `20261109010000_create_secure_wallet_ledger_foundation.sql` | Exact normalized body |
| `20261108193506` | create_server_only_razorpay_route_transfer_ledger | `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql` | Exact normalized body |
| `20261109103038` | customer_electrician_direct_call_contacts | `20261109103038_customer_electrician_direct_call_contacts.sql` | **Different**; function-body text differs slightly; requires semantic review |
| `20261109103143` | move_customer_call_contact_lookup_to_private | `20261109103143_move_customer_call_contact_lookup_to_private.sql` | **Different**; branch adds `CREATE SCHEMA IF NOT EXISTS private` and body/length differs |
| `20261109203132` | customer_admin_complaints | `20261110040000_customer_admin_complaints.sql` | Exact normalized body |
| `20261110133835` | restore_missing_customer_booking_quote_columns | `20261110140000_restore_missing_customer_booking_quote_columns.sql` | Exact normalized body |
| `20261111072823` | add_electrician_push_subscriptions | `20261111020000_add_electrician_push_subscriptions.sql` | **Material schema difference**; Production uses named endpoint/key length constraints and has no `user_agent` column; branch uses inline length checks and adds `user_agent` |
| `20261115091906` | retire_unused_legacy_accept_electrician_job | `20261115091906_retire_unused_legacy_accept_electrician_job.sql` | Exact normalized body |
| `20261115092149` | retire_unused_razorpay_route_transfer_ledger | `20261115092149_retire_unused_razorpay_route_transfer_ledger.sql` | Exact normalized body |

**Scope limitation:** these are the 14 exact normalized-name candidates, not a completed body-level mapping of all 87 Production migrations. The remaining 73 Production entries still need candidate discovery and comparison, including cases where a migration was renamed, consolidated, split, or removed. Same-name and exact-body matches do not by themselves prove replay order or dependency safety.

The Production SQL was read only. No database writes, migration execution, deployment, or merge occurred.


### Additional cross-name candidate checks (six more comparisons)

A second pass checked six important candidates whose filenames do not normalize to the Production migration name. This raises the checked set to **20 candidate comparisons overall: 14 exact normalized-body matches and 6 differences**.

| Production version | Production migration | PR-head candidate | Body result |
|---|---|---|---|
| `20261108095928` | add_actual_paid_amount_commission_and_status_history | `20261116200000_restore_service_bookings_amount_paid.sql` | **Not equivalent**. Production body also creates commission calculation trigger/function and status-history table, RLS, policies, grants, and status logger trigger/function; branch file only restores amount_paid and checks. |
| `20261108181453` | restrict_public_form_inserts_to_server_functions | `20261108233500_restrict_public_form_inserts.sql` | Exact normalized SQL body |
| `20261108181538` | combine_admin_customer_booking_read_policy | `20261108234000_combine_booking_read_policy.sql` | Exact normalized SQL body |
| `20261109075837` | electrician_inspection_quotes_and_service_only_commission | `20261109_electrician_inspection_quotes_and_service_only_commission.sql` | **Not exact**. Branch file has additional revokes and constraint DDL; function body statements also differ. Treat as modified/consolidated candidate, not identical historical SQL. |
| `20261109080400` | allow_quote_approval_booking_states | `20261109_allow_quote_approval_booking_states.sql` | Exact normalized SQL body |
| `20261114193300` | admin_approved_electrician_relocation | `20261114220000_admin_approved_electrician_relocation.sql` | Exact normalized SQL body |

**Updated tally:** 20 comparisons = 14 exact normalized SQL-body matches + 6 non-identical candidates. This is still a partial candidate audit, not an 87-of-87 reconciliation. The remaining Production entries require candidate discovery, including split/consolidated/renamed migrations.


### Next five Production ledger entries reviewed (versions 20261108092928–20261108095224)

These five original SQL bodies were retrieved from the read-only Production migration ledger and inspected against the current PR-head migration inventory:

| Production version | Production migration | Candidate / finding | Result |
|---|---|---|---|
| `20261108092928` | harden_srk_rls_policy_performance | `20261108234000_combine_booking_read_policy.sql` is only a partial thematic candidate; Production body also changes electrician profile and admin-user policies. | **Not equivalent / incomplete candidate** |
| `20261108093725` | add_atomic_payment_order_lock | No corresponding lock-table + claim/release-function migration found in the 87-file PR-head migration inventory. | **No candidate located** |
| `20261108093757` | add_service_role_policy_payment_order_locks | Depends on the payment-order-lock table from the preceding Production migration; no matching policy migration located in the PR-head inventory. | **No candidate located** |
| `20261108094007` | harden_security_definer_function_search_paths | Several later files redefine some of the same functions, but no single file reproduces this migration's full function set, bodies, grants and search-path changes. | **No equivalent candidate located** |
| `20261108095224` | add_missing_foreign_key_indexes | Production indexes `booking_status_history` and legacy `bookings` columns; no corresponding migration found in the current PR-head inventory. | **No candidate located** |

This pass adds five reviewed Production entries. For these entries, no new exact normalized-body match was established. The audit remains a partial 87-entry reconciliation; absence of a candidate in the current PR-head tree does not prove the SQL never existed in another branch, deleted ref, backup, or earlier baseline.


### Next five Production ledger entries reviewed (versions 20261108102159–20261108102951)

Read-only Production SQL bodies were retrieved and compared with the PR-head migration inventory and later search-path hardening candidates:

| Production version | Production migration | Candidate / finding | Result |
|---|---|---|---|
| `20261108102159` | harden_payment_order_lock_search_paths | Production alters `srk_claim_payment_order_lock(uuid)` and `srk_release_payment_order_lock(uuid,uuid)`; the similarly themed later branch files alter different financial read RPCs. | **No equivalent candidate located** |
| `20261108102323` | harden_booking_broadcast_search_path | Production alters `broadcast_booking_job()`; no corresponding function alteration found in the current PR-head migration files. | **No candidate located** |
| `20261108102612` | harden_booking_guard_trigger_search_path | Production alters `guard_new_booking()`; no corresponding function alteration found in the current PR-head migration files. | **No candidate located** |
| `20261108102837` | enable_realtime_job_offer_updates | Production adds `public.job_offers` to `supabase_realtime`; no corresponding publication alteration found in the current PR-head migration files. | **No candidate located** |
| `20261108102951` | enable_realtime_electrician_profile_updates | Production adds `public.electrician_profiles` to `supabase_realtime`; no corresponding publication alteration found in the current PR-head migration files. | **No candidate located** |

No exact normalized-body match was established in this batch. The later search-path migrations in the branch are not substitutes for the two payment-lock function alterations: they target different function signatures. Absence from the current PR-head tree is not proof that a source never existed elsewhere.


### 2026-11-16 follow-up: next five Production migration bodies compared (read-only)

The original SQL bodies for Production ledger entries `20261108103531`, `20261108115205`, `20261108184254`, `20261108184815`, and `20261108184938` were read from `supabase_migrations.schema_migrations.statements` and compared with the current PR #8 replay-prep migration tree.

| Production version | Production change | PR-head comparison | Result |
|---|---|---|---|
| `20261108103531 guard_booking_assignment_and_amount_integrity` | Adds range checks for `quoted_amount` and `amount_paid`, plus assigned-electrician requirement for assigned/in-progress/completed statuses | Quote workflow file repeats the assignment constraint, but the located branch files do not reproduce both Production range checks as a complete equivalent block. The late amount-paid restore adds only a nonnegative check (NOT VALID), not the Production 0..10,000,000 range check | Partial overlap; not equivalent |
| `20261108115205 tighten_legacy_definer_paths_and_history_grants` | Pins search_path for `accept_electrician_job(uuid)` and `srk_link_electrician_profile()`; revokes history-table access from anon/authenticated, then grants authenticated SELECT and service_role ALL | Later branch hardening files pin other RPCs (financial, quote/work, and admin-application functions); no matching alteration for these two exact functions and no matching history-table grant block was located | No complete equivalent located |
| `20261108184254 electrician_earnings_summary` | Creates `srk_get_my_earnings()` returning `completed_at` and paid/completed electrician earnings | `20261109003000_secure_commission_reporting.sql` creates a closely related function, but names the timestamp output `booking_created_at`; its definition is not an exact signature match | Close candidate; return-column name differs |
| `20261108184815 protect_commission_columns_and_admin_report` | Creates admin commission report; revokes SELECT and commission-column UPDATE from authenticated | `20261109003000_secure_commission_reporting.sql` contains the same admin report body, but its permission statements differ and it also includes additional UPDATE grants and electrician earnings RPC work | Partial overlap; not equivalent as a whole migration |
| `20261108184938 limit_booking_updates_and_correct_earnings_timestamp` | Restricts booking UPDATE columns and replaces electrician earnings RPC with `booking_created_at` output | `20261109003000_secure_commission_reporting.sql` contains the same four-column UPDATE grant and a closely matching earnings query/output name, but bundles additional admin-report work and does not reproduce the exact preceding revoke sequence/body as a standalone migration | Close candidate; bundled and not a one-to-one migration match |

These comparisons are source-level only. A similar function body or overlapping statements do not establish replay equivalence, dependency safety, or identical grants. The five Production bodies were inspected read-only; no Production SQL was changed, no migration was applied, and no tests were run.


### 2026-11-16 follow-up: next five Production migration bodies compared (read-only)

The original SQL bodies for Production ledger entries `20261109052929`, `20261109053005`, `20261109053301`, `20261109053328`, and `20261109075837` were read from the Production migration ledger and compared with the current PR #8 replay-prep migration tree.

| Production version | Production change | PR-head comparison | Result |
|---|---|---|---|
| `20261109052929 harden_wallet_reporting_rpc_paths_and_route_recipient_index` | Pins three wallet/commission RPC search paths and creates `srk_route_transfers_recipient_user_id_idx` | `20261115210001_harden_legacy_financial_read_rpc_search_paths.sql` pins the same three functions, but the recipient-user index is not included in the located branch files | Partial match; index DDL absent from located candidates |
| `20261109053005 harden_wallet_and_commission_security_definer_paths` | Repeats the same three search-path changes and recipient-user index creation | Same later branch search-path migration covers the three function alterations, but no matching recipient-user index creation was located | Partial match; same index gap |
| `20261109053301 grant_authenticated_select_service_bookings` | Grants SELECT on `public.service_bookings` to authenticated | Current combined booking read policy defines row visibility but does not itself grant the table-level SELECT privilege; no matching grant statement was located in the checked migration candidates | No matching grant located |
| `20261109053328 grant_authenticated_select_job_offers_for_rls_realtime` | Grants SELECT on `public.job_offers` to authenticated | No matching table-level SELECT grant was located in the checked migration candidates | No matching grant located |
| `20261109075837 electrician_inspection_quotes_and_service_only_commission` | Adds quote columns/constraints, commission trigger logic, three quote/work RPCs, expanded offer-details RPC, grants, and quote-related status/assignment constraints | The branch quote workflow file is a close structural match, but its SQL is not identical: formatting aside, the grant/revoke blocks differ (branch explicitly revokes PUBLIC/anon), and the separate quote-state migration repeats constraint work; exact source/body reconciliation remains necessary | Close candidate; not one-to-one equivalent |

**Additional ledger observation:** Production entries `20261109052929` and `20261109053005` have effectively the same three ALTER FUNCTION statements and the same recipient index creation, with only formatting differences. This is duplicated deployed migration work, not evidence that the PR branch has both historical entries represented.

The comparison is static source inspection only. It does not prove whether an equivalent grant is inherited from the base setup or another uninspected SQL artifact. No Production SQL was changed, no migration was applied, and no replay or pgTAP tests were run.


### 2026-11-16 follow-up: next five Production migration bodies compared (read-only)

The original SQL bodies for Production ledger entries `20261109080121`, `20261109080400`, `20261109081310`, `20261109082241`, and `20261109082620` were read from the Production migration ledger and compared with the current PR #8 replay-prep migration tree.

| Production version | Production change | PR-head comparison | Result |
|---|---|---|---|
| `20261109080121 lock_quote_workflow_rpcs_to_authenticated_users` | Revokes PUBLIC/anon execution and grants authenticated execution on the four quote/offer RPCs | The branch quote workflow file contains the same four-function revoke/grant set | Strong match; this block is present inside a larger migration, not as a separate numbered file |
| `20261109080400 allow_quote_approval_booking_states` | Replaces booking status and assignment constraints for quote states | The malformed-name branch file `20261109_allow_quote_approval_booking_states.sql` contains the same two constraint operations; the quote workflow file also repeats them | Matching DDL is present, but duplicate execution/order and malformed version naming remain unresolved |
| `20261109081310 srk_manual_electrician_payout_ledger` | Creates payout ledger table, RLS/policy, payout trigger/function, and Admin mark-paid RPC | Branch contains a later payout reconciliation migration that replaces the payout trigger and Admin payout RPC, but no matching initial `CREATE TABLE public.srk_electrician_payouts` definition was located in the inspected migration tree | Critical predecessor DDL not located; later function replacement alone cannot create the missing table |
| `20261109082241 index_electrician_payout_foreign_keys` | Adds indexes on payout electrician profile and paid_by columns | No matching index creation was located in the current migration tree | No equivalent located; depends on payout table predecessor |
| `20261109082620 lock_down_route_transfer_api_access` | Creates deny-all client RLS policy on `srk_route_transfers` and revokes anon/authenticated privileges | Initial Route ledger migration revokes client access and grants service_role, but no matching deny-all RLS policy creation was located; a later branch migration drops the Route ledger table | Partial overlap; policy DDL not located and later table retirement changes the object lifecycle |

**Replay significance:** The Production payout ledger's initial table creation is a prerequisite for later payout-trigger/function alterations. The current branch contains later logic referencing `public.srk_electrician_payouts`, but the inspected migration files do not provide its original CREATE TABLE DDL. Do not infer or synthesize the historical table definition from later code; recover the authoritative source or schema export before replay planning.

These are static source comparisons. “Not located” is limited to the current PR #8 replay-prep migration tree and inspected candidates; it is not proof that no external historical artifact exists. No Production SQL was changed, no migration was applied, and no replay or pgTAP tests were run.


### 2026-11-16 follow-up: next five Production migration bodies compared (read-only)

Production ledger bodies `20261109094209`, `20261109103038`, `20261109103143`, `20261109110140`, and `20261109112032` were read and compared with the PR #8 replay-prep branch.

| Production version | Production change | PR branch comparison | Result |
|---|---|---|---|
| `20261109094209 add_secure_admin_booking_offer_flow` | Defines Admin RPC `srk_admin_offer_booking(uuid)`, selecting eligible electricians and creating offers | Later branch introduces a different sequential/nearest-first dispatch architecture using private dispatch/candidate tables and `private.srk_dispatch_next_booking_offer`; no same-function implementation was located | No direct equivalent; later design is a substantial workflow replacement, not a one-to-one replay substitute |
| `20261109103038 customer_electrician_direct_call_contacts` | Creates customer call-contact RPC with booking-status restrictions and authenticated-only execution | `20261109103038_customer_electrician_direct_call_contacts.sql` contains the same function logic and grants | Matching migration body located |
| `20261109103143 move_customer_call_contact_lookup_to_private` | Moves implementation into private schema and exposes an invoker wrapper | Same-named branch migration has the private implementation and wrapper, but also creates the private schema and its implementation omits the Production status filter | Similar, but not exact; inspect security and returned-row behavior before treating as equivalent |
| `20261109110140 align_electrician_payouts_with_booking_commission_rate` | Replaces payout trigger and Admin paid-out RPC to calculate commission from booking commission_rate and verify ledger amounts | Later branch payout reconciliation migration replaces these same routines with a broader category/manual-payment-aware implementation | Later successor logic exists, but it is not a body-equivalent replacement; dependency on the payout ledger table remains |
| `20261109112032 allow_electricians_to_read_own_manual_payout_status` | Adds authenticated SELECT policy allowing an electrician to read their own payout rows | No matching own-payout SELECT policy was located in the inspected branch migration candidates | No equivalent located; verify intended electrician visibility and RLS before replay |

**Important security/behavior note:** The Production private call-contact implementation restricts results to a defined set of active booking statuses. The branch private implementation shown in the matching file does not carry that status predicate. Do not treat this as a harmless formatting difference: it changes which booking rows can be returned by the helper, and the wrapper's effective access behavior needs review.

These findings are static comparisons only. “Not located” is scoped to the current branch migration tree and inspected candidates. No Production SQL was changed, no migration was applied, and no PostgreSQL replay or pgTAP test was run.


### 2026-11-16 follow-up: next five Production migration bodies compared (read-only)

Production ledger SQL bodies `20261109112105`, `20261109114000`, `20261109114642`, `20261109161539`, and `20261109161545` were inspected and compared with current PR #8 branch migrations.

| Production version | Production change | PR branch comparison | Result |
|---|---|---|---|
| `20261109112105 consolidate_electrician_payout_read_policy` | Replaces separate payout read policies with one authenticated policy allowing Admin OR owner-electrician reads | No matching policy consolidation / own-payout SELECT policy was located in the inspected branch migration set | RLS behavior needs explicit reconciliation; do not assume later payout function code supplies this table policy |
| `20261109114000 protect_customer_and_electrician_phone_numbers_until_masked_calling` | Temporarily masks phone numbers in customer-call RPC and electrician offer-details RPC | Branch contains direct phone fields in its customer-contact and offer-details implementations; no corresponding masking migration located | Historical privacy change is not represented as a distinct branch migration |
| `20261109114642 enable_direct_customer_electrician_phone_calls` | Restores direct phone number in both RPCs, retaining active booking-status filtering in customer-contact RPC | Branch direct-call migration restores phone; private implementation in branch does not retain the Production status predicate | Partial behavioral match; status-based scope differs |
| `20261109161539 customer_contact_after_completion` | Extends customer-call contact visibility to completed bookings while keeping other status restrictions | Branch private helper does not include the Production status allow-list | Not equivalent; branch function may return rows outside the intended active/completed status set |
| `20261109161545 hide_customer_details_on_cancelled_bookings` | Hides customer name, phone, address, GPS and quote fields when booking is cancelled; allows disclosure only for assigned active-through-completed statuses | Branch `20261114370000_electrician_offer_details_immediate_booking_fields.sql` includes `cancelled` in the CASE conditions that expose customer details | **High-priority privacy discrepancy:** branch offer-details RPC currently allows customer PII fields for cancelled bookings; Production migration explicitly hides them |

**Priority finding:** Review `20261114370000_electrician_offer_details_immediate_booking_fields.sql` before any rollout. Its disclosure condition includes `cancelled`, whereas the inspected Production privacy migration expressly excludes cancelled bookings. This is a source-level discrepancy, not a live exploit finding; no runtime test was performed.

The phone-number sequence in Production is chronological: mask phone numbers, restore direct calls, then allow customer-contact visibility after completion. The current branch must be checked against the intended final product/privacy policy rather than copying one intermediate historical migration in isolation.

“Not located” is scoped to the current branch migration tree and inspected candidates. No Production SQL was changed, no migration was applied, and no PostgreSQL replay or pgTAP test was run.


### 2026-11-16 follow-up: next five Production migration bodies compared (read-only)

Production ledger bodies `20261109163755`, `20261109164808`, `20261109165802`, `20261109170626`, and `20261109170937` were inspected against the PR #8 replay-prep migration tree.

| Production version | Production change | PR branch comparison | Result |
|---|---|---|---|
| `20261109163755 fix_null_validation_quote_and_payout` | Adds explicit NULL checks to quote response and Admin payout method validation | Branch quote/work RPC hardening migration only pins search paths; later payout reconciliation validates commission rate including NULL and has its own Admin payout checks, but no exact paired function-body replacement was located | Partial coverage only; NULL semantics must be checked per RPC |
| `20261109164808 sync_electrician_auth_profile_link` | Replaces auth-profile link trigger and expands job-offer SELECT policy to match either identity column | Branch identity-linking migration provides stricter synchronized identity handling; sequential dispatch uses canonical identity checks, but no exact matching job-offer SELECT policy replacement was located in inspected files | Related identity safeguards exist; policy behavior differs and needs RLS reconciliation |
| `20261109165802 harden_electrician_payable_trigger_search_path` | Replaces payout trigger with pinned search_path and legacy quote payout logic | Later branch payout reconciliation redefines the same trigger with pinned search_path and broader category/manual-payment rules | Later successor exists, but behavior is materially broader; replay must ensure payout table and all referenced category/payment objects precede it |
| `20261109170626 expire_job_offers_when_booking_cancelled` | Adds trigger to cancel offered/accepted job offers when booking status changes to cancelled | Sequential dispatch marks dispatch cancelled when it next runs against a non-offerable booking and cancels sibling offers on acceptance; no equivalent booking-cancellation trigger was located | No direct trigger equivalent located; cancellation may leave outstanding offers until another workflow acts |
| `20261109170937 secure_admin_booking_updates_and_profile_columns` | Revokes direct booking UPDATE; adds validated Admin booking-update RPC; restricts electrician profile UPDATE to active column | Branch later direct-write closure revokes authenticated booking UPDATE and supplies narrower quote/location RPCs, but it does not reproduce this exact status-transition RPC or the same profile active-only grant | Partial permission hardening; Admin workflow and profile column grants require explicit reconciliation |

**Priority follow-ups:** (1) Confirm cancellation immediately expires existing offered/accepted rows, not merely that later dispatch refuses to continue; (2) compare the exact job-offer SELECT policy with the branch's identity model; (3) verify the intended Admin status-update flow before replacing the Production RPC with narrower branch endpoints. The branch's later payout trigger is not a drop-in historical replay equivalent.

These are static source comparisons. “Not located” is scoped to the current branch migration tree and inspected candidates. No Production SQL was changed, no migration was applied, and no PostgreSQL replay or pgTAP test was run.


### 2026-11-16 follow-up: next five Production migration bodies compared (read-only)

Production ledger bodies `20261109171033`, `20261109171621`, `20261109171942`, `20261109174234`, and `20261109175023` were inspected against the current PR #8 branch.

| Production version | Production change | PR branch comparison | Result |
|---|---|---|---|
| `20261109171033 tighten_admin_booking_rpc_input_validation` | Tightens address/district/state/PIN validation in Admin booking update RPC | Branch direct-write closure replaces the older Admin status RPC with separate quote/location RPCs; location RPC validates non-empty lengths and six-digit PIN but does not reproduce the same status-transition workflow | Not a drop-in replacement; Admin workflow and validation contract differ |
| `20261109171621 add_admin_verified_manual_payment_workflow` | Creates manual-payment audit table, Admin record-payment RPC, and updates payout trigger to accept verified manual payments | Branch legacy manual-payment migration extends a related workflow with category guards, paise-based split reconciliation, and stricter payout checks; it assumes the manual-payment table already exists and does not recreate the Production table DDL in that file | Partial successor only; table creation and exact historical contract must be recovered/reconciled |
| `20261109171942 add_admin_verified_manual_refund_workflow` | Creates manual-refund audit table and Admin manual-refund RPC, rejecting Razorpay-linked refunds and already-paid electrician payouts | Branch manual-refund completion uses approved refund requests, labour bills and cancellation-fee accounting, with a materially different contract; no exact initial table/RPC replay equivalent located | Not equivalent; ensure all required refund request/payment/payout dependencies exist before branch refund code |
| `20261109174234 allow_manual_payment_payout_settlement` | Extends payout settlement verification to allow a matching manual-payment audit row as well as Razorpay payment | Branch payout reconciliation contains manual-payment-aware payout handling, but uses newer category/labour-bill rules and does not preserve this exact legacy predicate | Related successor behavior exists, not an exact replacement |
| `20261109175023 serialize_manual_refund_and_electrician_payout` | Serializes payout settlement and manual refund with a shared booking-first lock order, then payout-row lock | Branch later financial RPC hardening and refund flows use booking-first locking in some paths; no exact matching replacement of this complete lock-order protocol was located in inspected candidates | Concurrency invariant needs explicit preservation and transaction-level testing |

**Replay blockers / checks:** The two Production audit-table definitions (`srk_manual_payment_entries`, `srk_manual_refund_entries`) are schema prerequisites, not merely RPC implementation details. Confirm their exact constraints, unique keys, RLS, and grants in the branch's canonical replay chain. Preserve the booking-first lock order across payout and refund paths to prevent concurrent settlement/refund races. Branch's later refund architecture is broader and must not be treated as an exact historical substitute.

“Not located” is scoped to the current branch migration tree and inspected candidates. These are static SQL comparisons only; no Production SQL was changed, no migration was applied, and no PostgreSQL replay or pgTAP test was run.


### 2026-11-16 follow-up: next five Production migration bodies compared (read-only)

Production ledger bodies `20261109180001`, `20261109202321`, `20261109202355`, `20261109202505`, and `20261109202511` were checked against the PR #8 branch migration tree.

| Production version | Production change | PR branch comparison | Result |
|---|---|---|---|
| `20261109180001 fix_manual_payout_special_forms` | Replaces payout-paid RPC with shared booking-first then payout-row locking and manual/Razorpay payment verification | Branch financial RPC/search-path hardening and payout reconciliation contain related checks, but no exact equivalent of this complete legacy RPC/lock protocol was located | Preserve lock order explicitly; not an exact match |
| `20261109202321 admin_audit_log` | Creates audit event table, allowlisted audit trigger function, triggers on six sensitive tables, and Admin list RPC | Branch `20261114125844_restore_financial_audit_core_schema.sql` creates audit table and financial relations, but no matching audit capture trigger/list RPC implementation was located in the branch migration tree | Schema foundation exists; audit capture and read API appear incomplete in replay chain |
| `20261109202355 razorpay_refund_tables_and_audit_type` | Creates Razorpay refund table, indexes/RLS/grants, webhook refund ID column, and expands audit entity type | Branch `20261114125844_restore_financial_audit_core_schema.sql` recreates the refund table and related refund-request/manual-refund relations with RLS and service-role grants; branch durable recovery migration adds append-only provider evidence. However, the exact webhook-column alteration and Production index/constraint sequence need separate confirmation | Broad schema successor exists; not an exact one-to-one replay |
| `20261109202505 razorpay_refund_prepare_rpc` | Admin RPC validates verified Razorpay payment and approved quote, blocks paid payouts, creates idempotent refund intent | Branch refund architecture has review queue and durable recovery evidence, but no matching Admin prepare-Razorpay-refund RPC was located by migration-tree search | No direct prepare-RPC equivalent located; verify the application calls a supported replacement |
| `20261109202511 razorpay_refund_list_rpc` | Admin-only paginated/list RPC for Razorpay refund records | Branch review queue exposes refund state as part of customer refund requests; no equivalent standalone Razorpay refund-list RPC was located | UI/API contract differs; ensure Admin visibility is fully covered |

**Important audit finding:** Branch financial core migration restores several required tables, but a table alone does not replace Production's audit trigger pipeline. Without the capture function, per-table triggers, and Admin list RPC, the schema may store audit rows without automatically generating them or exposing the intended review interface. Confirm whether another non-migration deployment artifact supplies these functions before treating the branch replay as complete.

These are static source comparisons. “Not located” is scoped to the current branch migration tree. No Production SQL was changed, no migration was applied, and no PostgreSQL replay or pgTAP test was run.
