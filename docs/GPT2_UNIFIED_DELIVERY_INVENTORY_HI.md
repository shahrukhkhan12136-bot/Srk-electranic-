# GPT-2 Unified Delivery Inventory — SRK ELECTRONIC
**Inventory date:** 15 November 2026  
**Branch:** `feat/customer-login-first-dashboard-20261114`  
**Inventory head before this document:** `c43c20325a5da6352ec7b1e8880f6e620788646f`  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`

## 1. Purpose and rule
This is the single index for GPT-2 scope, existing implementation, migrations, database contracts, Node regression tests, CI workflows, and remaining blockers. It consolidates pointers so repeated discovery is not needed. It is an inventory, not proof that every feature has passed runtime tests or is deployed.

## 2. GPT-2 responsibility and progress
- Scope: Admin Panel, Support Staff/RBAC, Supabase database schema/dependency audit, payments, billing, refunds, payouts, commission, accounting, Route settlement evidence, security/permissions and SOS backend/Admin support integration.
- Checklist baseline: **27/39 = 69% complete; 12/39 remaining**.
- Overall project: **56/86 = 65% complete; 30/86 remaining**.
- Percentages are checklist item counts, not runtime/Production readiness. Inventory consolidation alone does not change them.
- PR #8 remains Draft/unmerged. No merge, deployment, Production migration or live provider operation is authorized by this inventory.

## 3. Feature map — source already present

| Area | Existing Feature Branch source / behavior | Verification boundary |
|---|---|---|
| Admin identity and access | Main Admin vs Support Staff; active staff registry, role/permission checks, staff invite/disable controls; support inbox scope | Node/source tests exist; full actor-by-actor DB/browser ACL runtime pass remains |
| Support inbox and conversations | Customer/electrician support tickets, replies, status/assignment, conversation messages and attachment paths; Admin message listing | SQL contracts + Node tests exist; DB/storage/browser runtime still needed |
| Admin booking operations | Booking queue, guarded state transition, cancellation decisions, dispute review, location/assignment controls; direct authenticated booking UPDATE closure | Source and regression tests exist; isolated DB and browser role matrix remains |
| Electrician KYC/activation | Private KYC document storage/preview, review/audit, approval and activation gate; phone-change approval | Source and SQL contract tests exist; storage/Auth/DB actor flows need runtime |
| Commission and wallet | Service/labour-only commission rules, wallet ledger foundation, owner-scoped access; no unverified Route settlement represented as received | Source and contracts exist; only service_bookings.amount_paid base DDL remains unresolved for clean replay |
| Payment and receipts | Razorpay verification/webhook inbox; legacy manual payment and itemized receipt; new-category immutable labour bill + settled fee bridge; integer paise arithmetic in approved paths | Node suite passes; SQL runtime incomplete; base amount_paid DDL unresolved |
| Customer refunds | Customer-owned refund request/history, approval gate, full-refund cancellation fee/wallet reversal, idempotent refund preparation | Node + pgTAP source contracts; PostgreSQL and provider sandbox integration still needed |
| Admin refund recovery | Main Admin review/decision, manual refund evidence record, bounded provider refund pagination, exact full-amount checks and fail-closed recovery | Node tests pass; no live Razorpay call; DB runtime pending |
| Electrician payouts | Main Admin-only payout record, immutable bill/payable snapshot checks, pending/paid/blocked/refunded state checks; Route recipient validation and settlement warning | No bank transfer performed; independent Route settlement proof not implemented |
| Accounting | Read-only booking reconciliation, labour/material/fee separation, exact payment matching, route evidence explicitly unverified | SQL contracts/source; runtime DB reconciliation remains |
| Push delivery (shared interface) | Durable outbox, per-device delivery ledger, retries/backoff, lease fencing, dead-letter and health monitoring; server sender | Historical checklist records subset of disposable local PostgreSQL and Deno checks passing; managed schema/provider integration remains |
| SOS emergency alert | Customer/electrician alert creation from authenticated active booking, Admin/permissioned Support queue, acknowledgement, append-only event history; no location required | Node and pgTAP source contracts; pgTAP runtime, SMS/push provider, consented location and emergency-service integration not done |
| Security and audit | RLS, direct-grant revocations, append-only audit/event patterns, hardened search_path, row locks, fail-closed state transitions | Source contracts present; complete DB privilege/runtime matrix pending |

## 4. Key implementation entry points
- Admin UI: `admin.html`
- Staff management Edge Function: `supabase/functions/admin-staff-management/index.ts`
- Payment/refund provider code: `razorpay-refund.js`, `razorpay-refund-status.js`, `razorpay-webhook.js` and related API/function files in repository.
- Feature migrations: `supabase/migrations/`
- Database contract tests: `supabase/tests/database/`
- Node regression tests: `tests/`
- Package scripts: `npm test`, `npm run test:refund`, `npm run test:webhook`, `npm run test:customer-payment`.

## 3A. GPT-2 feature → migration → database test → Node test → UI/RPC map

यह cross-map source inventory है। जहाँ test cell सीमित है, वहाँ उसे coverage gap या runtime-unverified माना जाए—implementation failure या pass नहीं।

| GPT-2 क्षेत्र | प्रमुख migration(s) | SQL/pgTAP contract | Node regression | UI / server entry point और सीमा |
|---|---|---|---|---|
| Admin booking controls, status/write guards, work dispute | `20261114250000_admin_work_dispute_review_and_immutable_history.sql`, `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql`, `20261115160000_legacy_booking_status_write_guard.sql`, `20261115230000_admin_booking_direct_write_closure.sql` | `admin_work_dispute_review.test.sql`, `customer_booking_work_timeline.test.sql`, `legacy_booking_status_write_guard.test.sql` | `admin-booking-direct-write-closure.test.js`, `booking-lifecycle-serialization.test.js` | `admin.html`; Main Admin guarded RPCs; complete browser/role matrix अभी runtime-unverified |
| Support Staff RBAC and assigned inbox | `20261114390000_admin_staff_rbac_foundation.sql`, `20261115200000_harden_financial_admin_rpc_search_path.sql`, `20261115210001_harden_legacy_financial_read_rpc_search_paths.sql` | `admin_staff_rbac_foundation.test.sql`, `legacy_financial_read_rpc_search_path.test.sql` | `admin-refund-and-staff-access.test.js`, `legacy-financial-read-rpc-search-path.test.js` | `admin.html`, `supabase/functions/admin-staff-management/index.ts`; full Main Admin/Support actor ACL runtime pending |
| Customer/electrician support, complaint conversations and attachments | `20261110040000_customer_admin_complaints.sql`, `20261113220000_customer_support_conversation_schema.sql`, `20261113230000_support_attachment_paths_and_admin_message_list.sql`, `20261114300000_admin_customer_support_thread_replies.sql`, `20261114350000_electrician_support_tickets_and_admin_inbox.sql`, `20261114202250_customer_complaint_customer_safe_projection.sql` | `customer_complaint_customer_safe_projection.test.sql`, `support_attachment_admin_message_access.test.sql`, `electrician_support_ticket_security.test.sql` | `customer-electrician-support-contract.test.js` | `admin.html`, `booking.html`, `electrician.html`; complaint parent migration restored from historical source, but clean replay still unverified |
| Electrician KYC review and activation | `20261114330000_electrician_private_kyc_document_preview.sql`, `20261115140000_electrician_kyc_review_and_activation_gate.sql` | `electrician_kyc_review_and_activation_gate.test.sql` | `electrician-accounting-kyc-contract.test.js` | `admin.html`, `electrician.html`; Storage/Auth actor runtime pending |
| Identity linking / profile ownership | `20261109000500_harden_electrician_profile_identity_linking.sql`, `20261109001000_add_google_maps_location_support.sql`, `20261109001500_unique_electrician_admin_identity_linking.sql`, `20261114130000_harden_electrician_profile_identity_linking.sql` | `electrician_profile_identity_linking.test.sql` | `electrician-accounting-kyc-contract.test.js` | Admin approval, wallet, payout, SOS depend on profile ownership; `auth_user_id` is supplied by the migration chain (see §3B) |
| Payment capture, webhook and customer receipt | `20261114125844_restore_financial_audit_core_schema.sql`, `20261114190000_customer_receipt_immutable_labour_amount.sql`, `20261114200000_customer_payment_refund_history_rpc.sql`, `20261114202656_customer_change_payment_method_rpc.sql`, `20261115210000_legacy_manual_payment_and_itemized_receipt.sql`, `20261115270000_fix_customer_payment_method_unicode_contract.sql` | `financial_audit_core_schema.test.sql`, `customer_receipt_immutable_labour_amount.test.sql`, `customer_payment_refund_history_rpc.test.sql`, `legacy_manual_payment_and_itemized_receipt.test.sql`, `customer_change_payment_method_rpc.test.sql` | `customer-payment-method-enforcement.test.js`, `customer-payment-receipt-itemization.test.js`, `razorpay-webhook-inbox.test.js` | `admin.html`, `booking.html`, `create-order.js`, `verify-payment.js`, `razorpay-webhook.js`; base `service_bookings.amount_paid` definition unresolved |
| Customer/Admin refunds and recovery | `20261114280000_cancellation_fee_carry_forward_and_accounting.sql`, `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`, `20261115100000_customer_refund_request_contract.sql`, `20261115110000_admin_refund_review_queue_and_decisions.sql`, `20261115120000_durable_razorpay_refund_recovery_evidence.sql`, `20261115130000_admin_manual_refund_request_completion.sql`, `20261115240000_harden_refund_recovery_full_amount.sql`, `20261115250000_harden_refund_reconcile_full_amount.sql` | `cancellation_fee_refund_reversal.test.sql`, `customer_refund_request_contract.test.sql`, `customer_refund_admin_approval_gate.test.sql`, `admin_refund_review_queue.test.sql`, `durable_razorpay_refund_recovery_evidence.test.sql`, `admin_manual_refund_request_completion.test.sql`, `refund_reconcile_full_amount_guard.test.sql` | `customer-refund-ui-lifecycle.test.js`, `admin-refund-and-staff-access.test.js`, `razorpay-refund-executor.test.js`, `razorpay-refund-recovery.test.js`, `razorpay-refund-status.test.js`, `razorpay-webhook-inbox.test.js` | `admin.html`, `booking.html`, `razorpay-refund.js`, `razorpay-refund-status.js`; provider sandbox and PostgreSQL runtime not executed |
| Commission, wallet, cash collection and payout | `20261109003000_secure_commission_reporting.sql`, `20261109010000_create_secure_wallet_ledger_foundation.sql`, `20261114360000_new_category_electrician_payout_reconciliation.sql`, `20261115150000_admin_readonly_booking_accounting_reconciliation.sql`, `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` | `accounting_reconciliation_readonly_contract.test.sql`, `admin_labour_bill_payment_accounting_bridge.test.sql`, `electrician_payout_reconciliation.test.sql` | `admin-commission-report-labels.test.js`, `electrician-accounting-kyc-contract.test.js` | `admin.html`; Main Admin-only payout/payment RPCs; no bank transfer or payout executed |
| Route recipient and settlement evidence | `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql`, `20261115170000_admin_route_transfer_accounting_reconciliation.sql`, `20261115180000_admin_route_recipient_and_settlement_validation.sql`, `20261115190000_enforce_single_primary_route_bank_link.sql` | Recipient/settlement source contracts are represented in accounting/payout tests; no independent provider settlement proof contract/runtime | `admin-route-settlement-warning.test.js` | `admin.html`; settlement is explicitly unverified, no transfer/payout operation performed |
| Push outbox, device ledger and lease fencing | `20261111020000_add_electrician_push_subscriptions.sql`, `20261115170001_durable_push_delivery_outbox.sql`, `20261115180001_push_subscription_delivery_ledger.sql`, `20261115190001_push_delivery_health_monitoring.sql`, `20261115200001_push_delivery_lease_fencing.sql` | `push_delivery_lease_fencing.test.sql`; historical limited disposable-Postgres Push checks only, not current full-chain replay | `push-delivery-outbox.test.js`, `push-subscription-delivery-ledger.test.js`, `push-delivery-lease-fencing.test.js`, `push-job-offer-sender.test.js` | `admin.html`, `electrician.html`, `supabase/functions/push-job-offer/index.ts`, `netlify/functions/deliver-push-outbox.js`; no live provider send |
| SOS alert and Admin/Support acknowledgement | `20261115260000_sos_admin_support_alerts.sql` | `sos_admin_support_alerts.test.sql` | `admin-sos-staff-visibility.test.js`, `sos-admin-support-contract.test.js`, `sos-two-step-ui-contract.test.js` | `admin.html`, Customer/Electrician active-booking UI; SOS queue is explicitly shared with Main Admin and permissioned Support Staff; SMS/Push/location/emergency-service integrations not configured |
| Security, grants, search_path and audit | `20261115200000_harden_financial_admin_rpc_search_path.sql`, `20261115210001_harden_legacy_financial_read_rpc_search_paths.sql`, `20261115230000_admin_booking_direct_write_closure.sql` plus domain-specific RLS migrations above | RBAC, financial audit, legacy search-path, support, refund and SOS SQL contracts | `admin-booking-direct-write-closure.test.js`, `admin-refund-and-staff-access.test.js`, `legacy-financial-read-rpc-search-path.test.js` | `admin.html`, staff-management Edge Function and server RPCs; complete role/privilege matrix requires isolated PostgreSQL runtime |

## 5. Repository inventory snapshot
At inventory head `c43c20325a5da6352ec7b1e8880f6e620788646f`:
- SQL migrations: **78**
- Supabase database contract files: **32**
- Node test files: **39**
- GitHub Actions workflows: **3**
- Recursive tree was not truncated.

### 5A. All migration files
- `supabase/migrations/20261108120608_add_public_api_rate_limiting.sql`
- `supabase/migrations/20261108120658_enable_rls_public_api_rate_limits.sql`
- `supabase/migrations/20261108121115_add_customer_account_booking_access.sql`
- `supabase/migrations/20261108233500_restrict_public_form_inserts.sql`
- `supabase/migrations/20261108234000_combine_booking_read_policy.sql`
- `supabase/migrations/20261109000500_harden_electrician_profile_identity_linking.sql`
- `supabase/migrations/20261109001000_add_google_maps_location_support.sql`
- `supabase/migrations/20261109001500_unique_electrician_admin_identity_linking.sql`
- `supabase/migrations/20261109002000_expose_assigned_booking_map_pin.sql`
- `supabase/migrations/20261109003000_secure_commission_reporting.sql`
- `supabase/migrations/20261109010000_create_secure_wallet_ledger_foundation.sql`
- `supabase/migrations/20261109020000_create_server_only_razorpay_route_transfer_ledger.sql`
- `supabase/migrations/20261109103038_customer_electrician_direct_call_contacts.sql`
- `supabase/migrations/20261109103143_move_customer_call_contact_lookup_to_private.sql`
- `supabase/migrations/20261109_allow_quote_approval_booking_states.sql`
- `supabase/migrations/20261109_electrician_inspection_quotes_and_service_only_commission.sql`
- `supabase/migrations/20261110040000_customer_admin_complaints.sql`
- `supabase/migrations/20261110140000_restore_missing_customer_booking_quote_columns.sql`
- `supabase/migrations/20261111020000_add_electrician_push_subscriptions.sql`
- `supabase/migrations/20261113220000_customer_support_conversation_schema.sql`
- `supabase/migrations/20261113230000_support_attachment_paths_and_admin_message_list.sql`
- `supabase/migrations/20261114125844_restore_financial_audit_core_schema.sql`
- `supabase/migrations/20261114130000_harden_electrician_profile_identity_linking.sql`
- `supabase/migrations/20261114150000_customer_booking_submission_idempotency.sql`
- `supabase/migrations/20261114160000_customer_selected_rate_tier_and_server_estimate.sql`
- `supabase/migrations/20261114180000_harden_customer_avatar_object_integrity.sql`
- `supabase/migrations/20261114190000_customer_receipt_immutable_labour_amount.sql`
- `supabase/migrations/20261114200000_customer_payment_refund_history_rpc.sql`
- `supabase/migrations/20261114201428_customer_profile_saved_addresses_private_storage.sql`
- `supabase/migrations/20261114202250_customer_complaint_customer_safe_projection.sql`
- `supabase/migrations/20261114202656_customer_change_payment_method_rpc.sql`
- `supabase/migrations/20261114210000_sequential_nearest_offer_dispatch.sql`
- `supabase/migrations/20261114220000_admin_approved_electrician_relocation.sql`
- `supabase/migrations/20261114230000_recheck_electrician_current_area_before_offer.sql`
- `supabase/migrations/20261114240000_server_authoritative_customer_approved_work_timer.sql`
- `supabase/migrations/20261114250000_admin_work_dispute_review_and_immutable_history.sql`
- `supabase/migrations/20261114260000_fix_work_start_rpc_and_append_only_event_history.sql`
- `supabase/migrations/20261114270000_admin_only_cancellation_requests_and_decisions.sql`
- `supabase/migrations/20261114280000_cancellation_fee_carry_forward_and_accounting.sql`
- `supabase/migrations/20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`
- `supabase/migrations/20261114300000_admin_customer_support_thread_replies.sql`
- `supabase/migrations/20261114310000_electrician_self_availability.sql`
- `supabase/migrations/20261114320000_booking_scoped_live_electrician_location.sql`
- `supabase/migrations/20261114330000_electrician_private_kyc_document_preview.sql`
- `supabase/migrations/20261114340000_electrician_self_profile_name_edit.sql`
- `supabase/migrations/20261114350000_electrician_support_tickets_and_admin_inbox.sql`
- `supabase/migrations/20261114360000_new_category_electrician_payout_reconciliation.sql`
- `supabase/migrations/20261114370000_electrician_offer_details_immediate_booking_fields.sql`
- `supabase/migrations/20261114380000_electrician_phone_change_admin_approval.sql`
- `supabase/migrations/20261114390000_admin_staff_rbac_foundation.sql`
- `supabase/migrations/20261114410000_razorpay_webhook_event_inbox.sql`
- `supabase/migrations/20261115091906_retire_unused_legacy_accept_electrician_job.sql`
- `supabase/migrations/20261115092149_retire_unused_razorpay_route_transfer_ledger.sql`
- `supabase/migrations/20261115100000_customer_refund_request_contract.sql`
- `supabase/migrations/20261115110000_admin_refund_review_queue_and_decisions.sql`
- `supabase/migrations/20261115120000_durable_razorpay_refund_recovery_evidence.sql`
- `supabase/migrations/20261115120001_fix_multi_profile_electrician_labour_bill_access.sql`
- `supabase/migrations/20261115130000_admin_manual_refund_request_completion.sql`
- `supabase/migrations/20261115140000_electrician_kyc_review_and_activation_gate.sql`
- `supabase/migrations/20261115145900_fix_multi_profile_electrician_labour_bill_access.sql`
- `supabase/migrations/20261115150000_admin_readonly_booking_accounting_reconciliation.sql`
- `supabase/migrations/20261115160000_legacy_booking_status_write_guard.sql`
- `supabase/migrations/20261115170000_admin_route_transfer_accounting_reconciliation.sql`
- `supabase/migrations/20261115170001_durable_push_delivery_outbox.sql`
- `supabase/migrations/20261115180000_admin_route_recipient_and_settlement_validation.sql`
- `supabase/migrations/20261115180001_push_subscription_delivery_ledger.sql`
- `supabase/migrations/20261115190000_enforce_single_primary_route_bank_link.sql`
- `supabase/migrations/20261115190001_push_delivery_health_monitoring.sql`
- `supabase/migrations/20261115200000_harden_financial_admin_rpc_search_path.sql`
- `supabase/migrations/20261115200001_push_delivery_lease_fencing.sql`
- `supabase/migrations/20261115210000_legacy_manual_payment_and_itemized_receipt.sql`
- `supabase/migrations/20261115210001_harden_legacy_financial_read_rpc_search_paths.sql`
- `supabase/migrations/20261115220000_retire_live_legacy_quotation_rpcs.sql`
- `supabase/migrations/20261115230000_admin_booking_direct_write_closure.sql`
- `supabase/migrations/20261115240000_harden_refund_recovery_full_amount.sql`
- `supabase/migrations/20261115250000_harden_refund_reconcile_full_amount.sql`
- `supabase/migrations/20261115260000_sos_admin_support_alerts.sql`
- `supabase/migrations/20261115270000_fix_customer_payment_method_unicode_contract.sql`

### 5B. All database contract test files
- `supabase/tests/database/accounting_reconciliation_readonly_contract.test.sql`
- `supabase/tests/database/admin_labour_bill_payment_accounting_bridge.test.sql`
- `supabase/tests/database/admin_manual_refund_request_completion.test.sql`
- `supabase/tests/database/admin_refund_review_queue.test.sql`
- `supabase/tests/database/admin_staff_rbac_foundation.test.sql`
- `supabase/tests/database/admin_work_dispute_review.test.sql`
- `supabase/tests/database/cancellation_fee_refund_reversal.test.sql`
- `supabase/tests/database/customer_avatar_object_integrity.test.sql`
- `supabase/tests/database/customer_booking_work_timeline.test.sql`
- `supabase/tests/database/customer_change_payment_method_rpc.test.sql`
- `supabase/tests/database/customer_complaint_customer_safe_projection.test.sql`
- `supabase/tests/database/customer_payment_refund_history_rpc.test.sql`
- `supabase/tests/database/customer_profile_saved_addresses_private_storage.test.sql`
- `supabase/tests/database/customer_receipt_immutable_labour_amount.test.sql`
- `supabase/tests/database/customer_refund_admin_approval_gate.test.sql`
- `supabase/tests/database/customer_refund_request_contract.test.sql`
- `supabase/tests/database/durable_razorpay_refund_recovery_evidence.test.sql`
- `supabase/tests/database/electrician_kyc_review_and_activation_gate.test.sql`
- `supabase/tests/database/electrician_payout_reconciliation.test.sql`
- `supabase/tests/database/electrician_profile_identity_linking.test.sql`
- `supabase/tests/database/electrician_support_ticket_security.test.sql`
- `supabase/tests/database/financial_audit_core_schema.test.sql`
- `supabase/tests/database/legacy_booking_status_write_guard.test.sql`
- `supabase/tests/database/legacy_financial_read_rpc_search_path.test.sql`
- `supabase/tests/database/legacy_manual_payment_and_itemized_receipt.test.sql`
- `supabase/tests/database/push_delivery_lease_fencing.test.sql`
- `supabase/tests/database/razorpay_webhook_event_inbox.test.sql`
- `supabase/tests/database/refund_reconcile_full_amount_guard.test.sql`
- `supabase/tests/database/sequential_nearest_offer_dispatch.test.sql`
- `supabase/tests/database/server_authoritative_work_timer.test.sql`
- `supabase/tests/database/sos_admin_support_alerts.test.sql`
- `supabase/tests/database/support_attachment_admin_message_access.test.sql`

### 5C. All Node regression test files
- `tests/accepted-contact-visibility.test.js`
- `tests/admin-booking-direct-write-closure.test.js`
- `tests/admin-progress-card.test.js`
- `tests/admin-commission-report-labels.test.js`
- `tests/admin-refund-and-staff-access.test.js`
- `tests/admin-sos-staff-visibility.test.js`
- `tests/admin-route-settlement-warning.test.js`
- `tests/booking-lifecycle-serialization.test.js`
- `tests/customer-dashboard-menu-contract.test.js`
- `tests/customer-electrician-otp-login.test.js`
- `tests/customer-electrician-phone-visibility.test.js`
- `tests/customer-electrician-support-contract.test.js`
- `tests/customer-five-menu-source.test.js`
- `tests/customer-immediate-booking-contract.test.js`
- `tests/customer-payment-method-enforcement.test.js`
- `tests/customer-payment-receipt-itemization.test.js`
- `tests/customer-profile-address-navigation.test.js`
- `tests/customer-refund-ui-lifecycle.test.js`
- `tests/database-migration-version-uniqueness.test.js`
- `tests/database-pgtap-plan-counts.test.js`
- `tests/electrician-accounting-kyc-contract.test.js`
- `tests/electrician-legacy-quotation-retirement.test.js`
- `tests/electrician-live-location-client.test.js`
- `tests/legacy-financial-read-rpc-search-path.test.js`
- `tests/push-delivery-lease-fencing.test.js`
- `tests/push-delivery-outbox.test.js`
- `tests/push-job-offer-sender.test.js`
- `tests/push-subscription-delivery-ledger.test.js`
- `tests/razorpay-refund-executor.test.js`
- `tests/razorpay-refund-recovery.test.js`
- `tests/razorpay-refund-status.test.js`
- `tests/razorpay-webhook-inbox.test.js`
- `tests/sos-admin-support-contract.test.js`
- `tests/sos-two-step-ui-contract.test.js`
- `tests/welcome-screen-contract.test.js`

### 5D. All GitHub Actions workflows
- `.github/workflows/node-tests.yml`
- `.github/workflows/publish-pages.yml`
- `.github/workflows/supabase-schema-ci.yml`

### Additional source audit — 15 November 2026
- Cross-branch fetch of `SUPABASE_SCHEMA.sql` on five refs found the same starter-schema blob; it contains neither `service_bookings.amount_paid` nor `electrician_profiles.auth_user_id`. The latter is supplied by migration `20261109000500_harden_electrician_profile_identity_linking.sql`; the remaining checked-in base-DDL gap is `service_bookings.amount_paid`. Details: `docs/BASE_COLUMN_DDL_EVIDENCE_AUDIT_20261115.md`.
- This narrows the repository-source search but does not prove that no deleted Git object or external deployment artifact exists. Only the `service_bookings.amount_paid` base DDL contract remains unresolved; no guessed migration was added.

## 6. CI and test status — verified 16 November 2026
### Node CI
- Workflow: `.github/workflows/node-tests.yml`
- Triggers on push to this Feature Branch, pull requests targeting `main`, and manual dispatch.
- Uses GitHub-hosted Ubuntu, Node.js 22, `npm install --ignore-scripts --no-audit --no-fund`, then `npm test`.
- No secrets, DB writes, provider calls or deployment in this job.
- Latest verified PR head: `3670a2ee48952cb424f2da7380044d53793c0851`.
- Node run **43750241498** succeeded on that head; downloaded job log explicitly shows **217 tests, 217 pass, 0 fail, 0 cancelled, 0 skipped**.
- The tested head `3670a2ee48952cb424f2da7380044d53793c0851` includes the shared Main Admin/Support SOS visibility assertion and the added test that Support Staff cannot see Main Admin management, refund, accounting or profile-approval panels.
- This proves the Node regression suite only, not SQL migration replay, PostgreSQL/pgTAP, browser/mobile, Vercel Preview or Production parity.

### Supabase schema CI
- Workflow: `.github/workflows/supabase-schema-ci.yml`, manual dispatch only.
- It is hard-gated to `refs/heads/feature/platform-fee-cash-online-cycle`; it does not currently run on this GPT-2 Feature Branch.
- Requires `SUPABASE_DB_URL`, performs least-privilege checks and schema-only export, then starts temporary Supabase and applies a fixed list of five older migrations.
- It is not a complete replay harness for all current 78 migrations and GPT-2 work. Do not treat it as full database CI.
- No run was initiated during this inventory; no Production query/export performed.

### Pages publishing
- Workflow: `.github/workflows/publish-pages.yml`; deploys `gh-pages` when pushed or manually dispatched. It is a deployment workflow, not a test workflow. No deployment was triggered by this inventory.

### Database tests
- 32 SQL contract files are present. These are pgTAP/source contract assets; presence does not mean execution.
- Historical project checklist records the Push-specific disposable PostgreSQL checks and Deno checks as having passed at an earlier stage. That is a limited subsystem result, not a full 78-migration replay.
- No full clean-baseline replay of all current migrations has been established. This runtime environment previously lacked psql/postgres/initdb/pg_ctl/docker/podman/psycopg.

## 7. Consolidated blockers — keep these in one place
1. **Base DDL evidence:** authoritative definition remains unresolved for `public.service_bookings.amount_paid`. Do not guess its SQL type, precision, nullability, default, constraints, indexes or grants. `public.electrician_profiles.auth_user_id` is added by migration `20261109000500_harden_electrician_profile_identity_linking.sql` and is not a remaining base-DDL blocker.
2. **Dependency-matrix freshness:** `docs/MIGRATION_DEPENDENCY_MATRIX_HI.md` records a 73-migration static scan at an earlier commit; the consolidated current inventory has 78 migrations. Treat the 73-file matrix as historical until its newer migrations are reconciled. Do not call it a complete current replay order.
3. **Migration lineage:** two legacy 20261109 migrations may duplicate constraints; repository chronology alone cannot establish remote Supabase applied history. Do not rename/delete/repair without approved history evidence.
4. **Full database harness:** current schema CI is pinned to a different branch and applies only five older migrations. Need an isolated, reproducible test harness for the current migration chain after base DDL recovery.
5. **Runtime test matrix:** run pgTAP and role/ownership/concurrency tests in isolated PostgreSQL/Supabase; run browser tests for Admin and Support actor scopes. Avoid Production as test environment.
6. **Provider integrations:** Razorpay refund sandbox pagination/reconciliation, Route settlement evidence, push delivery provider, SMS/OTP and storage flows require authorized isolated integration tests. No live financial action.
7. **Main DB parity:** Feature Branch source is not Production. Any schema-only export/history evidence must be explicitly owner/DB-admin approved; no Production migration/history/catalog query is authorized here.
8. **UI/API completeness:** reconcile each Admin/Support button, field, RPC, permission, and error state to avoid dead controls/stale labels.
9. **Release:** PR #8 remains Draft/unmerged; Vercel Preview/visual QA and owner approval remain separate gates.

### Additional contract finding — 15 November 2026
- The customer payment-method SQL contract test previously expected a mojibake literal even though migration `20261115270000_fix_customer_payment_method_unicode_contract.sql` writes the canonical UTF-8 value. Corrected the SQL test in commit `13afb4d92e22673b50c5eee1751f66621fdf194f`; fetched the current branch file again and confirmed the canonical literal is present and the mojibake sequence is absent.
- Historical Node run `43743783902` passed 187/187 after the UTF-8 correction; it is superseded by run `43745940269`, which passed 189/189. Neither Node run executes pgTAP; PostgreSQL runtime assertions remain unverified.
- GPT-1's new inventory separately records missing dedicated DB tests for electrician availability, booking-scoped live-location RPCs, and phone-change approval. These are GPT-1-owned workflows; no such files were changed here. Its payment-test mismatch note predates the GPT-2 correction and should be treated as stale until GPT-1 refreshes its own inventory.
- The GPT-2 inventory now includes §3A cross-map from feature area to migrations, pgTAP files, Node tests and UI/server entry points. The older dependency inventory (71 migrations/33 SQL contracts) and dependency matrix (73 migrations) are explicitly marked historical; the replay manifest now clarifies that complaint base/event table definitions were recovered and are no longer unresolved source blockers.

## 8. No-go boundaries
No Production schema/history queries or migrations, no secrets, no provider refunds/transfers/payouts, no real SMS/OTP/push sends, no paid staging subscription, no PR merge, no deployment/go-live without separate explicit approval. Do not overwrite GPT-1 shared files.

## 9. Work order after inventory
1. Keep this document as the single inventory index and update it when a source/test/workflow is added or materially changed.
2. Resolve original base-column DDL from historical source/deployment artifact or approved schema-only export.
3. Repair the Supabase CI workflow so an isolated full migration replay can run on the Feature Branch only after prerequisites are authoritative.
4. Use the feature-to-migration-to-pgTAP-to-Node-test-to-UI/RPC matrix in §3A as the working map; update it only when source/tests change and close the identified gaps.
5. Execute isolated DB and Admin/Support browser actor matrix.
6. Only then update checklist percentages for actually closed items.

## 10. Current outcome
The GPT-2 feature set is not empty or waiting for discovery: the source already contains broad Admin/Support, payment/refund, accounting, payout, security, push and SOS implementations. The repository now has a single inventory of every migration, DB contract file, Node test file and CI workflow. The remaining work is to verify gaps, complete the test harness and resolve authoritative schema dependencies—not to repeatedly rediscover the same files.


## 3B. Source-DDL correction — 15 Nov 2026
- `auth_user_id` को missing base-DDL blocker न गिनें। Current branch migration `20261109000500_harden_electrician_profile_identity_linking.sql` इसे `uuid REFERENCES auth.users(id) ON DELETE SET NULL` के रूप में जोड़ती है; nullable/no explicit default, mismatch/duplicate checks, sync trigger and partial unique index included. यह Google Maps consumer migration `20261109001000` से पहले है। बाद की `20261114130000` migration में defensive `ADD COLUMN IF NOT EXISTS` भी है।
- Confirmed missing-column source DDL blocker केवल `service_bookings.amount_paid` है। Exact type/precision/nullability/default/constraints/indexes/grants अभी authoritative source से स्थापित नहीं।
- Latest branch head at audit time `6bbac5a55b9b9ed98621be90290c91949a9c8156` Node CI run `43746546950` passed: 189/189, 0 failures. No claim of PostgreSQL/pgTAP/full migration replay.


### Latest verification — 15 Nov 2026, 18:32 UTC
- PR head `659cd151fdf83779261bed034517b92b90d4a240` Node CI run `43747168727` PASS: 189/189, 0 fail, 0 skipped.
- This is not a PostgreSQL/pgTAP/full migration replay result and does not establish Production parity or deployment.
- DDL blocker list is corrected: `auth_user_id` is supplied by the migration chain; only `service_bookings.amount_paid` remains confirmed missing from checked-in baseline/DDL source evidence.


### Latest SOS source/CI boundary — 16 Nov 2026
- Commit `2c0f0624d69fab52389def0d93ca449d6c22c86d` records the Customer/Electrician → authenticated RPC → Admin/Support source integration recheck. It documents that clients send only `p_reason`; backend derives actor and the unique active booking, and Admin RPCs enforce SOS read/acknowledge permissions.
- Commit-level PR-triggered workflow lookup returned no runs for this documentation commit. Node run `43750568185` later completed successfully on PR head `609fd7843dc00fd3ca2e7560d3e0314b8bcec927` with **217/217** Node tests passing; it includes the shared SOS visibility test correction described below.
- SOS PostgreSQL/pgTAP runtime, SMS/Push delivery, consented location and browser/mobile end-to-end QA remain pending. No emergency-service auto-contact, Production migration, merge or deployment.


### Admin SOS Support visibility fix — 16 Nov 2026
- UI audit found the SOS card was a normal Admin-only direct child of `#app`, while `showState()` also loads SOS for Support Staff. `setAdminPortalMode('staff')` therefore hid the card even though the Support role is explicitly granted `support.sos.read` and `support.sos.acknowledge` by migration `20261115260000`.
- Fixed `admin.html` with the `admin-shared hidden` class so the SOS card is visible in both authorized Main Admin and Support Staff modes. Backend permission checks remain authoritative; no client-side permission bypass was added.
- Added `tests/admin-sos-staff-visibility.test.js` and updated the existing `tests/admin-refund-and-staff-access.test.js` role-visibility assertion and an explicit Main Admin panel isolation test. Latest test commit is `3670a2ee48952cb424f2da7380044d53793c0851`.
- Node run `43750241498` passed on descendant PR head `609fd7843dc00fd3ca2e7560d3e0314b8bcec927`; downloaded log confirms **216/216**. This is Node/source-contract evidence only, not browser or PostgreSQL/pgTAP runtime proof.


