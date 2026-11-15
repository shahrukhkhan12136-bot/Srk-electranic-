# GPT-1 Unified System Inventory — SRK ELECTRONIC

**Inventory checked:** 15 November 2026  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**PR:** #8 — Open, Draft, unmerged  
**Feature branch:** `feat/customer-login-first-dashboard-20261114`  
**Inspected PR head (refreshed):** `eed50b086218ed6dfa095102150651992933de87`

## 1. उद्देश्य और नियम

यह GPT-1 (Customer App, Electrician App, पहले से पूरा Welcome Screen/founder-photo integration) का एक consolidated index है। उद्देश्य है कि हर बार अलग-अलग code, API, Edge/Netlify function, migration और test files फिर से न खोजनी पड़ें।

यह **source inventory** है; इससे feature का live runtime, Production parity, deployment या mobile QA सिद्ध नहीं होता। कोई नया feature/scope नहीं जोड़ा गया। Welcome Screen/founder-photo को पूर्ण माना गया है और इस audit में उसे दोबारा नहीं खोला जाएगा।

GPT-2 के Admin/Support Staff, Main Supabase Database, Payments/Refunds/Payouts, Commission/Accounting और Security/Permissions की ownership GPT-2 के पास रहेगी। इस दस्तावेज़ में उन dependencies का केवल cross-reference है; GPT-2 के code/schema में बिना समन्वय बदलाव नहीं करना है।

## 2. Repository-wide inventory snapshot

Recursive Git tree (refreshed PR head) में 213 tracked files मिले; tree truncated नहीं था।

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
| Payment history, receipt, payment-method change | `booking.html`; `20261114190000_customer_receipt_immutable_labour_amount.sql`, `20261114200000_customer_payment_refund_history_rpc.sql`, `20261114202656_customer_change_payment_method_rpc.sql`, `20261115270000_fix_customer_payment_method_unicode_contract.sql` | `tests/customer-payment-method-enforcement.test.js`, `tests/customer-payment-receipt-itemization.test.js`; DB tests `customer_receipt_immutable_labour_amount.test.sql`, `customer_payment_refund_history_rpc.test.sql`, `customer_change_payment_method_rpc.test.sql`. **Previously found mismatch — now corrected in shared branch:** the pgTAP assertion now checks the canonical UTF-8 literal `razorpay ऑनलाइन भुगतान`, matching the corrective migration. Verified directly in the latest inspected branch head. This closes the source-text mismatch only; actual pgTAP execution is still unverified. |
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

## 7. Cross-GPT shared dependencies and coordination gates

| Shared system | GPT-1 dependency | GPT-2 owner responsibility | Current boundary |
|---|---|---|---|
| Main Supabase baseline / identity | Customer and Electrician RPCs require booking/customer/electrician ownership columns | Historical DDL, roles, grants, RLS, schema parity | `service_bookings.amount_paid` and `electrician_profiles.auth_user_id` authoritative DDL remain unresolved in baseline audit; do not guess |
| Booking and offer lifecycle | Customer booking creation/history and Electrician offer/accept/respond | Core booking state, offer dispatch, locking, triggers, DB privileges | Migrations and source are present; full replay and actor/race runtime not proven |
| Payment / receipts / refunds | Customer payment choice/history/receipt/refund request; Electrician earnings view | Provider verification, payment/refund ledgers, refund approvals/recovery, payout/accounting | Client-to-RPC source mapped; DB/provider runtime remains separate |
| Customer/Electrician support | Customer complaint messages/attachments; Electrician tickets/replies | Admin inbox, staff assignment, role scopes, audit and attachment access | Child schemas/RPCs present; end-to-end role/storage test pending |
| KYC and activation | Electrician upload/list/preview and account activation state | Private bucket policies, Admin review/audit, activation permissions | Source and SQL contract files present; storage/Auth runtime pending |
| Push delivery | Electrician opt-in, worker registration and click-to-offer UI | Outbox, delivery ledger, sender security, retry/health and provider credentials | Shared code/test assets present; managed/provider delivery integration pending |
| Phone-change approval | Electrician request/OTP UI and Edge Function calls | Admin approval/rejection and protected RPC authorization | Nine Edge Function RPC signatures matched to migration; dedicated full lifecycle DB test absent |

