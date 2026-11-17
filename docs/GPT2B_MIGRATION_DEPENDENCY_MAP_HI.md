# SRK ELECTRONIC — GPT-2B Migration Dependency Map (Source Review)

**Branch:** `chore/pr8-replay-audit-20261116-v2`  
**Date:** 17 November 2026  
**Scope:** GPT-2B payment/refund/webhook/payout/accounting and Support/RBAC/attachment work.  
**Method:** Read-only inspection of current migration source files and recursive migration inventory. No SQL was executed.

## 1. Inventory and hard gates

- Current `supabase/migrations/` inventory: **93 SQL files** (including the fixed-new-booking commission guard added 17 Nov 2026).
- Current `supabase/tests/database/` inventory: **36 pgTAP files**.
- One duplicate migration version token remains: `20261109` is used by both `20261109_allow_quote_approval_booking_states.sql` and `20261109_electrician_inspection_quotes_and_service_only_commission.sql`.
- `supabase/config.toml` is absent on this branch.
- This map is a **focused source-derived dependency map**, not proof of a clean replay or a complete semantic graph of every dynamic SQL/function reference.
- Duplicate-version resolution, approved canonical baseline, local config/stack, and full replay remain hard gates. Do not rename/delete/resequence migrations or query/repair remote history based on source inference.

## 2. Required pre-existing platform/core objects

The migration chain assumes a Supabase/PostgreSQL environment already provides:

1. Supabase roles and schemas: `auth.users`, `auth.uid()`, `storage.buckets`, `storage.objects`, and Supabase roles `anon`, `authenticated`, `service_role`.
2. Core application tables from a canonical base schema: `public.service_bookings`, `public.electrician_profiles`, `public.electrician_applications`, and referenced customer/profile fields.
3. Existing booking columns/constraints consumed by early migrations (for example booking owner, status, assignment, payment and location fields); exact full base DDL must come from an approved canonical snapshot, not inferred from consumers.
4. Existing admin authorization primitives used by legacy admin RPCs; later RBAC migrations add Staff-specific permission and assignment tables but do not automatically prove every earlier Admin helper exists.
5. Required PostgreSQL extensions/functions and default grants expected by Supabase. Exact extension/version list still needs to be enumerated from the canonical baseline and migration bodies.

**Gate:** the three starter SQL files are not a substitute for the full Supabase Auth/Storage/platform baseline plus ordered migration chain.

## 3. Source-derived dependency layers

### Layer A — Booking access, identity, commission and wallet foundations

- `20261108120608_add_public_api_rate_limiting.sql` creates private rate-limit schema/table and service-only RPC; the following `20261108120658_enable_rls_public_api_rate_limits.sql` enables RLS on that table.
- `20261108121115_add_customer_account_booking_access.sql` alters/indexes `service_bookings` and creates a customer booking-read policy; requires the core booking table and its customer identity column.
- `20261108233500_restrict_public_form_inserts.sql` and `20261108234000_combine_booking_read_policy.sql` replace booking/application policies and grants; require `service_bookings` and `electrician_applications`.
- `20261109000500_harden_electrician_profile_identity_linking.sql` alters `electrician_profiles`, references `auth.users`, and installs identity sync/guard triggers. Later electrician operations depend on this identity link.
- `20261109003000_secure_commission_reporting.sql` reads/writes booking commission/payment fields and replaces commission/earnings read RPCs. It assumes those booking columns and the Admin authorization function are present.
- `20261109010000_create_secure_wallet_ledger_foundation.sql` creates wallet accounts, ledger and bank-link tables; downstream cancellation and payout accounting use these tables.
- `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql` creates the server-only route transfer ledger; later route-transfer reconciliation depends on it.
- Quote migration pair with duplicate `20261109` version alters booking quote/status constraints and installs quote RPCs. Their exact replay treatment is unresolved; the full quote migration itself contains the same status-constraint work as the shorter companion file.

### Layer B — Complaint parent and Customer Support conversation base

- `20261110040000_customer_admin_complaints.sql` creates `srk_booking_complaints` and `srk_booking_complaint_events`; this is the parent-table producer for later complaint thread and attachment migrations.
- `20261113220000_customer_support_conversation_schema.sql` creates complaint message and attachment metadata tables, the private Storage bucket, Customer send/list/link RPCs, and the initial object access helper/policies. It depends on the complaint parent table, core booking/customer ownership, and Supabase Storage objects/buckets.
- `20261113230000_support_attachment_paths_and_admin_message_list.sql` adds attachment-list and Admin thread/attachment RPCs; it depends on the conversation/attachment tables and Admin authorization primitives.
- `20261114202250_customer_complaint_customer_safe_projection.sql` replaces Customer complaint create/list RPCs and inserts complaint/event rows; it depends on both complaint parent tables and booking ownership. Its per-customer advisory lock protects the configured submission cap at source level; concurrent runtime behavior remains untested.
- `20261114300000_admin_customer_support_thread_replies.sql` adds Admin reply RPC using complaint message table.
- `20261117100000_prevent_deleting_linked_support_attachments.sql` depends on the Customer object-access helper, Storage ownership metadata, and linked attachment metadata. It serializes object link/delete using row locks.
- `20261114390000_admin_staff_rbac_foundation.sql` creates Staff, permissions, role-permission, tracked session, assignment and audit foundations (including assignment structures and Staff permission helper).
- `20261117110000_support_staff_assigned_customer_attachment_read.sql` depends on RBAC permission/assignment state, complaint ownership, attachment metadata and the private Storage bucket/policy. It adds currently-assigned Staff read only; it does not grant Staff upload/delete.

### Layer C — Financial audit tables, payout writer and webhook inbox

- `20261114125844_restore_financial_audit_core_schema.sql` creates the financial audit core used later: labour bills, manual payment entries, electrician payouts, Admin audit events, Razorpay refunds, booking refund requests and manual refund entries. It assumes core booking/electrician profile tables and adds RLS/revokes direct client access.
- `20261114360000_new_category_electrician_payout_reconciliation.sql` defines payout writer and Admin payout-settlement RPC; it depends on the payout table, booking/electrician identity, completed booking/payment/quote fields and Admin authorization.
- `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` attaches the payout reconciliation trigger to `service_bookings` and replaces manual-refund/recovery functions. It depends on the financial audit tables and the booking/profile/commission columns.
- `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` adds the BEFORE commission setter and AFTER parity validator, and replaces Admin accounting/commission/earnings reporting RPCs. It depends on the payout writer/table and commission fields. The next migration `20261117120000_retire_legacy_booking_commission_trigger.sql` removes the legacy booking commission trigger; order is material.
- `20261114410000_razorpay_webhook_event_inbox.sql` creates the private webhook inbox plus service-only claim/complete RPCs. It relies on Supabase roles and service-side invocation; business settlement handlers subsequently depend on refund/payment records.
- `20261115100000_customer_refund_request_contract.sql` uses booking/refund request core; `20261115110000_admin_refund_review_queue_and_decisions.sql` adds Admin review/decision RPCs over those requests.
- `20261115120000_durable_razorpay_refund_recovery_evidence.sql` creates immutable recovery evidence and service-only record/finalize RPCs. It depends on refund, refund-request, booking and payout tables.
- `20261115240000_harden_refund_recovery_full_amount.sql` and `20261115250000_harden_refund_reconcile_full_amount.sql` replace recovery/reconciliation RPCs with full-amount checks; the later versions must remain after their function producers.
- `20261115130000_admin_manual_refund_request_completion.sql` and the later `20261116210000` replacement operate on refund entries, requests, bookings and payout state.
- `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` replaces manual-payment and customer receipt RPCs; it depends on manual payment entries, bookings, wallet/payout accounting and customer ownership fields.
- `20261115150000_admin_readonly_booking_accounting_reconciliation.sql` and `20261115170000_admin_route_transfer_accounting_reconciliation.sql` expose read-only reconciliation over booking/financial ledgers; `20261117010000` later replaces booking accounting/commission report definitions.

### Layer D — Electrician Support and Staff authorization

- `20261114350000_electrician_support_tickets_and_admin_inbox.sql` creates Electrician Support ticket/message tables and Electrician/Admin RPCs; it depends on electrician profile-to-auth identity and the Admin authorization primitive. It precedes the Staff RBAC foundation in filename order.
- `20261114390000_admin_staff_rbac_foundation.sql` adds Staff registry, role permissions, tracked sessions, audit events and current case assignment records.
- `20261116100000_fix_staff_permission_helper_volatility.sql` replaces the Staff permission helper; it is a later correction to the RBAC foundation.
- `20261117110000_support_staff_assigned_customer_attachment_read.sql` consumes current Staff assignment and permission state for attachment SELECT. Reassignment/session revocation behavior still needs runtime verification.

### Layer E — Final hardening and current GPT-2B fixes