### 3C. वर्तमान Feature Branch Node test inventory (2026-11-16 पुनर्गणना)

Recursive Git tree से `tests/*.test.js` की वास्तविक संख्या **39** सत्यापित हुई। पुराने §3B snapshot में 35 लिखा था; वह संख्या अब superseded है। वर्तमान पूरी सूची:

- `tests/accepted-contact-visibility.test.js`
- `tests/admin-booking-direct-write-closure.test.js`
- `tests/admin-commission-report-labels.test.js`
- `tests/admin-progress-card.test.js`
- `tests/admin-refund-and-staff-access.test.js`
- `tests/admin-route-settlement-warning.test.js`
- `tests/admin-sos-staff-visibility.test.js`
- `tests/booking-lifecycle-serialization.test.js`
- `tests/customer-booking-idempotency.test.js`
- `tests/customer-dashboard-menu-contract.test.js`
- `tests/customer-electrician-otp-login.test.js`
- `tests/customer-electrician-phone-visibility.test.js`
- `tests/customer-electrician-support-attachments-contract.test.js`
- `tests/customer-electrician-support-contract.test.js`
- `tests/customer-five-menu-source.test.js`
- `tests/customer-immediate-booking-contract.test.js`
- `tests/customer-language-ui-contract.test.js`
- `tests/customer-payment-method-enforcement.test.js`
- `tests/customer-payment-receipt-itemization.test.js`
- `tests/customer-profile-address-navigation.test.js`
- `tests/customer-refund-ui-lifecycle.test.js`
- `tests/database-migration-version-uniqueness.test.js`
- `tests/database-pgtap-plan-counts.test.js`
- `tests/electrician-accounting-kyc-contract.test.js`
- `tests/electrician-area-change-contract.test.js`
- `tests/electrician-legacy-quotation-retirement.test.js`
- `tests/electrician-live-location-client.test.js`
- `tests/legacy-financial-read-rpc-search-path.test.js`
- `tests/push-delivery-lease-fencing.test.js`
- `tests/push-delivery-outbox.test.js`
- `tests/push-job-offer-sender.test.js`
- `tests/push-subscription-delivery-ledger.test.js`
- `tests/razorpay-refund-executor.test.js`
- `tests/razorpay-refund-recovery.test.js`
- `tests/razorpay-refund-status.test.js`
- `tests/razorpay-webhook-inbox.test.js`
- `tests/sos-admin-support-contract.test.js`
- `tests/sos-two-step-ui-contract.test.js`
- `tests/welcome-screen-contract.test.js`

