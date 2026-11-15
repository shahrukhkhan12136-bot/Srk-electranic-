# SRK ELECTRONIC — Migration Replay Manifest (Static, Hindi)

**स्थिति:** Static inventory only — यह execution-ready replay plan नहीं है।  
**जाँचा गया commit:** `53a9c0f1fe4d33a5b29430654a7c39fa39f32d8f`  
**कुल SQL migrations:** 72  
**Production:** कोई access/apply नहीं। PostgreSQL/pgTAP runtime नहीं चला।

## 1. महत्त्वपूर्ण रोक (Do not replay yet)

1. Duplicate 8-digit version prefix `20261109`:
   - `20261109_allow_quote_approval_booking_states.sql`
   - `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
   Supabase CLI और migration-history reconciliation के बिना replay order/identity निश्चित नहीं है। Rename या history edit न करें।
2. Starter schema में `service_bookings.amount_paid` नहीं है, जबकि commission/quote/payment code इसे पढ़ता और update grant में शामिल करता है। उपलब्ध migration tree में authoritative ADD COLUMN DDL नहीं मिला।
3. Starter schema `electrician_profiles.user_id` जोड़ता है, लेकिन `auth_user_id` का authoritative ADD COLUMN DDL नहीं मिला। Google Maps approval और wallet ownership resolution दोनों इसे पढ़ते हैं।
4. Historical starter SQL complete current baseline नहीं है। Production schema parity, exact column contracts, RLS/ACL, trigger/function dependencies और existing migration history सत्यापित नहीं।
5. इसलिए नीचे का क्रम केवल filename/version-sorted inventory है; इसे सुरक्षित executable order न समझें।

## 2. Static filename/version-sorted inventory

यह क्रम timestamp/name के आधार पर है। Duplicate version वाली दो files को अलग-अलग सूचीबद्ध किया गया है।

### A. Public API, customer ownership, location, quote, commission, wallet (14)

1. `20261108120608_add_public_api_rate_limiting.sql`
2. `20261108120658_enable_rls_public_api_rate_limits.sql`
3. `20261108121115_add_customer_account_booking_access.sql`
4. `20261108233500_restrict_public_form_inserts.sql`
5. `20261108234000_combine_booking_read_policy.sql`
6. `20261109001000_add_google_maps_location_support.sql`
7. `20261109002000_expose_assigned_booking_map_pin.sql`
8. `20261109003000_secure_commission_reporting.sql`
9. `20261109010000_create_secure_wallet_ledger_foundation.sql`
10. `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql`
11. `20261109103038_customer_electrician_direct_call_contacts.sql`
12. `20261109103143_move_customer_call_contact_lookup_to_private.sql`
13. `20261109_allow_quote_approval_booking_states.sql`
14. `20261109_electrician_inspection_quotes_and_service_only_commission.sql`

### B. Quote restoration, Support, finance baseline, booking submission and customer flows (13)

15. `20261110140000_restore_missing_customer_booking_quote_columns.sql`
16. `20261113220000_customer_support_conversation_schema.sql`
17. `20261113230000_support_attachment_paths_and_admin_message_list.sql`
18. `20261114125844_restore_financial_audit_core_schema.sql`
19. `20261114150000_customer_booking_submission_idempotency.sql`
20. `20261114160000_customer_selected_rate_tier_and_server_estimate.sql`
21. `20261114180000_harden_customer_avatar_object_integrity.sql`
22. `20261114190000_customer_receipt_immutable_labour_amount.sql`
23. `20261114200000_customer_payment_refund_history_rpc.sql`
24. `20261114201428_customer_profile_saved_addresses_private_storage.sql`
25. `20261114202250_customer_complaint_customer_safe_projection.sql`
26. `20261114202656_customer_change_payment_method_rpc.sql`
27. `20261114210000_sequential_nearest_offer_dispatch.sql`

### C. Booking lifecycle, Admin/Support, Electrician, payout and webhook (18)

28. `20261114220000_admin_approved_electrician_relocation.sql`
29. `20261114230000_recheck_electrician_current_area_before_offer.sql`
30. `20261114240000_server_authoritative_customer_approved_work_timer.sql`
31. `20261114250000_admin_work_dispute_review_and_immutable_history.sql`
32. `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql`
33. `20261114270000_admin_only_cancellation_requests_and_decisions.sql`
34. `20261114280000_cancellation_fee_carry_forward_and_accounting.sql`
35. `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`
36. `20261114300000_admin_customer_support_thread_replies.sql`
37. `20261114310000_electrician_self_availability.sql`
38. `20261114320000_booking_scoped_live_electrician_location.sql`
39. `20261114330000_electrician_private_kyc_document_preview.sql`
40. `20261114340000_electrician_self_profile_name_edit.sql`
41. `20261114350000_electrician_support_tickets_and_admin_inbox.sql`
42. `20261114360000_new_category_electrician_payout_reconciliation.sql`
43. `20261114370000_electrician_offer_details_immediate_booking_fields.sql`
44. `20261114380000_electrician_phone_change_admin_approval.sql`
45. `20261114390000_admin_staff_rbac_foundation.sql`
46. `20261114410000_razorpay_webhook_event_inbox.sql`

### D. Refund, KYC, accounting, Route, Push and final financial hardening (26)

47. `20261115091906_retire_unused_legacy_accept_electrician_job.sql`
48. `20261115092149_retire_unused_razorpay_route_transfer_ledger.sql`
49. `20261115100000_customer_refund_request_contract.sql`
50. `20261115110000_admin_refund_review_queue_and_decisions.sql`
51. `20261115120000_durable_razorpay_refund_recovery_evidence.sql`
52. `20261115120001_fix_multi_profile_electrician_labour_bill_access.sql`
53. `20261115130000_admin_manual_refund_request_completion.sql`
54. `20261115140000_electrician_kyc_review_and_activation_gate.sql`
55. `20261115145900_fix_multi_profile_electrician_labour_bill_access.sql`
56. `20261115150000_admin_readonly_booking_accounting_reconciliation.sql`
57. `20261115160000_legacy_booking_status_write_guard.sql`
58. `20261115170000_admin_route_transfer_accounting_reconciliation.sql`
59. `20261115170001_durable_push_delivery_outbox.sql`
60. `20261115180000_admin_route_recipient_and_settlement_validation.sql`
61. `20261115180001_push_subscription_delivery_ledger.sql`
62. `20261115190000_enforce_single_primary_route_bank_link.sql`
63. `20261115190001_push_delivery_health_monitoring.sql`
64. `20261115200000_harden_financial_admin_rpc_search_path.sql`
65. `20261115200001_push_delivery_lease_fencing.sql`
66. `20261115210000_legacy_manual_payment_and_itemized_receipt.sql`
67. `20261115210001_harden_legacy_financial_read_rpc_search_paths.sql`
68. `20261115220000_retire_live_legacy_quotation_rpcs.sql`
69. `20261115230000_admin_booking_direct_write_closure.sql`
70. `20261115240000_harden_refund_recovery_full_amount.sql`
71. `20261115250000_harden_refund_reconcile_full_amount.sql`
72. `20261115260000_sos_admin_support_alerts.sql`

## 3. Dependency phases (provisional, not an apply order)

- **Phase 0 — Source baseline:** exact historical schema snapshot; core table columns/types; Auth ownership mapping; extensions; roles; grants; RLS; existing triggers/functions.
- **Phase 1 — Identity and public entry:** rate-limit tables/policies; customer ownership; booking read/write policy; electrician profile identity; location columns and checks.
- **Phase 2 — Booking/quote/payment core:** quote columns and status constraints; `amount_paid`; commission; wallet/ledger; Razorpay order/payment/refund dependencies.
- **Phase 3 — Customer/support objects:** customer profile, saved address, complaint and support base tables; storage buckets/policies; message/attachment child tables.
- **Phase 4 — Lifecycle:** offer dispatch; timer/event history; cancellation and fee ledger; immutable labour bill; dispute review.
- **Phase 5 — Staff/finance/security:** RBAC; KYC; payout; accounting; refund request/recovery/reconciliation; Route evidence and validation.
- **Phase 6 — Push:** subscription base table, outbox, delivery ledger, health and lease fencing.
- **Phase 7 — Final hardening:** direct-write closure, legacy RPC retirement, search_path and full-amount guards.

हर phase के भीतर exact table/function/trigger/storage dependencies और migration overlap line-by-line map होने के बाद ही execution plan बनाया जा सकता है।

## 4. अगली सुरक्षित जाँच

- Missing `amount_paid` और `auth_user_id` DDL के लिए older commit trees/tags और approved schema snapshot खोजें।
- Supabase CLI के वास्तविक version से timestamp parsing और duplicate-version व्यवहार को isolated scratch repository पर जाँचें; Production history पर नहीं।
- प्रत्येक migration के `CREATE/ALTER/DROP`, function calls, triggers, policies, grants, storage objects और referenced columns को machine-readable dependency matrix में रखें।
- Complete baseline मिलने के बाद ही disposable local PostgreSQL fixture और migration replay का प्रस्ताव दें; उसमें भी कोई Production credentials नहीं।


## 5. Static object-change audit — 15 नवम्बर 2026

72 files की SQL text को migration-by-migration scan किया गया। नीचे सूचीबद्ध object names source में CREATE/ALTER या function definition के रूप में मिले; यह semantic SQL parser या PostgreSQL execution नहीं है। Dynamic SQL, unqualified names, `DO` blocks और indirect function calls के कारण इसे पूर्ण dependency graph नहीं माना जाए।

### 5.1 Core schema / wallet / booking
- `20261109010000_create_secure_wallet_ledger_foundation.sql`: `srk_wallet_accounts`, `srk_wallet_ledger`, `srk_wallet_bank_links` बनाता/बदलता है; wallet summary/admin overview RPCs।
- `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql`: `srk_route_transfers` बनाता/बदलता है।
- दोनों `20261109` migrations `service_bookings` पर निर्भर हैं; quote/commission migration functions `srk_calculate_booking_commission`, `srk_submit_booking_quote`, `srk_customer_respond_booking_quote`, `srk_update_booking_work_status` परिभाषित करती है।
- `20261110140000_restore_missing_customer_booking_quote_columns.sql` `service_bookings` पर अतिरिक्त quote columns restore करता है; यह `amount_paid` की missing definition को resolve नहीं करता।

### 5.2 Complaint / support / audit / RBAC
- `20261113220000_customer_support_conversation_schema.sql`: `srk_booking_complaint_messages` और `srk_booking_complaint_message_attachments` child tables बनाता है; इन्हें complaint base tables पहले से चाहिए।
- `20261114125844_restore_financial_audit_core_schema.sql`: labour bills, manual payment entries, electrician payouts, admin audit events, Razorpay refunds, booking refund requests और manual refund entries के financial base objects तथा audit triggers बनाता है।
- `20261114350000_electrician_support_tickets_and_admin_inbox.sql`: electrician support ticket/message base tables बनाता है।
- `20261114390000_admin_staff_rbac_foundation.sql`: staff, permissions, role-permission mapping, staff sessions, staff audit, support assignments बनाता है और complaint-message table को alter करता है। इसलिए complaint base + customer support child schema तथा electrician support ticket schema उसके पूर्वापेक्षित objects हैं।

### 5.3 Customer / booking lifecycle / cancellation
- `20261114201428_customer_profile_saved_addresses_private_storage.sql`: customer profiles और saved addresses बनाता है।
- `20261114210000_sequential_nearest_offer_dispatch.sql`: `job_offers` को बदलता है और booking offer dispatch/candidate tables बनाता है; `broadcast_booking_job`, offer response/expiry functions तथा booking insert trigger जोड़ता है।
- `20261114240000_server_authoritative_customer_approved_work_timer.sql`: work timer authorization tables और labour bill guard/flow RPCs बनाता/बदलता है।
- `20261114250000_admin_work_dispute_review_and_immutable_history.sql`: append-only booking work events और audit capture trigger बनाता है; अगली migration row mutation/truncate रोकती है।
- `20261114270000_admin_only_cancellation_requests_and_decisions.sql`: cancellation request/event tables और immutable-event guards बनाता है।
- `20261114280000_cancellation_fee_carry_forward_and_accounting.sql`: wallet ledger को बदलता है और cancellation fee debts/items/ledger बनाता है; reservation/release triggers तथा payment breakdown RPCs जोड़ता है। इसलिए wallet base ledger तथा booking/cancellation objects का क्रम महत्वपूर्ण है।
- `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`: cancellation fee objects और refund flows पर निर्भर है।

### 5.4 Electrician / payout / KYC / webhook
- `20261114310000_electrician_self_availability.sql`: electrician profiles बदलता है और availability event table बनाता है।
- `20261114320000_booking_scoped_live_electrician_location.sql`: booking live-location table, RPCs और booking-transition trigger बनाता है।
- `20261114380000_electrician_phone_change_admin_approval.sql`: phone change request table और multi-step RPCs बनाता है।
- `20261114360000_new_category_electrician_payout_reconciliation.sql`: पहले से बने payout/bill/booking objects पर payable/payout RPCs परिभाषित करता है।
- `20261114410000_razorpay_webhook_event_inbox.sql`: webhook event inbox table और service claim/complete RPCs बनाता है।
- `20261115140000_electrician_kyc_review_and_activation_gate.sql`: KYC documents/events tables और activation/verification RPCs बनाता है; electrician profile/application तथा rate-tier gate पर निर्भर है।

### 5.5 Refund / Route / Push
- Refund sequence में refund request contract और review RPCs, durable recovery evidence table/immutable trigger, manual refund completion, read-only reconciliation, Route reconciliation/recipient checks तथा अंत में full-amount guards आते हैं। इन्हें financial audit base objects, booking payment snapshot, payout/refund ledger और fee ledger के बिना standalone replay नहीं किया जा सकता।
- `20261115170001_durable_push_delivery_outbox.sql`: push subscription + delivery outbox objects, claim/finish RPCs और job-offer enqueue trigger बनाता है।
- `20261115180001_push_subscription_delivery_ledger.sql`: subscription delivery ledger तथा claim/finish/completion RPCs जोड़ता है; subscription base और outbox/worker semantics पहले समझना आवश्यक है।
- `20261115190001_push_delivery_health_monitoring.sql` health/retry RPCs जोड़ता है; outbox/delivery tables पर निर्भर है।
- `20261115200001_push_delivery_lease_fencing.sql` पहले के push finish RPCs को fencing semantics के साथ बदलता है।

### 5.6 Static ordering concerns to resolve
1. Complaint base tables का DDL वर्तमान 71-file tree में नहीं है, पर complaint child schema और RBAC उनसे निर्भर हैं; ऐतिहासिक branch source मिला है, पर उसे वर्तमान baseline में reconcile करना बाकी है।
2. `srk_booking_complaint_messages` पहले customer support migration में बनता है और RBAC migration उसे alter करता है; इसी तरह electrician support tables RBAC functions द्वारा उपयोग होते हैं।
3. `srk_wallet_ledger` पहले wallet foundation में बनता है और cancellation fee migration उसे alter/extend करती है।
4. Financial audit base objects payout/refund/manual payment RPCs के पहले चाहिए; exact FK, trigger and enum/state dependencies line-by-line verify हों।
5. Push subscription/outbox/delivery/health/lease sequence का replay क्रम source-level function signature diff से confirm करना बाकी है।
6. इस scan से कोई missing DDL अनुमान से नहीं जोड़ा गया। Duplicate version, `amount_paid`, `auth_user_id` और baseline gaps अब भी hard blockers हैं।


### 5.7 Older branch/schema provenance re-check — 15 नवम्बर 2026
Older `feature/business-finance-dashboard` और `work/separate-customer-electrician-portals` source branches पर अतिरिक्त cross-check किया गया:
- `SUPABASE_SCHEMA.sql` तथा `COMPLETE_DATABASE_SETUP.sql` में `service_bookings` और `electrician_profiles` के base `CREATE TABLE` statements हैं, लेकिन इनमें `amount_paid` या `auth_user_id` column definition नहीं मिली। `PORTAL_SCHEMA.sql` में भी इन दो column names की definition नहीं मिली।
- Finance branch की `20261109075837_electrician_inspection_quotes_and_service_only_commission.sql` `service_bookings` में `service_charge`, `materials_amount`, quote status/timestamps और `work_started_at` जोड़ती है; `amount_paid` नहीं जोड़ती, जबकि trigger/function उसी column को पढ़ते हैं।
- Portal branch की `20261109171621_add_admin_verified_manual_payment_workflow.sql` `amount_paid` को UPDATE करती है और उसी को validate भी करती है; यह column को ADD नहीं करती। अन्य finance/refund migrations भी इसे पहले से मौजूद मानती हैं।
- Portal branch की `20261109223000_sync_electrician_auth_profile_link.sql` `auth_user_id` में Auth ID लिखती है और `user_id OR auth_user_id` से lookup करती है; यह column को ADD नहीं करती। `20261110030000_admin_direct_electrician_assignment.sql` भी इसे पहले से मौजूद मानती है।
- इन पुराने branches के schema/migration copies स्वतंत्र schema provenance नहीं हैं और इनके consumers column contract (type, nullability, default, constraints, indexes) प्रमाणित नहीं करते। इसलिए दोनों columns के exact base DDL अब भी unresolved हैं; कोई guessed `ADD COLUMN` प्रस्तावित नहीं है।
- ध्यान दें: पुराने finance branch में quote migrations को अलग timestamped filenames मिले थे (`20261109075837`, `20261109080400`), जबकि वर्तमान Feature Branch में दोनों `20261109` prefix पर हैं। यह historical lineage clue है, लेकिन वर्तमान Supabase migration history के लिए rename/replay plan नहीं है।


### 5.8 अतिरिक्त feature/fix branches का consumer audit — 15 नवम्बर 2026
अतिरिक्त उपलब्ध branches (`feature/flutter-mobile-apps`, `feature/electrician-categories-hourly-booking`, `feature/direct-upi-commission-15` आदि) के SQL migrations भी spot-check किए:
- Flutter cash-payment migration `20261110235000_add_mobile_cash_payment_and_booking_location.sql` `amount_paid` में verified cash amount लिखती है और electrician lookup में `user_id/auth_user_id` दोनों पढ़ती है; कोई `ADD COLUMN` definition नहीं।
- Category/hourly booking migration कई booking/profile columns जोड़ती है, पर `service_bookings.amount_paid` या `electrician_profiles.auth_user_id` नहीं। यह `auth_user_id` को पहले से मौजूद मानकर पढ़ती है।
- Direct UPI payment-report migration `amount_paid` update करती है, लेकिन उसे create नहीं करती।
- वर्तमान Google Maps migration केवल `location_lat/location_lng` जोड़ती है; उसी migration के Admin approval RPC में `auth_user_id` insert/update होता है।
- इन अतिरिक्त branch consumers से usage की पुष्टि होती है, पर authoritative column DDL नहीं मिलता। इसलिए दोनों base-column contracts unresolved रहेंगे।


## 6. Latest-head inventory correction — 15 Nov 2026

- PR #8 के commit `53a9c0f1fe4d33a5b29430654a7c39fa39f32d8f` पर Git tree दोबारा गिना: कुल **72 SQL migrations**। पुराने 71-file inventory में नवीनतम `20261115260000_sos_admin_support_alerts.sql` शामिल नहीं था; इसे Section D में item 72 के रूप में जोड़ा गया।
- Duplicate 8-digit version prefix अभी भी `20261109` है और इसमें वही दो files हैं: `20261109_allow_quote_approval_booking_states.sql` तथा `20261109_electrician_inspection_quotes_and_service_only_commission.sql`। कोई rename/history rewrite नहीं किया गया।
- SOS migration का स्पष्ट dependency cluster: पहले से मौजूद `srk_admin_permissions` और `srk_admin_role_permissions` (RBAC foundation), `service_bookings`, `auth.users`, तथा `srk_has_admin_permission` / Admin staff-session permission contract। यह केवल static source dependency observation है; replay order प्रमाणित नहीं।
- Inventory और dependency manifest अभी भी static है; PostgreSQL parser, migration replay, pgTAP या Production parity test नहीं चला।


## 7. Supabase CLI mixed-version ordering risk — 15 Nov 2026

- Repository workflow `.github/workflows/supabase-schema-ci.yml` pins `supabase/setup-cli@v1` to **CLI 3.0.0**. Its current guard केवल `feature/platform-fee-cash-online-cycle` branch पर है; इस जाँच में इसे चलाया नहीं गया। Workflow में Production schema export secret भी माँगा जाता है, इसलिए इसे Feature Branch पर चलाना सुरक्षित/अधिकृत रास्ता नहीं माना गया।
- इस repository में `20261109_*.sql` के 8-digit migration versions के साथ `20261109001000_*.sql`, `20261109002000_*.sql` आदि 14-digit versions मौजूद हैं; अर्थात 8-digit और 14-digit prefix overlap का pattern मौजूद है।
- Supabase CLI issue #6036 ने CLI 2.105.0 TypeScript path में इस pattern से false “Remote migration versions not found” sorting error दर्ज किया। Issue #6038 ने TypeScript path सुधारा, लेकिन Go implementation के लिए issue #6682 ने अलग से वही ordering defect report किया; issue body में v2.117.0 Go implementation की code inspection है। 29 Oct 2026 को issue बंद हुआ, लेकिन उपलब्ध issue thread में maintainer fix/confirmation नहीं है। यह CLI 3.0.0 पर direct execution proof नहीं है; pinned CLI implementation के कारण इसे unresolved risk मानें, not a confirmed failure.
- Repository का `tests/database-migration-version-uniqueness.test.js` इस `20261109` pair को explicitly allow-list करता है; यह केवल filename uniqueness guard है, Supabase CLI comparator regression test नहीं।
- इसलिए 8-digit files rename करना, history repair करना, `--include-all` चलाना या workflow trigger करना अभी नहीं। पहले isolated scratch repo में exact pinned CLI 3.0.0 पर synthetic versions का no-DB comparison/reproduction चलाएँ; इसके लिए उपलब्ध environment में CLI/PostgreSQL/Docker नहीं हैं। CLI sorting risk और actual remote history दोनों verify किए बिना कोई migration history action नहीं।


### 8. CLI 3.0.0 source-level verification — 15 Nov 2026

- Supabase CLI tag `v3.0.0` का exact source tree inspect किया। `apps/cli/src/command-internal/db-push-core.ts` का db-push path `findPendingMigrations(local, remote)` call करता है।
- उसी tag के `migration-pending.ts` में local paths को `sortMigrationPathsByVersion` से version-order में re-sort किया जाता है; `migration-history.ts` में shared sorter है।
- CLI 3.0.0 के `migration-pending.unit.test.ts` में खास regression test मौजूद है: 8-digit `20260420` और 14-digit `20260420010000` shared prefix pair, remote versions के same order में होने पर `kind: ok` देता है। दूसरा test mixed-width pending migrations का version order verify करता है।
- इसलिए पहले दर्ज किया गया CLI 3.0.0 db-push sorting risk **source-level पर addressed दिखता है**; यह अब CLI 3.0.0 TypeScript db-push path के लिए confirmed blocker नहीं है। फिर भी यह source inspection है, local CLI execution नहीं।
- Supabase CLI issue #6682 अलग Go implementation के लिए था; v3.0.0 db-push path inspected TypeScript implementation use करता है। इस issue को हमारे current pinned db-push workflow पर लागू defect नहीं मानें।
- Repository में दो 8-digit `20261109` files की duplicate version history concern अलग से बनी हुई है: source sorting test exact prefix pair ordering cover करता है, लेकिन duplicate exact same version identifiers को दो अलग migrations के रूप में लागू करने की policy नहीं। Rename/history repair अभी भी नहीं।


### Exact duplicate migration version — separate unresolved history blocker (15 Nov 2026)

- Re-read both exact files sharing version `20261109`:
  - `20261109_allow_quote_approval_booking_states.sql` (adds booking status/assignment constraints)
  - `20261109_electrician_inspection_quotes_and_service_only_commission.sql` (adds quote/workflow columns and RPCs, and repeats the booking status/assignment constraints)
- These are not merely 8-digit vs 14-digit prefix ordering. They have the **same exact version key**. Supabase migration history stores version as the primary key, so two distinct migration files cannot safely be represented as two separate applied rows under that same key.
- Existing Node uniqueness test explicitly allow-lists this pair as a known legacy collision. That is a detection/exception, not proof that both were applied or that remote history matches.
- The file contents overlap on booking status and assignment constraints. Do not delete, merge, rename, re-sequence, or repair history without establishing which version is recorded remotely and the intended source lineage. No remote history query performed.
- Node CI for latest docs commit `a84ea1e` completed successfully. This verifies repository Node tests only; it does not validate remote Supabase migration history or execute SQL.
- GPT-2 checklist remains 27/39 = 69%; no checklist closure claimed.
