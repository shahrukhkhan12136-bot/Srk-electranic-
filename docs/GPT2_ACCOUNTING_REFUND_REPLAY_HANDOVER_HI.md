# GPT-2 Handover — Accounting Bridge / Refund Replay
**Date:** 2026-11-17  
**Source branch:** `feat/customer-login-first-dashboard-20261114`  
**Audit branch:** `chore/pr8-replay-audit-20261116-v2`  
**PR:** #8 — remains Draft / unmerged.  
**Scope:** source comparison and recommendations only. No Audit Branch edits, database writes, migrations, deployment, merge, or provider operations.

## 1. Verified source snapshots

| Item | Feature Branch | GPT-2 Audit Branch |
|---|---|---|
| Accounting Bridge migration | `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` — blob `b23c494fece2b09510008e515a7136639ff81672` | same path — blob `68189051090a51bef26a98997caf103b62ed070c` |
| Refund Replay migration | `20261115250000_harden_refund_reconcile_full_amount.sql` — blob `0bdae500bcfda3721d8de4371695be08ba8e5f36` | same path — blob `3bda81c2b827f597f639846d33967a7c88296e21` |

Branch comparison at review time: Feature was 75 commits ahead and 255 behind Audit; branches are diverged. Do not merge/rebase them directly.

## 2. Accounting Bridge differences

The Feature version defines these five functions with `SET search_path = ''`:
- `srk_set_booking_commission_before_payout()`
- `srk_validate_booking_commission_payout_parity()`
- `srk_admin_get_booking_accounting_reconciliation(uuid)`
- `srk_admin_commission_report()`
- `srk_get_my_earnings()`

Audit version uses non-empty paths for four of these five:
- Commission BEFORE function: `pg_catalog, public, pg_temp`
- Payout parity AFTER function: `pg_catalog, public, pg_temp`
- Admin commission report: `public, pg_temp`
- Electrician earnings: `pg_catalog, public, auth, pg_temp`
- Accounting reconciliation is already `search_path = ''` in both.

**Recommendation for GPT-2 review:** consider aligning the four Audit definitions to the Feature empty-search-path pattern only after checking every relation, function, type, operator, and auth reference in the complete function bodies is schema-qualified. Do not mechanically change search_path without this body-level qualification review. No change has been made to Audit.

### Trigger contract / replay dependency

Feature Bridge adds:
- `zz_srk_set_booking_commission_before_payout` BEFORE trigger.
- `zz_srk_validate_booking_commission_payout_parity` AFTER trigger.

The Feature pgTAP bridge test asserts the timestamped Bridge's commission trigger is attached to `public.service_bookings` and calls `public.srk_set_booking_commission_before_payout()`. It also asserts the payout-creation trigger sorts before the parity trigger. The latest test-plan count noted in the prior source audit is 23; this is a static test contract, not proof of PostgreSQL execution.

A prior attempt placed the legacy `srk_calculate_booking_commission` trigger attachment in malformed 8-digit migration `20261109_electrician_inspection_quotes_and_service_only_commission.sql`; that attachment was removed in commit `7552361214ec5108bde001d43d959c263ce8f484`. Test assertion was updated in `0212221b2b27cfa650918f5632619f93f3da7fe8`. The separate payout-creation trigger attachment is in timestamped migration `20261114360000_new_category_electrician_payout_reconciliation.sql` (Feature source only).

**Important:** the migration dependency/replay sequence is still provisional. Do not infer a safe clean replay order from trigger names or static pgTAP checks alone.

## 3. Refund Replay difference

Feature migration includes additional guarded repair logic not present in Audit:
- Locks the payout after booking/refund in the documented booking → refund → payout order.
- When provider status is `processed`, a payout in an unexpected state fails closed with `ELECTRICIAN_PAYOUT_STATE_REQUIRES_MANUAL_RECONCILIATION`.
- A blocked payout is eligible for automatic replay repair only when its note exactly matches `Razorpay refund pending`; otherwise it raises `ELECTRICIAN_PAYOUT_BLOCK_REASON_MISMATCH`.
- For an already-processed refund, the exact refund-owned blocked payout can be changed to `refunded` with note `Razorpay full refund verified; payout permanently withheld.`
- The UPDATE is conditional on the exact blocked status/note and raises if it cannot close the payout.

Audit version lacks these additional replay-repair guards/branches.

**Recommendation for GPT-2 review:** preserve the Feature behavior as a candidate patch, but independently verify transaction/idempotency semantics, refund-row lock order, payout audit-trigger capture, provider replay paths, and all fail-closed branches before porting. Do not replace Audit's version wholesale or cherry-pick across the diverged branches without a reviewed patch plan.

## 4. Provisional dependency matrix

| Phase | Dependency / contract | Review status |
|---|---|---|
| 0 | Authoritative base schema, roles, extensions, RLS/ACL, Auth identity mapping | unresolved baseline/replay prerequisites |
| 1 | `service_bookings.amount_paid` and electrician identity column contracts | source DDL now exists for amount_paid; confirm exact lineage and identity contract |
| 2 | Labour bill snapshot / immutable bill and verified payment evidence | source-level dependency; runtime not replayed |
| 3 | Commission calculation BEFORE trigger and rate validation | Feature trigger attachment present; order needs runtime verification |
| 4 | Electrician payable creation AFTER trigger | Feature timestamped attachment present |
| 5 | Commission/payout parity AFTER trigger | Feature Bridge trigger present; alphabetic ordering is only static evidence |
| 6 | Payout audit trigger / append-only audit table | source trigger and static guards found; runtime behavior unverified |
| 7 | Admin accounting reconciliation, commission report, electrician earnings | Feature/Audit function definitions differ |
| 8 | Manual refund completion and Razorpay refund reconciliation/replay | replay-repair difference documented above |
| 9 | Route-retired reconciliation contract and Admin Manual Payout policy | user-approved design; no Production action |

## 5. Replay blockers / test limits

- The repository manifest records duplicate 8-digit `20261109` migration version lineage; do not rename/delete/resequence or edit remote history without owner-approved evidence and pinned-CLI scratch testing.
- A complete authoritative baseline and migration ordering are not yet proven.
- The available Supabase Test project was previously checked and lacks core finance tables including `service_bookings`, `srk_admin_audit_events`, `srk_booking_labour_bills`, `srk_booking_refund_requests`, `srk_electrician_payouts`, `srk_manual_payment_entries`, and `srk_razorpay_refunds`.
- Main Supabase project is Production and must not be used for replay.
- Node CI success does not equal PostgreSQL migration replay or pgTAP runtime success.
- No safe full PostgreSQL runtime environment is currently available. Do not create a paid Supabase branch/project without explaining cost and obtaining explicit approval.

## 6. Decisions / requested GPT-2 review

1. Review the four non-empty search_path functions in Audit and decide whether to align them after complete qualification audit.
2. Review Feature Refund Replay repair semantics and identify any contract conflicts with Audit's refund workflow.
3. Agree on one final Accounting Bridge contract and one Refund Replay contract before any integration.
4. Keep Route Transfer retired; preserve historical records; use Admin Manual Payout for electrician payouts as already approved.
5. Keep PR #8 Draft. No merge, Production migration, deployment, payout/refund action, or Audit Branch modification is authorized by this handover.

**Evidence classification:** all findings above are source/blob comparisons or prior static catalog/test observations. PostgreSQL runtime replay and pgTAP execution remain unverified.


## 7. Additional Feature-branch correction — refund trigger interaction (Nov 17)

A source-level control-flow review found an interaction between the provider refund RPC and the payout-creation trigger:
- The refund RPC changes `service_bookings.payment_status` to `refunded`.
- That update fires `srk_create_electrician_payable()`, whose refund branch can itself change the refund-owned blocked payout to `refunded` and clear `payout_note`.
- The RPC then attempted a second UPDATE requiring the payout still be `blocked` with note `Razorpay refund pending`; without handling the trigger's prior transition, it could raise `BLOCKED_PAYOUT_COULD_NOT_BE_CLOSED_AS_REFUNDED` and roll back the provider reconciliation transaction.

Feature branch correction:
- Commit `06f102e1cae57cb4cf40b2870092325f0fb342ac` updates `supabase/migrations/20261115250000_harden_refund_reconcile_full_amount.sql`.
- After attempting the exact blocked-payout transition, the RPC now accepts only the trigger-produced state `payout_status='refunded' AND payout_note IS NULL`, then restores the final provider-confirmed audit note. It does not overwrite any non-null note or accept other payout states.
- Commit `d4b2102db57eadfbb6f9433a356527705113ad99` updates `supabase/tests/database/refund_reconcile_full_amount_guard.test.sql`, increasing the static pgTAP plan from 9 to 10 and asserting the trigger-closure fallback and final note restoration.

**Verification boundary:** GitHub source diffs and fetched file contents were rechecked. The associated Node workflow run was pending at the time of this report update. The pgTAP assertion is static and has not been executed against PostgreSQL. GPT-2 should review the new correction before any branch integration.


### Follow-up verification (after the commits above)

- Re-read all five Feature Accounting Bridge function bodies. All application tables/types are explicitly schema-qualified under `search_path = ''`; Auth calls use `auth.uid()`, and the Admin predicate uses `public.is_srk_admin()`. Unqualified calls in the bodies are PostgreSQL built-ins resolved through implicit `pg_catalog`.
- The two trigger-only SECURITY DEFINER functions revoke direct execute from `public`, `anon`, and `authenticated`. The RPC ACLs for the reconciliation/report/earnings functions are inherited from their earlier definitions and must be confirmed in a clean replay/catalog test.
- Feature Node workflow for test commit `d4b2102db57eadfbb6f9433a356527705113ad99` completed successfully: run `44032065222`, job `133866127480`, all workflow steps successful.
- This Node workflow does **not** execute PostgreSQL migrations or pgTAP. The added pgTAP test remains runtime-unverified.


## 8. Commission trigger clean-replay conclusion (Nov 17)

Further migration-source review resolved the earlier open question about the legacy commission trigger:

- The malformed file `20261109_electrician_inspection_quotes_and_service_only_commission.sql` defines `public.srk_calculate_booking_commission()`, but contains no `CREATE TRIGGER` attachment. GitHub code search also found no separate migration attaching this trigger. Therefore a clean replay of the numbered migration set does not attach that legacy function.
- The function's former behavior was to validate nonnegative `amount_paid` / `service_charge`, validate commission rate, compute commission from legacy `service_charge` for completed+paid rows, and otherwise clear `commission_amount`.
- The timestamped Accounting Bridge migration explicitly attaches `zz_srk_set_booking_commission_before_payout` to INSERT and the relevant UPDATE columns. Its BEFORE function handles **both** workflows:
  - New-category bookings: requires the immutable labour bill to exist, be positive, and match the assigned electrician; computes commission from that bill.
  - Legacy quote bookings: when `selected_category IS NULL`, requires `quote_status='approved'` and computes commission from `service_charge`.
  - For both qualifying paths it validates `commission_rate` is 0–100 and sets `commission_amount`.
- Thus the Bridge trigger is the effective commission-calculation trigger for clean replay; adding the old trigger attachment is not required and would add a second overlapping BEFORE trigger. On a database where the old trigger already exists, its alphabetical name sorts before `zz_srk_set...`; the Bridge calculation overwrites its commission result for qualifying rows, including new-category bookings.

**Remaining nuance:** the old function cleared `commission_amount` when a booking ceased to be completed+paid; the Bridge function returns without clearing it for non-qualifying states. Reports filter to completed+paid, and payout history is retained, but this behavioral difference should be consciously accepted or covered by a specific state-transition test before release. Do not add the old trigger blindly.

**Conclusion:** no migration edit is recommended at this point. The prior "legacy commission trigger missing" concern is downgraded from a clean-replay blocker to a documented legacy-function/transition-semantics difference. Runtime migration replay and pgTAP are still required before release.


### Migration inventory re-count

The Feature Branch migration directory was fetched and parsed directly:
- 88 SQL migration files total.
- 86 valid 14-digit timestamped migrations.
- Exactly 2 malformed non-timestamped files: `20261109_allow_quote_approval_booking_states.sql` and `20261109_electrician_inspection_quotes_and_service_only_commission.sql`.
- No duplicate 14-digit migration versions.

This confirms the two known malformed filenames; do not silently rename or delete them. Their effect on Supabase CLI replay still requires a pinned-version isolated CLI test.


## 9. Legacy commission state-transition parity correction (Nov 17)

The legacy function body was re-read directly. It explicitly sets `NEW.commission_amount := NULL` whenever the row is not both `status='completed'` and `payment_status='paid'` (or amount/service-charge eligibility is missing). The Bridge function previously returned without clearing the old commission value on non-qualifying transitions.

Feature-branch correction:
- Commit `78b22b37ab7f7565ab183e34d399b1738ab9e0ff` updates the Bridge BEFORE trigger function to set `NEW.commission_amount := NULL` before returning for non-qualifying/unverified booking states.
- Commit `2ce98dc1310b0765269d28ae9be53b61cd875cef` increases the Accounting Bridge pgTAP static plan from 23 to 24 and asserts that the trigger function includes this clearing behavior.

This preserves the legacy state-transition contract without attaching the legacy trigger a second time. The payout ledger's historical values remain separate; this change only updates the booking commission field on qualifying trigger events.

**Verification boundary:** source diffs were committed to Feature Branch. PostgreSQL runtime pgTAP has not been executed. Node CI result for these latest commits is pending.


Latest CI tracking: workflow run `44032550519` was initially cancelled during the Node test step; its cancelled job was explicitly re-run. At the latest check, the rerun was `in_progress` (job `133867852566`). Do not treat it as passed until GitHub reports a completed success conclusion.


## 10. Full PostgreSQL migration replay gate (Nov 17)

A fresh dependency/replay review was performed against the current Feature Branch migration directory and the connected Supabase project catalogs. No database writes were made.