- `20261115200000_harden_financial_admin_rpc_search_path.sql`, `20261115210001_harden_legacy_financial_read_rpc_search_paths.sql`, and `20261116110000_pin_legacy_financial_read_rpc_search_paths.sql` alter existing function definitions; they must follow the relevant function producers.
- `20261116130000_pin_wallet_and_receipt_rpc_search_paths.sql` depends on wallet/receipt RPC definitions already existing.
- `20261116200000_restore_service_bookings_amount_paid.sql` adds/restores the nullable `numeric(12,2)` booking payment column and nonnegative check; source presence does not prove older data validation or remote parity.
- `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` must follow payout table/writer and commission reporting producers.
- `20261117100000_prevent_deleting_linked_support_attachments.sql` must follow Customer Support attachment schema/helper.
- `20261117110000_support_staff_assigned_customer_attachment_read.sql` must follow Support Staff RBAC and attachment schema.
- `20261117120000_retire_legacy_booking_commission_trigger.sql` must follow the replacement commission/payout parity triggers.

## 4. Critical ordering constraints

1. Supabase platform/core schema → booking access/identity → quote/payment columns and functions.
2. Complaint parent tables → conversation/message/attachment tables → Customer/Admin RPCs → Staff RBAC assignment → assigned-Staff attachment read.
3. Financial audit tables → payout writer and refund request contracts → webhook/recovery evidence → full-amount refund reconciliation replacements.
4. Payout writer → commission setter/parity validator → legacy commission trigger retirement.
5. Function producer → every later `ALTER FUNCTION` / `CREATE OR REPLACE FUNCTION` hardening migration.
6. Storage bucket/object-access helper → linked attachment delete guard → Staff assigned read policy.
7. Booking and refund rows must retain the documented booking-first lock order where payout/refund reconciliation functions share those records.

These are dependency constraints, not an instruction to manually reorder migrations. The canonical migration runner must use the repository's approved migration identities and version policy.

## 5. Outstanding source and runtime gates

| Gate | Status | Evidence needed |
|---|---|---|
| Canonical Supabase/Auth/Storage base schema | Blocked | Owner-approved baseline snapshot/version |
| Duplicate `20261109` migration identity | Blocked | Sanitized migration-history evidence and owner-approved resolution |
| Exact complete 92-file dependency graph | In progress | Full statement/function reference extraction including dynamic SQL and indirect calls |
| Local `supabase/config.toml` and pinned CLI | Not prepared | Reviewed local-only config and CLI version |
| Empty local migration replay | Not run | Full replay logs and resulting schema checks |
| 36 pgTAP SQL tests | Not run | Complete `supabase test db` output |
| Node test suite | Not run in this pass | Node 22 `npm test` output |
| Provider/Storage/concurrency integration | Not run | Controlled test-mode logs and cleanup evidence |

## 6. Safety and progress

- This work was read-only source inspection plus documentation only.
- No remote database URL/secret was read; no Production schema query/export, migration apply, PostgreSQL/pgTAP execution, provider call, Storage integration test, workflow dispatch, deployment, or merge occurred.
- The focused GPT-2B map is **documented**, but full replay readiness is **not established**.
- Official GPT-2 progress remains **27/39 = 69% complete; 12 checklist items remaining**. Documentation/source inspection does not increment the implementation percentage.


## 7. Customer Payment History RPC — dependency cross-check

**Consumer:** `supabase/migrations/20261114200000_customer_payment_refund_history_rpc.sql`  
**Consumer SHA:** `0cadc99ad47efa0e08e8f8efa21ca63b105aea12bd`

Static cross-check of the objects referenced by `srk_customer_get_payment_history(integer,integer)`:

| Required object/column | Source migration or baseline | Source SHA | Order check |
|---|---|---|---|
| `service_bookings.customer_user_id` | `20261108121115_add_customer_account_booking_access.sql` | `9877bb969b380d306567322eb110d81eaaa4c115` | Earlier than consumer |
| `service_bookings.amount_paid` | `20261109003000_secure_commission_reporting.sql` | `9b4ed1529ea2a6e4da4ba0804bdbc9b3612627b9` | Earlier than consumer; later `20261116200000_restore_service_bookings_amount_paid.sql` is a restoration/constraint pass |
| `srk_booking_refund_requests` and its customer/status/time columns | `20261114125844_restore_financial_audit_core_schema.sql` | `bdfdfcc01366a9d4a298b2107c53f1525b326bf9` | Earlier than consumer |
| `srk_razorpay_refunds` and `processed_at/updated_at/created_at` | `20261114125844_restore_financial_audit_core_schema.sql` | `bdfdfcc01366a9d4a298b2107c53f1525b326bf9` | Earlier than consumer |
| `srk_manual_refund_entries.recorded_at` | `20261114125844_restore_financial_audit_core_schema.sql` | `bdfdfcc01366a9d4a298b2107c53f1525b326bf9` | Earlier than consumer |
| `service_bookings.payment_verified_at`, `payment_status`, `payment_method`, `razorpay_payment_id` | `COMPLETE_DATABASE_SETUP.sql` baseline | `2b806e727f449ba18e71ad23edef805ceb2da2b5` | Present in the inspected baseline |

### Finding

The referenced relations and columns have identifiable producers before the payment-history RPC in the source sequence. This targeted cross-check did **not** identify an absent-table or absent-column forward dependency for this RPC. The RPC's explicit customer filter is based on `auth.uid()` through `customer_user_id`; its refund branches join the refund records back to the customer-owned booking where needed.

This is a source-order finding only. It does not prove that the full 92-file chain replays cleanly, that the function compiles in PostgreSQL, or that customer isolation/pagination works at runtime. The RPC's behavior still requires isolated database execution and role-scoped tests after the canonical baseline and migration-version blockers are resolved.

Static source review only. No SQL, database query, migration replay, pgTAP, runtime test, CI dispatch, deployment, or merge was run for this cross-check. Checklist remains 27/39 = 69%.


## 7. Function producer → consumer / replacement edges (second source pass)

This section records concrete named function edges found in additional migration bodies. A function call inside a PL/pgSQL body can be late-bound at invocation; therefore a textual reference to a function created later is not automatically a migration-time failure. By contrast, a trigger target, table/column reference in DDL, ALTER FUNCTION, DROP FUNCTION, FK, policy, or index can be a hard migration-time dependency.

### 7.1 Identity and Admin authorization baseline

- Early migrations use more than one authorization helper name: public.is_srk_admin(), public.srk_is_admin(), and public.srk_admin_users appears in later work-timeline code. These names are not interchangeable. They are referenced by source but are not created by the focused GPT-2B migrations reviewed here.
- Rate-tier, application review, Staff RBAC, SOS and finance Admin RPCs depend on the correct helper(s) being present in the canonical base schema.
- **Open baseline check:** prove exact signatures, definitions, grants and semantics for each helper from the approved base schema. Do not alias/rename them based on naming similarity.

### 7.2 Rate-tier / sequential offer dispatch / availability / KYC

- 20261114160000_customer_selected_rate_tier_and_server_estimate.sql creates rate-tier audit/authorization tables, activation guard, Admin rate-tier setter, initial private.srk_offer_booking_to_eligible_electricians(uuid), and job-offer rate-tier guard.
- 20261114210000_sequential_nearest_offer_dispatch.sql creates sequential dispatch state/candidate tables and replaces the private offer dispatcher with the sequential implementation; it also creates the next-offer dispatcher and public.srk_respond_to_offer(uuid,text).
- 20261114230000_recheck_electrician_current_area_before_offer.sql replaces private.srk_dispatch_next_booking_offer(uuid) to recheck current electrician area immediately before offering.
- 20261114240000_server_authoritative_customer_approved_work_timer.sql replaces/defines public.srk_respond_to_offer(uuid,text) again and calls private.srk_dispatch_next_booking_offer(uuid); that target is already produced by 14210000 and replaced by 14230000. Keep this chain in filename order.
- 20261114310000_electrician_self_availability.sql updates electrician_profiles, declines offers when availability is turned off, and calls the private next-offer dispatcher to advance sequential dispatch.
- 20261115140000_electrician_kyc_review_and_activation_gate.sql adds KYC tables/Storage bucket/policies and replaces electrician activation guard. It depends on the rate-tier authorization table/guard from 14160000, electrician availability events, job offers, and the private dispatch function.
- **Runtime gate:** sequential offers, area recheck, availability changes and KYC activation must be tested together after a complete local replay; isolated function existence checks are insufficient.

### 7.3 Work timer / immutable labour bill / dispute and cancellation