## 8. Known integration/replay gates — do not silently bypass

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

## 9. Current work order — inventory-first, no repeated searching

1. Use this document as the GPT-1 entry index; use GPT-2 unified inventory for GPT-2-owned assets.
2. Before editing a feature, follow its row above to the UI/client → API/Edge/Netlify → migration → SQL contract test → Node test.
3. Mark each contract as **present / missing / mismatch / runtime unverified**; presence is not a pass.
4. Resolve missing source/test contracts with the owning GPT before editing shared or GPT-2-owned code.
5. Once inventory reconciliation is complete, continue only already-approved unfinished implementation work. Do not reopen Welcome Screen.
6. Keep all device/mobile QA for the final consolidated QA stage.

## 10. Safety / changes made during this inventory

- This inventory refresh updates the PR-head snapshot and cross-GPT dependency references; no application source or database code was changed.
- No application source, migration, database, Storage bucket, Auth setting, Production configuration, payment, refund, payout, provider, or deployment was changed or invoked.
- No checklist progress percentage is changed by inventory consolidation.


## 11. नवीनतम verification snapshot — 15 नवम्बर 2026, commit 1a96cd48cae9a5765c7465385da331fccc6aeaff

- Shared Master Index commit `1a96cd48cae9a5765c7465385da331fccc6aeaff` पर GitHub Actions run `43744201207` — **Feature Branch Node tests: completed / success**। यह Node regression suite का परिणाम है; इससे pgTAP, clean migration replay, provider runtime, browser/mobile QA या Production parity सिद्ध नहीं होती।
- उसी commit का combined status एक Vercel check में **failure** दिखाता है; target URL पर Vercel build-rate-limit / upgrade-to-Pro संकेत है। इसे application test failure नहीं कहेंगे, लेकिन Preview build उपलब्ध/सफल भी नहीं मानेंगे।
- इस snapshot में कोई PostgreSQL/pgTAP runtime result नहीं मिला। अतः Customer payment/refund/cancellation और Electrician KYC/Storage/OTP/dispatch/timer/location/availability runtime gates अभी खुले हैं।
- GPT-1 के source inventory में कोई नया missing primary source file नहीं मिला। पहचाने गए gaps मुख्यतः runtime evidence और dedicated SQL security coverage के हैं: availability RPC, booking-scoped live-location RPCs, और phone-change OTP/Admin approval lifecycle।
- Customer/Electrician UI के visible buttons/actions तथा README/API copy का one-by-one source-to-contract reconciliation अभी शेष है; इसे केवल Node suite success से पूरा नहीं मानना है।
- SOS UI दोनों portals में मौजूद है, लेकिन `srk_create_sos_alert` backend authorization, Admin/Support queue, notification/acknowledgement और append-only audit GPT-2 ownership में हैं; GPT-1 केवल contract integration के लिए GPT-2 confirmation की प्रतीक्षा करेगा।
- Welcome Screen/founder-photo integration को owner instruction के अनुसार **complete** माना गया है; पुराने checklist के विरोधी pending text को इस inventory में काम का नया scope नहीं माना जाएगा। इसे दोबारा खोलना/बदलना नहीं है।

## 12. GPT-1 अगला कार्य क्रम

