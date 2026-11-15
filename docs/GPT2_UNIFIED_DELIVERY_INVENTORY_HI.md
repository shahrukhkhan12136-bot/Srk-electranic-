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
| Commission and wallet | Service/labour-only commission rules, wallet ledger foundation, owner-scoped access; no unverified Route settlement represented as received | Source and contracts exist; amount_paid/auth_user_id base DDL blockers affect clean replay |
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

## 5. Repository inventory snapshot
At inventory head `c43c20325a5da6352ec7b1e8880f6e620788646f`:
- SQL migrations: **78**
- Supabase database contract files: **32**
- Node test files: **33**
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
- `tests/admin-commission-report-labels.test.js`
- `tests/admin-refund-and-staff-access.test.js`
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

## 6. CI and test status — verified 15 November 2026
### Node CI
- Workflow: `.github/workflows/node-tests.yml`
- Triggers on push to this Feature Branch, pull requests targeting `main`, and manual dispatch.
- Uses GitHub-hosted Ubuntu, Node.js 22, `npm install --ignore-scripts --no-audit --no-fund`, then `npm test`.
- No secrets, DB writes, provider calls or deployment in this job.
- Latest verified PR head: `b709322d39bea1051c2111cc01191709f1a04773`.
- Node run **43743960808** on that head succeeded; log explicitly shows **187 tests, 187 pass, 0 fail, 0 skipped**. The immediately preceding run **43743783902** also passed 187/187 on the code-change head containing the UTF-8 pgTAP correction.
- Commit `13afb4d92e22673b50c5eee1751f66621fdf194f` corrected the customer payment-method pgTAP assertion from mojibake to the exact UTF-8 literal `Razorpay ऑनलाइन भुगतान`; the latest Node run includes this source correction.
- This proves Node regression suite only, not SQL migration replay, PostgreSQL/pgTAP, browser/mobile, Vercel Preview or Production parity.

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
1. **Base DDL evidence:** authoritative definitions remain unresolved for `public.service_bookings.amount_paid` and `public.electrician_profiles.auth_user_id`. Do not guess SQL types, nullability, defaults, FK/index/unique/grants.
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
- The latest Node CI run `43743783902` passed 187/187 after the correction. This does **not** execute pgTAP; the PostgreSQL runtime assertion remains unverified.
- GPT-1's new inventory separately records missing dedicated DB tests for electrician availability, booking-scoped live-location RPCs, and phone-change approval. These are GPT-1-owned workflows; no such files were changed here. Its payment-test mismatch note predates the GPT-2 correction and should be treated as stale until GPT-1 refreshes its own inventory.

## 8. No-go boundaries
No Production schema/history queries or migrations, no secrets, no provider refunds/transfers/payouts, no real SMS/OTP/push sends, no paid staging subscription, no PR merge, no deployment/go-live without separate explicit approval. Do not overwrite GPT-1 shared files.

## 9. Work order after inventory
1. Keep this document as the single inventory index and update it when a source/test/workflow is added or materially changed.
2. Resolve original base-column DDL from historical source/deployment artifact or approved schema-only export.
3. Repair the Supabase CI workflow so an isolated full migration replay can run on the Feature Branch only after prerequisites are authoritative.
4. Build a feature-to-migration-to-pgTAP-to-Node-test-to-UI-RPC matrix and close missing contracts.
5. Execute isolated DB and Admin/Support browser actor matrix.
6. Only then update checklist percentages for actually closed items.

## 10. Current outcome
The GPT-2 feature set is not empty or waiting for discovery: the source already contains broad Admin/Support, payment/refund, accounting, payout, security, push and SOS implementations. The repository now has a single inventory of every migration, DB contract file, Node test file and CI workflow. The remaining work is to verify gaps, complete the test harness and resolve authoritative schema dependencies—not to repeatedly rediscover the same files.
