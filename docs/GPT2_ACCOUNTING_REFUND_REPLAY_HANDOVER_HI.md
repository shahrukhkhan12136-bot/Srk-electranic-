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
