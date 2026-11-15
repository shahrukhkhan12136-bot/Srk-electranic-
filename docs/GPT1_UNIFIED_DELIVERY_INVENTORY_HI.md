# GPT-1 Unified System Inventory — SRK ELECTRONIC

**Inventory checked:** 15 November 2026  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**PR:** #8 — Open, Draft, unmerged  
**Feature branch:** `feat/customer-login-first-dashboard-20261114`  
**Inspected PR head:** `f8b7bcfcb6caaeac804a14a8193341ee89d84367`

## 1. उद्देश्य और नियम

यह GPT-1 (Customer App, Electrician App, पहले से पूरा Welcome Screen/founder-photo integration) का एक consolidated index है। उद्देश्य है कि हर बार अलग-अलग code, API, Edge/Netlify function, migration और test files फिर से न खोजनी पड़ें।

यह **source inventory** है; इससे feature का live runtime, Production parity, deployment या mobile QA सिद्ध नहीं होता। कोई नया feature/scope नहीं जोड़ा गया। Welcome Screen/founder-photo को पूर्ण माना गया है और इस audit में उसे दोबारा नहीं खोला जाएगा।

GPT-2 के Admin/Support Staff, Main Supabase Database, Payments/Refunds/Payouts, Commission/Accounting और Security/Permissions की ownership GPT-2 के पास रहेगी। इस दस्तावेज़ में उन dependencies का केवल cross-reference है; GPT-2 के code/schema में बिना समन्वय बदलाव नहीं करना है।

## 2. Repository-wide inventory snapshot

Recursive Git tree (inspected PR head) में 212 tracked files मिले; tree truncated नहीं था।

| Asset | मौजूद |
|---|---:|
| Supabase SQL migrations | 78 |
| Supabase database contract / pgTAP SQL tests | 32 |
| Node regression test files | 33 |
| GitHub Actions workflows | 3 |
| Supabase Edge Function source directories/files | 3 |
| Netlify Functions | 10 |

पूरे repository की migration filenames, SQL tests और Node tests की complete list GPT-2 index `docs/GPT2_UNIFIED_DELIVERY_INVENTORY_HI.md` के repository snapshot में दर्ज है। Migration dependency/replay context: `docs/MIGRATION_REPLAY_MANIFEST_HI.md`, `docs/MIGRATION_DEPENDENCY_INVENTORY_HI.md`, `docs/MIGRATION_DEPENDENCY_MATRIX_HI.md`। ये GPT-2-owned database source को बदलने की अनुमति नहीं देते।

## 3. GPT-1 source entry points — जो अभी repository में मौजूद हैं

### Customer App
- `booking.html` — OTP login/session gating, five-menu dashboard, booking, payments, support, profile UI.
- `customer-login.html` — Customer login entry page.
- `create-booking.js` and `netlify/functions/create-booking.js` — server-side booking request path / validation.
- `index.html` — root routing only; Welcome Screen is complete, do not reopen it.
- `sw.js`, `manifest.webmanifest` — shared PWA/service-worker layer.

### Electrician App
- `electrician.html` — OTP/session, offers, availability, booking workflow, timer, live location, KYC/support/profile UI.
- `apply-electrician.js` and `netlify/functions/apply-electrician.js` — electrician application path.
- `netlify/functions/expire-booking-offers.js` — scheduled offer expiry/advancement worker.
- `supabase/functions/electrician-phone-change/index.ts` — phone-change OTP/admin-approval backend (shared Admin approval dependency).
- `supabase/functions/push-job-offer/index.ts` — server-side offer push sender (shared infrastructure; GPT-2 owns backend/security parts).

### Shared interface / already-complete area
- `welcome.html`, `assets/srk-founder.jpg`, `index.html` — Welcome/founder-photo integration. Complete; do not change in this work.
- `netlify.toml`, `sw.js`, `manifest.webmanifest` — shared routing/PWA assets; touch only if a verified existing-scope defect requires it.

## 4. Customer feature → migration/source contract map