यह फ़ाइल-गणना है, टेस्ट निष्पादन का परिणाम नहीं। अलग Node CI run 43750241498 में कुल 216/216 टेस्ट पास हुए; PostgreSQL/pgTAP और वास्तविक browser-role runtime अभी प्रमाणित नहीं हैं।


### 3D. नवीनतम source-tree count correction — 16 Nov 2026
- वर्तमान PR Feature Branch recursive Git tree: **86 SQL migrations**, **32 pgTAP SQL test files**, **43 Node `.test.js` files**, और **3 GitHub Actions workflows**। §3C में दर्ज 39 Node test files पुराना snapshot है; अब superseded है।
- §3C की 39-file सूची में बाद में जोड़ी गई चार test files: `tests/admin-rpc-search-path-hardening.test.js`, `tests/customer-electrician-booking-status-sync-contract.test.js`, `tests/customer-electrician-cancellation-refund-contract.test.js`, `tests/customer-electrician-payment-history-contract.test.js`।
- वर्तमान PR head `9d49fbcd47d624ed205765dd1e9662c4dad4d4de` के Node CI run `43755687986` में **264 पास / 5 फेल** हुए। पाँच फेल टेस्ट Customer/Electrician UI source-contract tests हैं; यह केवल Node evidence है।
- `auth_user_id` अब missing-DDL blocker नहीं: migration `20261109000500_harden_electrician_profile_identity_linking.sql` इसे `uuid REFERENCES auth.users(id) ON DELETE SET NULL` के रूप में जोड़ती है। शेष confirmed missing base-column DDL source gap `service_bookings.amount_paid` है।
- ये source-tree counts और Node CI result PostgreSQL/pgTAP runtime, पूर्ण migration replay, Production parity, browser/mobile QA या deployment प्रमाणित नहीं करते।