- 20261114125844_restore_financial_audit_core_schema.sql creates srk_booking_labour_bills before the receipt/history RPCs consume it.
- 20261114240000_server_authoritative_customer_approved_work_timer.sql contains a second CREATE TABLE IF NOT EXISTS public.srk_booking_labour_bills definition. Normalized table-definition text was compared: the two declarations are identical. The later declaration does not upgrade a previously existing divergent table because it is guarded by IF NOT EXISTS.
- 14240000 creates work timer/transition authorization tables, bill immutability trigger, start/completion RPCs, booking quote/work-status RPC replacements, and the new-category booking status guard. Its function bodies reference complaint, offer, cancellation and dispatch objects created elsewhere in the chain; complete replay must finish before those RPCs are exercised.
- 20261114250000_admin_work_dispute_review_and_immutable_history.sql adds booking work-event audit table and trigger; 20261114260000_fix_work_start_rpc_and_append_only_event_history.sql replaces work-start flow, adds immutable event guards, and creates the customer work timeline RPC.
- 20261114270000_admin_only_cancellation_requests_and_decisions.sql creates cancellation request/event tables and booking cancellation guard; 20261114280000_cancellation_fee_carry_forward_and_accounting.sql extends wallet ledger and creates debt/item/fee-ledger objects; 20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql consumes these fee and refund objects.
- **Open check:** verify all trigger ordering and lock-order behavior in a replayed database, especially booking → refund/payout/wallet row lock order and event immutability.

### 7.4 Support Staff and SOS dependencies

- 20261114350000_electrician_support_tickets_and_admin_inbox.sql creates Electrician Support ticket/message tables and Electrician/Admin thread RPCs.
- 20261114390000_admin_staff_rbac_foundation.sql creates Staff, permission, role mapping, session, audit and current support assignment tables; it defines srk_has_admin_permission(text), Staff session/revocation RPCs, assignment RPCs and assigned Customer complaint/message RPCs. It calls the pre-existing public.is_srk_admin() helper.
- The RBAC migration defines srk_has_admin_permission(text) once, then replaces it later in the same migration after adding the tracked-session identity check. The later definition is the effective one at the end of that migration.
- 20261116100000_fix_staff_permission_helper_volatility.sql is a later replacement of that helper; its volatility declaration must be checked together with the final function body.
- 20261115260000_sos_admin_support_alerts.sql inserts new keys into RBAC permission/role mapping tables and creates SOS alert/event tables. Its Admin list/acknowledge/event RPCs call srk_has_admin_permission(text) and write Staff audit events. Therefore it requires RBAC foundation before SOS.
- 20261117110000_support_staff_assigned_customer_attachment_read.sql consumes current Staff permission/assignment rows and complaint attachment metadata; its policy/helper cannot be validated before both support attachment and RBAC producers.

### 7.5 Payment, refund, payout and reconciliation replacements

- 20261114125844_restore_financial_audit_core_schema.sql is the producer for the financial core tables used by receipt, manual payment, payout, refund and accounting reconciliation RPCs.
- 20261114360000_new_category_electrician_payout_reconciliation.sql defines srk_create_electrician_payable() and Admin payout settlement. 20261116210000_attach_electrician_payout_reconciliation_trigger.sql replaces the payable writer and attaches it to service_bookings; it also replaces manual-refund/recovery functions.
- 20261117010000_reconcile_booking_commission_and_manual_payment_method.sql installs the commission-before-payout setter and payout parity validator, and replaces Admin accounting/commission/earnings RPCs. 20261117120000_retire_legacy_booking_commission_trigger.sql then removes the old commission trigger. The replacement chain is source-ordered; runtime trigger ordering and exception rollback still need pgTAP execution.
- Accounting reconciliation function public.srk_admin_get_booking_accounting_reconciliation(uuid) is successively defined/replaced in 15150000, 15170000, 15180000 and again in 17010000. The final source body in the chain is the effective definition. Each intermediate replacement must still compile at its own migration point, and references must match objects available at that point.
- 20261115120001_fix_multi_profile_electrician_labour_bill_access.sql and 20261115145900_fix_multi_profile_electrician_labour_bill_access.sql were compared byte-for-byte: the complete 1,560-byte SQL files are identical (same blob SHA e3bdf2624c224322a6ac4c99f2ae6e77b1be4774). This is a repeated no-op function replacement, not a demonstrated runtime defect. Do not remove/rewrite historical migration files without approved migration-history evidence.
- 20261115210000_legacy_manual_payment_and_itemized_receipt.sql defines manual payment and receipt RPCs over booking, manual-payment, wallet/payout and labour-bill records. Later search-path hardening migration 20261116130000_pin_wallet_and_receipt_rpc_search_paths.sql alters wallet/receipt functions and therefore depends on these earlier definitions.
- Refund recovery sequence: durable recovery evidence producer → service record/finalize functions → full-amount replacement in 15240000 → reconciliation replacement in 15250000 → later 16210000 replacement. Service-only execute grants are explicit in these migrations; provider API itself is outside SQL replay.

### 7.6 Push outbox / per-subscription ledger / health / fencing

- 20261111020000_add_electrician_push_subscriptions.sql creates the subscription base table.
- 20261115170001_durable_push_delivery_outbox.sql hardens subscription RLS/policies, creates srk_private.srk_push_delivery_outbox, installs job-offer enqueue trigger and creates outbox claim/finish RPCs.
- 20261115180001_push_subscription_delivery_ledger.sql creates srk_private.srk_push_subscription_deliveries and per-subscription claim/finish/complete RPCs; it depends on both subscription and outbox tables.
- 20261115190001_push_delivery_health_monitoring.sql reads both push delivery tables and adds health/dead-letter retry RPCs.
- 20261115200001_push_delivery_lease_fencing.sql drops old 3-argument finish function signatures and creates lease-fenced finish signatures with attempt/lease token inputs. Callers must be updated to the new signatures; this is an API compatibility edge, not only a table dependency.
- **Runtime gate:** prove enqueue idempotency, per-subscription fanout, retry/dead-letter state, stale worker fencing and lease expiry under concurrency.

## 8. Duplicate definitions / replacement ledger and remaining checks

| Finding | Source evidence | Interpretation / action |
|---|---|---|
| Duplicate 20261109 version prefix | Two distinct migration filenames share the version token | Hard stop for replay planning; owner-approved history evidence required |
| Repeated labour-bill table declaration | 14125844 and 14240000 normalized DDL identical | Safe only if baseline object is same; IF NOT EXISTS will not reconcile drift |
| Repeated Electrician labour-bill read RPC migration | 15120001 and 15145900 are byte-identical 1,560-byte files | Redundant replacement in source; preserve history pending owner evidence |
| Accounting reconciliation RPC replacement chain | 15150000 → 15170000 → 15180000 → 17010000 | Final definition is latest; each intermediate definition needs compile/replay validation |
| Push finish RPC signature change | 15200001 drops old signatures and adds lease-fenced signatures | Verify all server callers use new signatures; stale client/worker callers may fail |
| RBAC permission helper replacement | Defined twice in 14390000, replaced again in 16100000 | Latest body/volatility and current session checks must be verified after replay |
| Admin authorization helper provenance | Calls to is_srk_admin, srk_is_admin, and srk_admin_users | Canonical base-schema signatures/grants are still a prerequisite |
| Function body references objects created later | Work timer/offer and SOS/support paths | Separate late-bound runtime references from DDL-time dependencies; exercise only after full replay |

**Completeness boundary:** this second pass materially expands the named function dependency edges for booking lifecycle, support/RBAC, payout/refund/accounting and push subsystems. It is still not a parser-generated, exhaustive graph of all 92 files, all dynamic SQL, all column references, or all trigger side effects. A clean replay remains the only way to validate compilation and object resolution end-to-end.



### 7.7 Push lease-fencing caller cross-check (worker source)

The source caller check was extended beyond SQL:

- Netlify worker netlify/functions/deliver-push-outbox.js calls srk_claim_push_delivery_outbox and passes p_attempt_count from the claimed row into srk_finish_push_delivery_outbox.
- Supabase Edge Function supabase/functions/push-job-offer/index.ts passes p_attempt_count from each claimed device delivery into srk_finish_push_subscription_delivery and checks srk_is_push_subscription_delivery_complete.
- Node source-contract tests tests/push-delivery-outbox.test.js and tests/push-subscription-delivery-ledger.test.js assert those caller argument names and the changed SQL signatures.
- pgTAP source file supabase/tests/database/push_delivery_lease_fencing.test.sql checks the new regprocedure signatures, service-role grants, stale-attempt guards, processing-state guard and retry caps.
- **Finding:** the two current worker source callers inspected match the lease-fenced attempt-count signatures. This reduces the specific stale-caller concern for these two tracked workers.
- **Not proven:** deployed worker versions, environment secrets, runtime RPC execution, concurrent stale worker rejection, actual retry/lease timing, or Node/pgTAP test pass. The contract test files were inspected only; no test runner or database was executed.



### 7.8 Legacy Admin authorization helper provenance (92 migration source scan)

**Scope:** all 92 files under `supabase/migrations/` on `chore/pr8-replay-audit-20261116-v2` were enumerated from the branch tree and inspected for definitions/replacements and references to `public.is_srk_admin()`, `public.srk_is_admin()`, `public.srk_admin_users`, and the newer Staff permission helper.

