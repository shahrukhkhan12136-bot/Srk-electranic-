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