### 3E. नवीनतम Node CI विफलता का विभागवार वर्गीकरण — 16 Nov 2026
- PR head `a0d0f43b66a22dc4e47768bff13d36a064b55214` पर Node workflow run `43756364424` असफल हुआ: **270 में 266 पास, 4 फेल**।
- चारों असफल source-contract tests Customer/Electrician UI क्षेत्र के हैं: `customer booking timeline isolates a rejected per-booking RPC transport`, `customer and electrician lifecycle actions expose retry states and always release their busy guards`, `Electrician earnings and wallet panels isolate rejected network requests`, और `customer direct-call lookup is authenticated and scoped to the booking owner`।
- ये चारों GPT-1 स्वामित्व वाले Customer/Electrician UI टेस्ट हैं। GPT-2 ने साझा `booking.html` या `electrician.html` को बिना अनुमति नहीं बदला; GPT-1 के सुधार की प्रतीक्षा है।
- इस रन में GPT-2 के Admin/Staff सुरक्षा वाले संबंधित Node checks पास हुए; फिर भी यह PostgreSQL/pgTAP, browser runtime, full migration replay या Production parity का प्रमाण नहीं है।

### 3F. Legacy verified-payment amount DDL gap — source fix (16 Nov 2026)
- Rechecked both root schema setup files: `COMPLETE_DATABASE_SETUP.sql` and `SUPABASE_SCHEMA.sql` define `public.service_bookings` without `amount_paid`, although later financial, webhook, receipt and accounting source references that column.
- Added migration `20261116200000_restore_service_bookings_amount_paid.sql`: idempotently adds nullable `amount_paid numeric(12,2)` and a named nonnegative CHECK constraint marked `NOT VALID` so legacy rows are not blocked during migration validation; new/updated values are checked. Existing payment data is not rewritten.
- Added three Node source-contract checks in `tests/legacy-amount-paid-ddl.test.js` and three pgTAP assertions in `financial_audit_core_schema.test.sql` (plan increased from 51 to 54).
- This resolves the missing-column DDL source gap for a clean schema assembled from the tracked setup SQL plus the feature migration chain. It does not prove full migration replay or production compatibility.
- Current source counts increase by one migration (87) and one Node test file (44), relative to the prior 86/43 snapshot. No Node, pgTAP, PostgreSQL or GitHub Actions run was observed for this change. No Production schema/data write, payment, refund, payout, merge or deployment was performed.