| Object | Migration-chain evidence | Starter-schema evidence | Result |
|---|---|---|---|
| `public.is_srk_admin()` | No `CREATE FUNCTION` / `CREATE OR REPLACE FUNCTION` producer found in the 92 migrations. Migration `20261114125844_restore_financial_audit_core_schema.sql` executes `ALTER FUNCTION ... SET search_path=''`, revokes PUBLIC/anon and grants authenticated/service_role, so the function must already exist before this migration. Many later functions/policies call it. | `COMPLETE_DATABASE_SETUP.sql` defines it as SQL, STABLE, SECURITY DEFINER, search_path `public, auth`; revokes PUBLIC and grants authenticated. | Starter evidence only; not proof of the canonical deployed/base definition. |
| `public.srk_is_admin()` | Referenced by `20261109001500_unique_electrician_admin_identity_linking.sql` and `20261114130000_harden_electrician_profile_identity_linking.sql`; no migration-chain producer, replacement, ALTER, or explicit function grants found. | `PORTAL_SCHEMA.sql` defines it as SQL, STABLE, SECURITY DEFINER, search_path `public`; revokes PUBLIC and grants authenticated. | Starter evidence only; provenance and current existence/grants remain unproven. |
| `public.srk_admin_users` | Queried by multiple migrations as the Main Admin allow-list; no `CREATE TABLE` / `ALTER TABLE` producer for this table found in the migration chain. | Both `PORTAL_SCHEMA.sql` and `COMPLETE_DATABASE_SETUP.sql` create it with `user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`; `COMPLETE_DATABASE_SETUP.sql` also enables RLS and adds a self-read policy. | Canonical base-table definition, RLS/policies, owner and grants are not established by the migration chain; starter scripts are evidence, not proof of the deployed baseline. |
| `public.srk_has_admin_permission(text)` | Created twice in `20261114390000_admin_staff_rbac_foundation.sql`; replaced in `20261116100000_fix_staff_permission_helper_volatility.sql`. Latest definition is PL/pgSQL, VOLATILE, SECURITY DEFINER, empty search_path; validates Main Admin separately, then checks active Staff registry and exact live Auth session while holding FOR SHARE locks. Latest migration revokes PUBLIC/anon and grants authenticated. | Not a legacy starter-schema producer. | Migration provenance is established; runtime correctness still requires replay and pgTAP/runtime checks. |

**Call-site / DDL timing notes**
- `20261108234000_combine_booking_read_policy.sql` uses `public.is_srk_admin()` directly inside a `CREATE POLICY` expression. This is a DDL-time dependency: the helper must exist when that migration runs.
- `20261114125844_restore_financial_audit_core_schema.sql` alters the function and its ACL; this is also a direct migration-time dependency and independently proves that a prior base object is assumed.
- Other occurrences include PL/pgSQL function/trigger bodies, policy expressions and Main Admin identity checks. A PL/pgSQL body reference is not interchangeable with a DDL-time policy dependency; do not infer that every body reference is validated at migration creation.
- The two starter files expose different legacy helper names (`srk_is_admin` vs `is_srk_admin`) and slightly different search_path declarations. Their presence in starter SQL does not establish that both exist, are equivalent, or have matching grants in the actual project baseline.
- No alias, replacement helper, migration, grant change, or auth-semantic change was made during this audit.

**Gate / owner evidence required:** obtain the owner-approved canonical baseline (sanitized schema definition and ACL/grant evidence for both helper signatures and `srk_admin_users`, plus confirmation of which starter/setup path is authoritative). Until then, fresh replay is blocked at the first direct policy/function-ACL dependency if the base objects are absent. Do not manufacture aliases or assume either starter SQL file is authoritative.


### 7.9 Fixed commission-rate migration dependency (17 November 2026)

- New migration: `20261117130000_enforce_fixed_new_booking_commission_rate.sql`.
- Adds `public.srk_enforce_new_booking_commission_rate()` and a row-level BEFORE trigger `aa_srk_enforce_new_booking_commission_rate` on `service_bookings`.
- On INSERT, the trigger overwrites any supplied `commission_rate` with exactly `15.00`. Its `aa_` name makes it run before the existing `zz_srk_set_booking_commission_before_payout` commission-amount calculator.
- On UPDATE OF `commission_rate`, the trigger rejects any value different from OLD with `BOOKING_COMMISSION_RATE_IS_IMMUTABLE`. Other updates leave the stored historical commission snapshot unchanged.
- No historical rows are updated or backfilled. The payout and accounting formulas continue to calculate the company share from the booking's stored snapshot, with labour-only service amount and materials excluded.
- The payout pgTAP file now declares `plan(52)` (48 `ok`, 3 `throws_ok`, 1 `lives_ok`): it covers trigger wiring, forced 15% on INSERT, immutable historical snapshots, the positive matching payout-parity update, and the two negative payout-parity rollback cases. Assertion totals were checked against source; they have **not** been executed, so runtime proof remains pending.
- Dependency edge: canonical `service_bookings` base table and existing commission BEFORE trigger must exist before this migration; subsequent payout setter consumes the enforced 15% value. Migration ordering is additive and does not change old migration history.


### 7.10 Current-tree recount and earliest Admin baseline gate (17 November 2026)

- The current recursive branch tree has **100** SQL migration files and **38** pgTAP SQL files (not the historical 92/93 and 36 counts in sections 5/7.8). It also has 57 Node `.test.js` files, 3 workflow files, and no `supabase/config.toml`. See Master Inventory §3AP for the tree recount evidence. This updates file-count metadata only; it does not assert that every migration was semantically parsed or replayed.
- The sole duplicate migration version token remains `20261109`: `20261109_allow_quote_approval_booking_states.sql` and `20261109_electrician_inspection_quotes_and_service_only_commission.sql`. Both source files were re-fetched and inspected; no rename, deletion, or reordering is authorized by this finding.
- The earliest direct Main Admin helper dependency confirmed in the inspected sequence is `20261108234000_combine_booking_read_policy.sql`, whose `CREATE POLICY` expression calls `public.is_srk_admin()`. This is a migration-time dependency, not merely a PL/pgSQL body reference. The later `20261114125844_restore_financial_audit_core_schema.sql` also performs `ALTER FUNCTION public.is_srk_admin()`, so the function must pre-exist that migration as well.
- `20261109003000_secure_commission_reporting.sql` also directly checks `public.is_srk_admin()` in its Admin RPC. The wallet migration `20261109010000_create_secure_wallet_ledger_foundation.sql` also calls the helper in its Admin operation. Neither creates it.
- The starter schemas still provide non-canonical evidence only: `COMPLETE_DATABASE_SETUP.sql` defines `is_srk_admin()`; `PORTAL_SCHEMA.sql` defines the distinct `srk_is_admin()` and `srk_admin_users`. Their existence in repository starter files does not prove which one is the approved deployed baseline or that both definitions/grants are present in the project.
- **Replay stop remains:** without owner-approved canonical baseline evidence for `is_srk_admin()`, `srk_is_admin()`, `srk_admin_users`, Supabase Auth/Storage platform objects, and their grants/ownership, do not attempt local replay or create compatibility aliases. A local config file also remains absent. No safe source-only code change can establish these external baseline facts.
- No checklist item is closed by this audit. Broad GPT-2 remains **27/39 = 69%**; four-workstream source checklist remains **27/27 applicable = 100%**; Runtime Acceptance remains **60/60 Pending**.
- Read-only source inspection and documentation only. No SQL execution, remote schema access/export, Node/pgTAP run, CI, deployment, production change, merge, or mobile QA. PR #8 remains Open/Draft/Unmerged.


### 7.11 Starter-schema cross-check correction and earliest authorization producers (17 November 2026)

- A re-read of the complete current `COMPLETE_DATABASE_SETUP.sql` shows that it **does create** `public.srk_admin_users` (the table appears in its Admin/portal section), enables RLS, and adds the self-read policy. The earlier wording in §7.8 that it “assumes it already exists” was inaccurate and is corrected in the table above. `PORTAL_SCHEMA.sql` also creates the same named table. This is a documentation correction; neither script was executed.
- The complete setup script defines **both** distinct helpers: `public.srk_is_admin()` in its portal section and `public.is_srk_admin()` in its later consolidated Admin section. `PORTAL_SCHEMA.sql` defines `srk_is_admin()`. The presence of both in the setup script does not prove the deployed database ran that complete script, nor that later migrations have the exact required function ACLs and definitions.
- The two earliest distinct Admin helper edges remain: `20261108234000_combine_booking_read_policy.sql` directly invokes `is_srk_admin()` in a policy expression; `20261109001500_unique_electrician_admin_identity_linking.sql` invokes `srk_is_admin()` in the Admin approval function body (whose producer is the preceding `20261109001000` migration). Both helper definitions therefore need to be present in the approved base schema before their respective consumers execute.
- The starter `service_bookings`, `electrician_applications`, `electrician_profiles`, and `job_offers` definitions are likewise supplied by the setup SQL rather than by the early migration chain. The setup file also relies on Supabase platform objects such as `auth.users`; it is not a complete Supabase Auth/Storage platform baseline or a migration replay log.
- **No source change to SQL** is justified: the outstanding uncertainty is which baseline was actually applied and what its live schema/ACL state is. Continue to require owner-approved, sanitized baseline evidence; do not execute setup scripts, create aliases, alter migration ordering, or access production.
- No checklist item closed. Broad GPT-2 remains **27/39 = 69%**; four-workstream source checklist **27/27 applicable = 100%**; Runtime Acceptance **60/60 Pending**. No SQL/test/CI/deploy/production/merge/mobile QA performed.