| Existing Customer workflow | Relevant source/migration(s) present | Existing test assets / verification boundary |
|---|---|---|
| OTP login, session restore, five-menu dashboard | `booking.html`, `customer-login.html` | `tests/customer-electrician-otp-login.test.js`, `tests/customer-five-menu-source.test.js`, `tests/customer-dashboard-menu-contract.test.js`; source tests only, not real SMS/Auth runtime |
| Booking submission, selected category/rate tier/duration, server estimate, idempotency | `create-booking.js`, `netlify/functions/create-booking.js`; `20261114150000_customer_booking_submission_idempotency.sql`, `20261114160000_customer_selected_rate_tier_and_server_estimate.sql` | `tests/customer-immediate-booking-contract.test.js`, `tests/booking-lifecycle-serialization.test.js`; DB dependency/replay still separate |
| Customer profile, avatar, saved addresses | `booking.html`; `20261114180000_harden_customer_avatar_object_integrity.sql`, `20261114201428_customer_profile_saved_addresses_private_storage.sql` | `tests/customer-profile-address-navigation.test.js`; `supabase/tests/database/customer_avatar_object_integrity.test.sql`, `customer_profile_saved_addresses_private_storage.test.sql` |
| Payment history, receipt, payment-method change | `booking.html`; `20261114190000_customer_receipt_immutable_labour_amount.sql`, `20261114200000_customer_payment_refund_history_rpc.sql`, `20261114202656_customer_change_payment_method_rpc.sql`, `20261115270000_fix_customer_payment_method_unicode_contract.sql` | `tests/customer-payment-method-enforcement.test.js`, `tests/customer-payment-receipt-itemization.test.js`; DB tests `customer_receipt_immutable_labour_amount.test.sql`, `customer_payment_refund_history_rpc.test.sql`, `customer_change_payment_method_rpc.test.sql`. **Known mismatch:** payment-method pgTAP test still asserts old mojibake literal while corrective migration uses proper UTF-8 `Razorpay ऑनलाइन भुगतान`; GPT-2 migration/test owner must coordinate the correction. |
| Customer support conversations, attachments, complaint projection | `booking.html`; `20261110040000_customer_admin_complaints.sql`, `20261113220000_customer_support_conversation_schema.sql`, `20261113230000_support_attachment_paths_and_admin_message_list.sql`, `20261114202250_customer_complaint_customer_safe_projection.sql`, `20261114300000_admin_customer_support_thread_replies.sql` | `tests/customer-electrician-support-contract.test.js`; DB tests `customer_complaint_customer_safe_projection.test.sql`, `support_attachment_admin_message_access.test.sql`. Support/RBAC child dependencies belong to GPT-2. |
| Refund request/history and cancellation fee lifecycle | `booking.html`; `20261114270000_admin_only_cancellation_requests_and_decisions.sql`, `20261114280000_cancellation_fee_carry_forward_and_accounting.sql`, `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`, `20261115100000_customer_refund_request_contract.sql` | `tests/customer-refund-ui-lifecycle.test.js`; DB tests `customer_refund_request_contract.test.sql`, `customer_refund_admin_approval_gate.test.sql`, `cancellation_fee_refund_reversal.test.sql`. Admin decisions, ledger and payment dependencies are GPT-2-owned. |
| Contact visibility before/after assignment | `booking.html`, `electrician.html`; `20261109103038_customer_electrician_direct_call_contacts.sql`, `20261109103143_move_customer_call_contact_lookup_to_private.sql` | `tests/accepted-contact-visibility.test.js`, `tests/customer-electrician-phone-visibility.test.js`; role/ACL runtime still pending |

## 5. Electrician feature → migration/source contract map

| Existing Electrician workflow | Relevant source/migration(s) present | Existing test assets / verification boundary |
|---|---|---|
| OTP login/session gating, offer inbox/response | `electrician.html`; booking/identity and offer migrations including `20261109000500_harden_electrician_profile_identity_linking.sql`, `20261114130000_harden_electrician_profile_identity_linking.sql`, `20261114210000_sequential_nearest_offer_dispatch.sql`, `20261114230000_recheck_electrician_current_area_before_offer.sql`, `20261114370000_electrician_offer_details_immediate_booking_fields.sql` | `tests/customer-electrician-otp-login.test.js`, `tests/booking-lifecycle-serialization.test.js`, `tests/electrician-legacy-quotation-retirement.test.js`; no complete actor/race DB runtime matrix yet |
| Availability and relocation | `electrician.html`; `20261114220000_admin_approved_electrician_relocation.sql`, `20261114310000_electrician_self_availability.sql` | Source call/signature inspected; dedicated availability pgTAP security test not found in current 32 SQL test files |
| Server-authoritative timer, completion approval, immutable labour bill | `booking.html`, `electrician.html`; `20261114190000_customer_receipt_immutable_labour_amount.sql`, `20261114240000_server_authoritative_customer_approved_work_timer.sql`, `20261114250000_admin_work_dispute_review_and_immutable_history.sql`, `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql` | `supabase/tests/database/server_authoritative_work_timer.test.sql`, `customer_booking_work_timeline.test.sql`, `admin_work_dispute_review.test.sql`; Node source contracts include booking lifecycle |
| Booking-scoped live location and failure cleanup | `electrician.html`; `20261114320000_booking_scoped_live_electrician_location.sql` | `tests/electrician-live-location-client.test.js`; dedicated DB RPC/ownership/security test not found |
| KYC upload/preview and activation gate | `electrician.html`, `apply-electrician.js`, `netlify/functions/apply-electrician.js`; `20261114330000_electrician_private_kyc_document_preview.sql`, `20261115140000_electrician_kyc_review_and_activation_gate.sql` | `tests/electrician-accounting-kyc-contract.test.js`, `supabase/tests/database/electrician_kyc_review_and_activation_gate.test.sql`; Storage/Auth runtime still pending |
| Support tickets/messages | `electrician.html`; `20261114350000_electrician_support_tickets_and_admin_inbox.sql` | `tests/customer-electrician-support-contract.test.js`, `supabase/tests/database/electrician_support_ticket_security.test.sql`; Admin inbox integration is GPT-2 dependency |
| Profile name edit and phone change | `electrician.html`, `supabase/functions/electrician-phone-change/index.ts`; `20261114340000_electrician_self_profile_name_edit.sql`, `20261114380000_electrician_phone_change_admin_approval.sql` | Source signature comparison found all 9 phone-change RPC calls match migration definitions; no dedicated OTP/Admin-approval pgTAP flow test found |
| Push notification opt-in and offer navigation | `electrician.html`, `sw.js`, `supabase/functions/push-job-offer/index.ts`, `netlify/functions/deliver-push-outbox.js`; push subscription/outbox/ledger migrations | `tests/electrician-live-location-client.test.js`, `tests/push-job-offer-sender.test.js`, `tests/push-delivery-outbox.test.js`, `tests/push-subscription-delivery-ledger.test.js`; provider/managed runtime remains shared GPT-2 dependency |