1. Customer/Electrician pages के हर visible action/button को existing JS handler → endpoint/RPC → migration/test mapping से एक-एक कर मिलाएँ; dead/placeholder/stale controls दर्ज करें, नया feature न जोड़ें।
2. README और user-visible portal copy को वर्तमान contracts से मिलाएँ; केवल वास्तविक mismatch सुधारें।
3. GPT-1 owned Node/source regression gaps को ठीक करें और CI evidence दर्ज करें।
4. Availability, live-location और phone-change DB security tests GPT-2 से coordination लेकर ही जोड़ें/बदलें, क्योंकि SQL/RLS/RPC ownership GPT-2 की है।
5. Isolated DB runtime tests, provider tests और consolidated mobile QA अपने-अपने approval/staging gates के बाद ही; Production/merge/deploy नहीं।


## 13. Portal button/action static binding audit — 15 Nov 2026

Inspected the current Feature Branch source for `booking.html` and `electrician.html`:

- Customer Portal: 41 rendered `<button>` templates. All inline handler names found in the page resolve to a declared function (10 distinct inline handler functions). Remaining fixed-ID controls have direct event-listener bindings or the customer-menu delegated/tab reference. Two controls intentionally use native behavior: the booking form submit button and `window.print()`. No missing inline handler definition was found.
- Electrician Portal: 27 rendered `<button>` templates. All 23 distinct inline handler names resolve to declared functions, including OTP, refresh/logout, profile, support, push, availability, area change, phone-change OTP, KYC upload/preview, work start/completion, offer response and SOS controls. No missing inline handler definition was found.
- This is a static source-binding audit only. It does not prove click behavior, API success, role authorization, browser rendering, or mobile interaction. Dynamic rows (booking/offer/ticket/document actions) still require isolated browser/runtime verification in the final QA stage.
- README route summary was compared with current `index.html`, `welcome.html`, and `customer-login.html`; the documented root Welcome route and OTP login entry correspond to the inspected source. No README route edit was warranted by this pass.



## 14. UI → API/RPC → migration source reconciliation — 15 Nov 2026