### 7.12 Early core/Auth/Storage baseline edges (17 November 2026)

- The first migration, `20261108120608_add_public_api_rate_limiting.sql`, is self-contained for its own `private` schema/table/RPC creation and service-role ACLs; the immediately following migration only enables RLS on that newly created table. No external application table is required for these two files.
- The next core-table migration, `20261108121115_add_customer_account_booking_access.sql`, alters `public.service_bookings`, adds a foreign key to `auth.users(id)`, and creates a policy using `auth.uid()`. The subsequent `20261108233500` and `20261108234000` migrations require existing `service_bookings` and `electrician_applications`; the latter also requires `is_srk_admin()` at policy-creation time. The identity hardening migration `20261109000500` requires existing `electrician_profiles` and `auth.users`, including Auth phone/confirmation columns.
- `COMPLETE_DATABASE_SETUP.sql` is the repository's inspected source for the initial `service_bookings`, `electrician_applications`, `electrician_profiles`, and `job_offers` tables and it enables RLS on them. It also starts with `CREATE EXTENSION IF NOT EXISTS pgcrypto`. However, it is a starter/setup script rather than a migration in the ordered chain; its `IF NOT EXISTS` statements do not prove parity with the actual database schema or resolve pre-existing drift.
- Supabase Auth is an external platform prerequisite, not created by these application migrations: the early chain references `auth.users`, `auth.uid()`, and the Auth user phone-confirmation fields. Do not attempt to synthesize or recreate the `auth` schema from app SQL.
- The first explicit Storage dependency in the inspected sequence appears in `20261113220000_customer_support_conversation_schema.sql`: it inserts the `srk-customer-support` bucket into `storage.buckets`, queries `storage.objects`, and installs policies on `storage.objects`. This migration assumes the Supabase Storage platform schema/tables and roles already exist; it creates the app bucket, not the Storage platform itself.
- No `supabase/config.toml` exists in the current branch tree. Therefore local Supabase project configuration and platform baseline are not established by the repository snapshot. No conclusion about the live project's extension set, roles, ownership, Auth/Storage version, or schema state can be drawn from these files alone.
- **Gate:** the next required evidence is an owner-approved, sanitized canonical baseline/export or explicit setup provenance that establishes the exact core table DDL, both legacy Admin helper definitions/ACLs, `srk_admin_users`, and the Supabase Auth/Storage platform baseline. Until then, source-only inspection may continue, but do not execute migrations/setup scripts or change ordering.
- No checklist item closed. Broad GPT-2 remains **27/39 = 69%**; four-workstream source checklist **27/27 applicable = 100%**; Runtime Acceptance **60/60 Pending**. Read-only inspection only; no DB, test runner, CI, deployment, production, merge, or mobile QA.


### 7.13 First application-schema dependency chain (17 November 2026)

| Migration | Direct prerequisite / edge verified from source | Resulting dependency |
|---|---|---|
| `20261108121115_add_customer_account_booking_access.sql` | Existing `public.service_bookings`; Supabase `auth.users(id)` FK and `auth.uid()` | Adds `customer_user_id`, index and customer-own-booking SELECT policy. |
| `20261108233500_restrict_public_form_inserts.sql` | Existing `service_bookings`, `electrician_applications`; roles `anon`, `authenticated`, `service_role` | Changes table INSERT ACLs; does not create either table. |
| `20261108234000_combine_booking_read_policy.sql` | Existing `service_bookings.customer_user_id` and `public.is_srk_admin()` at policy creation | Replaces earlier booking SELECT policies with one admin-or-customer policy. |
| `20261109000500_harden_electrician_profile_identity_linking.sql` | Existing `electrician_profiles.user_id`, `electrician_profiles.phone/verification_status`, Supabase `auth.users.phone/phone_confirmed_at` | Adds `auth_user_id`, sync/guard triggers and identity-linking functions. |
| `20261109001000_add_google_maps_location_support.sql` | Existing `service_bookings`, `electrician_applications`, `electrician_profiles`; existing Admin helper `is_srk_admin()`; identity columns `user_id` and `auth_user_id`; Auth phone fields | Adds six nullable coordinate columns, six named CHECK constraints, validates them, and replaces Admin approval with a `RETURNS void` version. |
| `20261109001500_unique_electrician_admin_identity_linking.sql` | Function signature from 090010; existing `electrician_applications`, `electrician_profiles`, Auth phone fields; distinct helper `srk_is_admin()`; role `authenticated` | Drops the void approval function and recreates it as `RETURNS jsonb`; unique-only phone linking. |
| `20261109002000_expose_assigned_booking_map_pin.sql` | Existing `srk_get_my_offer_details()` signature, `electrician_profiles.user_id/verification_status/active`, `job_offers`, `service_bookings`, Auth UID | Replaces the offer-details RPC projection; grant limited to authenticated. |
| `20261109003000_secure_commission_reporting.sql` | Existing `service_bookings` billing/commission columns, `electrician_profiles`, `job_offers`, Auth UID, and `is_srk_admin()` | Adds/uses commission reporting and electrician earnings RPCs. |
| `20261109010000_create_secure_wallet_ledger_foundation.sql` | Supabase Auth users/UID and roles; helper `is_srk_admin()` for Admin overview | Creates wallet account, ledger and bank-link tables plus owner-read policies and RPCs. |
| `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql` | Existing `service_bookings`, Auth users, Supabase roles | Creates Route-transfer ledger with booking/user foreign keys and RLS. This legacy ledger was later intentionally retired; do not reactivate it. |

**Important ordering observations:**
- `090010` adds the coordinate CHECK constraints without `IF NOT EXISTS`, then validates the exact same names. A partially applied/manual baseline that already contains those names can make replay fail with duplicate-constraint errors. This is a replay-risk observation, not proof of live state.
- `090010` and `090015` intentionally replace the same Admin approval signature, but the return type changes from `void` to `jsonb`; PostgreSQL cannot change a function return type via `CREATE OR REPLACE`, so the explicit DROP in 090015 is material to the sequence. Do not skip or reorder either migration.
- The Admin approval path is not backed by one interchangeable helper: 090010 calls `is_srk_admin()`; 090015 calls `srk_is_admin()`; 090030 and wallet Admin overview call `is_srk_admin()`. The starter setup script defines both distinct helpers, but that is not evidence either is present in the deployed project.
- This is a source-level dependency trace for the listed early migrations, not an exhaustive dependency graph or proof of successful replay. The remaining migration chain still needs the same table/column/function/constraint analysis and a canonical baseline comparison.
- No migration, SQL, test, CI, deployment, or live database operation was run. No checklist item closed: broad GPT-2 **27/39 (69%)**; four-workstream source **27/27 applicable (100%)**; Runtime Acceptance **60/60 Pending**.


### 7.14 Support, financial-audit and customer-profile dependency edges (17 November 2026)