### Source-tree findings
- Feature Branch currently has 88 SQL files: 86 timestamped migrations and two malformed non-timestamped files:
  - `20261109_allow_quote_approval_booking_states.sql`
  - `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
- Both malformed files contain live DDL against `public.service_bookings`; the second also defines quote workflow RPCs and the legacy commission function. They are not safely treated as normal timestamped migration history.
- The first timestamped feature migration that alters `public.service_bookings` is `20261108121115_add_customer_account_booking_access.sql`. It assumes the base `service_bookings` table and its columns/policies already exist; this branch does not contain a complete initial schema migration for that base table.
- The timestamped accounting sequence has clear dependencies: audit core (14125844) creates financial ledger/audit structures; cancellation-fee accounting (14280000) uses wallet, cancellation, and immutable labour-bill objects; payout reconciliation (14360000) uses labour bills, manual payment entries, cancellation-fee items and payout ledger; manual refund/reconciliation migrations build on those; amount_paid restoration (16200000) precedes the final accounting bridge (17010000).
- The current Main Supabase migration history includes earlier valid migration versions for quote/commission work (including versions `20261109075837` and `20261109080400`), while the Feature Branch contains similarly named SQL in the two malformed files. This is a migration-history/name alignment issue that must be resolved with an owner-reviewed baseline/replay plan, not by renaming files ad hoc.

### Connected database findings (read-only)
- Main project migration history has many already-applied production versions through Nov 15. It is not a disposable clean baseline and must not be reset or used for replay.
- The connected `SRK ELECTRONIC TEST` project still has only seven push-test migrations and lacks the required booking, financial audit, labour bill, refund, payout, and manual-payment tables. It cannot run the PR #8 SQL suite in its current state.
- No complete baseline schema snapshot or local Docker/PostgreSQL runtime is available in the current execution environment.
- Supabase's current environment guidance says reproducibility requires sequential migration replay from a suitable baseline; a full reset replays migrations in order. The existing repository workflow is not a safe substitute: it is guarded to an unrelated old branch, requires a schema-export secret, and applies a hard-coded five-migration list unrelated to this PR8 chain.

### Decision / gate
- Do **not** run `db reset`, `db push`, `apply_migration`, or any DDL against Main or the incomplete Test project.
- Do **not** create a paid Supabase branch/project. That remains deferred pending completion of implementation and explicit cost approval if later required.
- Before runtime replay, the owner/GPT-2 must agree on the canonical baseline and how the two malformed files map to the already-applied migration history. Then replay the complete ordered chain on a disposable local or approved isolated database and run the full pgTAP suite.
- This pass made no SQL migration edits. PR #8 remains Draft/Open/unmerged; Audit Branch and Production remain untouched.


## 11. Malformed quote migration ↔ Main history reconciliation (Nov 17)

A direct comparison was made between the current Feature Branch migration tree and the live Main Supabase `list_migrations` catalog (read-only).

### Exact / likely mappings
1. Feature file `20261109_allow_quote_approval_booking_states.sql` has SHA `ef4bf8b9b8a9a35bf3ddd94ea4614c7498fb1c6d`. Its SQL body matches the patch in Git commit `cd2c46e6e938ba7813eeb6461769f2a796ad3d93`. Main's applied history has version `20261109080400`, name `allow_quote_approval_booking_states`. This is a strong exact content/name mapping to the applied version, but the file is still malformed in Feature and is not yet renamed.
2. Feature file `20261109_electrician_inspection_quotes_and_service_only_commission.sql` SHA `014699d3190e45aacde4022ac7e7fa9ca4fec006` appears to correspond by name and SQL scope to Main's applied `20261109075837`, name `electrician_inspection_quotes_and_service_only_commission`. The original migration body for that applied version was not recovered from the current repository, so byte-for-byte equivalence is **not proven**. Do not rename it based on name alone.

### Additional applied migration absent by filename
Main history also contains `20261109080121` / `lock_quote_workflow_rpcs_to_authenticated_users`. No corresponding timestamped file exists in the Feature Branch migration directory. The malformed quote migration itself includes explicit revoke/grant statements for the quote/work-status RPCs, and later Feature hardening migrations exist, but this does not prove that the full original 09080121 migration behavior is reproduced. Its exact SQL still needs recovery or a schema/ACL equivalence review.

### Full history comparison
- Live Main Supabase migration history: 87 applied versions.
- Feature Branch migration directory: 88 SQL files (86 timestamped, 2 malformed).
- Only 7 timestamped version IDs overlap exactly between the 86 valid Feature files and the 87 live Main history versions.
- 79 Feature timestamped versions are not present in Main history (expected candidates for pending branch work, subject to dependency validation).
- 80 Main applied version IDs have no same-version timestamped file in the Feature directory. Two malformed Feature files appear to be intended counterparts to Main versions 09075837 and 09080400, but only 09080400 has a recovered exact patch match. One further applied Main version 09080121 has no counterpart file identified.
- Main's live schema has the quote columns and quote-related booking status values, but catalog presence alone does not prove every RPC grant, trigger, policy, or historical migration side effect.

### Required resolution (no edits made)
- Recover the authoritative SQL for applied versions 09075837 and 09080121 (for example from the original migration source/backup or a reviewed database schema/ACL export).
- Compare each original SQL body against Feature's current malformed/valid files and record exact semantic equivalence.
- Only then propose canonical timestamped filenames and decide whether the branch should retain already-applied historical versions as migration files. Do not simply rename and run them: Main already records these versions as applied, and the branch's full migration set is not a clean replay baseline.
- No migration files were renamed, deleted, or applied. No Main/Test DDL was executed.


## 12. Recovery of quote migration source and live ACL evidence (Nov 17)

### 09075837 source recovery
- GitHub file history for the malformed quote workflow file shows:
  - `073d59e64672ee436783338dc3842c35e920a078`: initial placeholder stating the migration was applied.
  - `04d0c02f03cd7fb27d9b699b109dedc0fa0e0bad`: full 99-line SQL workflow migration.
  - `b5e5b3bf2555bde77d17fde1e8e1d62a67b58f2b`: adds the booking status and assignment constraints.
- The current Feature file is byte-identical to the file at commit `b5e5b3b...` (blob SHA `014699d3190e45aacde4022ac7e7fa9ca4fec006`, 9,568 bytes).
- The Main migration ledger records version `20261109075837` with the exact matching name `electrician_inspection_quotes_and_service_only_commission`. This is now a high-confidence filename/name/source mapping. However, the original Main-applied SQL blob is not available in the repository's current history, so byte-for-byte identity with the SQL originally applied to Main is still not proven.

### 09080121 live security effect
- Main migration ledger records `20261109080121` / `lock_quote_workflow_rpcs_to_authenticated_users`, but no same-version migration file is present in the Feature tree and no historical source file was recovered.
- Read-only Main catalog inspection of the four quote/workflow RPCs found all four are SECURITY DEFINER with pinned `search_path = pg_catalog, public, auth, pg_temp`.
- Effective EXECUTE privileges for each of these four RPCs: `anon=false`, `authenticated=true`, `public=false`.
- The four inspected RPCs are `srk_submit_booking_quote`, `srk_customer_respond_booking_quote`, `srk_update_booking_work_status`, and `srk_get_my_offer_details`.
- This confirms the **current live security outcome** is locked to authenticated users. It does not recover the original 09080121 SQL nor prove that the Feature migration set reproduces every statement in that migration.

### Important live-vs-source divergence
- Main's current `srk_update_booking_work_status` accepts only `inspection`; its current body explicitly rejects `in_progress` and `completed` transitions, requiring customer approval for work start/completion. The malformed Feature source still includes those broader transitions.
- Main's current `srk_get_my_offer_details` additionally masks customer fields unless the booking is in an allowed assigned/work state.
- Main's current `srk_submit_booking_quote` resolves electrician profiles using both `user_id` and `auth_user_id`, orders by `created_at`, and uses a numeric total variable.
- These are live/current function definitions and may reflect later migrations or manual changes; do not back-port them blindly into the historical 09075837 migration. Reconcile against the later timestamped migrations and GPT-2's audit findings first.

### Replay decision
- The original Feature source for 09075837 has now been recovered from Git history, but no migration rename or replay is authorized.
- 09080121 remains a source-recovery gap; live ACL evidence establishes its present effect only.
- Keep both malformed files unchanged until the owner/GPT-2 approves a canonical baseline and migration-history alignment plan.
- All Main queries were read-only SELECT/catalog inspection. No DDL, migration application, or Production writes occurred.


## 13. Additional 09080121 ACL coverage review (Nov 17)

### Feature source already contains the core ACL statements
The recovered malformed Feature file `20261109_electrician_inspection_quotes_and_service_only_commission.sql` includes explicit:
- `REVOKE ALL ... FROM public, anon` for all four quote/workflow RPCs;
- `GRANT EXECUTE ... TO authenticated` for the same four RPCs.

The four exact signatures are:
- `srk_submit_booking_quote(uuid,numeric,numeric,text)`
- `srk_customer_respond_booking_quote(uuid,text)`
- `srk_update_booking_work_status(uuid,text)`
- `srk_get_my_offer_details()`

An earlier timestamped migration `20261109002000_expose_assigned_booking_map_pin.sql` independently revokes PUBLIC/anon and grants authenticated on `srk_get_my_offer_details()`.

### Interpretation of missing 09080121
- This means the **observable ACL effect** attributed to locking the four quote/workflow RPCs is already represented in Feature source, and Main live catalog confirms the same effective privilege outcome.
- It does not prove that the missing Main migration `20261109080121` had no other statements or that every original SQL statement is represented.
- Therefore keep 09080121 marked as a historical source-recovery gap, but do not add a duplicate ACL migration solely to repeat the four grants/revokes.

### Remaining source/behavior discrepancy
- Main's live `srk_update_booking_work_status` is more restrictive than the recovered malformed Feature SQL: live permits only `inspection`, rejecting `in_progress` and `completed` in this RPC.
- Main's live `srk_get_my_offer_details` masks personal/contact and quote fields unless the booking is in an allowed assigned/work state; the recovered malformed Feature source gates those fields only on assigned-electrician identity.
- These are current Main function definitions, not proven contents of migration 09080121. Their origin may be later migrations or later changes. Do not treat them as missing 09080121 SQL without further provenance.

### Evidence and safety
- Feature migration tree was re-listed: there is no valid timestamped file for 09080121, and no later timestamped quote/work-status replacement was found in the inspected migration range.
- Main privilege/function catalog checks were read-only SELECTs.
- No source SQL, migration name, or live database object was changed in this pass.


## 14. Main live quote/work-status behavior vs migration ledger (Nov 17)

### Read-only Main migration ledger check
Main project migration ledger confirms these historical entries:
- `20261109080121 lock_quote_workflow_rpcs_to_authenticated_users`
- `20261109161539 customer_contact_after_completion`
- `20261109161545 hide_customer_details_on_cancelled_bookings`

The ledger does **not** list Feature-branch later migrations:
- `20261114240000_server_authoritative_customer_approved_work_timer.sql`
- `20261115220000_retire_live_legacy_quotation_rpcs.sql`

### Current Main function definitions (read-only catalog query)
- `srk_update_booking_work_status(uuid,text)` explicitly rejects every `p_status` except `inspection`, with message that customer approval is required to start and complete work. For the allowed case, it requires an assigned, approved, active electrician and only transitions `assigned -> inspection`.
- `srk_get_my_offer_details()` exposes customer name/phone/address/location and legacy quote fields only when the electrician is the assigned electrician and booking status is one of `assigned, inspection, awaiting_quote_approval, quote_approved, in_progress, completed`. Cancelled and unassigned bookings are masked. The RPC resolves electrician profile using `p.user_id=auth.uid()` (not `auth_user_id` in this current Main definition).

### What can and cannot be concluded
- The current offer-details masking is consistent with the purpose of the Main ledger entries `customer_contact_after_completion` and `hide_customer_details_on_cancelled_bookings`, but without their original SQL source this is a semantic match, not proof of exact migration contents.
- The current inspection-only work-status RPC body is a live security restriction. Its exact originating migration/commit has not been recovered; do not attribute it to 09080121 or either contact-visibility migration without source evidence.
- The later Feature migration `20261115220000_retire_live_legacy_quotation_rpcs.sql` is a different, newer design: it revokes and drops the three legacy quote/work-status RPCs, and replaces offer-details with the server-timer contract. Its status-based contact guard covers `assigned, awaiting_work_start_approval, in_progress, completed, cancelled`, and it resolves both `user_id` and `auth_user_id`. This migration is not in Main's applied migration ledger, so do not assume Production has this newer contract.
- Feature's `20261114240000_server_authoritative_customer_approved_work_timer.sql` still contains legacy RPC definitions for historical rows, but blocks their use for new-category bookings; the later `15220000` migration retires those RPCs entirely. Both are Feature-branch source only in this review.

### Safety / next step
All Main checks in this section were read-only: migration ledger listing and SELECT of `pg_get_functiondef`. No Main DDL, data writes, migration application, or Production configuration changes occurred. The remaining provenance gap is the original SQL/commit for Main versions `09161539` and `09161545`, plus the exact source change that narrowed the live work-status RPC to inspection only.


## 15. Main Customer Call-Contact RPC — completed/cancelled visibility audit (Nov 17)

### Main live definitions (read-only catalog inspection)
- Public wrapper: `public.srk_get_customer_call_contacts()`
  - SQL, STABLE, SECURITY INVOKER.
  - Calls `private.srk_get_customer_call_contacts_impl()`.
  - Current `search_path = public, private, pg_temp`.
- Private implementation: `private.srk_get_customer_call_contacts_impl()`
  - PL/pgSQL, STABLE, SECURITY DEFINER.
  - Pinned `search_path = pg_catalog, public, auth, pg_temp`.
  - Requires non-null `auth.uid()`.
  - Returns electrician name/phone only for the authenticated customer's own bookings, with an assigned electrician, and status in:
    `assigned, inspection, awaiting_quote_approval, quote_approved, in_progress, completed`.
  - Cancelled bookings are excluded. Completed bookings remain eligible.
- Effective EXECUTE privilege for both wrapper and private implementation: `anon=false`, `authenticated=true`.
- The private implementation is SECURITY DEFINER; public wrapper is SECURITY INVOKER. The wrapper therefore exposes only the implementation's filtered result to authenticated callers.

### Feature source comparison
- Feature migration `20261109103038_customer_electrician_direct_call_contacts.sql` initially created the public SECURITY DEFINER RPC with a status allow-list that excluded completed bookings.
- Feature migration `20261109103143_move_customer_call_contact_lookup_to_private.sql` moved the lookup into a private SECURITY DEFINER implementation and replaced the public function with a SECURITY INVOKER wrapper.
- In that Feature migration's private implementation, the WHERE clause checked customer ownership and non-null assigned electrician, but had **no booking-status filter**. Therefore that historical Feature source would include cancelled as well as completed bookings.
- Main's current implementation has a deliberate status allow-list: completed included, cancelled excluded. This is consistent with the intent signalled by Main ledger versions `20261109161539 customer_contact_after_completion` and `20261109161545 hide_customer_details_on_cancelled_bookings`, but their original SQL bodies were not recovered. Do not claim exact historical source equivalence.

### Related Main migration history
Main ledger also records:
- `20261109114000 protect_customer_and_electrician_phone_numbers_until_masked_calling`
- `20261109114642 enable_direct_customer_electrician_phone_calls`
- `20261109161539 customer_contact_after_completion`
- `20261109161545 hide_customer_details_on_cancelled_bookings`

The live RPC behavior is compatible with the latter two names: completed calls allowed; cancelled calls hidden. The original migration bodies and exact chronological diffs remain unavailable, so provenance remains a semantic correlation only.

### Security conclusion and follow-up
- Current Main customer call-contact RPC is authenticated-only and status-filtered; cancelled bookings are excluded and completed bookings are included.
- The Feature branch's historical private implementation does not reproduce this status filter. A later Feature migration or current source replacement must be checked before any replay/equivalence claim.
- No code or migration was changed in this audit section. All Main checks were read-only catalog/privilege SELECTs. No Production DDL, data write, migration application, deployment, or configuration change occurred.


## 16. Phone privacy decision history and direct-call source comparison (Nov 17)

### Recovered Git decision history (Nov 9 UTC)
The repository commit history around the phone-visibility change provides the following sequence:
- `58259351074895b656c6ea6926619609eb7a9f89` (11:40:55Z): hide direct electrician phone number until masked calling is ready.
- `4bbfc6ee12638fc65e7277d7ba9df9e48e66ae0f` (11:40:57Z): hide direct customer phone number until masked calling is ready.
- `2dce997bd0029bbbd9ab04a4965072bf9cf2e628` (11:41:54Z): documentation records masked calling / Exotel GreenPin candidate, OTP ownership verification, and that both real numbers remain hidden until provider activation.
- `a61843d92acc22847078055d138af754dae700cd` (11:47:27Z): restores customer's ability to see assigned electrician phone and direct-call.
- `ffb9f1a5316beda02264b62046c78a6ff15c5d0b` (11:47:30Z): restores assigned/approved electrician's ability to see customer phone and direct-call.
- `ea50a8d0254405fa40b65eca734469a0dd22978b` (11:47:35Z): explicitly documents the owner's updated decision: masked calling / Exotel is not to be implemented now; direct calls are allowed for an assigned booking, with numbers restricted to the authenticated booking owner / assigned electrician. This supersedes the earlier masked-calling decision.

These commit diffs establish the decision timeline and UI intent. They do not, by themselves, prove that these commits are the exact original SQL bodies for Main ledger migration IDs `09114000` and `09114642`.

### Feature SQL source comparison
- `20261109103038_customer_electrician_direct_call_contacts.sql` creates `public.srk_get_customer_call_contacts()` as SECURITY DEFINER, authenticated-only, returning the assigned electrician phone to the authenticated customer for statuses `assigned, inspection, awaiting_quote_approval, quote_approved, in_progress`.
- `20261109103143_move_customer_call_contact_lookup_to_private.sql` moves the implementation to `private.srk_get_customer_call_contacts_impl()` and makes the public RPC a SECURITY INVOKER wrapper. The private implementation requires `auth.uid()`, scopes rows to `b.customer_user_id = auth.uid()` and a non-null assigned electrician, but has no booking-status filter in this historical Feature source.
- `20261116120000_pin_customer_call_contact_rpc_search_paths.sql` pins both functions' search paths to empty string. This is later Feature-only hardening in the checked branch; it is not in Main's recorded migration ledger.

### Current Main runtime comparison
- Main's current private implementation is SECURITY DEFINER, pinned to `pg_catalog, public, auth, pg_temp`, and requires a non-null authenticated UID.
- It scopes returned phone data to the caller's own customer bookings and a non-null assigned electrician.
- Its explicit status allow-list includes `assigned, inspection, awaiting_quote_approval, quote_approved, in_progress, completed`; `cancelled` is excluded.
- Both public wrapper and private implementation are executable by `authenticated`, not `anon`.
- Therefore Main's live behavior supports the owner's recovered direct-call decision: assigned-party phone visibility, completed bookings included, cancelled bookings excluded. It does not implement masked calling.

### Reconciliation conclusion
- The Nov 9 Git history confirms the earlier masked-calling proposal was explicitly superseded by the owner before direct-call UI was restored.
- Feature's original private RPC migration lacks the later Main status allow-list; Main live catalog is more restrictive for cancelled bookings and explicitly allows completed bookings.
- Main migration ledger names `09114000 protect_customer_and_electrician_phone_numbers_until_masked_calling` and `09114642 enable_direct_customer_electrician_phone_calls` describe the same broad change sequence, but exact SQL equivalence to the Git commits remains unproven. Do not infer original SQL solely from migration names or commit timestamps.
- No new phone-visibility code or SQL was changed in this pass. The report documents recovered decision evidence and live behavior only. Main access remained read-only; no DDL, data writes, migration application, deployment, or configuration changes occurred.


## 17. Customer ↔ Electrician phone-access RPC parity audit (Nov 17)

### Actual Feature UI call paths
- Customer booking UI calls `public.srk_get_customer_call_contacts()`, maps returned rows by `booking_id`, and only renders the electrician phone / `tel:` link when a matching contact row exists and the normalized number is 10–15 digits.
- Electrician dashboard calls `public.srk_get_my_offer_details()`. It renders customer phone and direct-call link from `customer_phone` only when that field is returned. The dashboard does not call `srk_electrician_get_my_assigned_booking_contacts()`.
- Therefore the actual two UI paths are asymmetric at the RPC level: Customer uses a dedicated contact RPC; Electrician uses the broader offer-details RPC whose response includes booking, quote, address, and contact fields.

### Main live Customer-side authorization
- `private.srk_get_customer_call_contacts_impl()` is SECURITY DEFINER, requires non-null `auth.uid()`, and filters `service_bookings.customer_user_id = auth.uid()`.
- It additionally requires a non-null assigned electrician and booking status in `assigned, inspection, awaiting_quote_approval, quote_approved, in_progress, completed`. Cancelled is excluded.
- Effective EXECUTE: authenticated=true, anon=false.
- Public `srk_get_customer_call_contacts()` wrapper is SECURITY INVOKER, authenticated-only, and delegates to the private implementation.

### Main live Electrician-side authorization
- Actual UI RPC `public.srk_get_my_offer_details()` is SECURITY DEFINER, pinned `search_path = pg_catalog, public, auth, pg_temp`, authenticated-only (anon=false).
- It joins `job_offers` to `electrician_profiles` and `service_bookings`; requires `p.user_id = auth.uid()`, `p.verification_status='approved'`, and `p.active=true`.
- Customer name, phone, address, coordinates, and quote fields are returned only when `b.assigned_electrician_id = p.id` and status is one of `assigned, inspection, awaiting_quote_approval, quote_approved, in_progress, completed`. For other offers/booking states these fields are NULL.
- Thus the actual dashboard does not expose customer phone from an unassigned offer; cancelled bookings are masked and completed bookings remain eligible.
- A separate Main RPC `public.srk_electrician_get_my_assigned_booking_contacts()` is also SECURITY DEFINER and authenticated-only. It checks profile ownership via `ep.user_id = auth.uid() OR ep.auth_user_id = auth.uid()`, approved/active status, and a similar non-cancelled status allow-list. However, this RPC is not called by the checked Feature Electrician dashboard code, so it is not the active UI access path.

### Parity / residual review items
- Both actual UI paths are booking-scoped and exclude cancelled bookings; both allow completed bookings. Both deny anon execution and require authenticated identity.
- They do not use identical ownership checks: Customer side matches `customer_user_id=auth.uid()`; Electrician dashboard's `srk_get_my_offer_details()` matches `p.user_id=auth.uid()`, while the separate assigned-contact RPC supports either `user_id` or `auth_user_id`.
- The current Main offer-details definition does not itself require `ep.verification_status='approved'` or `ep.active=true'` in the CASE expression that reveals contact fields; those checks exist for the joined profile as a whole. The function's WHERE clause does require the joined profile to be approved and active.
- The separate electrician contact RPC has an explicit profile ownership fallback but is unused by the Feature UI. Do not switch UI paths or change identity matching without confirming the canonical electrician-profile linkage and GPT-2/owner review.
- This audit confirms source-level authorization predicates and effective EXECUTE privileges; it is not a live authenticated-user integration test or proof that every possible profile-link state is covered.

### Safety / change record
- Read-only Main catalog/function/privilege inspection and Feature source reads only.
- No application code, SQL migrations, or database objects were changed in this audit section.
- No Production DDL/data writes, migration application, deployment, merge, or mobile QA occurred.


## 18. Electrician Profile auth identity linkage audit (Nov 17)

### Main live profile data (read-only snapshot)
- Main currently contains one `electrician_profiles` row.
- That row has non-null `user_id` and `auth_user_id`, and both UUIDs are identical.
- It is Admin-approved and active, with one assigned booking and one offer row.
- Across current profile rows, the audit found no UUID that links to more than one distinct profile through either identity column.
- This is a point-in-time observation of the current single-row dataset; it is not proof that future writes cannot create collisions.

### Schema constraints and policies
- `auth_user_id` has a partial UNIQUE index (`electrician_auth_user_unique`) when non-null.
- `user_id` has a non-unique partial index only; no UNIQUE constraint/index was found for it.
- Both columns have foreign keys to `auth.users(id)` with `ON DELETE SET NULL`.
- No database CHECK constraint enforces `user_id = auth_user_id`.
- Authenticated SELECT policy allows a profile when either identity column matches `auth.uid()`; Admin can also read. Profile INSERT/UPDATE/DELETE policies are Admin-only.
- The only inspected non-internal profile trigger is the audit trigger; no profile-table trigger automatically enforces identity parity.

