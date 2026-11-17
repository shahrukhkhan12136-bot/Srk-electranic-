# SRK ELECTRONIC — GPT-2B Migration Dependency Map (Source Review)

**Branch:** `chore/pr8-replay-audit-20261116-v2`  
**Date:** 17 November 2026  
**Scope:** GPT-2B payment/refund/webhook/payout/accounting and Support/RBAC/attachment work.  
**Method:** Read-only inspection of current migration source files and recursive migration inventory. No SQL was executed.

## 1. Inventory and hard gates

- Current `supabase/migrations/` inventory: **92 SQL files**.
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