- `20261110040000_customer_admin_complaints.sql` creates complaint and event tables, but requires the earlier `service_bookings` base table and Supabase `auth.users`; its Admin RPCs directly call `is_srk_admin()`. `20261110140000` later adds two quote/history columns to the existing `service_bookings` table.
- `20261111020000_add_electrician_push_subscriptions.sql` creates a table referencing `auth.users`, uses the Supabase `authenticated`/`anon` roles and `auth.uid()`, and relies on `gen_random_uuid()`. It is not a replacement for the Auth platform baseline.
- `20261113220000_customer_support_conversation_schema.sql` requires complaint tables from 10040000 and Supabase Storage platform objects/functions (`storage.buckets`, `storage.objects`, `storage.foldername`). It creates/configures the private `srk-customer-support` bucket, but does not create the Storage platform schema. Its attachment table also requires the preceding message table's composite unique key `(id, complaint_id)`; the migration correctly creates that unique index before the attachment FK.
- `20261113230000_support_attachment_paths_and_admin_message_list.sql` replaces/extends RPCs over the complaint/message/attachment tables and calls `is_srk_admin()`; it depends on the 13220000 objects being present first.
- `20261114125844_restore_financial_audit_core_schema.sql` creates the labour-bill, manual-payment, payout, admin-audit, Razorpay-refund, refund-request and manual-refund tables. Its FKs require the pre-existing booking/electrician core tables and Supabase Auth users. It then alters the existing `public.is_srk_admin()` function's search_path and ACL, creates audit triggers on the core and financial tables, and creates a payout read policy. This is a direct prerequisite gate: the helper must exist before the migration reaches its ALTER FUNCTION statement, and the trigger target tables must exist before their triggers can be created.
- `20261114130000_harden_electrician_profile_identity_linking.sql` alters the existing electrician profile table and Auth user records; its Admin approval replacement calls `srk_is_admin()`, not `is_srk_admin()`.
- `20261114150000_customer_booking_submission_idempotency.sql` adds request-key/fingerprint columns and a guarded check plus partial unique index to the existing `service_bookings` table. The constraint existence check is by constraint name only; this source inspection does not establish whether a same-named constraint on a different relation could exist in the target DB.
- `20261114160000_customer_selected_rate_tier_and_server_estimate.sql` adds selected-tier/estimate columns and supporting objects over the core booking/electrician/job-offer tables, Auth, and `is_srk_admin()`. This entry records existing source dependencies only; it does not reopen or expand the separately deferred Dynamic Rate Management scope.
- `20261114180000_harden_customer_avatar_object_integrity.sql` replaces the customer profile RPC and requires `public.srk_customer_profiles`, the Supabase Storage `storage.objects` table and `storage.foldername()`, plus an existing bucket named `srk-customer-avatars`. A repository-wide exact-string search found references in the customer UI and this migration but no migration/setup definition inserting that bucket. Therefore bucket existence/configuration is an unresolved baseline/provisioning dependency, not something to invent or create in this audit.
- **Unresolved platform/baseline evidence:** Supabase Auth and Storage objects/roles are platform prerequisites. The support bucket is provisioned by its migration; the customer-avatar bucket has no provisioning definition located in the searched repository. A canonical sanitized baseline or explicit owner-approved bucket provisioning provenance is required before replay.
- Source inspection only; this is not a complete replay graph and does not prove live DB state. No checklist item closed: broad GPT-2 **27/39 (69%)**; four-workstream source **27/27 applicable (100%)**; Runtime Acceptance **60/60 Pending**. No SQL/DB execution, tests, CI, deployment, production change, merge or mobile QA.


### 7.15 Booking payment, work timer, cancellation and refund chain (17 November 2026)

- `20261114125844_restore_financial_audit_core_schema.sql` is a major prerequisite node: it creates `srk_booking_labour_bills`, `srk_manual_payment_entries`, `srk_electrician_payouts`, `srk_admin_audit_events`, `srk_razorpay_refunds`, `srk_booking_refund_requests`, and `srk_manual_refund_entries`. These reference the pre-existing booking/electrician core tables and `auth.users`. It also directly `ALTER FUNCTION public.is_srk_admin()`, so the helper must exist before this migration, and it attaches audit triggers to pre-existing core tables.
- `20261114190000` and `20261114200000` define customer receipt/payment-history RPCs over the financial tables; `20261114202656` changes payment method through an authenticated customer RPC. Their functions rely on the earlier core/financial schema and Auth UID.
- `20261114240000_server_authoritative_customer_approved_work_timer.sql` adds booking timer/status columns and authorization tables, then defines work-start/completion, labour-bill, quote and offer RPCs. It references `srk_booking_complaints` (created by 10040000), `job_offers`, `electrician_profiles`, Auth, and `is_srk_admin()`. Its `CREATE TABLE IF NOT EXISTS srk_booking_labour_bills` definition was compared with the earlier 14125844 definition: the visible column/check definitions match; the later create is a no-op if the earlier table exists. This comparison is source-only and does not establish target DB parity.
- `20261114250000` adds immutable work-event history on existing `service_bookings` and uses `is_srk_admin()`. `20261114270000` creates cancellation request/event tables, uses Auth and the Admin helper, and installs a direct-booking-cancellation guard on `service_bookings`.
- `20261114280000` depends on the preceding cancellation request/event tables and the financial-core wallet/manual-payment tables (`srk_wallet_ledger`, `srk_wallet_accounts`, `srk_manual_payment_entries`), plus existing bookings and Auth. It adds cancellation-fee debt/items/ledger and service-role payment/cash RPCs. `20261114290000` then extends those fee and wallet ledgers with full-refund reversal and depends on existing payout/refund tables and Admin helper. Do not replay either in isolation from the financial core and cancellation chain.
- `20261114360000` adds/updates payout creation and Admin paid-settlement RPCs over the existing payout, labour-bill, booking, profile and Auth structures. It is not a provider bank-verification mechanism; settlement remains Admin-attested UPI/Bank reference workflow as documented in §3AO.
- `20261114410000` creates the Razorpay webhook event inbox and service-role-only claim/complete RPCs. The later 1720000 migration extends this queue for the background consumer; the queue schema and service-role grants are prerequisites to that later worker.
- Refund lifecycle: `20261115100000` customer refund-request RPCs require `srk_booking_refund_requests` from 14125844; `15110000` replaces the Admin queue/decision RPCs; `15120000` creates immutable recovery evidence referencing `srk_razorpay_refunds`, bookings and Auth users; `15130000` updates manual refund completion. Later 15240000/15250000 harden full-amount evidence/finalization/reconciliation RPCs and depend on the evidence and refund records already existing.
- **Replay gate:** this chain is not safely validated by applying one isolated migration. The required baseline includes the exact financial core tables, Admin helper and ACL, booking/electrician tables and columns, cancellation tables, wallet structures, Auth roles/users, and Storage platform state where referenced. `CREATE TABLE IF NOT EXISTS` is not a schema-reconciliation mechanism; it does not add missing columns to an already existing table.
- Scope boundary: this entry records prerequisites for the already-approved payment/refund/payout work only. It does not authorize new features or alter the previously agreed Dynamic Rate Management deferral, manual payout evidence model, or retired Route ledger.
- Source-level audit only; not an exhaustive graph and not proof of live schema or successful replay. No checklist item closed: broad GPT-2 **27/39 (69%)**; four-workstream source **27/27 applicable (100%)**; Runtime Acceptance **60/60 Pending**. No SQL/DB execution, tests, CI, deployment, production change, merge or mobile QA.



### 7.16 Refund identity, payout trigger ordering and financial read-model dependencies (17 November 2026)

- `20261115100000_customer_refund_request_contract.sql` customer RPCs depend on the refund-request table from `20261114125844_restore_financial_audit_core_schema.sql`, verified booking payment fields, the immutable labour-bill table, cancellation-fee items, Razorpay refund rows and manual-refund entries. New-category refund requests compare the captured collection in integer paise with labour plus settled fee ledger; legacy quote bookings follow their separate historical path.
- `20261115110000_admin_refund_review_queue_and_decisions.sql` replaces the Main Admin refund queue and decision RPCs. It joins the refund-request, booking, labour-bill, Razorpay-refund and electrician-payout records. The queue's expanded table return signature is preceded by an explicit DROP because PostgreSQL cannot change OUT columns with `CREATE OR REPLACE` alone.
- `20261115120000_durable_razorpay_refund_recovery_evidence.sql` adds append-only evidence referencing the existing Razorpay refund and booking rows plus `auth.users`. Its service-role writer also checks `srk_admin_users`, so the earlier Admin identity baseline remains a prerequisite. `20261115130000` manual-refund completion depends on the manual-payment, payout, refund-request, labour-bill and cancellation-fee ledgers.
- `20261115240000` and `20261115250000` independently require full-collection equality before a provider refund is finalized/reconciled. The latter uses booking-first then refund-row locking, matching the documented financial lock order. These are later replacements of existing RPCs, not standalone refund implementations.
- `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` installs the booking lifecycle trigger over the existing labour-bill, manual-payment, cancellation-fee and payout tables. It creates/refreshes only pending payout rows on qualifying paid/completed bookings; on refund it closes pending payouts or only the explicitly refund-owned blocked holds. Paid payouts are not rewritten by this trigger.
- `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` adds a BEFORE booking trigger to validate manual payment method/amount evidence and calculate the commission snapshot, plus a later AFTER validation trigger that checks parity against the payout ledger. Its documented trigger-name ordering assumes the payout AFTER trigger runs before the parity validation trigger; this is a source-order dependency to preserve and verify in runtime testing.
- `20261117120000_retire_legacy_booking_commission_trigger.sql` detaches the old completion-time commission trigger. `20261117130000_enforce_fixed_new_booking_commission_rate.sql` installs a BEFORE trigger forcing 15% only on new bookings while preserving historical stored rates. Do not reorder these relative to the new commission assignment logic without rechecking trigger names and timing.
- `20261117140000_enforce_unique_razorpay_refund_identity.sql` attaches one identity guard to both `srk_razorpay_refunds` and `srk_razorpay_refund_recovery_audits`. It serializes provider-ID and internal-record claims using transaction advisory locks and rejects conflicting one-to-one mappings. It therefore requires both tables to exist before trigger creation; those tables originate in 14125844 and 15120000 respectively.
- `20261117150000_fix_online_settlement_fee_retry_idempotency.sql` changes the service-role online-payment RPC to recognize an exact retry from the already-persisted booking collection snapshot after reserved cancellation-fee rows have become settled. It depends on the immutable labour bill, fee items and fee ledger/debt structures from the 14280000 chain. This avoids recalculating a retry against a now-empty reserved-fee set.
- `20261117160000` fences recovery finalization to a payout blocked specifically with note `Razorpay refund pending`; `20261117170000` similarly fences manual-refund closure to its own hold (`Manual refund processed`). These follow-up replacements preserve unrelated Admin payout blocks. They depend on the original recovery/manual-refund RPCs and payout table, and must be replayed after those definitions.
- `20261117180000_reconcile_admin_commission_report_to_payout_ledger.sql` and `20261117190000_reconcile_electrician_earnings_to_payout_ledger.sql` make the payout ledger the source for commission/payable reporting while keeping customer collection separate. Both require `srk_electrician_payouts` and the booking/profile core; the Admin report additionally requires `is_srk_admin()`. They deliberately exclude refunded payout rows and do not treat SRK cancellation-fee collections as electrician earnings.
- **Replay/verification gate:** the 15–17 November chain assumes the earlier financial core, refund evidence, payout trigger, cancellation-fee ledgers, Admin helper and role baseline are already present in their expected form. Replacing an RPC does not repair missing tables/columns, and trigger-name ordering/transactional behavior still needs runtime verification. The 17140000 cross-table identity guard also needs real concurrency tests; source inspection alone cannot establish race behavior.
- Source-only audit; no checklist item closed. Broad GPT-2 remains **27/39 (69%)**; four-workstream source remains **27/27 applicable (100%)**; Runtime Acceptance remains **60/60 Pending**. No SQL/DB execution, Node/pgTAP tests, CI, deployment, production change, merge or mobile QA.