### Main linkage and approval functions
- `srk_admin_review_application(uuid,text)` is Admin-only. On approval it finds a phone-confirmed `auth.users` row matching the application's normalized last 10 phone digits, then writes the same UUID into both `user_id` and `auth_user_id`. If no confirmed OTP account exists, approval fails.
- `srk_link_electrician_profile()` is a SECURITY DEFINER trigger function on the Auth user linkage path. When a phone-confirmed Auth user appears, it updates approved profiles whose `user_id IS NULL` and whose normalized phone matches, setting both identity columns to the new Auth UUID.
- `srk_admin_set_electrician_active(uuid,boolean)` refuses activation unless the profile is approved, `auth_user_id` is non-null, and `user_id IS NOT DISTINCT FROM auth_user_id`; it also requires latest identity and address proof documents to be approved.
- `srk_admin_offer_booking(uuid)` only creates offers for approved/active profiles with non-null `auth_user_id` and exact `user_id = auth_user_id`.
- These controls provide strong parity checks in the reviewed Admin approval, activation, and offer-creation paths.

### Identity predicate mismatch still present
- Actual Electrician UI reads customer contact through `srk_get_my_offer_details()`, whose ownership predicate is `p.user_id = auth.uid()`. It also requires approved/active profile and reveals customer contact fields only when the booking's `assigned_electrician_id = p.id` and status is in its allow-list.
- Other live RPCs use `p.user_id = auth.uid() OR p.auth_user_id = auth.uid()`, including the separate assigned-booking contact RPC and several booking workflow operations.
- Since the normal approval/activation/offer paths enforce equal IDs, this difference is not currently observable in the one-row Main snapshot. However, the schema itself does not globally enforce equality, and `user_id` is not unique. The mismatch remains a defense-in-depth consistency gap if any alternate Admin/import/manual write creates divergent values.
- The unique index on `auth_user_id` prevents two profiles sharing that column value, but does not by itself prevent one profile's `user_id` from colliding with another profile's `auth_user_id`.

### Recommendation for GPT-2 / owner review
- Keep the current feature/UI behavior unchanged pending coordinated review.
- Decide whether `user_id` is legacy alias or co-equal identity. Then standardize all electrician RPC ownership predicates and enforce the canonical invariant in a race-safe database constraint/trigger or canonical identity mapping.
- Any schema enforcement must be designed against the complete Main migration history and existing Admin/application flows; do not add a one-off migration based only on the current one-row data snapshot.
- This is a review recommendation only. No SQL, profile data, application code, or production settings were changed.


## 19. Main Electrician RPC identity / authorization inventory (Nov 17)

### Scope and method
- Read-only catalog inventory of all functions in public and private schemas whose definitions reference public.electrician_profiles.
- 29 functions were returned. The inventory includes self-service Electrician RPCs, Customer contact RPCs, Admin RPCs, and internal trigger functions.
- Effective EXECUTE was checked: anon=false for every function; authenticated=true for callable authenticated RPCs; internal trigger functions are not executable by anon/authenticated directly.
- This is a static live-definition and ACL review, not an impersonated JWT/session test.

### Ownership predicate groups

**A. user_id = auth.uid() only**
- Actual Feature Electrician dashboard RPC: srk_get_my_offer_details().
- Other functions in this group include srk_get_my_earnings() and srk_respond_to_offer(uuid,text).
- srk_get_my_offer_details() requires approved + active profile and only returns customer name/phone/address/coordinates and legacy quote details for the caller's assigned booking in its explicit allowed statuses. Unassigned offers and cancelled bookings have those sensitive fields masked.
- srk_respond_to_offer() binds the supplied offer UUID to a profile whose user_id=auth.uid(), requires approved + active, locks the offer, accepts only offered state, and conditionally assigns only an unassigned booking in new/confirmed. It does not trust a client-supplied electrician profile ID.
- srk_get_my_earnings() binds bookings through profile user_id=auth.uid() and approved status; unlike several workflow RPCs, this definition does not require active=true.

**B. user_id = auth.uid() OR auth_user_id = auth.uid()**
- Confirmed in live definitions including srk_electrician_get_my_assigned_booking_contacts(), srk_electrician_get_work_control(uuid), srk_electrician_request_work_start(uuid), srk_electrician_request_work_completion(uuid), srk_electrician_confirm_cash_payment(uuid), srk_get_my_assigned_booking_quote_details(), srk_get_my_assigned_cash_payment(uuid), srk_get_my_offer_price_details(), srk_submit_booking_quote(...), and srk_update_booking_work_status(uuid,text).
- Booking-mutating functions derive profile ID from authenticated UID, require approved + active profile, then bind the target booking to assigned_electrician_id = derived_profile_id. Cash confirmation additionally requires completed work, approved quote, cash payment method, eligible unpaid/pending state, and positive approved amount.
- Work-start/completion functions bind to the assigned booking and enforce expected quote/timer/status state. Legacy work-status RPC permits only assigned -> inspection; it rejects direct start/completion status changes.
- Assigned-contact RPC returns customer phone only for caller's assigned bookings and an explicit non-cancelled status allow-list. Assigned quote-details RPC is also assignment-bound and status-filtered.

**C. Strict dual-ID equality**
- srk_electrician_list_my_area_requests(), srk_electrician_request_area_change(...), srk_electrician_list_my_verification_documents(), and srk_electrician_submit_verification_document(...) require user_id=auth.uid() AND auth_user_id=auth.uid().
- Document submission additionally validates storage path prefix against caller UID, MIME type, file size, and existence in the private verification bucket; replacement identity/address documents deactivate the profile pending review.
- Area-change submission requires active + approved profile and writes a request scoped to the derived profile ID.

**D. Admin-gated / internal functions**
- Admin functions referencing electrician profiles include commission report, booking contacts, area-request/document listing and review, application review, offer dispatch, and profile activation. Their bodies check auth.uid() plus public.is_srk_admin() before privileged reads/writes. Profile IDs supplied to Admin-only RPCs are Admin parameters, not Electrician-controlled identity selectors.
- broadcast_booking_job() and srk_link_electrician_profile() are SECURITY DEFINER trigger functions, not directly executable by anon/authenticated. The former creates offers for active/approved area-matched profiles; the latter links phone-confirmed Auth users to approved unlinked profiles and writes both identity columns.
- The private Customer contact implementation requires authenticated UID and scopes rows to service_bookings.customer_user_id=auth.uid(), assigned electrician, and its explicit status allow-list.

### Security observations / residual risks
1. Identity predicate inconsistency remains confirmed. The actual Electrician dashboard's srk_get_my_offer_details() and offer-response path use user_id only; several workflow RPCs accept either identity column; KYC/area-request RPCs require both columns to be equal. Normal Admin approval, activation, and offer-creation paths set/check equality, but the schema still does not globally enforce it. This is a defense-in-depth consistency issue, not evidence of exploitable cross-profile access in the current one-profile snapshot.
2. Wallet summary RPC has a side effect. srk_get_my_wallet_summary() is SECURITY DEFINER and authenticated-only, but inserts missing customer wallet-account and (when a profile matches coalesce(auth_user_id,user_id)=auth.uid()) electrician wallet-account rows while returning a summary. It does not accept a client-supplied profile ID. This is not a direct privilege bypass, but its “get” name masks a write side effect and its identity predicate is yet another variant; flag for coordinated owner/GPT-2 review before future redesign.
3. No unassigned customer-contact leak was identified in the inspected Electrician contact paths. The actual dashboard offer-details RPC masks customer contact/address/location unless the booking is assigned to the derived profile and status is allowed. The separate assigned-contact and assigned-quote-detail RPCs also bind rows to assigned bookings.
4. No Electrician RPC was found that trusts a caller-supplied profile UUID as the sole ownership proof. Supplied booking/offer IDs are followed by server-side profile derivation and assignment/offer ownership checks. Admin-only activation/review/dispatch functions accept profile/application/request IDs behind an Admin predicate.
5. ACL result is consistent across the 29-function inventory: no anon EXECUTE. Authenticated callers can execute intended RPC surface, so body-level UID/assignment/Admin checks remain essential; SECURITY DEFINER alone is not an authorization boundary.

### App-path comparison
- Feature Customer UI calls the dedicated customer contact RPC; Main implementation scopes to authenticated booking owner and assigned electrician, excludes cancelled bookings, and includes completed bookings.
- Feature Electrician dashboard calls srk_get_my_offer_details() for offer data and customer contact. It does not call the separate srk_electrician_get_my_assigned_booking_contacts() RPC.
- Therefore the dashboard's active contact path inherits the user_id-only predicate and assigned-booking field masking described above; no UI switch or identity change is recommended without coordinated review.

### Recommendation / change boundary
- Keep app and Main schema unchanged for now. Ask GPT-2/owner to settle canonical electrician identity invariant, then review a coordinated migration that standardizes relevant RPC predicates and enforces the invariant race-safely against full migration history.
- Separately decide whether srk_get_my_wallet_summary() should remain a lazy account initializer or become a read-only summary plus explicit account-creation path.
- This section documents read-only Main catalog/function/ACL inspection and Feature source call paths. No SQL, data, application code, or Production settings were changed; no migration was applied, deployment or merge performed, or mobile QA run.


## 20. Electrician UI RPC-to-Main live schema parity (Nov 17)

### Source inventory
- Re-fetched Feature Branch electrician.html at blob SHA 0588cfe716e1e5c47690e826bbe2bb09a0c57bed.
- Extracted 23 distinct RPC names called by the current Electrician UI. The previously audited core workflow RPCs are present in Main; however, 13 other UI-called RPC names do not currently resolve in the connected Main project catalog:
  - srk_electrician_stop_live_location(uuid)
  - srk_electrician_start_live_location(uuid,double precision,double precision,numeric)
  - srk_electrician_update_live_location(uuid,double precision,double precision,numeric)
  - srk_electrician_list_my_support_tickets()
  - srk_electrician_create_support_ticket(text,text,text,uuid)
  - srk_electrician_list_my_support_messages(uuid)
  - srk_electrician_send_support_message(uuid,text)
  - srk_electrician_update_my_display_name(text)
  - srk_electrician_get_my_live_location_status(uuid)
  - srk_electrician_get_labour_bill(uuid)
  - srk_electrician_set_availability(boolean)
  - srk_create_sos_alert(text)
  - srk_electrician_get_my_verification_document_path(uuid)
- Exact live catalog checks returned null for the corresponding to_regprocedure lookups; name inventory across schemas also returned no matching definitions. Therefore these are not merely EXECUTE-grant failures in the inspected Main snapshot.

### Feature migration source evidence
- Feature source contains definitions for self-availability in 20261114310000, booking-scoped live location in 20261114320000, private KYC document path in 20261114330000, self profile-name edit in 20261114340000, Electrician support ticket/message RPCs in 20261114350000, SOS creation in 20261115260000, and labour bill in 20261115120001 / 20261115145900.
- Queried supabase_migrations.schema_migrations for those eight migration versions in the connected Main project; no matching rows were returned.
- The support-ticket migration grants authenticated execution and its bodies derive the caller profile from auth.uid; the live-location functions similarly bind the booking to the caller's approved profile and assigned booking; KYC path RPC scopes the document to the caller's own profile. SOS source derives exactly one in-progress selected-category booking from auth.uid and explicitly records SMS/Push as not_configured (no automatic police/112 or provider delivery is implemented by that migration).
- These source definitions are evidence of intended Feature Branch implementation only; they are not evidence that Main has those objects deployed.

### Direct table access policies used by Electrician UI
- srk_electrician_payouts SELECT policy permits Admin or rows whose electrician profile has user_id=auth.uid(); this is consistent with the UI's profile-ID filter only when the profile identity columns remain equal.
- srk_wallet_bank_links and srk_wallet_ledger SELECT policies scope directly to user_id=auth.uid().
- srk_push_subscriptions SELECT/INSERT/UPDATE/DELETE policies scope to user_id=auth.uid().
- electrician_profiles SELECT policy permits either auth_user_id=auth.uid(), user_id=auth.uid(), or Admin; profile writes remain Admin-only in the inspected policies.
- This confirms another practical consequence of the unresolved identity invariant: payout-history visibility is user_id-only even though other RPCs accept either identity column.

### Impact and safe boundary
- This is a Feature-source vs connected-Main schema/migration-history parity gap, not a claim that the Feature UI is defective. If this Main project is the intended runtime target, the affected UI actions can fail with missing-function errors until the relevant approved migrations are applied.
- Do not apply these migrations as a quick fix. The full migration replay/order and GPT-2 Admin/Accounting dependency blockers remain open; migration history, duplicate timestamps, and authoritative baseline must be reconciled first.
- No Production schema/data/settings were changed. No migration was applied, no provider action was triggered, no deployment/merge was performed, and no mobile QA was run.


## Section 21 — Admin Panel RPC, Support/RBAC और operational migration dependency audit (2026-11-17)

### Source snapshot
- Feature branch: `feat/customer-login-first-dashboard-20261114`
- Admin Panel source: `admin.html`, blob SHA `6b29511a1ecfab93b5689dff23012078091e57fc`.
- Support/RBAC foundation: `20261114390000_admin_staff_rbac_foundation.sql`, blob SHA `5aa0f9058a56d735455f2a9944c861e8312ddb89`.
- Staff permission volatility correction: `20261116100000_fix_staff_permission_helper_volatility.sql`, blob SHA `fc99aaf9c564b348e25a72b416dd4eb746e0fad3`.
- Main project checks below are live catalog/migration-ledger reads, not migration replay or runtime user tests.

### Exact Admin Panel RPC inventory
- Extracted 53 distinct `.rpc()` names from the current Admin Panel source.
- Connected Main public function catalog resolves 17 names; 36 names did not resolve by exact public function name at audit time.
- Resolved names: `is_srk_admin`, `srk_admin_commission_report`, `srk_admin_decide_booking_refund_request`, `srk_admin_list_booking_complaints`, `srk_admin_list_booking_refund_requests`, `srk_admin_list_electrician_area_requests`, `srk_admin_list_electrician_verification_documents`, `srk_admin_mark_electrician_payout_paid`, `srk_admin_offer_booking`, `srk_admin_record_manual_payment`, `srk_admin_record_manual_refund`, `srk_admin_review_application`, `srk_admin_review_electrician_area_request`, `srk_admin_review_electrician_document`, `srk_admin_set_electrician_active`, `srk_admin_update_booking_complaint`, `srk_admin_wallet_overview`.
- Names not resolved: `srk_admin_acknowledge_sos_alert`, `srk_admin_assign_support_case`, `srk_admin_confirm_legacy_booking`, `srk_admin_decide_booking_cancellation`, `srk_admin_get_booking_accounting_reconciliation`, `srk_admin_get_booking_work_review`, `srk_admin_get_cancellation_fee_ledger_summary`, `srk_admin_list_booking_cancellation_requests`, `srk_admin_list_booking_complaint_messages`, `srk_admin_list_complaint_message_attachments`, `srk_admin_list_electrician_support_messages`, `srk_admin_list_electrician_support_tickets`, `srk_admin_list_sos_alert_events`, `srk_admin_list_sos_alerts`, `srk_admin_list_staff`, `srk_admin_list_staff_audit_events`, `srk_admin_list_staff_sessions`, `srk_admin_list_support_assignments`, `srk_admin_record_new_booking_cash_payment`, `srk_admin_send_booking_complaint_message`, `srk_admin_send_electrician_support_message`, `srk_admin_set_electrician_rate_tier`, `srk_admin_staff_list_customer_complaints`, `srk_admin_staff_list_customer_messages`, `srk_admin_staff_list_electrician_messages`, `srk_admin_staff_list_electrician_tickets`, `srk_admin_staff_register_session`, `srk_admin_staff_revoke_session`, `srk_admin_staff_send_customer_message`, `srk_admin_staff_send_electrician_message`, `srk_admin_staff_set_status`, `srk_admin_staff_update_customer_complaint`, `srk_admin_staff_update_electrician_ticket`, `srk_admin_update_booking_customer_location`, `srk_admin_update_electrician_support_ticket`, `srk_has_admin_permission`.
- The count is source-to-Main catalog parity only. It does not imply all 36 are independently broken: some are grouped behind one feature migration or may have alternate supported paths. Exact argument and return-shape parity remains a separate check.
- Of the inspected Main functions, `is_srk_admin()` is SECURITY DEFINER, has a pinned search_path, grants authenticated execution, and denies anon execution. The RBAC helper `srk_has_admin_permission(text)` was not present in the Main public catalog.

### Migration and schema dependency grouping
- Customer complaints: `20261110040000_customer_admin_complaints.sql` defines complaint and immutable event tables plus customer/Admin complaint RPCs. Main has `srk_booking_complaints` and `srk_booking_complaint_events` with RLS enabled, but the corresponding migration version is absent from the queried Main ledger.
- Complaint conversation and attachments: `20261113220000_customer_support_conversation_schema.sql` defines message/attachment tables and customer-side RPCs; `20261113230000_support_attachment_paths_and_admin_message_list.sql` adds Admin message/attachment listing. Those message/attachment tables were not found in the inspected Main table set.
- Work review: `20261114250000_admin_work_dispute_review_and_immutable_history.sql` defines `srk_booking_work_events` and `srk_admin_get_booking_work_review`; the table/function were not found in the inspected Main catalog.
- Cancellation: `20261114270000_admin_only_cancellation_requests_and_decisions.sql` adds request/event tables, direct-cancellation guard trigger, customer request RPCs, and Admin decision RPC. These objects were not found in the inspected Main table set. This migration has a dependency on the existing booking table and must be reviewed with cancellation-fee/accounting migrations before any replay.
- Staff Support: `20261114390000_admin_staff_rbac_foundation.sql` defines six tables: `srk_admin_staff`, `srk_admin_permissions`, `srk_admin_role_permissions`, `srk_admin_staff_sessions`, `srk_admin_staff_audit_events`, and `srk_admin_support_assignments`; it also defines permission, session, assignment, Staff inbox, status, and audit RPCs. None of those six tables were found in the inspected Main catalog.
- Electrician Support: `20261114350000_electrician_support_tickets_and_admin_inbox.sql` defines ticket/message tables, Electrician-facing ticket/message RPCs, and Admin inbox/reply/status RPCs. The tables were not found in the inspected Main table set.
- SOS: `20261115260000_sos_admin_support_alerts.sql` defines SOS alert/event tables, authenticated SOS creation, Admin list/acknowledgement, and immutable event guard. The tables and Admin RPCs were not found in the inspected Main catalog.
- New-category payout reconciliation: `20261114360000_new_category_electrician_payout_reconciliation.sql` adds payable creation and Admin paid-marking logic; the paid-marking RPC name resolves in Main, so its live signature/body and underlying payout/accounting contract must be compared rather than treating the function as absent.
- Queried migration-ledger versions for `20261110040000`, `20261113220000`, `20261113230000`, `20261114250000`, `20261114270000`, `20261114300000`, `20261114350000`, `20261114360000`, `20261114390000`, `20261115260000`, and `20261116100000`: none were present in the returned Main ledger rows. Ledger absence is a migration-history signal, not standalone proof that every object is absent; catalog checks above provide the object-level evidence where queried.

### Staff invitation and identity-exclusivity blocker
- Admin UI calls Edge Function `admin-staff-management` for Support Staff invitation. The Edge Function validates the caller with `auth.getUser(token)` and `is_srk_admin()`, fixes the role to Support, creates an Auth invitation with the service-role client, then calls `srk_admin_staff_register_invited_user(uuid,text,uuid)`.
- That service-role-only RPC verifies the actor UUID exists in `srk_admin_users`, then inserts the target UUID into `srk_admin_staff`; it does not check that the target UUID is absent from `srk_admin_users`. The Staff table's primary key only prevents duplicates within the Staff table.
- The permission helper deliberately checks `is_srk_admin()` first and returns full Main Admin access before evaluating Staff permissions. Therefore cross-table identity exclusivity is a security prerequisite, not merely a data-cleanliness preference.
- Required before RBAC can be accepted: add a database-side, race-safe invariant preventing one Auth UUID from existing in both Main Admin and Staff registries; cover both invite/registration and any Main Admin provisioning path. Do not rely only on a preflight check in the Edge Function. This is a blocker for owner/GPT-2 review; no fix was applied.
- The Edge Function sends the Auth invitation before registering the Staff row. If registration fails, it attempts to delete the new Auth user and warns that an email may already have been sent. This compensating cleanup is documented behavior, not a guaranteed email recall; test the failure path only in approved isolated staging.

