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