### 3G. Node CI परिणाम — 16 Nov 2026
- नवीनतम दर्ज Node workflow run `43758276843` (head `68a69199e93a599b22dedbc0de38b10a06699b04`) में **280/284 पास, 4 फेल**। इस बदलाव के तीनों नए `legacy-amount-paid-ddl.test.js` checks पास हुए।
- चार failures Customer/Electrician UI के GPT-1 स्वामित्व वाले tests हैं: customer booking timeline RPC transport, customer/electrician lifecycle retry guards, electrician earnings/wallet network errors, और customer direct-call owner scoping। GPT-2 ने इन UI files/tests को नहीं बदला।
- यह Node/source evidence है। pgTAP, PostgreSQL migration replay, browser runtime, Production parity और deployment अभी प्रमाणित नहीं हैं।


### 3H. नवीनतम GPT-2 स्रोत-सुधार — 16 Nov 2026 (PR head 30db813)
- §3F में दर्ज `20261116200000_restore_service_bookings_amount_paid.sql` migration अब वर्तमान PR head में मौजूद है। यह `public.service_bookings.amount_paid` को nullable `numeric(12,2)` के रूप में idempotently जोड़ती है और named non-negative CHECK को `NOT VALID` रखती है, ताकि पुराने rows का validation स्वतः न चले। यह source-level DDL recovery है; PostgreSQL replay या Production compatibility का प्रमाण नहीं।
- इसलिए इस PR head पर `service_bookings.amount_paid` को “missing introducing DDL” कहना अब superseded है। पुराने §3, §3A, §3F और §3G में मौजूद unresolved wording ऐतिहासिक snapshot के रूप में पढ़ें; इस §3H का status नवीनतम है।
- `electrician_profiles.auth_user_id` का DDL पहले ही §3D/§11 में सही रूप से resolved दर्ज है। अभी भी अलग migration-history blocker: दो files का exact duplicate 8-digit version `20261109`। इसे rename/delete/resequence या remote history repair न करें।
- Current source count prior snapshot 86 migrations / 43 Node tests से बढ़कर **87 SQL migrations / 44 Node test files** हुआ है; **32 pgTAP SQL files / 3 workflows** का पिछला count इस update में दोबारा recursive-tree से सत्यापित नहीं किया गया। नई migration के लिए तीन Node source-contract checks और `financial_audit_core_schema.test.sql` में तीन pgTAP assertions मौजूद हैं।
- Exact PR head `${head}` पर इस audit में कोई GitHub Actions workflow run उपलब्ध नहीं था। पुराने head `68a6919` पर दर्ज 280/284 परिणाम इस head का CI परिणाम नहीं है। Netlify Deploy Preview सफल और Vercel build rate-limit failure अलग status checks हैं।
- कोई PostgreSQL/pgTAP execution, full ordered replay, Production query/write, payment/refund/payout, merge या deployment नहीं किया गया।