### Staff authorization migration order
- The RBAC foundation uses session-aware permission checks and row locks. The follow-up `20261116100000_fix_staff_permission_helper_volatility.sql` explicitly changes `srk_has_admin_permission(text)` to VOLATILE because PostgreSQL row-locking `FOR SHARE` is incompatible with a STABLE helper.
- Safe source replay order therefore requires the Staff RBAC foundation before the volatility correction, followed by verification of the exact final function definition, grants, RLS, immutable audit triggers, and Edge Function deployment/configuration. Do not apply either migration independently or directly to Production.
- Main currently exposes `is_srk_admin()`, but the inspected public catalog did not expose `srk_has_admin_permission(text)`; Staff session and permission behavior has not been integration-tested with authenticated Main Admin/Staff identities.

### Safe next sequence
1. Reconcile the full authoritative migration baseline and exact version order, including the already identified Accounting/Refund/Payout dependencies and duplicate timestamp risks.
2. Resolve the Main Admin ↔ Staff UUID exclusivity invariant with owner/GPT-2 approval before accepting the Staff RBAC migration.
3. Compare each missing Admin RPC's exact signature, output contract, authorization predicate, RLS/trigger dependencies, and side effects against the current Admin UI caller.
4. Review customer support, electrician support, cancellation, work-review, SOS, and accounting/payout groups as dependency bundles; do not cherry-pick isolated RPCs.
5. Only after all implementation is consolidated should isolated end-to-end testing/staging be discussed; obtain explicit approval before any paid branch, migration application, deployment, merge, or external action.

### Change boundary
- This section records source and connected-Main audit findings only. No application code, SQL migration, database schema/data, Auth user, invitation, email, provider action, deployment, or PR merge was changed or triggered.
- PR #8 remains Open, Draft, and Unmerged. No mobile QA was performed.


## Section 22 — Admin UI ↔ Main live RPC contract comparison (2026-11-17)

### Snapshot revalidation
- PR #8 फिर से जाँचा: Open, Draft, Unmerged; target Feature branch वही है।
- `admin.html` blob SHA अभी भी `6b29511a1ecfab93b5689dff23012078091e57fc` है।
- Main public catalog में पहले मिले 17 Admin RPC के exact argument names, return types, SECURITY DEFINER, volatility, search_path और grants पढ़े। सभी 17 के लिए anon EXECUTE=false और authenticated EXECUTE=true है। यह authenticated runtime behavior का test नहीं है।
- 36 unresolved RPC names को सभी PostgreSQL schemas के `pg_proc` catalog में दोबारा खोजा; exact name matches किसी schema में नहीं मिले। इसलिए इन्हें केवल public-schema miss नहीं माना जा रहा।

### Confirmed high-impact contract mismatches

**A. Customer Refund Review**
- Feature Admin UI calls `srk_admin_decide_booking_refund_request` with named JSON arguments `p_request_id`, `p_decision`, `p_admin_note`; it requires an audit note of 10–2000 characters.
- Feature migration `20261115110000_admin_refund_review_queue_and_decisions.sql` defines the same `p_decision` argument and enforces the 10–2000 character note.
- Main live function currently exposes `p_request_id uuid, p_status text, p_admin_note text DEFAULT NULL`; it does not expose the UI's `p_decision` argument name and only caps the note at 2000 rather than enforcing the Feature minimum. This named-argument mismatch can make the UI RPC call fail.
- Refund queue mismatch is also confirmed: Feature UI expects row keys such as `request_id`, `booking_status`, `request_amount`, `request_reason`, `request_status`, `processed_at`, labour/refund/payout recovery fields. Feature migration defines that projection. Main live function currently returns a different row contract including `id`, `amount`, `reason`, `status`, and a smaller legacy projection. The UI reads `request_id`, `request_status`, `request_amount`; those values do not match the Main return names.
- Therefore this is not merely a missing migration ledger entry: a live function with the same name exists but is contract-incompatible with the current Admin UI. Keep refund approval separate from actual provider refund execution; the UI itself states approval does not send money.

**B. Manual Refund**
- Function name and signature exist in Main: `srk_admin_record_manual_refund(p_booking_id uuid,p_reference text,p_note text DEFAULT NULL)`, matching the UI argument names.
- But Main live body is the older manual-payment-only flow: it requires a manual payment entry, rejects Razorpay-linked bookings, blocks if electrician payout is already paid, inserts manual refund entry, and marks booking refunded.
- Feature migration `20261115130000_admin_manual_refund_request_completion.sql` adds completion of an approved Customer refund request and reconciles the newer labour/cancellation-fee accounting contract. Same function signature does not mean equivalent behavior. Do not assume the Main implementation completes the new Customer refund request lifecycle.

**C. Manual Payment**
- Main live `srk_admin_record_manual_payment(uuid,text,text,text)` matches the UI's argument names, but its current body is the older legacy quote flow: completed booking, approved quote, no Razorpay IDs, and amount = service_charge + materials_amount.
- Feature migration `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` replaces it with paise-based labour/materials/commission/payout consistency. UI separately calls `srk_admin_record_new_booking_cash_payment` for server-timed/category bookings; that RPC did not resolve in Main.
- Consequence: the Main function's existence does not prove the newer itemized/manual-payment behavior is installed. The new-category Cash path is a definite missing RPC dependency.

**D. Electrician Payout**
- Main live `srk_admin_mark_electrician_payout_paid(uuid,text,text,text)` signature matches UI arguments and allows only `upi` / `bank`, denies anon and grants authenticated.
- Feature migration `20261114360000_new_category_electrician_payout_reconciliation.sql` replaces the body with checks against the immutable labour bill and category-booking payment/payout parity. The Main live body inspected is still legacy quote/service-charge/materials reconciliation and does not establish that the Feature's new-category labour-bill contract is present.
- Keep Admin Manual Payout as the only active electrician payout path. Razorpay Route Transfer remains retired; no Route payout or transfer activation is proposed.

### Other missing RPCs mapped to their source bundles
- `20261114390000_admin_staff_rbac_foundation.sql`: `srk_admin_list_staff`, `srk_admin_list_staff_sessions`, `srk_admin_staff_revoke_session`, `srk_admin_assign_support_case`, `srk_admin_list_support_assignments`, `srk_admin_list_staff_audit_events`, `srk_admin_staff_register_session`, `srk_admin_staff_set_status`, and the four `srk_admin_staff_*` support inbox/reply/update families. Followed by `20261116100000_fix_staff_permission_helper_volatility.sql` for the final session-locking permission helper.
- `20261113230000_support_attachment_paths_and_admin_message_list.sql`: `srk_admin_list_booking_complaint_messages`, `srk_admin_list_complaint_message_attachments`; `20261114300000_admin_customer_support_thread_replies.sql`: `srk_admin_send_booking_complaint_message`.
- `20261114350000_electrician_support_tickets_and_admin_inbox.sql`: `srk_admin_list_electrician_support_tickets`, `srk_admin_list_electrician_support_messages`, `srk_admin_send_electrician_support_message`, `srk_admin_update_electrician_support_ticket`.
- `20261114250000_admin_work_dispute_review_and_immutable_history.sql`: `srk_admin_get_booking_work_review`.
- `20261114270000_admin_only_cancellation_requests_and_decisions.sql`: `srk_admin_list_booking_cancellation_requests`, `srk_admin_decide_booking_cancellation`; `20261114280000_cancellation_fee_carry_forward_and_accounting.sql`: `srk_admin_get_cancellation_fee_ledger_summary` and `srk_admin_record_new_booking_cash_payment`.
- `20261115260000_sos_admin_support_alerts.sql`: `srk_admin_list_sos_alerts`, `srk_admin_acknowledge_sos_alert`, `srk_admin_list_sos_alert_events`.
- `20261115150000_admin_readonly_booking_accounting_reconciliation.sql`, subsequently revised by `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`: `srk_admin_get_booking_accounting_reconciliation`. Do not revive Route-specific settlement/payout behavior from the retired Route workstream.
- `20261115230000_admin_booking_direct_write_closure.sql`: `srk_admin_update_booking_customer_location`.
- `srk_admin_confirm_legacy_booking` and `srk_admin_set_electrician_rate_tier` are called by the current Admin UI but were not located in the migration files inspected during this pass. Their authoritative source migration and Main dependencies remain unresolved; do not invent or create replacements.
- The already-present `srk_admin_list_booking_complaints(integer)`, `srk_admin_update_booking_complaint(uuid,text,text)`, area-request RPCs, KYC review RPCs, and Admin payout/payment RPCs need full return/body parity checks; matching names and signatures alone do not establish Feature parity.

### Main catalog security snapshot
- All 17 same-name Main Admin RPCs inspected were SECURITY DEFINER, had authenticated EXECUTE=true and anon EXECUTE=false.
- Most had pinned search_path. `srk_admin_decide_booking_refund_request` and `srk_admin_list_booking_refund_requests` had empty search_path. This is a useful grant baseline, but not proof that the function body implements the Feature contract or that every referenced table's RLS is correct.
- No SQL, migration, Auth, provider, or Production changes were made during this comparison. This is source/catalog inspection only.

### Implementation gate
- Before any implementation port: resolve the refund named-argument and row-shape mismatch, confirm the intended manual refund/payment and payout body versions, locate authoritative source for legacy confirm/rate-tier RPCs, and reconcile complete migration order/dependencies.
- Staff UUID exclusivity blocker from Section 21 remains unresolved and must be decided with owner/GPT-2 before the Staff RBAC bundle is accepted.
- Do not cherry-pick isolated financial RPCs, run production migrations, deploy, merge PR #8, trigger refunds/payouts, or perform mobile QA in this phase.


## Section 23 — Legacy Booking Confirm और Electrician Rate Tier RPC source verification (2026-11-17)

### Source खोज का परिणाम
दोनों RPC के Feature source अब मिल गए हैं; इन्हें अब “source unresolved” नहीं माना जाएगा:
- `srk_admin_confirm_legacy_booking(uuid)`: `supabase/migrations/20261115160000_legacy_booking_status_write_guard.sql`, blob SHA `b07658edbc51285a607a5007c7d99d95ae3bd104`.
- `srk_admin_set_electrician_rate_tier(uuid,text)`: `supabase/migrations/20261114160000_customer_selected_rate_tier_and_server_estimate.sql`, blob SHA `940943827c648bd9877faccc52844b81996bfcab`.

### 1. Legacy Booking Confirm
- Admin UI sends named args `p_booking_id` and expects `jsonb.success=true`.
- Feature migration function has the same signature and returns `jsonb`; requires authenticated Main Admin (`auth.uid()` and `is_srk_admin()`).
- It locks the booking row, only permits legacy rows with `selected_category IS NULL`, status exactly `new`, no assigned electrician, no paid/refunded payment, and no Razorpay order/payment IDs.
- It updates only `new` → `confirmed`, guards against concurrent conflict, and returns booking ID/status.
- Migration also revokes direct client status update privileges and restores only the explicit legacy payment/quote columns. This is an important dependency of the new audited booking-status write boundary.
- Main all-schema `pg_proc` search found no function with this name. The queried Main migration ledger also did not show `20261115160000`. Main's existing booking status write grants/policies were not changed.

### 2. Admin Electrician Rate Tier
- Admin UI sends named args `p_electrician_profile_id` and `p_rate_tier`, validates the four allowed tiers, and displays success only after RPC returns without error.
- Feature migration defines the same argument names and returns `jsonb`; requires authenticated Main Admin and an approved KYC profile.
- It records an authorization row in private schema `srk_private.electrician_rate_tier_authorizations`, updates the four approved-rate fields, deletes the transaction-scoped authorization row, and inserts an audit record in `srk_electrician_rate_tier_audit`.
- A trigger blocks direct setting of approved rate-tier fields and blocks activation unless the approved rate tier, card version, approver, and approval timestamp are all present.
- Audit table has RLS enabled, direct public/anon/authenticated table privileges revoked, and an Admin-only SELECT policy. Authorization table is private and has no client privileges.
- Main all-schema `pg_proc` search found no function with this name. Main catalog query also found none of the rate-tier columns/tables checked (`approved_rate_tier`, `approved_rate_card_version`, `rate_tier_approved_by`, `rate_tier_approved_at`, `srk_electrician_rate_tier_audit`). The queried Main migration ledger did not show `20261114160000`.

### 3. Current Admin RPC security snapshot — existing 17 names
- Rechecked Main public catalog for the 17 names previously found. All are SECURITY DEFINER, authenticated EXECUTE=true, anon EXECUTE=false.
- All except two had explicit pinned `search_path=pg_catalog, public, auth, pg_temp`; the exceptions are `srk_admin_decide_booking_refund_request(uuid,text,text)` and `srk_admin_list_booking_refund_requests(integer)`, both have `search_path=''`. Empty search_path is intentional hardening when all object references are schema-qualified; body-level dependency review remains necessary.
- Volatility: the list/read projections are STABLE where appropriate; mutation/administrative workflows are VOLATILE.
- Confirmed Main argument/return contracts for selected Admin UI calls:
  - `srk_admin_review_application(uuid,text)` args match UI named args; return is `void`, and UI checks only the error.
  - `srk_admin_set_electrician_active(uuid,boolean)` args match UI; return is `jsonb`, and UI checks `success`.
  - `srk_admin_offer_booking(uuid)` args match UI; return is `jsonb`.
  - Complaint list and area/KYC list functions return typed table projections; these require continued per-field UI comparison before declaring full parity.
- Existing refund UI/Main mismatches and legacy body parity gaps remain as Section 22; no new resolution is implied by this security snapshot.

### Implementation gate and status
- Both RPC source migrations are identified, but their dependent columns/tables/functions are not present in the queried Main catalog. Do not deploy either RPC by itself.
- Rate-tier rollout must include the complete category/rate-card schema and booking estimate migration dependencies, private authorization table, audit table, guard trigger, offer-dispatch eligibility, and Admin RPC as one reviewed bundle.
- Legacy confirm rollout must include the status write guard and all dependent booking/payment write contracts; do not re-enable broad direct status updates.
- No application code or SQL changed; no Production migration, Auth action, deployment, PR merge, refund, payout, or mobile QA occurred in this pass.


## Section 24 — Admin RPC response parity और KYC Event-table contract drift (2026-11-17)

### Revalidation
- Feature `admin.html` SHA: `6b29511a1ecfab93b5689dff23012078091e57fc`.
- PR #8 अब भी Open, Draft, Unmerged है।
- Main RPC bodies और Feature Admin UI की named arguments/response keys का targeted comparison किया गया।

### 1. Existing RPCs जिनका targeted UI contract match हुआ
- `srk_admin_list_booking_complaints(p_limit)`: UI `p_limit:100` भेजता है। Main table projection में UI द्वारा पढ़े जा रहे complaint fields और `activity` event keys मौजूद हैं।
- `srk_admin_update_booking_complaint(p_complaint_id,p_status,p_admin_note)`: UI named args और success JSON expectation Main signature/body से match करते हैं; Main status allow-list UI के चार status से match है; note limit 2000 है।
- `srk_admin_list_electrician_area_requests(p_limit)`: UI `p_limit:200` और Main row projection में UI के द्वारा पढ़े गए पुराने/नए क्षेत्र, reason, status, admin note, created_at fields match हैं।
- `srk_admin_review_electrician_area_request(p_request_id,p_decision,p_note)`: UI named args और success JSON match हैं। Main rejection पर 5+ अक्षरों का कारण अनिवार्य करता है; Feature UI भी यह validation करता है। Approval पर RPC profile lock लेकर area बदलता है, पुराने unaccepted offers बंद करता है और eligible booking के लिए existing Admin offer RPC reuse करता है।
- `srk_admin_review_application(p_application_id,p_decision)`: UI named args match; Main `void` लौटाता है और UI केवल error check करता है। Approval के लिए phone-confirmed Auth user आवश्यक है और profile inactive बनता है।
- `srk_admin_set_electrician_active(p_profile_id,p_active)`: UI args और `jsonb.success` match। Main latest identity/address proof approvals और OTP-linked identity enforce करता है।
- `srk_admin_offer_booking(p_booking_id)`: UI arg और JSON keys `success/message/offers_created` match; Main booking row lock, unassigned status, approved/active OTP-linked profiles, PIN/district matching लागू करता है।
- `srk_admin_commission_report()`: UI keys `total_commission`, `total_collected`, `total_electrician_payable`, `partners` तथा partner fields Main JSON से match हैं। गणना legacy completed+paid booking rows पर आधारित है; इसे नए category/cancellation accounting का parity proof न मानें।
- `srk_admin_wallet_overview()`: UI के सभी छह keys Main JSON से match हैं: customer_wallets, electrician_wallets, posted_ledger_credits, posted_ledger_debits, pending_entries, verified_bank_links।

### 2. KYC Event table नाम का महत्वपूर्ण drift
- Feature UI `srk_admin_list_electrician_verification_documents(p_limit:300)` call करती है और `activity[]` में `actor_role,event_type,note,created_at` पढ़ती है।
- Feature authoritative migration `20261115140000_electrician_kyc_review_and_activation_gate.sql` (SHA `3b6f6f2434deec960baba386cfc61a00e226c09b`) table `public.srk_electrician_verification_document_events` बनाती है।
- उसी Feature migration का Admin list RPC `srk_electrician_verification_document_events` से activity पढ़ता है; Admin review RPC भी इसी table में append करता है।
- Connected Main live Admin list/review RPC bodies इसके बजाय legacy `public.srk_electrician_verification_events` table इस्तेमाल करते हैं। Main catalog में legacy table और `srk_electrician_verification_documents` मिले; नई `srk_electrician_verification_document_events` table नहीं मिली।
- अतः same RPC names और broadly similar UI fields के बावजूद Feature KYC event schema और Main live event schema अलग हैं। Main live function body को Feature migration parity न समझें। Feature KYC migration bundle में नया append-only event table, trigger, grants/RLS, Admin list/review RPC bodies और संबंधित upload/activation behavior साथ reconcile करना होगा।
- किसी table को rename/drop/copy या दोनों histories को merge करने का निर्णय नहीं लिया गया। Legacy event history को सुरक्षित रखना आवश्यक है।

### 3. KYC review behavior का अतिरिक्त अंतर
- Feature migration review केवल pending document पर निर्णय स्वीकार करती है; rejection/resubmission reason 5–1000 अक्षर enforce करती है; नई document-event table में event लिखती है।
- Main live review body का पहले निरीक्षण किए गए संस्करण में review-state transition/lock और side-effect rules अलग हैं; वह Feature migration के समान व्यवहार का प्रमाण नहीं है।
- Feature UI note length सीमा रखता है और rejection/resubmission के लिए 5+ अक्षर की जाँच करता है। UI के अनुरूप होने के बावजूद backend body parity अलग से आवश्यक है।

