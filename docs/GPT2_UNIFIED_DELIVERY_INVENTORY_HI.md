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


### 3I. GPT-2 audit branch — Support Attachment Security और वर्तमान source-tree count (17 Nov 2026)

वर्तमान GPT-2 audit branch `chore/pr8-replay-audit-20261116-v2`, HEAD `ac4e55deec73c1f6b050bd96673f20afb66bf301` पर recursive Git tree से निम्न source counts सत्यापित हुए:

- **91 SQL migrations**
- **36 Supabase pgTAP SQL test files**
- **54 Node `.test.js` files**
- **3 GitHub Actions workflows**

ये पूरे branch के repository counts हैं; इन्हें केवल GPT-2-owned files की संख्या न समझें। पुराने §3H के 87/44 counts इस branch snapshot के लिए superseded हैं।

इस audit branch पर हाल के GPT-2 Support Attachment source changes:

1. `20261117100000_prevent_deleting_linked_support_attachments.sql`: generic Customer Support Storage DELETE को linked attachment metadata के रहते रोकता है; unlinked pending object cleanup path रखता है। साथ में link/delete row-lock serialization जोड़ी गई।
2. `support_attachment_deletion_lifecycle.test.sql`: 8 pgTAP source-contract assertions; **execute नहीं किया गया**।
3. `20261117110000_support_staff_assigned_customer_attachment_read.sql`: Support Staff को केवल वर्तमान में assigned Customer Complaint की metadata-linked attachments पढ़ने देता है। Customer owner और Main Admin read path बना रहता है; Staff upload/delete नहीं मिलता।
4. `support_attachment_staff_access.test.sql`: 10 pgTAP source-contract assertions; **execute नहीं किया गया**।
5. `admin.html`: Staff Customer Complaint thread में attachment listing/open controls; authenticated Storage `download()` request इस्तेमाल होती है, Staff signed URL नहीं बनाया जाता।
6. `staff-customer-attachment-access-contract.test.js`: 6 Node source-contract cases; **Node test runner में execute नहीं किया गया**।
7. इस audit में `admin.html` का एक inline script और नया Node test source in-memory JavaScript syntax compilation से गुजरे; यह Node test suite/CI run का विकल्प नहीं है।

### 3J. Migration version lineage — current branch recheck (17 Nov 2026)

Recursive migration filename scan में अभी भी केवल एक duplicate version group मिला:

- `20261109_allow_quote_approval_booking_states.sql`
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql`

`tests/database-migration-version-uniqueness.test.js` इस exact legacy pair को explicit exception के रूप में allow करता है; नए duplicate versions को fail करता है। दोनों files के SQL content में status constraints दोबारा replace होते हैं, पर repository source से hosted environment में कौन-सा version/SQL पहले या दोनों लागू हुए थे, यह स्थापित नहीं होता।

**सुरक्षित स्थिति:** filenames rename/resequence, migration history repair या remote migration-list query नहीं किया गया। पहले owner/DBA से sanitized read-only migration-history evidence आवश्यक है। Supabase migration tracking timestamps पर आधारित है; इसलिए समान version prefix को filename-only बदलाव मानकर सुरक्षित रूप से हल नहीं किया जा सकता।

### 3K. Progress / verification boundary — 17 Nov 2026

- Official GPT-2 checklist: **27/39 = 69% complete; 12 remaining** — unchanged.
- Support attachment changes are source additions only. No pgTAP, PostgreSQL replay, Storage actor runtime, browser runtime or CI execution is claimed.
- Complaint/Message hard-delete के बाद orphan Storage object cleanup workflow remains open; no automatic cleanup feature was added.
- PR #8 remains Open/Draft/Unmerged and points to its separate feature head; the GPT-2 audit branch was not merged.
- No remote/Production database query, migration execution, provider operation, deployment, merge or mobile QA was performed.


### 3L. Legacy completion commission trigger और नया payout commission trigger — coexistence audit (17 Nov 2026)

Read-only source recheck में एक अतिरिक्त trigger-wiring concern मिला:

- `PORTAL_SCHEMA.sql` में `srk_booking_commission_trigger` नाम का `BEFORE UPDATE OF status` trigger अभी भी `srk_calculate_commission_on_completion()` को call करता है।
- उस legacy function का predicate `new.status='completed'` और `old.status IS DISTINCT FROM 'completed'` है; यह commission को `new.quoted_amount * new.commission_rate / 100` से बनाता है। Legacy quote में `quoted_amount` labour + materials total हो सकता है।
- नई migration `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` अलग `zz_srk_set_booking_commission_before_payout` BEFORE trigger जोड़ती है। यह तभी labour-only commission set करती है जब booking completed + paid + verified हो और Razorpay या matching manual evidence उपलब्ध हो।
- नई migration पुराने `srk_booking_commission_trigger` को DROP/replace नहीं करती। Trigger names के alphabetical order में पुराना `srk_...` trigger नए `zz_...` trigger से पहले चलता है। यदि completion पर payment अभी verified नहीं है, तो नया function early-return करता है; इससे legacy trigger द्वारा `quoted_amount` पर निकाला गया commission value बना रह सकता है। बाद के qualifying payment update पर नया trigger उसे labour-only amount से overwrite कर सकता है।

**Classification:** यह source-level coexistence / interim commission-value concern है; इससे live payout गलत हुआ है, ऐसा कोई runtime प्रमाण नहीं। नई Admin commission report payout ledger पढ़ती है, लेकिन booking के `commission_amount` और payout parity की जाँच अलग reconciliation path में होती है।

**Safe next step:** owner से तय कराएँ कि legacy completion trigger अब obsolete है और उसे additive follow-up migration में drop/replace करना है, या वह किसी historical compatibility case के लिए आवश्यक है। इस निर्णय के बिना trigger हटाया/बदला नहीं गया। Isolated PostgreSQL में completed-unpaid, later verified-paid, manual-evidence mismatch और rollback scenarios जोड़कर जाँचना बाकी है।

- Source files re-read: `PORTAL_SCHEMA.sql`, `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`, `20261116210000_attach_electrician_payout_reconciliation_trigger.sql`, `electrician_payout_reconciliation.test.sql`.
- No database/pgTAP execution, source migration edit, Production query, payout/refund operation, merge or deployment performed for this finding.
- Official GPT-2 progress remains **27/39 = 69%**.


### 3M. Owner approval और legacy commission trigger retirement — source migration (17 Nov 2026)

- Owner ने पुराने `srk_booking_commission_trigger` को obsolete मानकर additive migration में हटाने की स्पष्ट अनुमति दी।
- नई migration `20261117120000_retire_legacy_booking_commission_trigger.sql` केवल `public.service_bookings` से `srk_booking_commission_trigger` को `DROP TRIGGER IF EXISTS` करती है।
- Legacy function `srk_calculate_commission_on_completion()` को जानबूझकर delete नहीं किया; compatibility के लिए function definition बनी रहती है, लेकिन अब यह booking completion पर commission overwrite नहीं कर सकती।
- Authoritative labour-only commission assignment पहले से मौजूद `zz_srk_set_booking_commission_before_payout` verified-payment trigger के पास रहता है।
- Migration source branch पर commit हुई; इसे किसी database पर apply नहीं किया गया। PostgreSQL migration replay, pgTAP/runtime test और payout/refund side-effect test अभी pending हैं।
- यह source change अपने-आप checklist item को complete नहीं करता; official GPT-2 progress **27/39 = 69% complete; 12 remaining** अपरिवर्तित है।


### 3N. Payout parity exception guards — अतिरिक्त pgTAP source assertions (17 Nov 2026)

- `supabase/tests/database/electrician_payout_reconciliation.test.sql` का plan **34 से 39** किया गया; पाँच अतिरिक्त assertions legacy trigger retirement, compatibility function preservation, verified-payment trigger presence, payout-row-missing/commission-mismatch exception guards और blocked payout upsert protection को जाँचते हैं।
- यह migration-chain के बाद database catalog/function definitions पर चलने वाला pgTAP contract है। इसे अभी execute नहीं किया गया; इसलिए इसे runtime rollback प्रमाण नहीं माना जाएगा।
- वास्तविक exception/rollback scenarios के लिए isolated PostgreSQL fixture अभी आवश्यक है: (1) qualifying paid/completed booking पर payout row missing होने से booking update rollback, (2) blocked payout में commission mismatch होने से booking update rollback और blocked payout unchanged रहना। Fixture schema/constraints की पूरी पुष्टि के बिना behavioral test source नहीं जोड़ा गया।
- कोई PostgreSQL/pgTAP run, database migration apply, Production query/write, provider refund/payout, merge या deployment नहीं हुआ। Official GPT-2 progress **27/39 = 69% complete; 12 remaining** अपरिवर्तित।


### 3O. Parity-only update paths — fixture design refinement (17 Nov 2026)

- Payout trigger और parity validator की UPDATE column lists की तुलना से एक सुरक्षित targeted guard path पहचाना: payout writer `materials_amount` और `commission_amount` पर fire नहीं होता, जबकि AFTER parity validator दोनों पर fire होता है।
- इसलिए missing-payout guard को valid verified booking पर payout row बनने के बाद test transaction में row हटाकर, फिर केवल `materials_amount` बदलकर exercise किया जा सकता है; parity validator exception देगा और उसी statement/transaction का rollback row deletion सहित सभी बदलाव वापस करेगा। (यह design है, executed result नहीं।)
- Commission mismatch guard के लिए existing blocked payout row का commission value fixture में अपेक्षित booking commission से अलग रखा जा सकता है; फिर केवल `commission_amount` update करने पर payout writer fire नहीं होगा और parity validator mismatch reject करेगा। Transaction rollback के बाद blocked payout row unchanged verify किया जा सकता है।
- pgTAP file में दो assertions जोड़े गए हैं जो दोनों triggers की column-list separation जाँचते हैं। Plan अब **41 assertions** है; actual fixture/rollback assertions अभी नहीं जोड़े गए, क्योंकि complete authoritative baseline और exact table constraints/migration replay अभी unresolved हैं।
- Test file source count rechecked: plan **41**, `select ok(...)` assertions **41**, `finish()` और transaction rollback मौजूद। pgTAP execution **NOT RUN**।
- GPT-2 official progress **27/39 = 69%** unchanged; source assertions/documentation implementation checklist item complete नहीं करते।


### 3O correction — payout trigger column overlap (17 Nov 2026)

- पिछले §3O draft में `materials_amount` को parity-only field मानना गलत था। Trigger DDL दोबारा पढ़ने पर payout writer भी `materials_amount` पर fire होता है; इसलिए उसे बदलकर missing-row test करने पर payout row फिर insert/upsert हो सकती थी। उस प्रस्तावित test path को वापस लिया गया।
- सही अलग trigger path केवल `commission_amount` है: BEFORE commission trigger और AFTER payout writer दोनों की UPDATE column list में यह field नहीं है; AFTER parity validator की list में है। इसलिए missing payout row और commission mismatch दोनों को केवल `commission_amount` update द्वारा parity validator तक पहुँचाने का source-level रास्ता है, बिना payout writer चलाए।
- pgTAP source assertions को इसी corrected condition पर बदला गया: payout writer trigger definition में `commission_amount` नहीं, parity validator definition में `commission_amount` है। Plan **41** ही है; assertions **41** हैं।
- यह trigger-definition source inspection है, PostgreSQL/pgTAP execution नहीं। Actual rollback fixtures अभी pending हैं; clean local replay के blockers और authoritative baseline unresolved हैं।
- GPT-2 official progress **27/39 = 69%** unchanged।


### 3P. Fresh-install और सुरक्षित runtime test environment recheck (17 Nov 2026)

- Current audit branch पर `supabase/migrations/` में **92 migration files** हैं। सभी filenames में valid timestamp prefix है। Duplicate version का केवल एक legacy group मिला: `20261109_allow_quote_approval_booking_states.sql` और `20261109_electrician_inspection_quotes_and_service_only_commission.sql`; इसे production migration history evidence के बिना rename/resequence नहीं करना है।
- `COMPLETE_DATABASE_SETUP.sql`, `SUPABASE_SCHEMA.sql` और `PORTAL_SCHEMA.sql` starter/older setup scripts हैं; ये वर्तमान 92-file ordered migration chain का विकल्प नहीं हैं। इसलिए इन्हें अकेले replay करके GPT-2B का fresh-install baseline प्रमाणित नहीं किया जा सकता।
- मौजूदा `.github/workflows/supabase-schema-ci.yml` manual dispatch पर चलता है, लेकिन job केवल `feature/platform-fee-cash-online-cycle` ref पर enabled है। इसके अतिरिक्त यह `SUPABASE_DB_URL` secret से remote schema-only export/check करता है, फिर local Supabase में केवल पाँच चुनी हुई feature migrations apply करता है—पूरी 92-migration chain नहीं।
- Workflow में remote schema export step स्पष्ट रूप से production schema कहता है। इसलिए इसे इस GPT-2B audit branch पर dispatch करना **सुरक्षित isolated fresh-install test नहीं** होगा; इसमें remote database से read-only schema access भी होगा। कोई workflow dispatch या remote query नहीं किया गया।
- इस branch tree में checked-in `supabase/config.toml` नहीं मिला। Empty local Supabase project और full ordered migration replay चलाने से पहले reproducible local config, required extensions/auth/storage baseline और test harness तय करना आवश्यक है।
- सुरक्षित अगला कदम: अलग local-only CI workflow/config प्रस्तावित करना जो किसी remote URL/secret को न पढ़े, empty local Supabase stack से शुरू हो, सभी migrations timestamp order में replay करे और pgTAP suites चलाए। इसे जोड़ने से पहले local prerequisites और migration compatibility source-level पर जाँचनी होगी; workflow execution के लिए अलग अनुमति/CI evidence आवश्यक होगा।
- Payout pgTAP source file की नवीनतम स्थिति अलग से rechecked: `plan(46)` और 46 assertion statements; दो `throws_ok` parity rollback cases source में मौजूद हैं। PostgreSQL/pgTAP execution अभी भी **NOT RUN** है। पुराने §3O में दर्ज plan 41 ऐतिहासिक snapshot था, वर्तमान count नहीं।
- कोई migration apply, DB query, workflow dispatch, remote schema export, provider action, deployment या merge नहीं हुआ। Official GPT-2 progress **27/39 = 69% complete; 12 remaining** अपरिवर्तित।


### 3Q. Payout parity rollback fixtures और वर्तमान Support Staff contract counts — 17 Nov 2026

- Current source recheck पर `supabase/tests/database/electrician_payout_reconciliation.test.sql` का plan **55** और 55 assertion calls है। इसमें transaction-scoped legacy quote fixtures के साथ positive commission-only update, missing-payout parity exception, blocked payout commission mismatch exception और failed statement के बाद payout row/state preservation assertions मौजूद हैं (fixture section: `payout_rollback_fixtures`).
- ये fixtures `lives_ok` / `throws_ok` source contracts हैं; PostgreSQL/pgTAP में execute नहीं किए गए। इसलिए actual trigger rollback behavior अभी unverified है।
- Support Staff current source contract counts rechecked: `admin_staff_rbac_foundation.test.sql` 73, `electrician_support_ticket_security.test.sql` 17, `support_attachment_staff_access.test.sql` 11, `support_attachment_deletion_lifecycle.test.sql` 8, `support_attachment_admin_message_access.test.sql` 14, `sos_admin_support_alerts.test.sql` 28. ये सभी plan/assertion source counts हैं, pass counts नहीं।
- Additional Node source contracts: `admin-refund-and-staff-access.test.js` में 29 tests और `staff-customer-attachment-access-contract.test.js` में 6 tests; execute नहीं किए गए।
- Payout commission-only edit path में payout writer trigger column list से `commission_amount` बाहर है और parity validator में शामिल है; इसी वजह से missing payout तथा mismatch exception fixtures payout upsert को दोबारा चलाए बिना parity guard तक पहुँचते हैं। यह source wiring evidence है, runtime result नहीं।
- No database operation, pgTAP/Node test execution, CI dispatch, migration replay, production access, provider action, deployment, merge या mobile QA किया गया। Official GPT-2 progress **27/39 = 69% complete; 12 remaining** अपरिवर्तित; Runtime Acceptance **60/60 Pending**।


### 3R. Cancellation Fee Refund Reversal और Cash/Online Collection Reconciliation Audit — 17 Nov 2026

- `20261114280000_cancellation_fee_carry_forward_and_accounting.sql` source recheck: customer-scoped advisory transaction lock के बाद open debts को ordered `FOR UPDATE` से reserve किया जाता है; cancellation पर केवल उसी booking के reserved debt items release होते हैं। Cash collection Main Admin-only है, booking row lock करती है, immutable labour bill + reserved fee से total निकालती है, duplicate manual payment रोकती है, electrician wallet row lock करती है और fee debit/receivable entries को per-item idempotency keys से लिखती है। Online collection service_role-only है, booking row lock, provider ID format, order ID, exact captured amount और payment state जाँचती है; fee collection entries per-item idempotency key से लिखी जाती हैं।
- `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` source recheck: full refund trigger केवल paid → refunded transition पर चलता है; Razorpay path processed exact-full refund record और manual path exact-full manual refund record माँगता है; unsettled fee items या missing original ledger/wallet debit पर fail closed; reversal original ledger row से linked है और partial unique index एक original entry पर duplicate reversal रोकता है। Cash path exact earlier electrician wallet debit का credit reversal भी लिखता है। Debt open और booking fee item reversed होता है।
- Admin cancellation-fee summary online collections और cash electrician debits से linked reversals घटाता है; अलग reversed-fee total और entry counts देता है। Read RPC Main Admin check करता है।
- `cancellation_fee_refund_reversal.test.sql` current source plan **44**; source assertions केवल DDL/function contract दर्शाते हैं, pgTAP execute नहीं हुआ।
- Source review में इस pass में कोई नया निश्चित defect पुष्ट नहीं हुआ। यह concurrent runtime, wallet ledger balance, provider confirmation या database-applied schema का प्रमाण नहीं है।
- कोई database operation, migration replay, pgTAP/Node test execution, CI, production access, provider action, deployment, merge या mobile QA नहीं हुआ। Official GPT-2 progress **27/39 = 69% complete; 12 remaining** अपरिवर्तित; Runtime Acceptance **60/60 Pending**।


### 3S. Electrician Earnings RPC को canonical Payout Ledger से align किया — 17 Nov 2026

- Audit में निश्चित mismatch मिला: पुराने `srk_get_my_earnings()` RPC में electrician earning `service_bookings.amount_paid - commission_amount` से निकल रही थी। New-category customer collection में carry-forward Cancellation Fee भी शामिल हो सकती है, जबकि वह SRK की receivable है, electrician की कमाई नहीं। Admin commission report पहले ही canonical payout ledger पर align हो चुकी थी, लेकिन Electrician App earnings RPC पुरानी गणना पर था।
- Source fix: `20261117190000_reconcile_electrician_earnings_to_payout_ledger.sql` में `srk_get_my_earnings()` अब customer collection `amount_received` को अलग रखता है; `commission_amount` को `srk_electrician_payouts.platform_commission` और `electrician_earning` को `srk_electrician_payouts.electrician_payable` से लेता है। Join booking और उसी electrician profile दोनों से बँधा है; केवल pending/paid/blocked payout rows शामिल हैं, refunded payout को earning से बाहर रखा गया है। Missing payout पर earning शून्य रहती है—customer collection से अनुमान नहीं लगाया जाता।
- RPC SECURITY DEFINER + empty search_path, anon/PUBLIC execute revoke और authenticated execute grant रखता है। Return columns वही हैं, इसलिए मौजूदा Electrician App caller contract नहीं बदला।
- नया source contract: `supabase/tests/database/electrician_earnings_payout_ledger_contract.test.sql`, plan **13**, 13 assertion calls। अतिरिक्त assertions authenticated user ownership, approved electrician profile और 200-booking response bound जाँचते हैं। Test file inspect/commit हुई है; pgTAP execute नहीं हुआ।
- Commits: migration `87fe55e49d9f9777fc06faa3ced705e383213e9c`; test `9de53bda0e099396e4ed63248e425cbac744afba`।

- UI compatibility recheck: `electrician.html` मौजूदा RPC field names (`amount_received`, `commission_amount`, `electrician_earning`) ही consume करता है; return shape अपरिवर्तित है। UI payout state अलग से canonical payout table से पढ़ता है। Repo-wide targeted search में कोई दूसरा live `amount_paid - commission_amount` electrician earning formula नहीं मिला; पुराना formula केवल historical migration में है और नया migration उसे replace करता है।
- Source fix committed only; database migration applied नहीं, कोई runtime/CI test नहीं चला। Official GPT-2 checklist progress **27/39 = 69% complete; 12 remaining** अपरिवर्तित; Runtime Acceptance **60/60 Pending**।

### 3T. Razorpay Webhook upstream request timeout और header-case hardening — 17 Nov 2026

- Latest webhook source recheck में पाया गया कि inbox claim lease 2 मिनट का है, लेकिन razorpay-webhook.js के Supabase RPC, booking lookup/update, payment breakdown और refund reconciliation fetch calls पर कोई request timeout नहीं था। Network request अटकने पर Worker lease अवधि से अधिक समय तक processing में रह सकता था और lease expiry के बाद दूसरा Worker event reclaim कर सकता था।
- सीमित source fix: webhookFetch() wrapper जोड़ा गया, जो प्रत्येक upstream fetch पर AbortSignal.timeout(15000) लागू करता है। सभी 8 upstream call sites wrapper से गुजरते हैं। इससे प्रत्येक individual network request अधिकतम 15 सेकंड में abort होगी; यह कुल handler duration या वास्तविक दो-Worker concurrency का runtime प्रमाण नहीं है।
- tests/razorpay-webhook-inbox.test.js के mixed-case header test में यह assertion जोड़ा गया कि upstream RPC request में bounded timeout signal मौजूद हो। Test file में अभी 19 test cases हैं; Node tests execute नहीं किए गए।
- पहले से जोड़े गए case-insensitive Razorpay signature/event-ID header lookup की भी current source पर पुनः पुष्टि हुई।
- Commits: timeout wrapper source 5d6c27a8697be18d303bdb126f5f6dbebe9b0e12; test assertion b815d1d2a82d12f61fc5c365c3c9478a6a60d8b5.
- Current re-fetch: razorpay-webhook.js SHA 496df0a22b8e9e47be06a66dfb6fb934176a513c; test SHA a6767a68115ef7ecf73afa5b4b31d700278d18ac. Source count: one native fetch inside wrapper, eight wrapper call sites, one 15-second timeout configuration.
- Remaining limitation: multiple sequential requests can still extend total handler duration; 2-minute lease renewal/heartbeat is not implemented. Runtime overlap, provider retry timing and Vercel execution limits remain unverified. No heartbeat feature was added.
- No Node test execution, pgTAP, database operation, migration apply, CI dispatch, deployment, merge or production change. Official GPT-2 progress 27/39 = 69% complete; 12 remaining अपरिवर्तित; Runtime Acceptance 60/60 Pending।

### 3U. Aggregate earnings missing-payout evidence gap — current source recheck (17 Nov 2026)

- Re-fetched current Admin commission report migration SHA `e3eaa21836628c459e757461a5598aa51ea8b66c` and Electrician earnings migration SHA `f12d41362dcb230bfe606aa43e47ba6ee3f6c444`.
- Admin report correctly separates customer collection from payout-ledger totals and counts only matched payout rows, but does not expose an explicit missing/mismatched payout-row count or booking IDs.
- Electrician earnings now correctly sources commission and payable from the canonical payout ledger (therefore excludes SRK cancellation-fee carry-forward), but its LEFT JOIN + COALESCE still returns zero values when the payout row is absent. That is ambiguous with a legitimate zero and does not expose the existing per-booking reconciliation exception.
- Classification: **known source-level reporting-completeness gap**, not evidence that any live payout row is missing. It remains open for an owner-approved signal/contract decision; do not alter the Electrician UI or RPC return shape without coordination with GPT-1/owner.
- No code/SQL migration changed; no database, pgTAP, Node, CI, provider, deployment, merge or mobile QA executed. Official GPT-2 progress **27/39 = 69%** and Runtime Acceptance **60/60 Pending** remain unchanged.


### 3V. Missing payout exception surfaced in existing Admin reconciliation + contract strengthened — 17 Nov 2026

- Re-fetched current Main Admin per-booking reconciliation function and Admin UI. Existing RPC emits `MISSING_PAYOUT_ROW` only when booking is completed, payment evidence is verified, an electrician is assigned, and no payout row exists. Existing Admin panel already renders the exceptions array and explicitly says when the payout record is absent.
- Clarification: the aggregate commission card remains a summary and does not expose a global missing-payout count; the existing per-booking read-only reconciliation panel is the exception surface. No new UI or RPC response field was added.
- Strengthened `supabase/tests/database/accounting_reconciliation_readonly_contract.test.sql` with a source assertion for the missing-payout exception and its guards. Current declaration `plan(76)`; exact source has 76 `SELECT ok` calls. Test SHA `eebcc4523feba1e4af608c9b9b725f5c3f86d783`.
- Static source contract only; pgTAP/Node/runtime not run. No database, deployment, merge, CI or mobile QA. GPT-2 official checklist remains **27/39 = 69%**; Runtime Acceptance **60/60 Pending**.


### 3W. Razorpay webhook acknowledgement deadline — source-level integration gap (17 Nov 2026)

- Re-fetched `razorpay-webhook.js` SHA `496df0a22b8e9e47be06a66dfb6fb934176a513c`: after signature verification, the handler awaits the durable claim RPC, then performs payment/refund lookup and business reconciliation RPC(s), then awaits completion RPC before returning HTTP 200.
- Each upstream call has a 15-second AbortSignal timeout, and a refund event can require at least claim + refund-row lookup + reconciliation + completion. The bounded per-request timeout does not enforce the provider's webhook acknowledgement deadline for the whole handler.
- Razorpay's published webhook guidance says the receiver should respond within five seconds; non-2xx or late response is treated as delivery failure and may be retried. Therefore this synchronous processing shape can cause avoidable redeliveries even while the durable event inbox protects against duplicate business processing.
- Safe classification: **confirmed source-level acknowledgement-latency risk**, not evidence of a production timeout or duplicate financial action. Existing event-level claim fencing and business reconciliation remain safeguards.
- A proper fix requires a durable asynchronous worker/outbox or a provider-compatible fast-ack design that commits receipt before returning 2xx. Do not return 2xx before durable receipt; do not use unawaited background work without a durable execution guarantee. No queue/worker feature was added because it changes architecture and needs owner-approved scope.
- Refund create path rechecked against Razorpay API docs: `X-Refund-Idempotency` and stable `receipt` are sent with the same persisted refund key/body; the provider docs describe receipt as an idempotency key. Existing code treats network timeout as ambiguous and does not generate a new key.
- Source-only audit. No Node/pgTAP execution, provider calls, DB, CI, deployment, merge or mobile QA. GPT-2 official checklist remains 27/39 = 69%; Runtime Acceptance 60/60 Pending.


## 3X. 17 November 2026 — Webhook lease budget and Refund Recovery timeout audit

**Audited branch:** `chore/pr8-replay-audit-20261116-v2`  
**Pre-documentation HEAD:** `814c5a6728f5e9adba8d1259f76d78e83c048de3`

### Razorpay Webhook — verified source facts
- `razorpay-webhook.js` verifies the HMAC signature before claiming an event, then synchronously performs claim, event-specific reconciliation and completion before returning its HTTP response. There is no separate durable worker/queue handoff in this handler; do not describe it as fast-acknowledgement/background processing.
- The inbox migration grants a 2-minute claim lease and uses a fresh claim token as a fencing token. Completion accepts only the current token; stale completion is rejected.
- Each of the eight Supabase request call sites uses `webhookFetch` with a 15-second AbortSignal timeout. They are alternative branches, not eight requests on every execution.
- Source-path budget: ordinary refund processing has up to four sequential HTTP requests (claim, refund lookup, reconcile RPC, completion); the new-category payment path has up to five (claim, booking lookup, breakdown RPC, settlement RPC, completion); the legacy payment concurrency-recheck path can reach six. At 15 seconds per request, their nominal network timeout ceilings are 60, 75 and 90 seconds respectively, before local processing. Therefore the earlier broad suggestion that four 15-second requests alone exceed the 2-minute lease was incorrect. A 2-minute lease can still be exceeded by runtime/platform delays or other unbounded work; no heartbeat/lease extension exists. These are source calculations, not measured runtime timings.
- No provider webhook latency/SLA claim is made in this audit. No durable worker architecture was added or approved.

### Refund Recovery — verified source facts
- `razorpay-refund-recovery.js` has per-request timeouts: 10 seconds for Auth checks, 10 seconds for ordinary Supabase reads, and 15 seconds for RPC/provider requests.
- When the provider refund ID is not stored, the recovery handler can read up to ten pages of 100 refunds sequentially. Ten provider calls alone have a theoretical configured timeout budget of 150 seconds, before Auth, Supabase reads, evidence persistence and optional finalization. There is no overall handler deadline or cancellation budget in this source.
- Pagination is bounded and fail-closed: a full ten-page scan returns `provider_search_limit_reached` without saving evidence; malformed/duplicate page IDs also stop the search. Exact single-match checks precede evidence persistence.
- Evidence persistence and accounting finalization are separate HTTP/PostgREST requests and therefore separate database transactions. Only fresh (`<15 minutes`) provider evidence with status `processed` can finalize. Failed/pending evidence is recorded but does not finalize or release payout.
- This is a potential handler-duration/platform-timeout risk, not proof of a failed or duplicated refund. Runtime limits are not verified here.

### Verification boundary and status
- Source files and migration were re-fetched from the audited branch. No Node tests or pgTAP tests were executed.
- No database operation, migration apply/replay, CI dispatch, deployment, merge, provider refund, or production setting change occurred.
- Official GPT-2 checklist remains **27/39 = 69% (12 remaining)**; Runtime Acceptance remains **60/60 Pending**. This audit note does not complete an official checklist item.


## 3Y. 17 November 2026 — Main Admin payout settlement and accounting reconciliation recheck

**Audited branch:** `chore/pr8-replay-audit-20261116-v2`

- Re-fetched `supabase/migrations/20261114360000_new_category_electrician_payout_reconciliation.sql` and verified `srk_admin_mark_electrician_payout_paid`: authenticated Main Admin gate; UPI/Bank only; bounded UTR/UPI reference; booking row locked before payout row; only pending payout may transition to paid; completed + verified-paid booking required; new-category payout is recalculated from immutable labour bill and commission; booking assignment, labour-bill electrician, payout electrician and payout ledger amounts must agree; reserved cancellation-fee items block payout settlement; settled fees are included in collection parity but excluded from electrician payable.
- The payout lifecycle trigger creates/refreshes only pending rows and does not overwrite paid/blocked/refunded rows. Full refund closes pending or explicitly refund-owned blocked payout holds, preserving unrelated Admin blocks and already-paid payouts.
- Re-fetched `supabase/tests/database/electrician_payout_reconciliation.test.sql`: declared plan 55. Its source contains 55 `SELECT ok` assertions, including Main Admin settlement authorization, lock order, reference validation, immutable labour bill parity, fee separation and refund hold ownership. This is static test-source coverage only; pgTAP was not executed.
- Re-fetched `supabase/migrations/20261115170000_admin_route_transfer_accounting_reconciliation.sql`: Admin reconciliation explicitly treats the retired Razorpay Route ledger as retired and does not infer provider settlement. The manual Admin payout RPC remains the authoritative payout-paid record after actual transfer and UTR entry.
- No additional source defect was confirmed in this pass. This closes a source-audit subtask, but does not complete the full Payout/Accounting workstream: runtime/schema-chain verification remains pending, and the separate aggregate-report missing-payout visibility limitation remains documented in section 3X/related notes.

**Verification boundary:** source re-fetch only; no Node/pgTAP execution, DB operation, migration apply/replay, CI, deployment, merge or mobile QA.


## 3Z. 17 November 2026 — Serverless execution ceiling cross-check

- The repository contains `netlify.toml` with `functions = "netlify/functions"`, and `netlify/functions/razorpay-refund-recovery.js` is a wrapper around the root recovery handler. The configured redirects route `/api/razorpay-refund-recovery` to that Netlify Function. This establishes a Netlify deployment path in source, but does not by itself prove which provider currently serves Production.
- Current Netlify Functions documentation states a default synchronous execution limit of 60 seconds and a background execution limit of 15 minutes. See https://docs.netlify.com/build/functions/configuration/ .
- Comparing this platform limit with the source budgets recorded in section 3X: the unlinked Refund Recovery path can spend up to 150 seconds in provider page requests alone; the webhook source's longest inspected sequential request path has a nominal 90-second per-request-timeout budget. If these handlers are served as standard synchronous Netlify Functions, both source paths can exceed the documented 60-second ceiling before completion. This is a concrete conditional platform-timeout risk; it is not proof of a live Production timeout because the active hosting provider/site configuration and actual request timings have not been verified.
- Safe fix is not to raise arbitrary per-call timeouts or return success before durable work. Refund Recovery needs a bounded synchronous scan that stops before the platform ceiling while preserving its existing fail-closed/no-evidence behavior, or an explicitly approved durable background/recovery-job architecture. Webhook needs durable receipt/worker handoff or a verified bounded synchronous path; do not acknowledge 2xx before durable receipt. Background execution changes response/lifecycle behavior and is not added without owner approval.
- No code changed in this audit. No Node/pgTAP, DB, provider, CI, deployment, merge or mobile QA executed.


## 3AA. 17 November 2026 — Hosting evidence correction and timeout scope

- Correction to section 3Z: the repository's linked Vercel team/project was inspected read-only. The team is on Hobby; the linked Git repository is this project. A READY Vercel production deployment exists for `main` at commit `7f62b622e33e49b0196d0d93febf73049579c281`, and the project's latest deployment metadata was also read. Therefore, the earlier Netlify 60-second ceiling must **not** be presented as the confirmed limit for the live Vercel production site.
- The checked source tree has no root `api/` directory; the relevant handlers are under `netlify/functions/`, with `netlify.toml` routing to them. The Vercel deployment metadata does not establish that those Netlify functions are deployed or executed by Vercel. No Netlify account/site or active function deployment was available in this read-only check. Hosting of these payment handlers remains unverified and may be separate from the Vercel static/site deployment.
- Official Vercel documentation says Fluid Compute defaults to 300 seconds on Hobby, while non-Fluid Hobby defaults to 10 seconds and maximum 60 seconds. The linked Vercel project was created recently enough that Fluid Compute is normally enabled by default, but the effective per-function timeout and whether these handlers are part of that deployment were not verified with deployment function inspection. Do not apply either Vercel or Netlify limits to these handlers as fact until their actual host/function deployment is identified.
- Thus the 150-second Refund Recovery pagination budget and 90-second webhook request budget remain source-level upper-bound risks, but no confirmed 60-second production timeout finding is established. Do not add maxDuration, Netlify background mode, or a queue based on the earlier assumption. Next safe step is to identify the actual host/deployment for `netlify/functions/razorpay-refund-recovery.js` and `netlify/functions/razorpay-webhook.js`, then compare its effective function limit against bounded handler budgets.
- No source/runtime behavior changed. No Node/pgTAP tests, DB operations, provider calls, CI, deployment, merge, or mobile QA executed. Vercel inspection was read-only.



## 3AB. 17 November 2026 — Production Vercel deployment बनाम Payment Function hosting की read-only पुष्टि

- Vercel team के linked project `srk-electranic-` का Production deployment read किया: deployment ID `dpl_BaUb7Kpt2LZ1TgNv9TE4J7Pq4bkq`, state READY, target production, branch `main`, commit `7f62b622e33e49b0196d0d93febf73049579c281`. यह Vercel पर साइट का Production deployment प्रमाणित करता है।
- उसी Production commit की Git tree में `netlify.toml`, `netlify/functions/` और Razorpay webhook wrapper मौजूद हैं; root `api/` directory नहीं मिली। `vercel.json` में केवल version/cleanUrls/trailingSlash हैं, कोई Vercel function route/runtime/maxDuration declaration नहीं है।
- `netlify.toml` स्पष्ट रूप से `functions = "netlify/functions"` सेट करता है और `/api/razorpay-webhook` को `/.netlify/functions/razorpay-webhook` पर redirect करता है। Feature branch पर Refund Recovery wrapper भी इसी Netlify functions directory में है; Production `main` commit में वह wrapper नहीं है।
- Vercel deployment API का `type=LAMBDAS` अकेले यह प्रमाणित नहीं करता कि Netlify wrappers Vercel पर build/run हुए; deployment file-tree endpoint ने इस Git deployment के लिए 404 दिया। अतः Vercel Production site की मौजूदगी सिद्ध है, लेकिन Razorpay webhook का live host अभी भी Netlify site/deployment record या वास्तविक configured webhook URL से ही पुष्टि होगा। Refund Recovery के लिए अलग से यह भी पुष्टि चाहिए कि feature branch का wrapper किसी active host पर deploy है या नहीं।
- निष्कर्ष: Netlify Functions के synchronous 60-second ceiling को live payment path पर लागू तथ्य न मानें; Vercel की Hobby limits भी इन handlers पर लागू तथ्य नहीं हैं, जब तक यह सिद्ध न हो कि वे Vercel Function के रूप में deploy हुए हैं। अभी दोनों handler paths के लिए platform ceiling unverified है।
- अगला सुरक्षित कदम: Netlify site/deployment का read-only evidence या Razorpay Dashboard में configured webhook endpoint domain प्राप्त करना; secrets/tokens माँगे या expose किए बिना। उसके बाद ही platform timeout बनाम source request budgets तय करें।
- कोई source/runtime behavior नहीं बदला। कोई Netlify/Vercel setting, function, deployment, webhook endpoint, DB, provider, CI, merge या mobile QA नहीं बदला/चलाया गया।


## 3AC. 17 November 2026 — Netlify deployment gate और live host evidence का repository audit

- Feature branch README.md स्पष्ट रूप से वर्तमान deployment target Netlify बताता है और Razorpay webhook, refund executor, refund status तथा refund recovery को Netlify Functions के रूप में सूचीबद्ध करता है।
- netlify.toml में functions = netlify/functions और /api/razorpay-webhook, /api/razorpay-refund, /api/razorpay-refund-status, /api/razorpay-refund-recovery के Netlify Function redirects मौजूद हैं।
- NETLIFY_PIPELINE_SETUP_HI.md कहता है कि pipeline patch स्वयं live deploy नहीं करता। ADMIN_SETUP_HINDI.md में स्पष्ट निर्देश है कि Production publishing स्थगित रखें; केवल Dashboard deploy status देखें और audit, migration reconciliation, testing तथा owner की स्पष्ट अनुमति से पहले resume/upgrade/deploy न करें।
- इसलिए repo evidence Netlify को intended deployment platform सिद्ध करता है, लेकिन live Netlify Site/Deploy record या Razorpay Dashboard endpoint URL उपलब्ध न होने से वर्तमान webhook host और Refund Recovery deployment status की पुष्टि अभी नहीं हुई। Vercel का READY Production site अलग तथ्य है; उससे Netlify functions के live होने का निष्कर्ष नहीं निकाला जा सकता।
- इस चैट में कोई Netlify connector/authorized Netlify deployment read tool उपलब्ध नहीं मिला। अगली पुष्टि owner-controlled Netlify Dashboard के Deploys view अथवा Razorpay Dashboard में configured webhook URL के domain से होगी; secret values की जरूरत नहीं। जब तक पुष्टि न हो, platform timeout limits को handlers पर लागू मानकर code change नहीं करेंगे।
- कोई Netlify/Vercel deploy pause/resume, upgrade, environment change, webhook edit, source handler change, DB operation, CI/runtime test या mobile QA नहीं किया गया। Owner approval gate यथावत है।


## 3AD. 17 November 2026 — Refund Recovery ambiguous evidence-write outcome fail-closed fix

- Re-audit में मिला कि evidence RPC request dispatch होने के बाद network/timeout error आने पर outer catch `evidence_saved:false` देता था, जबकि database transaction commit हो चुकी हो सकती है। यह caller को evidence absence का गलत संकेत दे सकता था।
- `razorpay-refund-recovery.js` में evidence RPC शुरू होने से पहले stage flag false रहता है; RPC dispatch से ठीक पहले true होता है। उसके बाद exception या invalid/missing audit ID response पर Handler HTTP 202, `evidence_saved:"unknown"`, `accounting_finalized:false`, `safe_to_retry:false`, status `evidence_write_outcome_unknown` देता है। यह नया refund बनाने/अंधाधुंध retry करने से रोकता है और audit record की जाँच माँगता है।
- Valid audit UUID मिलने पर existing flow unchanged: pending/failed evidence finalization नहीं करता; processed evidence को अलग RPC transaction में finalize करता है; finalization failure में वही audit ID लौटाता है।
- नया Node test source `tests/razorpay-refund-recovery.test.js` में ambiguous evidence RPC response case जोड़ता है; test source मौजूद है, लेकिन इस चरण में Node/CI test execute नहीं किया गया।
- Source blob SHA `46e2a349cc03b0b613705ded0b2658ff5c6b57f4`; test blob SHA `5fa1cd40c6b7f6f6e14f2d1bac970856d08bce42`; latest branch commit `47389fffa43b104cbd33880a2477d633409d4509` पर दोनों files re-fetch करके सत्यापित।
- यह fix ambiguous evidence write की reporting सुधारता है; पूरे Handler की overall deadline अभी implement नहीं हुई। Hosting/runtime ceiling अभी live deployment evidence से verify नहीं है। कोई DB, provider, deploy, CI, merge या mobile QA नहीं किया गया।


## 3AE. 17 November 2026 — Refund Recovery evidence retry idempotency

- 3AD के ambiguous evidence-write safeguard के बाद अगली जाँच में मिला कि हर Handler invocation नया random `observation_id` बनाता था। यदि पहली evidence transaction commit हो जाए लेकिन response खो जाए, तो बाद की manual retry नया audit observation बना सकती थी।
- `razorpay-refund-recovery.js` अब `refund_record_id + provider_payload_sha256` से SHA-256 आधारित deterministic UUIDv5-format observation ID बनाता है। समान internal refund और समान provider payload पर retry वही observation ID भेजेगी; migration `20261115120000_durable_razorpay_refund_recovery_evidence.sql` का `ON CONFLICT (observation_id) DO NOTHING` और matching-row lookup उसी audit ID को वापस दे सकता है। बदले हुए provider payload/status पर नया hash और नया observation ID बनेगा, जिससे नई timestamped observation सुरक्षित रह सकती है।
- नया Node regression test पहले evidence RPC का response खोने और फिर उसी provider payload पर retry करने का simulated case जोड़ता है; दोनों attempts में observation ID समान होने की assertion मौजूद है। Test source लिखा गया है, execute नहीं किया गया।
- Source blob SHA `4391163b402d0032ff96acbbddbde7bd607bdbba`; test blob SHA `8770541b2bbd4eed01e8da75c6e6ddd103857e72`; इस inventory edit से पहले source/test commits `68209278712fe3177258e473cc903db8ee44aba2` और `00a85538bca81017ef3a4a2f548554655ef7d0ce`।
- Overall Handler deadline अभी लागू नहीं हुई; Netlify runtime ceiling/live deploy status अभी सत्यापित नहीं है। कोई DB, deploy, CI, merge या mobile QA नहीं किया गया।


## 3AF. 17 November 2026 — Refund Recovery bounded synchronous handler deadline

- Official Netlify Functions documentation currently lists a 60-second synchronous execution limit (configuration docs); this is platform documentation only, not proof of the user's live Site plan/deployment/configuration. Repository `netlify/functions/razorpay-refund-recovery.js` is a thin wrapper importing root `razorpay-refund-recovery.js`; `netlify.toml` routes `/api/razorpay-refund-recovery` to it. Live Deploy and runtime setting remain unverified.
- Root Handler now sets a 52,000 ms total request budget, leaving 8 seconds below the documented 60-second synchronous ceiling. All outbound auth, admin RPC, internal DB GET, Razorpay provider GET/pagination, evidence RPC, and finalization RPC use a per-request AbortSignal bounded by remaining overall time.
- Before each pre-evidence request, 32,000 ms is reserved for evidence save + accounting finalization. Evidence RPC is allowed up to 15 seconds while reserving 17,000 ms for the separate finalization request and a small return margin; finalization is capped at 15 seconds. If discovery reaches its reserve boundary before evidence dispatch, Handler returns HTTP 202 `deadline_before_evidence`, `evidence_saved:false`, `accounting_finalized:false`, `safe_to_retry:false`; no evidence or accounting write is started. If evidence RPC dispatch begins but response is ambiguous, existing 3AD behavior reports evidence outcome unknown; deterministic observation ID from 3AE makes same-payload retry idempotent.
- New Node regression test simulates the time budget being consumed during provider pagination and asserts stop before page 2, evidence RPC, or finalization RPC. Test source is present but has NOT been executed. No CI/DB/runtime/production/mobile test was run.
- Root source blob SHA `a3d14c8d1ccd1835b4598ed51838855c7347c815`; test blob SHA `1f989fd180847a3acc3e5b04ebb1a16c67d4e148`; latest verified source/test/docs still require final re-fetch after this inventory update. No deploy, environment change, schema change, merge, or production action.


## 3AG. 17 November 2026 — Deadline initialization and preflight budget correction

- Follow-up static review of 3AF caught a critical omission: request helpers accepted `deadlineAt`, but the Handler had not initialized it. This is now corrected at the very start of `exports.handler` with `Date.now() + HANDLER_BUDGET_MS`; without this, the deadline helper would fail before completing the request.
- Pre-evidence authentication and two internal read calls are capped at 5 seconds each (rather than 10 seconds) while preserving the 32-second evidence/finalization reserve. Razorpay provider requests remain capped at 15 seconds but are also bounded by the same remaining budget. Evidence save keeps a 17-second reserve for finalization; the finalization RPC is capped at 15 seconds.
- Latest root source blob SHA `deeb64d5ac6338b0d4a380604ba80e29d137f82f`. This corrects the earlier 3AF source statement; it does not mean tests were executed. The regression test is still source-only; no Node test, CI, DB, live runtime, deployment, production, or mobile QA was run.
