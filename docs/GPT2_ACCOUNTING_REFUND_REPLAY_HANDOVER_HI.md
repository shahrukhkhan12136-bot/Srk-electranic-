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