## 6. All current test entry points

- Node suite: `npm test` → `node --test tests/*.test.js` (33 files in inspected tree).
- Customer-focused Node tests: `customer-electrician-otp-login`, `customer-five-menu-source`, `customer-dashboard-menu-contract`, `customer-immediate-booking-contract`, `customer-payment-method-enforcement`, `customer-payment-receipt-itemization`, `customer-profile-address-navigation`, `customer-refund-ui-lifecycle`, `customer-electrician-support-contract`, `customer-electrician-phone-visibility`, `accepted-contact-visibility`, `booking-lifecycle-serialization`.
- Electrician-focused Node tests: `electrician-live-location-client`, `electrician-accounting-kyc-contract`, `electrician-legacy-quotation-retirement`, plus shared OTP/contact/booking/push tests above.
- SQL/pgTAP coverage currently present: `customer_avatar_object_integrity`, `customer_booking_work_timeline`, `customer_change_payment_method_rpc`, `customer_complaint_customer_safe_projection`, `customer_payment_refund_history_rpc`, `customer_profile_saved_addresses_private_storage`, `customer_receipt_immutable_labour_amount`, `customer_refund_admin_approval_gate`, `customer_refund_request_contract`, `electrician_kyc_review_and_activation_gate`, `electrician_profile_identity_linking`, `electrician_support_ticket_security`, `sequential_nearest_offer_dispatch`, `server_authoritative_work_timer`, `support_attachment_admin_message_access`.
- Coverage gaps identified from filename/source scan: standalone DB security tests for electrician availability RPC, booking-scoped live-location RPCs, and phone-change OTP/Admin approval lifecycle were not found. This is a coverage gap, not proof of a runtime defect.

## 7. Known integration/replay gates — do not silently bypass

1. Current PR is Draft and source-only; do not merge, deploy, or apply migrations to Production.
2. Historical baseline DDL is still unresolved for `public.service_bookings.amount_paid` and `public.electrician_profiles.auth_user_id`. Never guess types/defaults/nullability/FKs/indexes.
3. Complaint base schema and push subscription base schema were historically recovered into current branch, but remote applied-history still requires independent evidence.
4. Legacy migration filenames include two 8-digit `20261109` prefixes; duplicate remote lineage/application history must be reconciled before any replay plan.
5. `docs/MIGRATION_REPLAY_MANIFEST_HI.md` and dependency docs are static inventories, not proof of a valid PostgreSQL clean replay.
6. The existing Supabase schema CI is not a full replay harness for this branch; Node CI does not execute pgTAP.
7. No standalone DB tests were found for availability, live-location RPC security, and phone-change approval. Do not mark these flows runtime-verified.
8. Customer payment-method pgTAP source mismatch noted above must be handed to GPT-2 owner; GPT-1 must not silently edit GPT-2-owned SQL test/migration.
9. All manual mobile-device checks remain deferred until every implementation task is complete; then do one consolidated sequential mobile QA pass.
10. Do not create a paid Supabase development branch now. Consider staging only after all implementation is finished and consolidated end-to-end testing is next, with cost disclosure and explicit approval.

## 8. Current work order — inventory-first, no repeated searching

1. Use this document as the GPT-1 entry index; use GPT-2 unified inventory for GPT-2-owned assets.
2. Before editing a feature, follow its row above to the UI/client → API/Edge/Netlify → migration → SQL contract test → Node test.
3. Mark each contract as **present / missing / mismatch / runtime unverified**; presence is not a pass.
4. Resolve missing source/test contracts with the owning GPT before editing shared or GPT-2-owned code.
5. Once inventory reconciliation is complete, continue only already-approved unfinished implementation work. Do not reopen Welcome Screen.
6. Keep all device/mobile QA for the final consolidated QA stage.

## 9. Safety / changes made during this inventory

- This commit adds only this index document.
- No application source, migration, database, Storage bucket, Auth setting, Production configuration, payment, refund, payout, provider, or deployment was changed or invoked.
- No checklist progress percentage is changed by inventory consolidation.