- Current branch head at start of this pass: `70010d08ab74e60e5c84551f8c2295105273a7b4` (GPT-2 had added a newer documentation commit after GPT-1's previous snapshot). PR #8 remains **open / Draft**; no merge or deployment was performed.
- Parsed the current portal source call-sites: `booking.html` has 27 distinct Supabase RPC names; `electrician.html` has 23 distinct RPC names. `srk_create_sos_alert` is shared, so there are 49 distinct names across both pages. This is a call-site inventory, not proof that all 49 were runtime-executed.
- Confirmed the UI call names/signatures against the definitions in the relevant branch migrations for these representative flows:
  - Customer receipt: `srk_customer_get_payment_receipt(p_booking_id uuid)` — `20261114190000_customer_receipt_immutable_labour_amount.sql`.
  - Customer payment history: `srk_customer_get_payment_history(p_limit integer, p_offset integer)` — `20261114200000_customer_payment_refund_history_rpc.sql`.
  - Customer saved addresses/profile reads and address save/delete — `20261114201428_customer_profile_saved_addresses_private_storage.sql`.
  - Customer complaint creation/list — `20261114202250_customer_complaint_customer_safe_projection.sql`; conversation send/list and attachment linking — `20261113220000_customer_support_conversation_schema.sql`; attachment list — `20261113230000_support_attachment_paths_and_admin_message_list.sql`.
  - Customer payment-method change — `20261114202656_customer_change_payment_method_rpc.sql`; refund request/list — `20261115100000_customer_refund_request_contract.sql`; cancellation request/list — `20261114270000_admin_only_cancellation_requests_and_decisions.sql`.
  - Electrician availability — `20261114310000_electrician_self_availability.sql`; booking-scoped location start/update/stop and customer read — `20261114320000_booking_scoped_live_electrician_location.sql`.
  - Electrician KYC upload/list/review/activation — `20261115140000_electrician_kyc_review_and_activation_gate.sql`; secure preview path — `20261114330000_electrician_private_kyc_document_preview.sql`.
  - Electrician display-name update — `20261114340000_electrician_self_profile_name_edit.sql`; support ticket/message functions — `20261114350000_electrician_support_tickets_and_admin_inbox.sql`.
  - Offer response and sequential dispatch — `20261114210000_sequential_nearest_offer_dispatch.sql`; offer detail RPC — `20261114370000_electrician_offer_details_immediate_booking_fields.sql` and timer migration `20261114240000_server_authoritative_customer_approved_work_timer.sql`.
  - Phone-change Edge Function's nine RPC operations were checked against `20261114380000_electrician_phone_change_admin_approval.sql`; the function uses authenticated user lookup before user-scoped requests and explicitly checks Admin authorization for Admin actions.
  - Customer and Electrician SOS clients both call `srk_create_sos_alert({p_reason})`; the same-named backend definition is in `20261115260000_sos_admin_support_alerts.sql`. UI contract tests exist in `tests/sos-two-step-ui-contract.test.js` and `tests/sos-admin-support-contract.test.js`; delivery remains backend/provider-runtime dependent.
- Customer booking/payment HTTP adapter chain was traced: `booking.html` → `/api/create-booking` → Netlify adapter `netlify/functions/create-booking.js` → root `create-booking.js`; online payment → `/api/create-order` / `/api/verify-payment` → Netlify adapters → root handlers. Static source inspection found customer-session/verified-phone checks in booking creation, idempotency-key validation and server rate-limit gate; order creation checks booking ownership, selected online payment method, completed-work state and server-computed amount before Razorpay order creation. Existing Node contracts include `customer-immediate-booking-contract` and `customer-payment-method-enforcement`; no live provider transaction was run.
- The relevant migrations inspected in this pass consistently include `SECURITY DEFINER` and a pinned `search_path` for the listed customer/electrician RPC definitions. This is a source-level check only; it does not replace role/ACL/RLS execution tests.
- Remaining reconciliation work: finish exact definition/signature and test mapping for every remaining call-site in the 49-name inventory (including customer work timeline/labour bill/cancellation-fee RPCs and electrician earnings/wallet/area-change RPCs), and trace all client table reads/storage operations to their RLS/bucket policies. Do not treat the representative checks above as a full pass.
- No app code, migrations, database, provider, payment/refund, Storage, Auth setting, Production configuration, deployment, or mobile QA was changed or invoked in this pass.


## 15. शेष RPC call-sites का अगला contract pass — 15 Nov 2026

इस follow-up में section 14 के खुले उदाहरणों में से निम्नलिखित भी migration definitions से मिलाए गए:

- Customer work timeline: `srk_customer_get_my_booking_work_timeline(p_booking_id uuid)` — `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql`.
- Customer/Electrician labour bill reads और work-start/completion approval RPCs — `20261114240000_server_authoritative_customer_approved_work_timer.sql`; customer completion response का optional dispute note भी signature में मौजूद है।
- Customer cancellation-fee debt list, fee-item list और service-role payment breakdown — `20261114280000_cancellation_fee_carry_forward_and_accounting.sql`; cancellation fee ledger reversal/refund paths — `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`.
- Electrician area-change request/list — `20261114220000_admin_approved_electrician_relocation.sql`.
- Electrician earnings read — `20261109003000_secure_commission_reporting.sql`; wallet summary — `20261109010000_create_secure_wallet_ledger_foundation.sql`.
- Electrician live-location source calls (start/update/stop/status) and customer location read have matching definitions in `20261114320000_booking_scoped_live_electrician_location.sql`.

इन signatures/definitions का मिलान source-level पर हुआ है; actual RPC execution, actor isolation, grants/RLS, concurrency और returned payload behavior अभी runtime-verified नहीं हैं। अब शेष प्रमुख source reconciliation काम है: सभी direct Supabase table selects/inserts/updates और Storage bucket operations को संबंधित RLS/bucket policies तथा test coverage से जोड़ना; इसके बाद केवल वास्तविक mismatch मिलने पर code change करना।


## 16. Direct table / Storage access और RLS dependency audit — 15 Nov 2026

Portal source में direct client access inventory:

- Customer: `service_bookings` SELECT (customer UID filter); `srk-customer-avatars` upload/signed-read/delete; `srk-customer-support` upload/signed-read/delete.
- Electrician: `electrician_profiles` SELECT (current user filter); `srk_electrician_payouts` SELECT (profile ID filter); `srk_wallet_bank_links` और `srk_wallet_ledger` SELECT; `srk_push_subscriptions` upsert/delete.

Migration-source checks:

- Customer `service_bookings` own-row SELECT policy `srk_customer_read_own_bookings` मिली — `20261108121115_add_customer_account_booking_access.sql`.
- Customer avatar और support-object policies/private buckets संबंधित migrations में मिलीं — `20261114201428_customer_profile_saved_addresses_private_storage.sql`, `20261114180000_harden_customer_avatar_object_integrity.sql`, `20261113220000_customer_support_conversation_schema.sql`. Support attachment object access customer complaint ownership helper से gated है; पूरा Storage runtime अभी pending है.
- Electrician `srk_push_subscriptions` पर own-user RLS policy `20261111020000_add_electrician_push_subscriptions.sql` में मिली.
- Electrician payout SELECT policy `srk_read_authorized_electrician_payouts` `20261114125844_restore_financial_audit_core_schema.sql` में मिली; यह Admin या linked profile के `ep.user_id = auth.uid()` को अनुमति देती है.
- Wallet ledger और bank-link owner-read policies `20261109010000_create_secure_wallet_ledger_foundation.sql` में मिलीं.
- **GPT-2 handoff / unresolved migration-baseline dependency:** Electrician UI सीधे `electrician_profiles` से अपना profile पढ़ता है। Legacy `COMPLETE_DATABASE_SETUP.sql` में `srk_electrician_read_own_profile` policy (`user_id = auth.uid()`) मौजूद है; इस audit में migration chain की जाँची गई identity migrations (`20261109000500...`, `20261114130000...`) में यह policy नहीं मिली। इसे अभी **confirmed missing** नहीं कह रहे, क्योंकि historical/base DDL और remote applied policy history अभी authoritative रूप से reconcile नहीं हैं। GPT-2 को यह exact dependency verify करनी है; fresh migration replay में policy न हो तो Electrician profile SELECT fail हो सकता है. GPT-1 ने कोई SQL/RLS change नहीं किया.

यह source/policy-file inspection है, live role test नहीं। आगे का सुरक्षित कदम GPT-2 से authoritative baseline और migration replay में profile own-read policy की पुष्टि लेना है; Production query/change या migration apply नहीं किया गया।


## 17. RLS regression-test coverage reconciliation — 15 Nov 2026

इस pass में portal direct-access tables के migrations और उपलब्ध pgTAP files को साथ मिलाया:

| Client direct access | Migration policy evidence | Dedicated DB security regression test |
|---|---|---|
| Customer `service_bookings` own-row SELECT | `20261108121115_add_customer_account_booking_access.sql`; merged Admin/customer policy `20261108234000_combine_booking_read_policy.sql` | इस tree के 32 pgTAP SQL files में इस exact own-row policy/actor-isolation की dedicated assertion नहीं मिली |
| Electrician `electrician_profiles` own-row SELECT | Legacy `COMPLETE_DATABASE_SETUP.sql` / `PORTAL_SCHEMA.sql` में policy; current migration chain में इस audit तक authoritative confirmation नहीं | नहीं; `electrician_profile_identity_linking.test.sql` identity trigger/link consistency जाँचता है, self-read RLS नहीं |
| Electrician `srk_push_subscriptions` own-user upsert/delete | `20261111020000_add_electrician_push_subscriptions.sql` में RLS + `user_id = auth.uid()` policy | push delivery tests मौजूद, पर table owner-policy isolation का dedicated pgTAP test नहीं मिला |
| Electrician `srk_wallet_accounts`, `srk_wallet_ledger`, `srk_wallet_bank_links` own-user SELECT | `20261109010000_create_secure_wallet_ledger_foundation.sql` में तीनों owner-read policies और authenticated SELECT grants | wallet RLS owner-vs-other-user का dedicated pgTAP test नहीं मिला; accounting tests दूसरे accounting contracts को cover करते हैं |
| Electrician `srk_electrician_payouts` own/admin SELECT | `20261114125844_restore_financial_audit_core_schema.sql` में `srk_read_authorized_electrician_payouts` | `financial_audit_core_schema.test.sql` में grant और Admin/linked electrician policy definition assertions मौजूद |
| Customer avatar/support Storage objects | Private buckets + owner/complaint/admin-scoped policies | `customer_profile_saved_addresses_private_storage.test.sql`, `customer_avatar_object_integrity.test.sql`, `support_attachment_admin_message_access.test.sql` में policy/bucket/object ownership assertions मौजूद |

**GPT-2 को भेजने योग्य database/security verification items:** (1) Electrician own-profile SELECT policy migration chain में मौजूद है या नहीं, authoritative base schema + migration replay से तय करें; (2) customer booking own-row SELECT, electrician profile self-read, push subscription owner-only write, और wallet owner-only read के लिए अलग pgTAP actor-isolation tests जोड़ें/मौजूदा tests में exact assertions पहचानें। यह केवल test-coverage gap है, runtime vulnerability का दावा नहीं। GPT-1 ने इन GPT-2-owned SQL/RLS areas में कोई edit नहीं किया।

**GPT-1 source/test reconciliation:** Customer Storage controls की dedicated pgTAP coverage मौजूद है; payout RLS contract test मौजूद है। Customer/Electrician portal के RPC/UI Node source contracts मौजूद हैं, पर वे live authenticated actor isolation या वास्तविक DB execution सिद्ध नहीं करते। Manual mobile QA और all-provider runtime QA अभी deferred हैं।


## 18. Portal regression-test scope mapping — 15 Nov 2026

`package.json` में default `npm test` script `node --test tests/*.test.js` चलाता है। इस pass में संबंधित GPT-1 test files के घोषित test cases पढ़े और UI/API source coverage की सीमा दर्ज की:

- `tests/customer-immediate-booking-contract.test.js`: immediate booking payload/अनुपस्थित schedule fields का contract; live booking creation या DB persistence नहीं.
- `tests/customer-payment-method-enforcement.test.js`: Cash/refunded booking पर order/payment रोकना और payment-method RPC UTF-8 contract; Razorpay sandbox payment नहीं.
- `tests/electrician-accounting-kyc-contract.test.js`: KYC MIME/type/size validation, signed preview contract, earnings-vs-payout error handling, owner-scoped wallet reads, withdrawal UI निषेध, profile-name validation; live Storage/RLS/accounting execution नहीं.
- `tests/electrician-live-location-client.test.js`: GPS error/stop cleanup, duplicate-start guard, push gesture/route और retry handling; actual GPS, realtime channel या device push delivery नहीं.
- `tests/sos-two-step-ui-contract.test.js` और `tests/sos-admin-support-contract.test.js`: approved reason codes, active-booking UI, authenticated actor/booking derivation contract, private append-only case history, Admin/Support permission contracts और provider-delivery disclaimer; actual SMS/push/location delivery नहीं.

इससे UI/client contract tests की सीमा स्पष्ट हुई। ऊपर के files के नाम/declared assertions का निरीक्षण किया गया; इस pass में `npm test` execute नहीं हुआ और कोई CI success claim नहीं है। DB actor-isolation, migration replay, Razorpay sandbox, Storage runtime, push/SMS providers, browser interaction और final mobile QA अलग verification gates हैं।


## 19. Remaining Customer/Electrician RPC signature mapping — 15 Nov 2026

Source call-sites के RPC names और payload keys को संबंधित migration declarations/grants के विरुद्ध जाँचा। नीचे के mappings में call-site के `p_*` keys declared SQL arguments से मेल खाते हैं:

| Portal call | SQL signature / migration | Source contract observation |
|---|---|---|
| Customer `srk_get_customer_call_contacts()` | no args; `20261109103038_customer_electrician_direct_call_contacts.sql`, private implementation wrapper hardening `20261109103143_move_customer_call_contact_lookup_to_private.sql` | authenticated execute grant; private implementation migration मौजूद |
| Customer `srk_customer_respond_work_start(uuid,text)` | `(p_booking_id,p_response)`; `20261114240000_server_authoritative_customer_approved_work_timer.sql`, later fix `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql` | दोनों keys और types source payload से match |
| Customer `srk_customer_respond_work_completion(uuid,text,text)` | `(p_booking_id,p_response,p_note)`; `20261114240000_server_authoritative_customer_approved_work_timer.sql` | तीनों keys source payload से match |
| Customer `srk_customer_request_booking_cancellation(uuid,text)` | `(p_booking_id,p_customer_note)`; `20261114270000_admin_only_cancellation_requests_and_decisions.sql` | source payload match; customer list RPC उसी migration में no-arg |
| Customer cancellation fee RPCs | `srk_customer_list_my_cancellation_fee_debts()` और `srk_customer_list_booking_cancellation_fee_items()`; `20261114280000_cancellation_fee_carry_forward_and_accounting.sql` | दोनों no-arg calls; SQL में `auth.uid()`-scoped customer rows |
| Customer `srk_customer_get_live_electrician_location(uuid)` | `(p_booking_id)`; `20261114320000_booking_scoped_live_electrician_location.sql` | booking-scoped customer read; authenticated execute grant |
| Electrician live-location RPCs | start/update `(p_booking_id,p_latitude,p_longitude,p_accuracy_meters)`; stop/status `(p_booking_id)`; `20261114320000_booking_scoped_live_electrician_location.sql` | frontend keys and SQL argument types match; numeric accuracy argument accepted by SQL signature |
| Electrician availability | `srk_electrician_set_availability(p_available boolean)`; `20261114310000_electrician_self_availability.sql` | source boolean key matches; authenticated execute grant |
| Electrician support RPCs | create `(p_category,p_subject,p_body,p_booking_id)`; list tickets `()`; list/send messages `(p_ticket_id)` / `(p_ticket_id,p_body)`; `20261114350000_electrician_support_tickets_and_admin_inbox.sql` | source payload keys align; SQL functions are SECURITY DEFINER and user-scoped; Admin counterparts separately permission-gated |
| Electrician `srk_get_my_offer_details()` | no args; `20261114370000_electrician_offer_details_immediate_booking_fields.sql` and matching timer migration definition | source no-arg call matches; function resolves authenticated electrician identity |
| Electrician `srk_respond_to_offer(uuid,text)` | `(p_offer_id,p_response)`; `20261114210000_sequential_nearest_offer_dispatch.sql` and timer migration grant reconciliation | source keys match; SQL checks authenticated owner of offer/profile |
| Electrician KYC submit/list/preview | submit `(p_document_type,p_storage_path,p_file_name,p_mime_type,p_file_size_bytes)` and list `()` in `20261115140000_electrician_kyc_review_and_activation_gate.sql`; preview `(p_document_id)` in `20261114330000_electrician_private_kyc_document_preview.sql` | all source keys/signatures match; private bucket owner/admin policies exist in KYC migration |

**नतीजा:** इस अतिरिक्त RPC subset में कोई payload-key/signature mismatch नहीं मिला। यह static source-to-migration comparison है; Supabase runtime invocation या `authenticated` बनाम दूसरे user के actor-isolation test का विकल्प नहीं। पिछले sections के बाकी RPC mappings और GPT-2 RLS test gaps अभी लागू रहते हैं।


## 20. Final uncovered RPC/test mapping subset — 15 Nov 2026

इस pass में पिछली सूची के शेष RPC names को उनकी वास्तविक SQL declaration और उपलब्ध DB tests से जोड़ा:

| UI RPC | SQL declaration | Test evidence / सीमा |
|---|---|---|
| `srk_customer_create_booking_refund_request(uuid,text)` और `srk_customer_list_booking_refund_requests()` | `20261115100000_customer_refund_request_contract.sql` | `customer_refund_request_contract.test.sql` में 17 pgTAP assertions: booking owner, verified paid amount, immutable labour bill, fee-ledger reconciliation, duplicate/refund guards, customer-safe projection, authenticated-only grants. |
| `srk_customer_get_my_profile()` / saved-address list/save/delete | `20261114201428_customer_profile_saved_addresses_private_storage.sql` | `customer_profile_saved_addresses_private_storage.test.sql` में RLS, private tables, `auth.uid()` scoping, RPC grants, address cap/concurrency, private buckets और Storage policy assertions. |
| `srk_customer_update_my_profile(text,text,text)` | `20261114180000_harden_customer_avatar_object_integrity.sql` | `customer_avatar_object_integrity.test.sql` में MIME/size/owner metadata and authenticated-only grant checks. |
| Complaint message send/list/attachment link/list | `20261113220000_customer_support_conversation_schema.sql`; attachment list `20261113230000_support_attachment_paths_and_admin_message_list.sql` | `customer_complaint_customer_safe_projection.test.sql` customer complaint list/create projection checks; `support_attachment_admin_message_access.test.sql` Storage access checks. इन files में हर message/attachment RPC के runtime cross-user actor tests होने का दावा नहीं। |
| `srk_electrician_update_my_display_name(text)` | `20261114340000_electrician_self_profile_name_edit.sql` | dedicated pgTAP file इस inventory में नहीं मिली; UI contract test अलग static validation है। |
| `srk_electrician_request_area_change(text,text,text,text)` / `srk_electrician_list_my_area_requests()` | `20261114220000_admin_approved_electrician_relocation.sql` | dedicated relocation pgTAP test नहीं मिला। SQL function authenticated linked profile जाँचता है, duplicate pending request रोकता है; Admin decision अलग `is_srk_admin()` gate से guarded है। |
| `srk_get_my_earnings()` | `20261109003000_secure_commission_reporting.sql` | payout reconciliation test payout settlement/amount logic को cover करता है; `srk_get_my_earnings()` projection के लिए dedicated pgTAP assertion इस audit में नहीं मिली। |
| `srk_get_my_wallet_summary()` | `20261109010000_create_secure_wallet_ledger_foundation.sql` | wallet account/ledger/bank-link tables में RLS owner-read policies और authenticated RPC grant हैं; wallet-summary function/owner-vs-other-user के लिए dedicated pgTAP assertion नहीं मिली। |

**महत्वपूर्ण naming reconciliation:** वर्तमान `booking.html` का refund history call `srk_customer_list_booking_refund_requests()` है और वर्तमान migration भी यही function declare/grant करती है। पुराने `docs/SRK_ELECTRONIC_PROJECT_PROGRESS_HI.md` में खोज परिणाम के अनुसार legacy नाम `srk_customer_list_my_booking_refund_requests()` का उल्लेख है; उसे वर्तमान source contract न माना जाए। यह दस्तावेज़ी drift है, वर्तमान UI/migration mismatch नहीं। GPT-1 ने GPT-2-owned SQL या legacy progress document edit नहीं किया।

**Remaining evidence gaps (handoff only):** Electrician display-name, relocation, earnings projection, wallet summary तथा message/attachment RPC cross-user actor isolation के लिए dedicated DB tests की उपलब्धता GPT-2 database/security owner को verify करनी है। ये test-coverage gaps हैं; इनमें से कोई अकेले runtime vulnerability सिद्ध नहीं करता।