### 7.17 Support Staff RBAC, session fencing, attachments and SOS dependencies (17 November 2026)

- `20261114390000_admin_staff_rbac_foundation.sql` creates the Support Staff registry, permission catalogue, role-permission map, tracked Staff sessions and append-only Staff audit table. These objects reference `auth.users`, use Auth session identity and depend on the pre-existing Main Admin helper `public.is_srk_admin()`. Main Admin remains a separate identity class; Staff are not inserted into `srk_admin_users`. Direct browser-role table access is revoked and RLS is enabled.
- The RBAC foundation first defines `srk_has_admin_permission(text)` as STABLE, then in the same migration adds `auth_session_id`, a unique partial index, and replaces the helper with a row-locking implementation. `20261116100000_fix_staff_permission_helper_volatility.sql` then explicitly changes the helper to VOLATILE. This is required because the helper takes `FOR SHARE` locks on active Staff registry and tracked-session rows; PostgreSQL does not permit that row-locking operation from a STABLE function. Preserve this migration order.
- Staff authorization requires three distinct checks: active Staff registry entry, a non-revoked tracked row for the exact JWT `session_id`, and a matching still-existing `auth.sessions` row. The helper also maps the requested permission through the role-permission catalogue. The Main Admin check is separate and remains an explicit bypass for the full-control identity.
- `20261113220000_customer_support_conversation_schema.sql` precedes `20261113230000_support_attachment_paths_and_admin_message_list.sql`. The first requires the complaint table from `20261110040000_customer_admin_complaints.sql`, Supabase Storage platform objects/functions, and provisions the private `srk-customer-support` bucket. It creates a unique `(message_id, complaint_id)` key before the attachment table's composite FK is declared. The following migration adds customer/Admin attachment and message-list RPCs over those tables.
- `20261114300000_admin_customer_support_thread_replies.sql` extends the same complaint-message thread and depends on the complaint and message tables plus the Main Admin helper. The electrician support-ticket migration `20261114350000_electrician_support_tickets_and_admin_inbox.sql` separately depends on Auth, electrician profiles and booking core; its original Admin inbox/reply/status RPCs are Main-Admin-only definitions. Staff permissions for Customer complaint handling must not be assumed to grant access to electrician tickets unless a separate scoped Staff RPC/policy explicitly does so.
- `20261115260000_sos_admin_support_alerts.sql` inserts `support.sos.read` and `support.sos.acknowledge` into the earlier permission catalogue and assigns them to the existing Support role. It therefore requires the RBAC foundation first, plus booking, Auth and electrician profile tables. It creates SOS case/event tables with append-only event protection. The migration explicitly does not configure SMS/Push delivery or emergency-service dispatch.
- `20261117100000_prevent_deleting_linked_support_attachments.sql` replaces the Customer support object-delete helper and attachment-link RPC. It depends on the original Storage access helper, the private bucket, Storage object rows and the complaint attachment metadata table. Both link and delete paths lock the same Storage object row, so concurrent linking/deletion is serialized. It also removes the earlier permissive delete policy before installing the locking policy; leaving an older permissive policy in place would undermine the intended restriction because permissive Storage policies combine with OR.
- `20261117110000_support_staff_assigned_customer_attachment_read.sql` adds Staff read access only after the permission helper, Customer complaint table, assignment table, attachment metadata and Storage folder conventions exist. It requires `support.customer.read`, checks the exact Customer/complaint path, locks the complaint and current assignment, and confirms that the object is already linked to a message. The new policy retains existing Customer-owner and Main Admin access and does not grant Staff upload/delete.
- **Security/replay gate:** Staff RBAC and support attachment policies depend on exact Auth session semantics, the Admin helper, Storage platform objects and the current assignment relation. A source migration chain cannot prove that deployed Auth exposes the expected `auth.sessions` rows or that Storage owner metadata matches these checks. The Staff session lock/revocation ordering, assignment/reassignment serialization, and Storage link/delete race still require runtime/concurrency verification. The earlier Staff RBAC helper-volatility correction must not be dropped or reordered.
- Source-only dependency mapping; no checklist item closed. Broad GPT-2 remains **27/39 (69%)**; four-workstream source remains **27/27 applicable (100%)**; Runtime Acceptance remains **60/60 Pending**. No SQL/DB execution, Node/pgTAP tests, CI, deployment, production change, merge or mobile QA.


### 7.18 Admin RPC direct-write closure and SECURITY DEFINER search-path hardening chain (17 November 2026)

- `20261115200000_harden_financial_admin_rpc_search_path.sql` uses `ALTER FUNCTION` on the payout-paid RPC, manual-refund RPC and payout trigger function. It does not create those functions: their exact signatures must already have been produced by earlier financial/payout migrations. A partial baseline missing any signature will stop replay at this point.
- `20261115210001_harden_legacy_financial_read_rpc_search_paths.sql` similarly assumes the legacy Admin commission report and wallet read RPCs already exist. It initially sets a non-empty path including `public`, `auth` and `pg_temp`; later `20261116110000` deliberately tightens these same functions to an empty path. Preserve the later correction.
- `20261115230000_admin_booking_direct_write_closure.sql` replaces Admin quote and customer-location mutation RPCs over `service_bookings`. The quote path locks the booking and rejects new-category, cancelled, paid/online and customer-approved quote edits; the location path is also an Admin-only SECURITY DEFINER RPC. It depends on the existing booking table and the Main Admin identity helper. Its purpose is to close direct Admin table writes through controlled RPCs; it is not a new permission class.
- The 16 November search-path pinning migrations are ordered hardening overlays, not function producers: `20261116120000` pins Customer call-contact implementation/wrapper; `16130000` pins wallet and receipt RPCs; `16150000` pins Admin application review; `16160000` pins legacy quote/work-status RPCs if those signatures still exist; and `16170000` pins the public rate-limit RPC. Each `ALTER FUNCTION` requires the exact prior signature unless explicitly marked `IF EXISTS`.
- `20261116160000` is intentionally tolerant of branch histories where legacy quote/work-status RPCs were already retired: its three `ALTER FUNCTION IF EXISTS` statements do not recreate those functions. The rate-limit hardening migration `16170000` is not IF EXISTS and therefore requires the earlier rate-limit function from `20261108120608_add_public_api_rate_limiting.sql`.
- Empty `search_path` is safe only where every application relation, helper and non-catalog function reference inside the target function is schema-qualified. The migration comments assert that condition; static review of ALTER statements alone does not prove every function body has remained qualified across all historical replacements.
- **Replay/security gate:** these ALTER-only migrations depend on exact function signatures and prior definitions. Do not cherry-pick or replay them independently against an arbitrary partial schema. The Main Admin helper and booking/financial tables remain earlier prerequisites. Confirm actual installed function definitions and ACLs from an owner-approved sanitized baseline before any replay; then run privilege/search-path regression tests in the approved final test phase.
- Source-only dependency mapping; no checklist item closed. Broad GPT-2 remains **27/39 (69%)**; four-workstream source remains **27/27 applicable (100%)**; Runtime Acceptance remains **60/60 Pending**. No SQL/DB execution, Node/pgTAP tests, CI, deployment, production change, merge or mobile QA.