### Status
- इस pass में कोई application code/SQL edit नहीं हुआ; केवल इस handover report में audit evidence जोड़ा गया।
- Main Database पर कोई migration/DDL/DML, Auth action, deployment, merge, payment/refund/payout या mobile QA नहीं किया गया।
- Remaining: KYC event history reconciliation; selected category booking और legacy Admin offer RPC boundary की समीक्षा; फिर शेष Admin RPCs के complete body/dependency parity checks।


## Section 25 — Legacy Admin Offer RPC में server-side category guard gap (2026-11-17)

- Feature Admin UI `offerBookingInternal()` पहले booking row से `selected_category` पढ़ती है और non-null होने पर `srk_admin_offer_booking` call करने से पहले रोक देती है। UI स्पष्ट रूप से कहती है कि नई श्रेणी की booking को legacy bulk-offer RPC से नहीं भेजना है।
- Connected Main live `srk_admin_offer_booking(uuid)` body inspected: Admin auth, booking lock, unassigned state, `new/confirmed` status, active+approved+OTP-linked electrician, PIN/district matching लागू करता है; लेकिन function body में `selected_category IS NULL` guard नहीं है।
- इसलिए सुरक्षा सीमा अभी UI-side check पर निर्भर है। Authenticated Main Admin द्वारा RPC को सीधे call करने पर selected-category booking भी legacy matching flow में जा सकती है। यह privilege escalation नहीं (RPC Main Admin-only है), लेकिन business workflow isolation gap और accidental misuse risk है।
- Owner-approved architecture में Customer payments Razorpay हैं, Electrician payouts Admin Manual Payout हैं, Razorpay Route retired है; यह finding offer dispatch scope के बारे में है, payment/payout routing नहीं।
- Safe remediation: Feature Branch में legacy RPC के server-side body में `selected_category IS NULL` hard guard जोड़ने वाला reviewed migration; साथ ही Main intended schema, offer uniqueness/locking, and new-category sequential dispatcher contracts reconcile हों। Existing historical offers/booking rows को mutate न करें।
- कोई migration या code change नहीं किया गया; Production पर कोई बदलाव नहीं हुआ।


## Section 26 — Main live work-review, cancellation और legacy RPC boundary revalidation (2026-11-17)

### Live database recheck
- Main Supabase project `Srk electranic` (project ref `gnqhoaqatmoiwwhgzkgm`) पर केवल read-only catalog/function inspection किया गया।
- PR #8 re-fetch: Open, Draft, Unmerged; head SHA `06a6b718bb107afe177ace6cc4c421521eaa0d4f`।
- Feature `admin.html` SHA `6b29511a1ecfab93b5689dff23012078091e57fc`; handover report SHA before this append `1551a90ec01228399f353481eb479622459107e6`।

### 1. Admin work-review RPC live Main में अनुपस्थित
- Main public catalog में `srk_admin_get_booking_work_review(uuid)` नहीं मिला।
- इस कारण Feature Admin Panel का Booking UUID work-history / immutable final bill / dispute review call अभी Main live database पर resolve नहीं हो सकता।
- Feature source migration में `srk_booking_work_events` append-only event history और Admin-only review RPC का पूरा dependency bundle है; इसे अकेले RPC के रूप में deploy नहीं करना है। Event table, lifecycle trigger, RLS/revokes, bill/complaint dependencies और संबंधित booking schema को साथ reconcile करना होगा।
- Main में `srk_booking_work_events`/नए work-review event schema की मौजूदगी इस query से establish नहीं हुई; इसे अनुपस्थित मानकर destructive action नहीं लेना है। अलग catalog/table verification आवश्यक है।

### 2. Main live customer cancellation अभी पुराना direct path है
- Main में `srk_customer_cancel_my_booking(uuid)` मौजूद है। Body केवल booking owner (`customer_user_id = auth.uid()`), unassigned state और `new/confirmed` status verify करके booking को सीधे `cancelled` करती है।
- यह function Admin-reviewed cancellation request, arrival evidence, ₹99 fee eligibility और Main Admin approval workflow implement नहीं करता।
- Main में cancellation status trigger `srk_cancel_booking_job_offers()` booking cancelled होने पर offered/accepted offers को cancelled करता है; यह trigger केवल offer cleanup है, fee approval workflow नहीं।
- इसलिए PR की source-only cancellation-request flow को Main पर इस पुराने function के साथ parity मानना गलत होगा। पुराने customer cancel path को बंद/बदलने से पहले compatibility, existing clients और complete migration sequence review जरूरी है। इस pass में कोई function/trigger बदला नहीं गया।

### 3. Main legacy electrician status RPC अभी सीमित inspection transition देता है
- Main में `srk_update_booking_work_status(uuid,text)` body केवल `inspection` status स्वीकार करती है; active+approved electrician profile और assigned booking verify करके `assigned -> inspection` transition करती है।
- यह Feature के customer-approved start request, server-clock timer, completion request/approval/rejection/dispute और immutable bill workflow का विकल्प नहीं है।
- इस pass में Feature के नए timer/bill migrations को Main पर apply या पुराने RPC को alter नहीं किया गया।

### 4. Existing refund/payment/payout RPC body evidence rechecked
- Main `srk_admin_list_booking_refund_requests(integer)` refund queue में manual-payment presence, refund record ID, provider status और booking payment fields लौटाता है; इसका signature `p_limit` है।
- Main `srk_admin_decide_booking_refund_request(uuid,text,text)` status allow-list `in_review/approved/rejected` है; यह केवल request status/admin note update करता है, provider refund execute नहीं करता। Feature UI का named argument `p_decision` और Main का `p_status` अभी mismatch है।
- Main `srk_admin_record_manual_payment` completed + approved-quote booking, quote total, manual-only payment और existing manual-entry duplicate रोकता है; Razorpay-linked booking को reject करता है।
- Main `srk_admin_record_manual_refund` केवल verified manual payment refund करता है; Razorpay-linked refund reject, duplicate refund reject, और paid electrician payout होने पर block करता है।
- Main `srk_admin_mark_electrician_payout_paid` legacy approved quote/service-charge/materials reconciliation पर निर्भर है; यह Feature के immutable labour bill/new category payout contract का parity proof नहीं है।
- इन bodies की वजह से पहले Sections 21–22 में दर्ज Feature/Main accounting, refund, payment और payout contract drift अभी unresolved है। इस recheck ने उसे resolve नहीं किया।

### 5. Legacy bulk-offer server guard gap की body-level पुष्टि
- Main `srk_admin_offer_booking(uuid)` का पूर्ण body फिर inspect किया। Booking row lock, unassigned/status checks और active+approved+OTP-linked electrician eligibility मौजूद हैं; लेकिन `selected_category IS NULL` server-side predicate अब भी नहीं है।
- Feature UI guard को अकेला enforcement न मानें। Server-side guard और sequential-dispatch dependency reconciliation अभी आवश्यक हैं; historical offers/booking rows को mutate न करें।

### Status / no-write confirmation
- यह section केवल live read-only SQL/catalog inspection और Feature Branch handover documentation पर आधारित है।
- कोई application code, SQL migration, Production DDL/DML, Auth action, deployment, merge, payment/refund/payout, या mobile QA नहीं किया गया।
- Remaining: work-event schema/table/trigger exact catalog reconciliation; cancellation request migration bundle + old direct cancellation compatibility; Feature timer/bill vs Main legacy status transition dependency mapping; refund/payment/payout contract reconciliation; KYC event-history preservation; legacy offer category hard guard।


## Section 27 — KYC legacy history और work/cancellation schema catalog reconciliation (2026-11-17)

### 1. Main KYC legacy event store की exact स्थिति
- Main में `public.srk_electrician_verification_events` table मौजूद है और RLS enabled है।
- इसका live schema: `id, document_id, electrician_profile_id, actor_user_id, actor_role, event_type, note, created_at`।
- Main live `srk_admin_list_electrician_verification_documents(integer)` और `srk_admin_review_electrician_document(uuid,text,text)` दोनों इसी legacy event table को पढ़ते/लिखते हैं। इसलिए इसे drop/rename करना current live Admin KYC history contract तोड़ देगा।
- Main `public.srk_electrician_verification_document_events` table नहीं मिली। Feature migration `20261115140000_electrician_kyc_review_and_activation_gate.sql` इसी नए table को बनाती है और Feature Admin list/review + electrician submission RPCs उसी पर निर्भर हैं।
- Read-only row count snapshot: legacy KYC events = 0; KYC documents = 0। यह केवल वर्तमान snapshot है, future history को सुरक्षित रखने की आवश्यकता समाप्त नहीं करता।
- Safe integration direction अभी तय नहीं: legacy table को authoritative रखते हुए Feature RPCs को उसी schema पर adapt करना, compatibility layer बनाना, या explicit reviewed backfill/dual-read plan। कोई rename/drop/copy/backfill या migration नहीं किया गया।
- KYC document table live मौजूद है और RLS enabled है; Main legacy list/review function behavior Feature migration से अलग है। Feature review pending-only lock, 5–1000 char rejection/resubmission note, append event, latest KYC approval के आधार पर deactivation/offer advancement लागू करती है; Main body पुराने lock/update/event/deactivation contract पर है। इनका behavioral parity अभी unresolved है।

### 2. Main work-history schema absence की पुष्टि
- Main public catalog में `srk_booking_work_events`, `srk_booking_labour_bills`, `srk_admin_get_booking_work_review(uuid)` नहीं मिले।
- Feature migration `20261114250000_admin_work_dispute_review_and_immutable_history.sql` event table + append-only lifecycle trigger + Admin review RPC बनाती है; यह `service_bookings` के timer/approval columns और `srk_booking_labour_bills` पर निर्भर है।
- Feature follow-up `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql` event mutation रोकने के triggers, private timer authorization dependencies और customer-safe timeline RPC भी जोड़ती है।
- Main `service_bookings` में inspected subset के कुछ पुराने work fields मौजूद हैं, पर Feature का पूरा selected-category/rate snapshot + server timer + immutable bill schema live parity के रूप में स्थापित नहीं हुआ। Full column-by-column reconciliation बाकी है।
- Main `service_bookings` triggers अभी legacy booking broadcast, admin audit, commission, cancellation-offer cleanup, work-approval transition guard, status log और legacy payable generation चलाते हैं। Feature lifecycle event trigger जोड़ने से पहले trigger order/side effects और function dependencies का migration-level review जरूरी है।

### 3. Cancellation migration dependency और compatibility
- Feature migration `20261114270000_admin_only_cancellation_requests_and_decisions.sql` cancellation request table, append-only cancellation event table, direct-cancel guard trigger और customer/Admin RPC workflow जोड़ती है।
- Main catalog में `srk_booking_cancellation_requests` और `srk_booking_cancellation_events` नहीं मिले। Main का पुराना `srk_customer_cancel_my_booking(uuid)` direct-cancel path मौजूद है; Feature migration guard लगाने के बाद पुराने function/client call को intended rejection/compatibility behavior के साथ verify करना होगा।
- Feature cancellation fee/accounting आगे की migrations `20261114280000` और `20261114290000` पर निर्भर है; अकेली request/decision migration पूरी cancellation/accounting rollout नहीं है।
- No schema/function/trigger changes made.

### No-write / next review
- यह section केवल Main live catalog, current KYC function bodies, row counts और Feature migration source का read-only reconciliation है।
- कोई Production DDL/DML, data copy, table rename/drop, migration apply, Auth action, deployment, merge, refund/payout या mobile QA नहीं हुआ।
- Remaining: Feature vs Main complete `service_bookings` column diff; KYC legacy/new event strategy owner/GPT-2 review; old KYC history retention + event immutability parity; cancellation migration 27–29 dependency and legacy direct-cancel behavior; work event trigger ordering and labour bill schema dependency review।


## Section 28 — service_bookings का exact live-column diff और trigger interaction (2026-11-17)

### 1. Main live column inventory — read-only
- Main Supabase project `gnqhoaqatmoiwwhgzkgm` पर `information_schema.columns` से `public.service_bookings` के सभी columns, types, nullability और defaults पढ़े।
- Live table में legacy work fields मौजूद हैं: `work_start_approval_status`, `work_start_requested_at`, `work_timer_running`, `work_timer_seconds`, `completion_requested_at`, `completion_approval_status`, `customer_completed_at`, साथ में legacy `work_started_at`।
- इसलिए इसे “कोई timer/work fields नहीं हैं” कहना गलत होगा। सही स्थिति: कुछ legacy timer/approval columns मौजूद हैं, लेकिन Feature के authoritative timer/bill contract का पूरा schema नहीं है।
- Main live में Feature के इन 10 target columns में से कोई भी नहीं मिला: `selected_category`, `selected_duration_hours`, `selected_rate_tier`, `estimated_labour_paise`, `estimate_rate_card_version`, `work_start_origin_status`, `work_timer_elapsed_seconds`, `labour_rate_tier_snapshot`, `labour_rate8h_paise_snapshot`, `labour_rate_card_version_snapshot`।
- Live `work_timer_seconds` अभी integer है; Feature timer migration इसे bigint बनाती है और fractional elapsed seconds अलग `numeric(24,6)` column में रखती है। केवल column-name overlap से behavioral parity सिद्ध नहीं होती।

### 2. Authoritative Feature migration dependencies
- `20261114160000_customer_selected_rate_tier_and_server_estimate.sql` (blob SHA `940943827c648bd9877faccc52844b81996bfcab`) category/duration/tier/estimate snapshot और electrician approved-tier fields जोड़ती है।
- `20261114240000_server_authoritative_customer_approved_work_timer.sql` (blob SHA `e84e2e0124b90b526d07f305bc9bf1e2eb6f0ebe`) timer elapsed precision, approved rate snapshot, private timer authorization और status/assignment constraints पर निर्भर है।
- `20261114250000_admin_work_dispute_review_and_immutable_history.sql` (blob SHA `1bfb04b90aebeb644cdfa52096222f8d1d8175ec`) `srk_booking_work_events`, append-only lifecycle capture और Admin review RPC बनाती है।
- `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql` (blob SHA `2cf12e7a53d0fbe95de1933d31798d60e442d97f`) work-start authorization और event immutability hardening जोड़ती है।
- Migration ordering और पूरा dependency graph साथ में review करना होगा; किसी एक migration को अकेले apply करना सुरक्षित नहीं माना गया।

### 3. Existing Main trigger interaction — exact inventory
Main `service_bookings` पर ये non-internal triggers live हैं:
- `a_guard_booking` — BEFORE INSERT, `guard_new_booking()`
- `broadcast_new_booking` — AFTER INSERT, `broadcast_booking_job()`
- `srk_audit_service_bookings` — AFTER INSERT/UPDATE/DELETE, admin audit capture
- `srk_calculate_booking_commission` — BEFORE INSERT और financial/status UPDATE
- `srk_cancel_booking_job_offers` — cancellation पर offer cleanup
- `srk_guard_work_approval_transitions` — BEFORE UPDATE OF status
- `srk_log_service_booking_status` — status history log
- `trg_srk_create_electrician_payable` — payment/status/quote/service-charge/materials/assignment changes पर legacy payable generation
Feature work-event trigger जोड़ने से पहले इनके साथ event ordering, same-row writes, recursion, audit payload, cancellation cleanup और legacy payable side-effects का परीक्षण आवश्यक है।

### 4. Cancellation rollout dependency reminder
- `20261114270000_admin_only_cancellation_requests_and_decisions.sql` (blob SHA `131413a17b71530889067bc5c9889ca3bdcfec2b`) request/event tables और direct-cancel guard workflow बनाती है।
- Fee/accounting continuation `20261114280000_cancellation_fee_carry_forward_and_accounting.sql` (blob SHA `e8554d1b8c85810b8dc32eb9428697d9e29dc53a`) और `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` (blob SHA `901512e832279d51ab9278c6ea6522df2a30978c)) पर निर्भर है।
- Main के existing direct-cancel function और live status/offer cleanup triggers के साथ compatibility review अभी बाकी है।

### 5. Verification boundary / no-write
- Live schema, column types और trigger definitions केवल read-only SQL से inspect किए।
- Feature migrations source files से पढ़ीं; कोई migration apply, DDL/DML, trigger/function alteration, production deployment, merge, payout/refund या mobile QA नहीं किया।
- Next: exact status/assignment constraints + trigger function bodies की तुलना; KYC legacy/new event strategy और cancellation direct-call guard के owner/GPT-2 review के बाद ही integration proposal तैयार करना।


## Section 29 — Live status constraints, protected-transition trigger और cancellation/payable interaction (2026-11-17)

### 1. Main live constraints
- `service_bookings_status_check` में वर्तमान allowed states हैं: `new, confirmed, assigned, inspection, awaiting_quote_approval, quote_approved, awaiting_work_start_approval, quote_rejected, in_progress, completed, cancelled`।
- Assignment constraint assigned/work/legacy quote states में non-null `assigned_electrician_id` मांगता है।
- Work-start approval constraint केवल `not_requested/pending/approved/rejected` स्वीकारता है।
- Completion approval constraint में `not_requested/pending/approved/rejected/disputed/admin_approved/reopened` पहले से हैं।
- Timer seconds constraint integer seconds को 0–604800 तक सीमित करता है।
- Feature timer migration status/assignment constraints को replace करती है; rollout में existing rows और status values की preflight validation आवश्यक है।

### 2. Existing Main protected work transition guard
- Live `srk_guard_work_approval_transitions()` SECURITY DEFINER trigger function `srk_private.work_transition_authorizations` में current transaction, booking और target status का authorization खोजती है।
- यह direct `in_progress/completed` status transition रोकती है; completion पर approved/admin_approved और start पर approved/reopened state भी मांगती है।
- Feature timer migration इसी protected-authorization pattern को आगे बढ़ाती है और `srk_private.work_transition_authorizations` के साथ timer-specific authorization table रखती है। इसलिए यह “नई authorization प्रणाली पूरी तरह अलग है” वाला मामला नहीं; मौजूदा Main guard को final Feature RPC definitions और transaction-scoped authorization writes के साथ regression-test करना होगा।
- Feature event capture trigger अतिरिक्त AFTER trigger होगा; existing BEFORE status guard और AFTER audit/status/payable triggers के साथ ordering/rollback behavior test करना बाकी है।

### 3. Existing Main legacy payable gate — high-priority accounting compatibility
- Live `trg_srk_create_electrician_payable` केवल तब payable बनाता/अपडेट करता है जब booking `payment_status='paid'`, `status='completed'`, `quote_status='approved'`, electrician assigned, payment verified हो और Razorpay/manual payment evidence मौजूद हो।
- इसके बाद यह `service_charge + materials_amount` को quote total से मिलाता है और quote-based commission/payable लिखता है।
- Feature नए category flow को quotation-free बताती है और immutable labour-only bill / separate material treatment पर आधारित है। यदि Feature की authoritative payout reconciliation migration इस legacy trigger को safely replace/branch नहीं करती, तो नया completed+paid booking legacy quote gate पार नहीं करेगा और payable छूट सकता है; दूसरी ओर legacy quote branch को हटाना पुराने NULL-category bookings को प्रभावित कर सकता है।
- यह release blocker है: payout path को Main legacy bookings और नए category bookings के लिए अलग, idempotent, audited reconciliation के साथ प्रमाणित करना होगा। केवल trigger का नाम/मौजूदगी देखकर payout parity घोषित नहीं की जा सकती।

### 4. Cancellation approval interaction
- Feature Admin decision RPC Booking row पहले lock करता है, फिर pending request lock/revalidate करता है; approval पर transaction-local `srk.cancel_request_id` सेट करके booking को cancelled करता है।
- Feature status guard में इसी approved request ID और booking relationship की जाँच के बाद cancellation allow करने का path है।
- Main live cancellation trigger cancelled होने पर `job_offers` के offered/accepted records को cancelled करता है। यह cleanup रखना जरूरी है; cancellation integration के बाद trigger firing और rollback atomicity verify करनी होगी।
- Main के पुराने direct-cancellation RPC/function को नए request-only path के साथ reconcile करना बाकी है; UI guard अकेला पर्याप्त नहीं।

### 5. Verification / next actions
- Live constraints और सात trigger functions की definitions read-only SQL से inspect कीं। कोई live row या schema नहीं बदला।
- Feature timer, work-event, cancellation और payout migration source files inspect कीं; कोई migration apply नहीं की।
- Next: Feature payout migration में payable trigger replacement/branch को पूरा पढ़कर exact diff निकालना; फिर legacy NULL-category vs new-category payment/completion/refund cases के static/pgTAP matrix तैयार करना। उसके बाद GPT-2/owner के साथ payout contract और cancellation direct-call guard पर निर्णय आवश्यक है।


## Section 30 — Feature payout reconciliation migration: legacy parity, trigger coverage और remaining blockers (2026-11-17)

### 1. Main vs Feature payable function
- Main live `srk_create_electrician_payable()` अभी legacy-only है: `payment_status='paid'`, `status='completed'`, `quote_status='approved'`, assignment, payment verification और Razorpay/manual payment evidence के बाद quote service+materials से payout बनाता है।
- Feature migration `20261114360000_new_category_electrician_payout_reconciliation.sql` (blob SHA `bc657107350b43a392b7883238be1b3e00a02ee2`) इस legacy path को बनाए रखती है और `selected_category IS NOT NULL` पर immutable labour bill path जोड़ती है।
- New-category branch bill का electrician assignment और positive labour amount verify करती है; amount_paid को labour + reserved/settled cancellation fee items से मिलाती है; electrician gross service और commission केवल labour पर calculate होते हैं, cancellation fees electrician earnings में शामिल नहीं होतीं।
- Legacy NULL-category branch अब भी approved quote और service+materials total पर निर्भर है। इस प्रकार source migration दोनों paths अलग रखती है; Main live में यह Feature implementation अभी लागू नहीं है।

### 2. Payout settlement hard checks
- Feature `srk_admin_mark_electrician_payout_paid(uuid,text,text,text)` Admin-only है; UPI/Bank method और valid reference मांगती है; Booking-first फिर Payout row lock करती है।
- New-category payout में bill/booking electrician match, completed+paid+verified payment, exact labour+settled fee total, Razorpay/manual payment evidence, no reserved fee items और ledger gross/materials/commission/payable parity check होती है।
- Legacy branch approved quote, exact payment, electrician assignment और ledger calculations re-check करती है।
- यह source-level contract है; live runtime behavior नहीं। Manual payout ही वर्तमान owner-approved payout mode है; Razorpay Route retired है।

### 3. Trigger coverage gap to resolve before rollout
- Main live payout trigger अभी `service_bookings` पर INSERT या UPDATE OF `payment_status,status,quote_status,service_charge,materials_amount,assigned_electrician_id,payment_verified_at,razorpay_payment_id,amount_paid` पर fire होता है।
- Feature migration trigger list वही fields रखती है; इसमें `selected_category` और `commission_rate` नहीं हैं।
- इसलिए यदि इन दो fields में से किसी का standalone correction/update payout eligibility या commission बदलता है, trigger ledger को स्वतः recalculate नहीं करेगा। यह तभी सुरक्षित है जब upstream workflow इन्हें payable trigger से पहले immutable/final कर दे; उस invariant को migration chain और constraints से प्रमाणित करना बाकी है।
- Labour bill table Main live catalog में मौजूद नहीं मिली (column inventory query ने zero rows लौटाईं); Feature payout function उसे अनिवार्य रूप से पढ़ती है। Main पर इस migration को अकेले लागू करना असंभव/असुरक्षित है; पूरी bill + timer + cancellation fee dependency chain आवश्यक है।
- Feature payout migration `srk_booking_labour_bills` insert/update पर अलग payout trigger नहीं बनाती। Expected workflow में bill completion transaction के दौरान पहले बने और फिर booking status/payment transition trigger को fire करे—इस transaction-order invariant को work-completion RPC source और tests से प्रमाणित करना होगा।

### 4. Refund replay caveat
- Feature payout trigger refund पर pending payout को `refunded` करता है और केवल refund-owned blocked notes (`Razorpay refund pending`, `Manual refund processed`) को release करता है; unrelated Admin block और already-paid payout को overwrite नहीं करना चाहिए।
- Main live पुराने function में refund path केवल pending payout को refunded करता है; refund-owned blocked payout handling और payout-note preservation parity अभी नहीं है।
- यह GPT-2 के Manual Refund Note Preservation और Refund Replay work के साथ joint review मांगता है।

### 5. Verification boundary / next
- Main live payout function, trigger definition, payout unique index और bill table catalog read-only queries से inspect किए। Feature payout migration पूरी पढ़ी।
- कोई Production DDL/DML, migration apply, payout/refund, deployment, merge या mobile QA नहीं किया।
- Next: exact work-completion RPC transaction ordering और bill immutability/unique constraints inspect करें; commission/category immutability proof लें; फिर legacy/new category × Razorpay/manual × full/partial refund × pending/blocked/paid payout replay matrix GPT-2 के साथ reconcile करें।


## Section 31 — Labour Bill transaction ordering, immutability और commission-trigger coverage (2026-11-17)

### 1. Completion transaction order verified in Feature source
- `20261114240000_server_authoritative_customer_approved_work_timer.sql` (SHA `e84e2e0124b90b526d07f305bc9bf1e2eb6f0ebe`) में `srk_customer_respond_work_completion(uuid,text,text)` customer ownership और pending completion request lock/verify करती है।
- Approved response पर उसी transaction में पहले `srk_booking_labour_bills` में final bill INSERT होता है; उसके बाद protected `completed` status transition और `service_charge` update होता है। इसलिए booking payable AFTER trigger fire होने तक bill row transaction में मौजूद होती है। किसी बाद के step में exception आए तो PostgreSQL transaction bill और booking update दोनों rollback करेगी।
- Bill guard INSERT को उसी transaction के `work_timer_authorizations` record और authenticated actor से बांधता है; booking customer/electrician, stopped timer, pending completion request, category/rate snapshots, elapsed seconds, billable minutes और paise amount server booking snapshot से पुनः verify करता है।
- Bill table में `booking_id` PRIMARY KEY है; FK booking DELETE पर RESTRICT; customer/electrician FKs भी RESTRICT। UPDATE और DELETE हमेशा reject होते हैं। Labour amount paise-to-rupee consistency CHECK से enforce है। Table RLS enabled और PUBLIC/anon/authenticated table privileges revoked हैं।
- यह source-level transactional proof है; Main DB पर dependency migrations अभी apply नहीं हैं।

### 2. Work completion Admin review
- `srk_admin_get_booking_work_review(uuid)` उसी bill row, work event history और complaints को पढ़ता है; Admin auth check मौजूद है।
- `20261114260000` में customer work-start response fix है; यह final bill creation function को replace नहीं करता। Completion bill path अभी `20261114240000` में defined है।
- Append-only work event migration अलग से UPDATE/DELETE/TRUNCATE रोकती है; replay verification अभी शेष है।

### 3. Trigger field coverage — refined finding
- Feature status guard में `selected_category` बदलने पर हमेशा `BOOKING_CATEGORY_IS_IMMUTABLE` raise होता है। इसलिए payout trigger के UPDATE OF list में `selected_category` न होना अकेले bypass नहीं है; approved category immutable है।
- Main live `srk_calculate_booking_commission()` BEFORE UPDATE OF `commission_rate` trigger से rate को 0–100 range में validate करता है और `commission_amount` recalculate करता है। Main live payout trigger की UPDATE OF list में `commission_rate` नहीं है। अतः यदि commission_rate paid/completed booking पर अलग update हो, commission_amount बदल सकता है पर payout ledger स्वतः recalculate नहीं होगा।
- Main public function inventory में commission_rate का reference केवल booking guard, commission calculation, finance dashboard और payout functions में मिला; कोई dedicated Admin commission-rate RPC नहीं मिला। फिर भी database-level update path/owner operation को बंद या immutable सिद्ध नहीं किया गया।
- Safe release choice: either `commission_rate` को payout calculation के लिए immutable snapshot बनाएं/updates रोकें, या payout trigger में `commission_rate` जोड़ें और paid/complete recalculation के replay cases test करें। GPT-2/owner review आवश्यक; अभी कोई code change नहीं किया।

### 4. Main live database cross-check
- Main live `service_bookings` में `commission_rate` मौजूद और NOT NULL है; `selected_category` अभी absent है।
- Main live `service_bookings` पर BEFORE commission trigger और AFTER payout trigger मौजूद हैं। Payout trigger field list में commission_rate नहीं है।
- Main live payout function अभी legacy quote-only है और Main live में `srk_booking_labour_bills` table नहीं मिली। इसलिए Feature timer/bill/payout migration chain Main पर लागू नहीं है।
- कोई Production DDL/DML, migration apply, payout/refund, deployment, merge या mobile QA नहीं किया।

### 5. Next verification
- GPT-2 के साथ commission-rate immutability vs trigger-field update decision।
- Bill insert + completion update + payment transition + payout creation के success/rollback/idempotent replay tests।
- Refund replay matrix में pending, refund-owned blocked, unrelated Admin blocked और paid payout states; payout-note preservation की assertion।


## Section 32 — Manual Refund ↔ payout trigger transaction-order conflict (2026-11-17)

### Critical source-level conflict found
- Feature migration `20261115130000_admin_manual_refund_request_completion.sql` (SHA `51f3b13adc80e117cc62f05b0e70ae795ee0f9fd`) में `srk_admin_record_manual_refund(uuid,text,text)` पहले pending payout को `blocked` + `payout_note='Manual refund processed'` बनाती है।
- उसी RPC में बाद में `service_bookings.payment_status='refunded'` update होता है। यह `20261114360000_new_category_electrician_payout_reconciliation.sql` का AFTER payout trigger चलाता है।
- उस trigger का refund branch `pending` payout या `blocked` payout whose note is `'Razorpay refund pending'` / `'Manual refund processed'` को तुरंत `refunded` करता है और `payout_note=NULL` लिखता है।
- Manual Refund RPC इसके बाद payout row को फिर update करने की कोशिश करती है, लेकिन WHERE condition `payout_status='blocked'` मांगती है; trigger ने उसे पहले ही `refunded` कर दिया है। इसलिए UPDATE zero rows लौटाता है और RPC `BLOCKED_PAYOUT_COULD_NOT_BE_CLOSED_AS_REFUNDED` exception देती है।
- PostgreSQL exception पूरे transaction को rollback कर देगी: manual refund entry, booking refunded status और payout state सभी rollback होंगे। बाहरी वास्तविक transfer पहले हो चुका हो तो उसके लिए यह गंभीर reconciliation risk है।
- यह static source ordering से निकला high-confidence finding है; live execution test नहीं चलाया गया। मौजूदा `admin_manual_refund_request_completion.test.sql` केवल RPC body में refund status closure text की मौजूदगी assert करता है; trigger interleaving/rowcount conflict को test नहीं करता।

### Required coordinated correction (not applied)
- GPT-2/owner को एक authoritative close owner चुनना होगा: या payout trigger refund-owned manual hold को पहले close करे और RPC उसी exact final state/note को idempotently verify करे; या trigger manual-refund-owned hold को RPC के explicit finalization तक blocked छोड़े।
- किसी भी fix में unrelated Admin blocked payout note preserve हो, Razorpay-owned marker अलग रहे, already-paid payout reject हो, और repeated finalize सुरक्षित हो।
- Add transaction-level pgTAP regression: pending payout → manual refund RPC → trigger ordering → final refunded payout + durable audit row; injected failure must prove full DB rollback while external transfer reference/recovery evidence remains independently durable.
- Existing RPC lock order booking → refund request → payment evidence/fee rows → payout should remain consistent with Razorpay refund reconciliation and payout settlement; concurrency test still needed.

### Verification boundary
- केवल Feature Branch source files और existing pgTAP assertions inspect किए।
- कोई code/SQL edit, migration apply, Production DDL/DML, external money transfer, provider API call, deployment, merge या mobile QA नहीं किया।


## Section 33 — Manual Refund conflict: safe reconciliation design and regression coverage (2026-11-17)

### 1. Cross-check against existing Razorpay repair pattern
- Razorpay migration `20261115250000_harden_refund_reconcile_full_amount.sql` (SHA `56d300abc8495d1c5c5371d60bc0321650623db5`) already handles an analogous trigger interleaving: after booking becomes refunded, if the trigger has already changed the exact refund-owned payout to `refunded` and cleared its note, the RPC restores the provider-confirmed final note only when `payout_status='refunded' AND payout_note IS NULL`.
- Manual refund RPC does not yet implement the equivalent post-trigger reconciliation. It only tries `WHERE payout_status='blocked'`, so it conflicts with the trigger's earlier transition.
- The Razorpay pattern is a useful precedent, but cannot be copied blindly: manual refund uses a different exact marker (`Manual refund processed`) and final audit note, and must keep unrelated Admin block reasons untouched.

### 2. Proposed narrow correction for GPT-2/owner review
- Preserve the existing pre-update locked payout row in `v_payout`.
- If it was pending, the RPC creates its own exact `Manual refund processed` hold. After booking refund update fires the trigger, accept only either:
  1. the same payout still blocked with exact manual-refund marker, then close it to refunded; or
  2. the same payout already refunded with NULL note because the trigger closed that exact marker, then restore `Manual refund completed` as the final audit note.
- If it is already blocked for any other reason, already paid, or has any unexpected state/note, raise and rollback. Do not overwrite unrelated Admin notes.
- If payout was already blocked before RPC entry, do not assume it is a manual-refund-owned hold. The current code permits any blocked payout to proceed; this should be reviewed explicitly and likely reject unless the block reason is an approved recoverable state.
- Keep all writes inside the same booking-first transaction and keep the payout audit trigger enabled.

### 3. Required regression tests (current tests are static)
- Extend `admin_manual_refund_request_completion.test.sql` to assert the post-trigger fallback recognizes only `refunded + payout_note IS NULL` for the exact payout row and restores `Manual refund completed`.
- Add transaction-level fixtures for: pending payout; unrelated Admin blocked payout; pre-existing refund-owned blocked payout; already-paid payout; no payout row; duplicate manual refund replay.
- Assert success case leaves booking refunded, one manual refund entry, approved request processed, payout refunded with final note, and immutable audit events for each state transition.
- Assert conflict/failure cases rollback booking, refund entry, request and payout atomically.
- Add concurrent settlement/refund test to verify booking → request/payment evidence → payout lock ordering; no provider call is part of the DB test.
- Existing test `admin_manual_refund_request_completion.test.sql` (SHA `211fe123674a6e7affc207d02ddbae350e4cdc8f`) is source-definition/static pgTAP coverage; it currently checks the existence of a blocked-to-refunded update but does not model the AFTER booking trigger running between the two RPC statements.
- Existing `electrician_payout_reconciliation.test.sql` (SHA `e80aa9213343c280bab95b786e29f0386a010d65`) checks that trigger contains both refund markers and clears the note, which together expose the interleaving but do not prove end-to-end RPC success.

### 4. Decision boundary
- This is a proposed correction, not an applied patch. The manual refund, payout trigger, Razorpay reconciliation, and GPT-2 refund replay work must be reviewed together before changing source.
- No SQL/code changed in this section; no test execution, Production DDL/DML, migration apply, external transfer/refund, deployment, merge or mobile QA.


## Section 34 — Manual Refund pre-existing payout state matrix: unrelated Admin block overwrite risk (2026-11-17)

### Additional critical finding
- Manual Refund RPC currently allows any pre-existing `payout_status='blocked'` row to continue; it does not verify `payout_note` ownership before refund.
- After booking status changes to refunded, payout trigger only closes refund-owned holds whose note exactly matches `Razorpay refund pending` or `Manual refund processed`. An unrelated Admin block remains blocked.
- Manual Refund RPC then executes an unconditional `UPDATE ... WHERE id=v_payout.id AND payout_status='blocked'`, changing that unrelated Admin block to `refunded` and replacing its note with `Manual refund completed`.
- Thus the earlier trigger interleaving is not the only defect: even after adding a safe trigger fallback, a pre-existing unrelated Admin block could be silently overwritten unless the RPC validates the original locked payout state and note before writing.

### Required payout state policy
| State at RPC entry | Safe handling |
| --- | --- |
| No payout row | Continue refund; no payout transition |
| `pending` | Claim with exact `Manual refund processed` marker; after booking trigger, reconcile only exact marker or exact trigger-produced `refunded + NULL note` |
| `blocked` + exact `Manual refund processed` | Treat only as an explicitly approved recoverable manual-refund hold; reconcile carefully |
| `blocked` + any other note (including NULL) | Reject for Admin reconciliation; never overwrite |
| `paid` | Reject with recovery-required error |
| `refunded` or other terminal/unexpected state | Reject unless an explicitly designed idempotent replay path proves matching refund entry/reference |

### Tests to add before enabling the fix
- Existing blocked Admin note (including NULL note) must remain unchanged and manual refund RPC must fail atomically.
- Exact refund-owned marker may be finalized, but only for matching booking/payout and no existing refund entry.
- Trigger-produced `refunded + NULL note` is accepted only when the RPC itself had changed the locked pending payout to the exact manual marker earlier in the same transaction; never accept a pre-existing refunded row merely because note is NULL.
- Pending payout happy path verifies final note, audit history, booking state, refund entry and customer request status.
- The test must exercise actual trigger invocation from `service_bookings.payment_status` UPDATE, not only inspect function source strings.

### Coordination and boundary
- PR #8 currently has no submitted review or review-thread feedback for this proposed correction; no GPT-2 approval is visible in the available PR review data.
- Because payout trigger, manual refund RPC, Razorpay reconciliation and GPT-2 replay work intersect, no implementation change is made until the owner/GPT-2 jointly confirms the state policy.
- No code/SQL changed, no test run, no Production writes, provider actions, deployment, merge or mobile QA.


## Section 35 — Admin Panel non-RPC integration surface and remaining security checks (2026-11-17)

### Current source snapshot
- Re-fetched `admin.html`; SHA `6b29511a1ecfab93b5689dff23012078091e57fc`.
- Re-extracted all Admin client integration entry points: 53 distinct RPC names remain; client also invokes Edge Functions `admin-staff-management` and `electrician-phone-change`.
- Direct Supabase table references include `electrician_applications`, `electrician_profiles`, `service_bookings`, `srk_electrician_payouts`, and Storage bucket `srk-customer-support` (the bucket reference is via Storage, not a SQL table).
- This is a source inventory, not proof that direct access is authorized or correctly RLS-protected in Main.

### Required integration gates
1. **Direct table reads:** verify each exact SELECT/UPDATE operation, selected columns, filters and pagination against Main RLS and grants. Admin UI visibility checks are not a replacement for database authorization.
2. **Storage attachments:** verify private bucket status, object path ownership, signed URL lifetime, MIME/size limits, and Admin/Staff role-specific read policy. Do not expose public object URLs for customer support attachments.
3. **Staff Edge Function:** `admin-staff-management` invitation flow must be tested only after UUID cross-registry exclusivity is implemented and reviewed. Invitation sends an externally visible email; no test/invitation without explicit approval and isolated staging.
4. **Electrician phone-change Edge Function:** verify actor identity, current phone/session challenge, OTP provider boundary, rate limits, audit event and profile ownership. No OTP/SMS or phone change operation is to be triggered during this audit.
5. **RPC call-site arguments:** continue exact named-argument and response-field mapping for all 53 names. Existing refund named-argument/queue shape mismatch and missing Staff/Support RPC bundles remain release blockers.

### Scope decision
- No new feature or UI change is proposed. These checks are part of existing Admin Panel integration/security verification.
- No direct table write, Storage object read/write, Edge Function invocation, invitation, email, OTP/SMS, Production DDL/DML, deployment, merge or mobile QA occurred.


## Section 36 — Admin direct-table RLS and Storage bucket live-Main verification (2026-11-17)

### Live Main catalog snapshot
- Project: `gnqhoaqatmoiwwhgzkgm`; read-only SQL/catalog inspection only.
- Admin direct-read tables `electrician_applications`, `electrician_profiles`, `service_bookings`, and `srk_electrician_payouts` all exist, have RLS enabled, and grant `SELECT` to `authenticated`; the inspected grant snapshot did not show direct authenticated INSERT/UPDATE/DELETE grants for these four tables.
- Exact live policies:
  - `electrician_applications`: SELECT and UPDATE scoped to `is_srk_admin()`; UPDATE has both USING and WITH CHECK.
  - `electrician_profiles`: SELECT is owner (`auth_user_id` or `user_id`) or Admin; INSERT/UPDATE/DELETE are Admin-only, with UPDATE USING + WITH CHECK.
  - `service_bookings`: SELECT is Admin or booking customer; UPDATE is Admin-only with USING + WITH CHECK. The current Admin UI uses direct reads plus protected RPCs for the restricted state transitions; do not treat the broad row policy as permission to bypass lifecycle RPC guards.
  - `srk_electrician_payouts`: SELECT is Admin or the linked electrician owner. No direct authenticated mutation grant was present in the inspected table-grant result; payout state changes must continue through the audited Admin Manual Payout RPC.
- RLS is enabled but not FORCE on these four tables. This is not by itself a defect: privileged owners/SECURITY DEFINER functions can bypass RLS, so their body authorization and grants remain separately important.

### Storage bucket and object-policy findings
- Live `storage.buckets` query returned only one bucket: `srk-electrician-verification`, private, 5 MiB limit, MIME allow-list PDF/JPEG/PNG.
- Admin KYC UI uses `ADMIN_KYC_BUCKET` for short-lived signed previews (60 seconds). Live Storage policies include authenticated owner upload, owner-or-`is_srk_admin()` read, and owner cleanup only while the object is not registered in `srk_electrician_verification_documents`. The bucket is private; Admin preview is not a public URL.
- Admin Customer Support UI requests signed URLs from bucket `srk-customer-support` for 300 seconds. That bucket is absent from live Main.
- Live Main also lacks `srk_booking_complaint_messages` and `srk_booking_complaint_message_attachments` tables. Feature migration `20261113220000_customer_support_conversation_schema.sql` (SHA `75230ab805e61206515fd73e17e748de7ec249e5`) creates these dependencies, creates the private 10 MiB support bucket with JPEG/PNG/WebP/PDF allow-list, and installs owner/admin object access policies. The migration is not reflected in the queried Main catalog. Thus Customer Support attachment signed URLs cannot work on current Main until the entire reviewed support schema + bucket + policies bundle is integrated; do not create the bucket alone.
- Live Main Storage object policies currently list only the three electrician-verification policies. No support-bucket policy exists in the inspected catalog.

### Security advisor triage
- Supabase Security Advisor snapshot reported 13 RLS-enabled/no-policy INFO findings, 59 authenticated-executable SECURITY DEFINER WARN findings, one `pg_net`-in-public WARN, and leaked-password protection disabled WARN.
- These are project-wide findings, not all Admin Panel defects. RLS/no-policy on append-only/audit/payment tables may be intentional when all access is via narrowly authorized SECURITY DEFINER RPCs and direct grants are revoked; verify grants and each function body before classifying. Similarly, authenticated EXECUTE on a SECURITY DEFINER Admin RPC is expected only when its body enforces Main Admin/Staff authorization and anon/PUBLIC execution is revoked. Do not blanket-revoke or alter functions based on advisor counts alone.
- Leaked-password protection is an Auth-wide security hardening item, not an Admin direct-table/Storage authorization finding; enabling it changes project Auth behavior and requires owner approval.
- Advisor remediation references: Supabase Database Linter RLS no-policy `https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy`; SECURITY DEFINER executable `https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable`; leaked password protection `https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection`.

### Status / next steps
- Four Admin direct-read tables have explicit Admin/owner RLS policies as summarized above; KYC documents remain private and Admin-previewable.
- Customer Support attachment flow is a confirmed Main integration blocker: bucket + message/attachment tables + RPCs + policies are missing as a bundle.
- Next: inspect the full Main live function bodies behind Admin reads and mutations, and map each direct-table query's exact column/filter requirements to existing grants and RLS. Review support bundle dependencies together with GPT-2; do not apply migrations or create buckets in Production.
- No DDL/DML, bucket creation, object access, signed URL generation, policy change, function change, Auth setting change, deployment, merge, external action, or mobile QA was performed.


## Section 37 — Admin Panel live RPC authorization + contract parity snapshot (2026-11-17)

### Admin.html current surface
- Re-fetched `admin.html`; SHA remains `6b29511a1ecfab93b5689dff23012078091e57fc`.
- 53 distinct RPC names are called by the Admin UI.
- Five direct Supabase surfaces are referenced: `electrician_applications`, `electrician_profiles`, `service_bookings`, `srk_electrician_payouts`, and Storage bucket `srk-customer-support`.
- Direct reads observed:
  - `service_bookings`: explicit booking fields for the main dashboard and small eligibility snapshots before protected RPC actions.
  - `electrician_profiles`: one small explicit eligibility projection before activation.
  - `electrician_applications` and `electrician_profiles`: broad `select('*')` in dashboard load, bounded to 300 and 500 rows respectively.
  - `srk_electrician_payouts`: bounded latest 300 rows with joined display name/phone, plus paginated summary reads of id/payable/status.
  - No direct table `.update()`/insert/delete write chain was observed in the extracted direct-table call sites; state-changing Admin actions use RPCs.
- Broad `select('*')` is Admin-RLS-scoped today, but is unnecessary data over-fetch and makes UI coupling sensitive to future schema additions. Treat as a minimization/code-review item, not a proven unauthorized disclosure. Do not change until the agreed scope is reviewed.

### Main live RPC inventory
- Queried all 53 exact Admin UI RPC names against the live Main `public` catalog.
- 17 exact names exist in Main; 36 exact names are absent from Main public catalog. This is consistent with the previously documented incomplete Feature→Main migration parity. Missing functions are not assumed to be absent from Feature; their Feature migration dependency bundles remain tracked in earlier sections.
- All 17 present functions are SECURITY DEFINER, EXECUTE is false for `anon` and true for `authenticated`, and every one explicitly references `auth.uid()` and `is_srk_admin()` in its body. No present Admin RPC in this 17-function sample used the Staff permission helper. This means the live Main functions inspected are Main-Admin-only, not Support-Staff-capable. This is consistent with the known unintegrated Staff RBAC migration; do not grant Staff access by changing grants alone.
- All 17 functions have a configured search_path. Fifteen pin `pg_catalog, public, auth, pg_temp`; two use `search_path = ''`: `srk_admin_decide_booking_refund_request` and `srk_admin_list_booking_refund_requests`. Their bodies schema-qualify referenced objects/functions in the inspected definitions. No search_path change made.
- Main `is_srk_admin()` checks only membership in `srk_admin_users`, and is SECURITY DEFINER with pinned search_path. The separate Main Admin vs Staff UUID exclusivity blocker remains unresolved; no Staff helper or invariant added.

### Contract mismatch re-confirmation
- Live Main `srk_admin_decide_booking_refund_request(uuid,text,text)` argument is `p_status`, while Admin UI calls the same RPC with `p_decision`. PostgREST named-argument invocation therefore does not match the live Main signature.
- Live Main `srk_admin_list_booking_refund_requests(integer)` returns legacy columns including `id`, `amount`, `status`, `refund_record_id`, `refund_id`, and `provider_status`; current Admin UI expects newer projection keys such as `request_id`, `request_amount`, `request_status`, `refund_record_status`, and payout/customer details. This is a response-shape incompatibility, not just a missing UI field.
- Other major Admin workflow RPCs remain missing from Main: staff inbox/assignment/session APIs, customer and electrician support message APIs, SOS, cancellation, work-review, accounting reconciliation, new-category cash payment, legacy confirm, and rate-tier operations. The earlier migration bundle/dependency notes remain authoritative.
- Existing Main `srk_admin_mark_electrician_payout_paid`, `srk_admin_record_manual_payment`, `srk_admin_record_manual_refund`, `srk_admin_review_application`, `srk_admin_review_electrician_document`, and `srk_admin_set_electrician_active` all include explicit Main Admin authorization checks. Payout settlement also locks booking then payout; the inspected function requires payment evidence and reconciled booking/payout amounts. This is static body inspection, not runtime proof.

### Status / next steps
- Confirmed: Main currently supports only the 17 overlapping Admin RPC contracts; the rest of the 53-name UI surface is not deploy-ready on Main.
- Confirmed: current Main Admin RPCs inspected are Main-Admin-only; Staff support requires the complete RBAC + support inbox/session bundle and the UUID exclusivity invariant review.
- Next read-only inspection: source of `admin-staff-management` and `electrician-phone-change` Edge Functions, plus their environment/config/auth boundaries. Do not invoke them, invite staff, send OTP, change phone, or send external messages.
- No code/SQL changes, migrations, function execution, direct table writes, Storage URL creation, Staff invitation, OTP, payout, refund, deployment, merge, or mobile QA performed in this section.


## Section 38 — Edge Function staff invitation + electrician phone-change security review (2026-11-17)

### `admin-staff-management` Edge Function
- Source re-fetched: `supabase/functions/admin-staff-management/index.ts`, SHA `c783989ca7142fce9d88270286bc916a66d22298`.
- Accepts POST only (plus CORS preflight), requires a Bearer token, validates it using `auth.getUser(token)`, and checks `userClient.rpc('is_srk_admin') === true`. It does not trust browser-supplied user/app metadata for role.
- Only supported action is `invite_support_staff`; email/name are validated; role is fixed server-side to Support; redirect URL is protocol/host checked. Service-role key is used only server-side.
- Invitation email is sent by `inviteUserByEmail` before `srk_admin_staff_register_invited_user` registers the Staff row. If registration fails, the function attempts to delete the Auth identity, but cannot retract an email already delivered. This side-effect ordering is an operational retry risk already identified; no invocation/invitation was made.
- No explicit application-level invitation rate limit was found in this Edge Function source. This is a review item, not proof of abuse or a confirmed vulnerability; do not add rate limiting outside approved scope.
- Function uses wildcard CORS origin but still requires a valid Bearer token and server-side Main Admin check. No CORS change proposed from static inspection alone.

### `electrician-phone-change` Edge Function + Feature migration
- Source re-fetched: `supabase/functions/electrician-phone-change/index.ts`, SHA `372e52c8ca18a7ca984ae2de2fcdbb2a5ea87bc5`.
- Every action first validates the Bearer token with `auth.getUser(token)`. Customer-side send/verify/history actions pass the verified actor UUID to service-role RPCs; Admin actions additionally call `is_srk_admin()` before the Admin queue/review branches. No user-supplied role metadata is used.
- OTP is generated using Web Crypto CSPRNG with rejection sampling; only HMAC-SHA256 digest is persisted; expiry is 5 minutes; wrong attempts are capped at five; migration enforces at most three requests/hour and a 60-second resend gap; only one open request per electrician and one open request per new phone are allowed.
- The preparation RPC requires exactly one matching electrician profile, a verified current Auth phone, a different and globally unused new Indian number, and a 10–500 character reason. The OTP verify RPC locks the request row and consumes the digest on success.
- Admin approval is a two-stage claim → Auth phone update → profile finalize flow. It checks the Auth number before changing it, supports retry after an interrupted Auth/profile sync, and records sync_error instead of silently rolling back an ambiguous external Auth update. Admin claim/finalize/release/reject RPCs check the supplied Admin UUID against `srk_admin_users`; Edge Function derives that UUID from the verified JWT actor.
- Feature migration `20261114380000_electrician_phone_change_admin_approval.sql`, SHA `0c389a039afab594b092fc69b81bc9fbc4bff650`, revokes all direct execute from public/anon/authenticated and grants the phone-change RPCs only to service_role. This makes the Edge Function's JWT-to-actor binding especially important; no direct RPC execution or OTP send was performed.
- Live Main check: phone-change request table and public phone-change RPCs are absent. The live Main catalog also lacks Staff registry, Staff sessions, and support assignment tables. These workflows are Feature-branch source only until their approved migration bundles are integrated; do not test them against Main.

### RBAC integration boundary
- Feature Staff RBAC migration `20261114390000_admin_staff_rbac_foundation.sql`, SHA `5aa0f9058a56d735455f2a9944c861e8312ddb89`, creates separate Staff registry/session/audit/assignment objects and permission-scoped customer/electrician support RPCs. The Edge Function intentionally invites only the fixed Support role.
- Migration comments and helper logic preserve Main Admin as a distinct full-control class, but the previously recorded race-safe cross-table UUID exclusivity invariant still needs owner/GPT-2 resolution. The invite registration RPC must not be treated as proof that a user UUID is excluded from `srk_admin_users`; no change made.
- Since these migration bundles are absent from Main, no production invitation, phone-change workflow, OTP, or Staff session was exercised.

### Status / next steps
- Static Edge Function and migration source review complete; live Main absence confirmed for phone-change and Staff tables.
- Next: inspect refund Edge Function source and its authentication/idempotency/provider boundaries, then reconcile all remaining Admin UI→Feature migration dependency bundles with GPT-2 without changing the GPT-2 Audit Branch.
- No Edge Function invocation, invitation, email, OTP/SMS, Auth phone update, Staff creation, migration, SQL write, deployment, merge, or mobile QA occurred.


## Section 39 — Razorpay Refund Edge/API handler static security review (2026-11-17)

### Refund initiation handler
- Root source `razorpay-refund.js`, SHA `afd68c6c1dd33102c40f5119616aec78e8f0ae1e`; Netlify wrapper only re-exports this handler.
- POST-only; validates bearer-token shape, verifies the token against Supabase Auth, then asks live DB `is_srk_admin()` using the same user token. No client role metadata is trusted; only Main Admin may initiate.
- Refund preparation is delegated to `srk_admin_prepare_razorpay_refund`; provider request uses exact prepared payment ID, paise amount, receipt/idempotency key, and record IDs in notes. Amount is a safe integer >= 100 paise; payment and idempotency identifiers are format-checked.
- Network timeout/ambiguous provider result retains hold and instructs same-record retry; provider 409 is treated as still processing; other provider errors are held for reconciliation. Successful provider response must match payment, amount, INR currency, refund ID and allowed status before DB reconciliation RPC is attempted.
- If provider accepted but DB reconciliation fails, response leaves reconciliation pending and points to signed webhook recovery. No new refund record or payout release is attempted by the handler in that path.

### Read-only provider status handler
- Root source `razorpay-refund-status.js`, SHA `35d2086391485aa0f760e3431028ea962690647a`.
- POST-only; verifies Supabase user and Main Admin membership before querying internal record/provider. Requires exactly one internal refund record and matching booking payment ID.
- If refund ID is stored, fetches that exact provider refund. If not, searches up to 10 pages of 100 refunds, rejects unstable/duplicate pagination and requires exactly one exact match by payment/amount/currency plus internal record note or idempotency receipt.
- Returns read-only verification metadata with `safe_to_retry:false`; no database write or provider refund action in this handler. Incomplete pagination, zero/multiple matches, or provider mismatch do not authorize retry.

### Recovery handler
- Root source `razorpay-refund-recovery.js`, SHA `2573aa5c6442ace359515f2227c5d93019534184`.
- Verifies bearer token with Supabase Auth and Main Admin membership; requires valid booking UUID and 10–2000 character audit note.
- Requires exactly one internal record and booking/payment ID match; fetches provider refund by exact stored ID or performs the same bounded full-page exact-match search. Ambiguous/no match never authorizes a new refund.
- Stores a SHA-256 provider payload digest, unique observation ID, provider evidence, Admin UUID and note through a dedicated evidence RPC. Only provider status `processed` proceeds to a separate HTTP/PostgREST accounting-finalization transaction. Pending/failed states save evidence but do not finalize accounting or release payout.
- If finalization is ambiguous/fails after evidence save, response preserves the recovery audit ID and instructs Admin reconciliation; no refund retry or payout release is performed.

### Static-review caveats
- This source inspection does not establish that Netlify environment variables, deployed function versions, provider credentials, webhook configuration, or live deployed code match the branch. No live provider request, refund, webhook, function invocation, or runtime test was made.
- No explicit per-Admin initiation/recovery rate limit was found in these three handlers. Existing database idempotency and provider identity checks reduce duplicate-operation risk, but do not prove abuse-rate protection. Record as a review item; do not add scope without owner approval.
- Refund handler uses server-side service-role credentials for its PostgREST reconciliation call only after verifying the user's bearer token and Main Admin membership. Secrets are not returned to the client in the inspected source.
- Main live RPC contract drift documented in Sections 22 and 37 still blocks direct Feature UI parity; this static handler review does not resolve that drift.

### Status / next steps
- Static review of all three refund API handlers complete.
- Next: inspect existing refund/webhook test coverage and exact reconciliation RPC transaction contracts; keep runtime/provider tests for the consolidated approved staging QA phase.
- No provider API calls, refunds, recovery evidence writes, database writes, webhook sends, deployment, merge, or mobile QA performed.


## Section 40 — Razorpay refund test coverage and SQL test syntax blocker (2026-11-17)

### Node handler test coverage inspected
- `tests/razorpay-refund-executor.test.js` SHA `cb6a99eb61b7b74803f00b14e127c4af6d46a116`: covers missing login, Main Admin authorization before provider call, stable provider idempotency key + response reconciliation, and ambiguous timeout remaining unknown without reconciliation.
- `tests/razorpay-refund-status.test.js` SHA `d65daae0b2a607fe4200562e58f92daf7f64398b`: covers missing session, Main Admin authorization, exact stored refund GET/no provider write, unlinked refund pagination, amount/payment mismatch, and booking-payment mismatch.
- `tests/razorpay-refund-recovery.test.js` SHA `681234cbf4e3e5f11b5ed407fe88d0ef5e6507e3`: covers audit-note requirement, Main Admin authorization, evidence save then separate finalization request, evidence ID retention on finalization failure, pending provider state without finalization, amount mismatch, exact-note matching, unrelated same-payment/same-amount rejection, and pagination to page two.
- These are source-level test definitions. They were inspected, not executed; they do not establish deployed provider behavior or database transaction concurrency.

### Database recovery evidence contract
- Migration `20261115120000_durable_razorpay_refund_recovery_evidence.sql`, SHA `adf83de704725e791a096462eaa385b28f92c7a7`, creates a private append-only recovery evidence table; writer/finalizer are service_role-only and independently enforce service role.
- Evidence writer verifies the Main Admin actor, exact provider payload fields, internal payment/booking identity and amount, and idempotent observation UUID.
- Finalizer requires processed evidence less than 15 minutes old, locks Booking → Refund → Payout, independently checks full captured collection, rejects already-paid payouts, requires refund-owned blocked payout state, and finalizes booking/refund/request/payout in one transaction.
- Hardening migration `20261115240000_harden_refund_recovery_full_amount.sql`, SHA `40ebd534cf4209e98adc8c1f44b53b9ebfc09920`, adds the full-collection paise equality guard.
- Provider reconciliation migration `20261115250000_harden_refund_reconcile_full_amount.sql`, SHA `56d300abc8495d1c5c5371d60bc0321650623db5`, independently checks full amount, booking-first locks, payout hold ownership and trigger-interleaving replay. This is static SQL review, not runtime/pgTAP evidence.

### Confirmed SQL test syntax blocker — needs GPT-2 repair/review
- Test file `supabase/tests/database/refund_reconcile_full_amount_guard.test.sql`, SHA `a81dcc344db145533be6ec239d47270f30da1c6f`, declares `plan(10)` and has ten `ok(...)` assertions, but a quote-aware parenthesis scan of the SQL source ends with three unmatched opening parentheses.
- The malformed expressions are around source lines 13–15, 29–30 and 31–32 (the `position(... in lower(pg_get_functiondef(...))` assertions). The test file is therefore not parse-ready and cannot provide reliable pgTAP evidence until corrected.
- The companion `durable_razorpay_refund_recovery_evidence.test.sql`, SHA `a191a6f74a1112f4eccfad448be291d93aaf95d8`, passed the same source parenthesis-balance scan (depth 0); it still has not been executed.
- This is in the refund/accounting GPT-2 workstream. No edit was made; hand off the exact test syntax defect for GPT-2 review/fix and rerun on isolated staging. Do not alter the GPT-2 Audit Branch or silently patch overlapping financial tests.

### Status / next steps
- Refund API source and test definitions reviewed; no tests run against Production/Main.
- A concrete test syntax blocker is now recorded for GPT-2.
- Next: continue the remaining Admin Panel integration/dependency map and prepare a concise GPT-2 handoff for the identified Staff/RBAC, support, refund contract, and SQL test issues. Runtime/pgTAP/provider testing remains deferred to consolidated approved staging QA.
- No code or SQL changed; no refund/provider call, test execution, database write, deployment, merge, or mobile QA occurred.


## Section 41 — Main live Storage और Edge Function availability cross-check (2026-11-17)

### 1. Main live Storage catalog — read-only
- Connected Main project पर `storage.buckets` और `storage.objects` की `pg_policies` सूची पढ़ी।
- Admin UI का Support Attachment bucket नाम `srk-customer-support` है; Main live bucket catalog में यह bucket नहीं मिला। इससे Section 35/पहले की finding पुष्ट होती है कि Support Attachment signed-URL preview अभी live Main Storage पर उपलब्ध नहीं है।
- KYC का वास्तविक live bucket ID `srk-electrician-verification` मिला; यह UI के KYC preview flow से मेल खाता है। Bucket private है।
- KYC Storage policies में authenticated owner-folder upload, owner-or-Admin read, और owner-folder cleanup (केवल तब जब document row उस path को reference न करती हो) मौजूद हैं। ये policies Support bucket के लिए नहीं हैं।
- इस query में Support bucket या उसके लिए कोई Storage object policy नहीं मिली। कोई bucket/policy create या modify नहीं की।

### 2. Main live Edge Functions — read-only
- Main project की deployed Edge Function सूची में केवल `send-sms-2factor` और `push-job-offer` नाम के Functions मिले।
- Admin UI से संबंधित `admin-staff-management` और `electrician-phone-change` इस Main live deployed Function सूची में नहीं मिले। इसलिए इन दोनों की deployed implementation/OTP/RBAC behavior का live code audit इस project पर संभव नहीं हुआ।
- कोई Function invoke, deploy, invitation, SMS/OTP, phone update या Auth action नहीं किया।

### 3. Integration conclusion
- Admin Panel में Support Attachment preview और Main Storage configuration के बीच confirmed availability gap है। इसे Support message/attachment tables, private bucket, object path contract, signed URL authorization और Staff/Admin read policy के पूरे reviewed bundle के रूप में reconcile करना होगा; केवल bucket बनाना पर्याप्त नहीं।
- Staff Management तथा Electrician Phone Change UI/backend integration को release से पहले सही target environment में Function source/deployment contract के साथ सत्यापित करना होगा। Main में Function absent होने को source code defect या सुरक्षित behavior का प्रमाण न मानें।
- KYC bucket की मौजूदा policies को Support bucket पर copy न करें; दोनों के ownership/path/access models अलग हो सकते हैं।

### Verification boundary / no-write
- Main Supabase catalog और deployed Edge Function inventory केवल read-only देखे गए। Feature `admin.html` source पहले से re-fetched है; कोई source edit या SQL migration नहीं की।
- Production DDL/DML, Storage write, Function invocation/deployment, Auth/OTP/invitation, payment/refund/payout, merge और mobile QA नहीं हुए।


## Section 42 — Admin UI के 53 RPC नामों का Main live PostgreSQL catalog re-check (2026-11-17)

### Method
- Feature branch `admin.html` को re-fetch किया; SHA `6b29511a1ecfab93b5689dff23012078091e57fc`। Source से 53 distinct `.rpc()` names निकाले।
- Main Supabase पर केवल read-only catalog query चलाई: `public.pg_proc`, function identity arguments, `prosecdef`, `proconfig`, और `anon` / `authenticated` EXECUTE privileges। कोई RPC invoke नहीं किया।

### Findings
- 53 में से 17 RPC names के लिए Main `public` schema में कम-से-कम एक overload मिला; शेष 36 के लिए कोई `public` overload नहीं मिला। यह Section 21 की count की पुनः पुष्टि है।
- मिले हुए 17 में सभी SECURITY DEFINER हैं; `anon` EXECUTE false और `authenticated` EXECUTE true मिला। यह privilege result अपने-आप में Admin authorization सिद्ध नहीं करता; प्रत्येक function body की role/permission guard अलग से verify करनी होगी।
- `srk_admin_list_booking_refund_requests(p_limit integer)` और `srk_admin_decide_booking_refund_request(p_request_id uuid, p_status text, p_admin_note text)` में `search_path=""` configuration मिली। इनके bodies में सभी object references schema-qualified हैं या नहीं, यह function-body review का शेष बिंदु है; बिना पुष्टि इसे सुरक्षित/असुरक्षित घोषित न करें।
- बाकी मिले हुए SECURITY DEFINER functions में pinned `search_path=pg_catalog, public, auth, pg_temp` मिला।
- Main में मौजूद UI-called legacy RPC signatures का exact argument contract UI और Feature migrations से अलग हो सकता है; केवल नाम का मिलना contract parity नहीं है। विशेषकर Refund UI में `p_decision` बनाम Main `p_status` और refund projection key drift Section 22 में दर्ज है।
- Main में अनुपस्थित प्रमुख names में Staff RBAC/session RPCs, Support messages/attachments RPCs, SOS RPCs, Work Review, Cancellation decision, Accounting reconciliation, New Booking Cash Payment, Customer Location update और Rate Tier update शामिल हैं।

### Release implication
- Main live Admin Panel contract अभी पूर्ण नहीं है: 36 names absent और कई existing names के argument/response contracts drift में हैं। UI-only guard से इन RPC gaps को सुरक्षित नहीं माना जा सकता।
- किसी भी missing RPC को isolated रूप से जोड़ना उचित नहीं; संबंधित table/schema, RLS, trigger, audit, grants, staff identity invariant और dependency migrations को reviewed bundle में reconcile करना होगा।
- SECURITY DEFINER + authenticated EXECUTE को देखकर Admin-only access assume न करें। हर function body में Admin/Staff authorization path और UUID identity exclusivity की समीक्षा आवश्यक है।

### No-write boundary
- यह catalog-only read audit था। कोई function execute, SQL DDL/DML, migration, code edit, deployment, payment/refund/payout, SMS/OTP या merge नहीं किया गया।


## Section 43 — Admin Panel direct table access बनाम Main live RLS/grants (2026-11-17)

### Feature UI source re-check
- `admin.html` re-fetch SHA: `6b29511a1ecfab93b5689dff23012078091e57fc` (1093 lines)।
- Direct PostgREST table reads केवल इन चार tables पर दिखे: `service_bookings`, `electrician_applications`, `electrician_profiles`, `srk_electrician_payouts`। कोई direct `.insert()`, `.update()`, `.delete()` या `.upsert()` write call नहीं मिला; UI writes संबंधित RPCs से करती है।
- `service_bookings`: मुख्य dashboard query 300 latest rows और offer/save से पहले एक booking-specific read।
- `electrician_applications`: 300 latest applications।
- `electrician_profiles`: 500 latest profiles; activation से पहले profile-specific verification/rate approval read।
- `srk_electrician_payouts`: latest 300 payout rows और अलग summary query में ordered range pagination।
- KYC documents RPC से आते हैं और `srk-electrician-verification` bucket से signed preview बनता है। Support attachment preview में `srk-customer-support` bucket संदर्भित है।

### Main live table grants/RLS result (read-only catalog)
- चारों tables पर RLS enabled; `anon` को कोई table privilege नहीं; `authenticated` को SELECT है; `service_role` को SELECT/INSERT/UPDATE/DELETE है।
- `service_bookings`: SELECT policy Admin या booking customer; UPDATE policy Admin-only। UI के direct reads इस policy के अधीन हैं।
- `electrician_applications`: SELECT और UPDATE policies Admin-only; authenticated को केवल SELECT table grant मिला। इसलिए Admin read path policy-guarded है; UI application decision RPC से होता है।
- `electrician_profiles`: SELECT policy profile owner या Admin; INSERT/UPDATE/DELETE policies Admin-only। ध्यान दें: direct SELECT policy profile owners को भी rows पढ़ने देती है; यह table-wide Admin-only visibility नहीं है।
- `srk_electrician_payouts`: SELECT policy Admin या संबंधित electrician profile के `user_id` owner को अनुमति देती है; authenticated UPDATE grant/policy नहीं दिखा। UI payout write RPC `srk_admin_mark_electrician_payout_paid` call करता है।
- चारों tables में `relforcerowsecurity=false`; यह अपने-आप client-side bypass नहीं दर्शाता, पर privileged roles/SECURITY DEFINER execution की समीक्षा अलग से आवश्यक है।

### Integration risks / follow-up
- Main live grants और RLS इन चार direct read paths को role-gated करते हैं; फिर भी Admin UI का पूरा authorization भरोसेमंद मानने से पहले `is_srk_admin()` की Admin-vs-Staff identity exclusivity और Staff access policy model को resolve करना होगा (Section 21/42)।
- `srk_electrician_payouts` की UI direct reads और Admin manual payout RPC को नई owner-approved “Manual Payout only; Route retired” architecture तथा GPT-2 finance migration bundle के साथ reconcile करना होगा। कोई payout action नहीं किया गया।
- Support bucket `srk-customer-support` Main live bucket catalog में अनुपस्थित होने की Section 41 finding के साथ, UI का signed-URL path अभी live integration में उपलब्ध प्रमाणित नहीं है। Bucket/policies create नहीं किए।
- UI के direct table reads पर client-side row limits (300/500) मौजूद हैं; इन्हें server-side pagination/total completeness के रूप में न समझें। Payout summary अलग range pagination करता है।

### No-write boundary
- केवल GitHub source read और Main Supabase catalog SELECT। कोई table row read/query, customer data access, Storage object access, signed URL creation, RPC invocation, DDL/DML, bucket/policy creation, deploy, invitation, OTP/SMS, payout/refund या merge नहीं हुआ।


## Section 44 — Admin Edge Functions source security review (2026-11-17)

### Source versions inspected
- `supabase/functions/admin-staff-management/index.ts`, SHA `c783989ca7142fce9d88270286bc916a66d22298` (103 lines).
- `supabase/functions/electrician-phone-change/index.ts`, SHA `372e52c8ca18a7ca984ae2de2fcdbb2a5ea87bc5` (206 lines).
- Related migration sources: `20261114380000_electrician_phone_change_admin_approval.sql` SHA `0c389a039afab594b092fc69b81bc9fbc4bff650`; `20261114390000_admin_staff_rbac_foundation.sql` SHA `5aa0f9058a56d735455f2a9944c861e8312ddb89`.

### admin-staff-management findings
- POST-only handler (OPTIONS preflight), validates Bearer token through `auth.getUser(token)`, then checks `userClient.rpc('is_srk_admin')`; browser-supplied metadata is explicitly not used for authorization.
- Only supported action is `invite_support_staff`; role is hard-coded to `support`, not client-selectable. Email/name input is validated; redirect URL is restricted to HTTPS (HTTP only localhost), with no embedded credentials.
- Uses service-role key only after Main Admin authorization; Auth invitation is sent before staff registry RPC. On registry failure it attempts Auth user deletion and accurately warns that an already-sent email cannot be recalled.
- Source handler contains no explicit per-Admin invitation rate limit/cooldown. The related staff migration registers invited identity through service_role and writes an audit event on successful registration; invitation failure/cleanup path does not have a compensating DB audit entry visible in this handler. Add only after owner-approved security review; no code changed.
- Main Admin identity exclusivity (same UUID present in both Main Admin and Staff registries) remains a prerequisite because the Edge Function's trust boundary is `is_srk_admin()`. Do not deploy/invoke while that invariant is unresolved.

### electrician-phone-change findings
- POST-only; authenticates Bearer token using `auth.getUser(token)`. Customer/electrician actions bind RPC arguments to authenticated actor UUID. Admin actions independently require `is_srk_admin()` before listing/reviewing requests.
- Indian phone normalization, cryptographically secure six-digit OTP generation with rejection sampling, HMAC-SHA256 digest bound to request UUID, five-minute expiry, and provider request timeout are implemented in source.
- OTP is sent only after DB prepare; SMS failure calls cancellation RPC and returns an explicit cleanup-pending warning if cleanup cannot be confirmed. Verify path does not expose OTP or store plaintext in DB.
- Migration enforces at most five OTP attempts, OTP expiry, one open request per electrician and one open request per new phone; resend is rate-limited to 60 seconds and request creation is limited per electrician per hour (source message says wait one hour). DB row locks protect verify/claim/finalize state transitions. These are source migration controls, not proof that Main has applied them.
- Admin approval claims request, compares current Auth phone against expected old/new phone, avoids repeating an already-completed Auth update, finalizes profile after Auth sync, and preserves a recoverable sync-error state on ambiguous finalization. No automatic rollback of Auth phone on uncertain result.
- Both handlers use permissive `Access-Control-Allow-Origin: *`; authorization is Bearer-token/RPC-based rather than CORS-based. Browser CORS origin restriction could be defense-in-depth but is not treated as an authorization substitute.
- No Edge Function runtime/deployment configuration file was found at the assumed `supabase/config.toml` path in this branch listing; deployed JWT verification settings remain unverified. Both handlers perform their own `auth.getUser(token)` validation in source.

### Live / release status
- Section 41 already found neither Edge Function in the Main deployed function list. This review is source-only and does not change that live deployment absence.
- Do not invoke either function: Staff invitation sends external email; phone-change can send SMS or change Auth phone. No invocation, email, SMS, OTP, Auth mutation, deploy, DDL/DML or live request occurred.
- Required before release: resolve Main Admin-vs-Staff UUID exclusivity; add/review Staff invitation abuse throttling and failure audit policy; verify deployed `verify_jwt` configuration and secrets; reconcile all dependent RPC migrations with Main; and obtain owner approval for any external-action testing in isolated staging.


## Section 45 — Customer Support private Storage और Main live dependency cross-check (2026-11-17)

### Feature branch source
- `20261113220000_customer_support_conversation_schema.sql`, SHA `75230ab805e61206515fd73e17e748de7ec249e5`:
  - Customer complaint messages और attachments tables बनाता है; दोनों पर RLS enabled और direct public/anon/authenticated table grants revoke हैं।
  - Attachment metadata में allowlisted MIME (JPEG/PNG/WEBP/PDF), अधिकतम 10 MiB, unique storage path और message↔complaint composite FK है।
  - Customer attachment link RPC authenticated customer, complaint ownership, customer-authored message, user/complaint path prefix, bucket ID और Storage owner ID verify करता है।
  - Private bucket `srk-customer-support` को 10 MiB और allowlisted MIME types के साथ create/upsert metadata करता है।
  - Storage policies: authenticated INSERT केवल own customer complaint path; SELECT own complaint या Main Admin; DELETE केवल own customer complaint path। UPDATE policy नहीं है; client upload flow साधारण `upload(path,file)` है, upsert नहीं।
  - `srk_customer_support_object_access(text,boolean)` SECURITY DEFINER, `search_path=''`, authenticated-only execute; Admin read bypass को policy में सीमित `bucket_id='srk-customer-support'` के साथ जोड़ा गया है।
- `20261113230000_support_attachment_paths_and_admin_message_list.sql`, SHA `aaeb6f0d7efe680735039a0a516bd5fcce2dafa0`: Customer/Admin attachment list RPCs complaint ownership/Admin authorization check करते हैं; Admin attachment list अधिकतम 100 records देता है।
- Customer client contract test SHA `f1fac5679a81b1144885ae945b4d2531437729f8` upload count/MIME/size validation, ownership-link RPC, cleanup-after-uncertain-link और 300-second private signed URL behavior को source-level assert करता है। Admin UI भी signed URL 300 seconds के लिए बनाता है।

### Main live read-only result
- `storage.buckets` में केवल private `srk-electrician-verification` मिला; `srk-customer-support` absent है।
- `storage.objects` policies में केवल Electrician Verification के तीन policies मिले; Customer Support bucket policies absent हैं।
- Public schema में संबंधित support tables में से केवल `srk_booking_complaints` मिला (RLS enabled, authenticated direct SELECT/INSERT grants false)। `srk_booking_complaint_messages`, `srk_booking_complaint_message_attachments`, `srk_electrician_support_tickets`, `srk_electrician_support_messages` live catalog query में absent मिले।
- यह Feature migration source बनाम Main live database का स्पष्ट deployment gap है; कोई migration apply नहीं हुई।

### Security / integration review
- Upload path is customer UUID / complaint UUID / filename; link RPC owner check और complaint membership enforce करता है। Admin read policy को customer-owned complaint access helper के माध्यम से दिया गया है।
- Upload में `upsert=false` default behavior के अनुरूप INSERT-only policy पर्याप्त दिखती है; यदि भविष्य में client upsert जोड़ा जाए तो Storage INSERT+SELECT+UPDATE permissions और overwrite ownership की अलग समीक्षा आवश्यक होगी।
- Delete policy केवल own complaint path पर है; helper `p_allow_admin=false` होने पर Admin को delete bypass नहीं देता।
- Signed URLs 300 seconds के हैं; URL बनाना केवल authenticated session और SELECT policy के बाद सफल होना चाहिए। Live bucket absent होने से current Main पर signed URL workflow अभी काम करने योग्य प्रमाणित नहीं है।
- Main Admin identity exclusivity unresolved होने के कारण `is_srk_admin()`-based Admin storage read authorization अभी release blocker से जुड़ा हुआ है।

### No-write boundary
- केवल Feature source/tests read और Main catalog SELECT। कोई Storage bucket/policy create, object list/read/upload/delete, signed URL generation, migration, RPC invocation, DDL/DML, deployment या user data access नहीं हुआ।