### 7.19 Admin/Support RPC EXECUTE grants, table ACLs and RLS boundary audit (17 November 2026)

- **Important interpretation:** कई privileged RPCs को `authenticated` role पर EXECUTE दिया गया है, लेकिन function body में अलग से Main Admin या `srk_has_admin_permission(...)` जाँच है। इसलिए केवल GRANT देखकर उन्हें Staff-accessible या public मानना गलत होगा; वास्तविक authorization function body और उसके row/assignment checks से तय होती है.
- `20261108120608_add_public_api_rate_limiting.sql` private rate-limit table पर PUBLIC/anon/authenticated के सभी table privileges revoke करता है और केवल service_role को देता है. RPC भी PUBLIC/anon/authenticated से revoke और केवल service_role को grant है. `20261108120658` table पर RLS enable करता है. यह service-only boundary है; बाद की search_path pinning इसी exact RPC signature पर निर्भर है.
- `20261109010000_create_secure_wallet_ledger_foundation.sql` wallet tables पर RLS enable करता है, direct authenticated writes revoke करके SELECT grants और owner-read policies रखता है; service_role को table access देता है. Wallet summary और Admin overview RPC authenticated को callable हैं, लेकिन Admin overview body में Main Admin guard है. ACL और row-level/identity guard दोनों को साथ पढ़ना आवश्यक है.
- `20261110040000_customer_admin_complaints.sql` complaint/event tables पर RLS और direct table privilege revocation रखता है. Customer RPCs authenticated के लिए customer ownership से सीमित हैं; Admin list/update RPCs भी authenticated को EXECUTE देते हैं लेकिन body में `auth.uid()` तथा `is_srk_admin()` अनिवार्य है.
- Customer support message/attachment RPCs (`20261113220000`, `20261113230000`, `20261114300000`) direct table access revoke/RLS और per-customer complaint ownership checks रखते हैं. Storage policies अलग से bucket, owner/path, complaint/message linkage और Main Admin identity पर आधारित हैं. Linked-attachment delete helper और Staff attachment-read policy बाद की migrations में उसी policy chain को replace/extend करते हैं; permissive Storage policies OR होती हैं, इसलिए पुरानी delete policy हटाना security-critical है.
- `20261114350000_electrician_support_tickets_and_admin_inbox.sql` ticket/message tables पर RLS तथा direct table privilege revocation रखता है. Its legacy Admin inbox/reply/status RPCs are Main-Admin-only inside function bodies, despite authenticated EXECUTE grants. `20261114390000` अलग Staff RPC surface देता है, जिसमें specific electrician-support permission और current assignment की जाँच होती है. पुराने Admin RPC grants को Staff permission का substitute न मानें.
- `20261114390000_admin_staff_rbac_foundation.sql` Staff registry, permission catalogue, role map, tracked sessions, audit events और assignment table पर RLS enable करके direct authenticated table access revoke करता है. Staff-facing RPCs authenticated को EXECUTE देते हैं लेकिन permission helper, exact live Auth session, non-revoked tracked session और assigned-case checks लागू करते हैं. Invited-user registration RPC केवल service_role को दिया गया है. Staff status, session revoke, assignment, audit listing और assignment listing Main Admin guarded हैं.
- `20261115260000_sos_admin_support_alerts.sql` SOS tables/events पर RLS और direct table privilege revocation रखता है. Customer SOS create RPC authenticated है; Admin read/acknowledge/event RPCs authenticated EXECUTE के बावजूद `support.sos.read` या `support.sos.acknowledge` helper permission जाँचते हैं.
- `20261116100000_fix_staff_permission_helper_volatility.sql` permission helper के function-body/volatility correction के साथ उसका PUBLIC/anon revoke और authenticated EXECUTE grant दोहराता है. Staff permission decision को सीधे table grants से नहीं, इसी helper और उसकी live-session fencing से evaluate किया जाता है.
- **ACL verification limitation:** यह audit migration source में explicit GRANT/REVOKE, RLS enablement और प्रमुख privileged function-body guards का static cross-check है. PostgreSQL effective privileges में default function EXECUTE grants, ownership, inherited roles, pre-existing grants/policies, platform roles और later migrations भी प्रभाव डालते हैं. इस source inspection से live database ACL/RLS state प्रमाणित नहीं होती.
- **Final replay/runtime gate:** canonical baseline से effective table/function privileges, function owners, SECURITY DEFINER status, search_path, all policies (including older permissive policies), Main Admin helper definitions और Staff session/assignment fencing जाँचें. फिर anon/authenticated/Main Admin/Staff (assigned और unassigned; active और revoked session) के positive तथा negative permission tests चलाएँ. अभी कोई DB/pgTAP/Node execution नहीं हुआ.
- Source-only audit; कोई implementation checklist item बंद नहीं हुआ. चार-workstream source **27/27 applicable (100%)**; व्यापक GPT-2 **27/39 (69%)**, 12 शेष; Runtime Acceptance **60/60 Pending**. No CI, deployment, production change, merge or mobile QA.


### 7.20 RLS policy replacement order, legacy booking writes and immutable audit tables (17 November 2026)

- **Customer booking SELECT policy history:** `20261108121115_add_customer_account_booking_access.sql` creates/replaces the customer-owned booking read policy. `20261108234000_combine_booking_read_policy.sql` explicitly drops both the earlier Admin-read and Customer-read policies before creating one combined authenticated SELECT policy: Main Admin OR matching `customer_user_id`. This is a deliberate cleanup of duplicate permissive policies, not an additive third policy.
- **Wallet policy baseline:** `20261109010000_create_secure_wallet_ledger_foundation.sql` enables RLS on wallet account, ledger and bank-link tables; drops/recreates named owner-read policies. It revokes client table writes and grants controlled reads. Replay against a baseline with differently named permissive policies still needs full `pg_policies` comparison; dropping the three named policies alone cannot remove unknown historical policies.
- **Cancellation request/event boundary:** `20261114270000_admin_only_cancellation_requests_and_decisions.sql` enables RLS on both tables and revokes table access from anon/authenticated. All four exposed request/list/decision RPCs revoke PUBLIC/anon and grant authenticated EXECUTE; customer RPCs enforce booking ownership, Admin list/decision enforce `is_srk_admin()`, and the event mutation trigger rejects UPDATE/DELETE. The trigger also blocks direct booking cancellation outside the controlled workflow. These RPC grants are intentional and do not bypass the body checks.
- **Work-history boundary:** `20261114250000_admin_work_dispute_review_and_immutable_history.sql` enables RLS and revokes table access from PUBLIC/anon/authenticated on the work-event history. The capture trigger is not client-executable; the review RPC is authenticated-callable but Main-Admin-guarded. Its history protection relies on the absence of client table grants plus trigger-owned inserts; verify effective owner/service-role privileges and append-only expectations against the canonical baseline.
- **Electrician relocation boundary:** `20261114220000_admin_approved_electrician_relocation.sql` enables RLS and revokes all table privileges from PUBLIC/anon/authenticated on the private request table. Electrician request/list RPCs require a linked, active, approved profile and scope rows to that profile. Admin list/review RPCs check Main Admin. The Admin list grant sequence revokes authenticated then grants it back; this is not a contradiction because the function body still enforces Main Admin.
- **Legacy booking status closure:** `20261115160000_legacy_booking_status_write_guard.sql` revokes table-wide UPDATE and status-column UPDATE from authenticated, then grants only `quoted_amount`, `amount_paid`, and `payment_status` column updates. Legacy confirmation is routed through a Main-Admin-guarded RPC. This depends on all legitimate app/payment writes already using the approved RPC/trigger paths; runtime compatibility is still unverified.
- **Support Storage policy replacement:** `20261117100000` drops both historical Customer support delete policies before installing the lock-aware delete policy. `20261117110000` drops and replaces the previous support read policy with Customer/Main Admin access plus current assigned-Staff read. This explicit DROP is essential because permissive policies combine with OR. The upload policy is intentionally unchanged; Staff gets no upload/delete permission.
- **Static review conclusion:** in the inspected booking, wallet, cancellation, work-history, relocation and support-Storage chains, the named historical policy replacements are explicit where the migration identifies an OR-policy risk. No additional broad permissive policy was established by this limited source review. This is not proof that the live database has no unknown policies, grants, owners or default privileges.
- **Final gate:** before replay, compare the complete canonical `pg_policies` and effective table/function ACL inventory (not just policy names in this branch), then test anon, Customer, Electrician, Main Admin and Staff roles including unassigned/reassigned and revoked-session cases. Validate that column-level booking UPDATE grants do not break any approved client workflow. No DB/pgTAP/Node execution has occurred.
- Source-only audit; no implementation item closed. Four-workstream source **27/27 applicable (100%)**; broad GPT-2 **27/39 (69%)**, 12 remaining; Runtime Acceptance **60/60 Pending**. No CI, deployment, production change, merge or mobile QA.
