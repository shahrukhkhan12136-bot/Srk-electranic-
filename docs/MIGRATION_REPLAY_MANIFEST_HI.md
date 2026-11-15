# SRK ELECTRONIC — Migration Replay Manifest (Static, Hindi)

**स्थिति:** Static inventory only — यह execution-ready replay plan नहीं है।  
**जाँचा गया commit:** `c3a34066edcfd8a67a95317ea0a880fb7c766a11`  
**कुल SQL migrations:** 77  
**Production:** कोई access/apply नहीं। PostgreSQL/pgTAP runtime नहीं चला।

## 1. महत्त्वपूर्ण रोक (Do not replay yet)

1. Duplicate 8-digit version prefix `20261109`:
   - `20261109_allow_quote_approval_booking_states.sql`
   - `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
   Source history में duplicate/follow-up संकेत हैं, लेकिन remote Supabase migration history और deployed body का प्रमाण नहीं है। Rename, delete या history edit न करें।
2. Starter schema में `service_bookings.amount_paid` नहीं है। Historical source/deployment artifact से इसका exact type, precision, nullability, default और constraints अभी नहीं मिले।
3. Starter schema `electrician_profiles.user_id` जोड़ता है, लेकिन `auth_user_id` की मूल column definition अभी नहीं मिली।
4. Support conversation migration `srk_booking_complaints` parent table को पहले से मौजूद मानती है; जाँची गई migration files में उसका मूल CREATE TABLE source अभी नहीं मिला।
5. Push prerequisite के लिए historical branch `feature/electrician-categories-hourly-booking` में staged migration `20261111020000_add_electrician_push_subscriptions.sql` मिली। उसी exact 1,317-byte SQL source (blob `33ea8450fe892d40e6fab818c535aae53caf39f1`) को वर्तमान Feature Branch में पुनर्स्थापित किया गया। यह source recovery है, Production deployment या runtime validation का प्रमाण नहीं। बाद की outbox/ledger migrations आवश्यक columns से मेल खाती दिखती हैं; full replay अभी बाकी है।
6. Historical starter SQL complete current baseline नहीं है। Production schema parity, exact column contracts, RLS/ACL, trigger/function dependencies और existing migration history सत्यापित नहीं।
7. इसलिए नीचे की सूची executable replay order नहीं है। पहले authoritative base schema और remote history के स्वीकृत read-only प्रमाण चाहिए।

## 2. Static filename/version-sorted inventory

यह सूची वर्तमान Feature Branch commit `c3a34066edcfd8a67a95317ea0a880fb7c766a11` के recursive Git tree से बनाई गई है। कुल 77 SQL migration files हैं। यह केवल filename/version inventory है; duplicate 8-digit `20261109` entries को अभी भी अलग remote migration identities मानकर replay नहीं करना है।

1. `20261108120608_add_public_api_rate_limiting.sql`
2. `20261108120658_enable_rls_public_api_rate_limits.sql`
3. `20261108121115_add_customer_account_booking_access.sql`
4. `20261108233500_restrict_public_form_inserts.sql`
5. `20261108234000_combine_booking_read_policy.sql`
6. `20261109000500_harden_electrician_profile_identity_linking.sql`
7. `20261109001000_add_google_maps_location_support.sql`
8. `20261109001500_unique_electrician_admin_identity_linking.sql`
9. `20261109002000_expose_assigned_booking_map_pin.sql`
10. `20261109003000_secure_commission_reporting.sql`
11. `20261109010000_create_secure_wallet_ledger_foundation.sql`
12. `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql`
13. `20261109103038_customer_electrician_direct_call_contacts.sql`
14. `20261109103143_move_customer_call_contact_lookup_to_private.sql`
15. `20261109_allow_quote_approval_booking_states.sql`
16. `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
17. `20261110140000_restore_missing_customer_booking_quote_columns.sql`
18. `20261111020000_add_electrician_push_subscriptions.sql`
19. `20261113220000_customer_support_conversation_schema.sql`
20. `20261113230000_support_attachment_paths_and_admin_message_list.sql`
21. `20261114125844_restore_financial_audit_core_schema.sql`
22. `20261114130000_harden_electrician_profile_identity_linking.sql`
23. `20261114150000_customer_booking_submission_idempotency.sql`
24. `20261114160000_customer_selected_rate_tier_and_server_estimate.sql`
25. `20261114180000_harden_customer_avatar_object_integrity.sql`
26. `20261114190000_customer_receipt_immutable_labour_amount.sql`
27. `20261114200000_customer_payment_refund_history_rpc.sql`
28. `20261114201428_customer_profile_saved_addresses_private_storage.sql`
29. `20261114202250_customer_complaint_customer_safe_projection.sql`
30. `20261114202656_customer_change_payment_method_rpc.sql`
31. `20261114210000_sequential_nearest_offer_dispatch.sql`
32. `20261114220000_admin_approved_electrician_relocation.sql`
33. `20261114230000_recheck_electrician_current_area_before_offer.sql`
34. `20261114240000_server_authoritative_customer_approved_work_timer.sql`
35. `20261114250000_admin_work_dispute_review_and_immutable_history.sql`
36. `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql`
37. `20261114270000_admin_only_cancellation_requests_and_decisions.sql`
38. `20261114280000_cancellation_fee_carry_forward_and_accounting.sql`
39. `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`
40. `20261114300000_admin_customer_support_thread_replies.sql`
41. `20261114310000_electrician_self_availability.sql`
42. `20261114320000_booking_scoped_live_electrician_location.sql`
43. `20261114330000_electrician_private_kyc_document_preview.sql`
44. `20261114340000_electrician_self_profile_name_edit.sql`
45. `20261114350000_electrician_support_tickets_and_admin_inbox.sql`
46. `20261114360000_new_category_electrician_payout_reconciliation.sql`
47. `20261114370000_electrician_offer_details_immediate_booking_fields.sql`
48. `20261114380000_electrician_phone_change_admin_approval.sql`
49. `20261114390000_admin_staff_rbac_foundation.sql`
50. `20261114410000_razorpay_webhook_event_inbox.sql`
51. `20261115091906_retire_unused_legacy_accept_electrician_job.sql`
52. `20261115092149_retire_unused_razorpay_route_transfer_ledger.sql`
53. `20261115100000_customer_refund_request_contract.sql`
54. `20261115110000_admin_refund_review_queue_and_decisions.sql`
55. `20261115120000_durable_razorpay_refund_recovery_evidence.sql`
56. `20261115120001_fix_multi_profile_electrician_labour_bill_access.sql`
57. `20261115130000_admin_manual_refund_request_completion.sql`
58. `20261115140000_electrician_kyc_review_and_activation_gate.sql`
59. `20261115145900_fix_multi_profile_electrician_labour_bill_access.sql`
60. `20261115150000_admin_readonly_booking_accounting_reconciliation.sql`
61. `20261115160000_legacy_booking_status_write_guard.sql`
62. `20261115170000_admin_route_transfer_accounting_reconciliation.sql`
63. `20261115170001_durable_push_delivery_outbox.sql`
64. `20261115180000_admin_route_recipient_and_settlement_validation.sql`
65. `20261115180001_push_subscription_delivery_ledger.sql`
66. `20261115190000_enforce_single_primary_route_bank_link.sql`
67. `20261115190001_push_delivery_health_monitoring.sql`
68. `20261115200000_harden_financial_admin_rpc_search_path.sql`
69. `20261115200001_push_delivery_lease_fencing.sql`
70. `20261115210000_legacy_manual_payment_and_itemized_receipt.sql`
71. `20261115210001_harden_legacy_financial_read_rpc_search_paths.sql`
72. `20261115220000_retire_live_legacy_quotation_rpcs.sql`
73. `20261115230000_admin_booking_direct_write_closure.sql`
74. `20261115240000_harden_refund_recovery_full_amount.sql`
75. `20261115250000_harden_refund_reconcile_full_amount.sql`
76. `20261115260000_sos_admin_support_alerts.sql`
77. `20261115270000_fix_customer_payment_method_unicode_contract.sql`

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

77 files की SQL text को migration-by-migration scan किया गया। नीचे सूचीबद्ध object names source में CREATE/ALTER या function definition के रूप में मिले; यह semantic SQL parser या PostgreSQL execution नहीं है। Dynamic SQL, unqualified names, `DO` blocks और indirect function calls के कारण इसे पूर्ण dependency graph नहीं माना जाए।

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


### Duplicate 20261109 lineage — historical Git chronology recovered (15 Nov 2026)

- Git path history establishes a concrete sequence:
  1. `073d59e` (08:00:19Z): first recorded inspection-quote workflow migration commit.
  2. `04d0c02` (08:01:17Z): the same `electrician_inspection_quotes_and_service_only_commission.sql` file changed from a one-line “Applied migration” placeholder to the full 99-line SQL migration.
  3. `b5e5b3b` (08:04:11Z): that full migration was extended with the booking status and assignment constraints.
  4. `cd2c46e` (08:04:25Z): a second file, `20261109_allow_quote_approval_booking_states.sql`, was newly added with only those same two constraints.
- The full quote migration already contains the same two constraint statements at its end. The later-added second file therefore duplicates the constraint work in source; it is not an independent feature migration.
- This chronology strongly suggests the second file was an accidental duplicate follow-up. It does **not** prove which SQL file was actually applied to the remote database or whether version `20261109` exists in its history. No remote query was run.
- Safe decision: keep both files untouched for now. Do not delete or rename the second file, because remote history state remains unknown and migration version is the ledger key. Before cleanup, establish the remote applied-version row through an approved read-only schema/history export and reconcile with deployment records.
- Node CI had passed on commit `a84ea1e`; no SQL replay/runtime assertion follows from that.


### Original placeholder lineage and CI verification — 15 Nov 2026

- Full Git path history adds an earlier event: `073d59e` first introduced the 8-digit quote migration path as a one-line comment saying the migration was already applied under the live Supabase migration name `electrician_inspection_quotes_and_service_only_commission`.
- `04d0c02` replaced that one-line marker with the full SQL body; `b5e5b3b` appended the two booking-state/assignment constraints; `cd2c46e` then introduced the second same-version file containing those exact two constraints.
- This makes the likely source-history explanation clearer: the full quote migration path began as a marker for a separately named live migration, then was later populated with SQL, followed by a duplicate constraint-only migration path. It remains only a Git-source lineage finding, not proof of remote ledger rows or actual applied SQL.
- The `d106ec8` commit's Feature Branch Node tests workflow completed successfully (run 43733401357). This is Node CI only; it does not execute PostgreSQL/pgTAP or establish Production migration parity.
- No files renamed/deleted; no migration repair or Production operation. GPT-2 remains 27/39 = 69%.


## अतिरिक्त prerequisite सत्यापन — 15 नवम्बर 2026

### Support conversation base table
- `20261113220000_customer_support_conversation_schema.sql` creates
  `srk_booking_complaint_messages` and attachment rows, but its foreign keys
  and RPCs require the pre-existing `public.srk_booking_complaints` table.
- The migration contains references to the complaint parent; it does not
  create the parent table itself.
- The inspected migration tree has no authoritative
  `CREATE TABLE srk_booking_complaints` declaration. The current search
  surfaced only consumers, not a base-table DDL source.
- Therefore the support conversation chain has a separate base-object gate.
  Obtain its original schema/deployment artifact or approved schema-only
  catalog export before replay. Do not synthesize the parent table contract.

### Push subscription base table
- `20261115170001_durable_push_delivery_outbox.sql` explicitly checks
  `to_regclass('public.srk_push_subscriptions')` and raises a prerequisite
  error if the base table is absent. It also checks for expected columns
  before applying RLS and creating the durable outbox.
- `20261115180001_push_subscription_delivery_ledger.sql` again requires
  `public.srk_push_subscriptions` and adds delivery-ledger references to
  its `id` column.
- The inspected current migration tree contains consumers and prerequisite
  checks, but no authoritative base-table CREATE declaration. The repository
  UI's upsert is consumer evidence only; it does not establish the full table
  definition, indexes, RLS, grants or policies.
- Do not invent a replacement subscription table. Obtain its original
  migration/deployment artifact or approved schema-only catalog export.

### Replay inventory correction
- Current Feature Branch recursive tree inventory: **73 SQL migration files**.
- The earlier manifest header/list of 77 files predates the latest SOS
  migration `20261115260000_sos_admin_support_alerts.sql`. The dependency
  matrix already records 73. This is a documentation count correction only;
  it does not alter migration filenames or replay history.

### Updated blocking prerequisites
A clean replay requires authoritative base contracts for:
1. `service_bookings.amount_paid`
2. `electrician_profiles.auth_user_id`
3. `public.srk_booking_complaints`
4. `public.srk_push_subscriptions`

The first two are missing starter-column definitions; the latter two are
parent/base tables assumed by later migrations. These are independent
prerequisite gates. No PostgreSQL replay or Production query was run.


## 6. Historical push subscription base migration recovery — 15 Nov 2026
- पुराने branch `feature/electrician-categories-hourly-booking` में `20261111020000_add_electrician_push_subscriptions.sql` मिली; Git blob SHA `33ea8450fe892d40e6fab818c535aae53caf39f1`।
- वही source current Feature Branch पर उसी migration filename के साथ restore किया गया; commit `c3a34066edcfd8a67a95317ea0a880fb7c766a11`।
- यह `srk_push_subscriptions` की मूल table, primary key, Auth user FK, endpoint unique constraint, Web Push key columns, timestamps, user index और own-row RLS policy define करती है।
- `20261115170001_durable_push_delivery_outbox.sql` की preflight अपेक्षित `id,user_id,endpoint,p256dh,auth` columns से मेल खाती है; `20261115180001_push_subscription_delivery_ledger.sql` की FK `id` से मेल खाती है।
- कोई database पर migration apply नहीं की गई। PostgreSQL runtime/pgTAP replay अभी नहीं चला; staged historical migration को Production-ready न माना जाए।

## 9. Latest prerequisite status correction — 15 Nov 2026

- Section 5's earlier 73-file count and four-item prerequisite list are a historical snapshot; they are superseded by the later source recovery recorded in Section 6 and the current 77-file inventory in Sections 1–2.
- The original migration `20261111020000_add_electrician_push_subscriptions.sql` has been restored from the historical branch. It defines `public.srk_push_subscriptions`; its required columns match the later outbox/ledger references at static source level. This is not a database replay or runtime validation.
- The currently unresolved base prerequisites are therefore:
  1. `service_bookings.amount_paid`
  2. `electrician_profiles.auth_user_id`
  3. `public.srk_booking_complaints`
- The support complaint parent table remains unresolved. The reviewed complaint/support migrations consume it but do not create it. No authoritative CREATE TABLE source has been recovered.
- Current inventory remains 77 SQL migration files. No checklist completion percentage is increased by this documentation correction; no Production access or migration execution occurred.

## 10. Support event-ledger dependency found — 15 Nov 2026

- Migration `20261114202250_customer_complaint_customer_safe_projection.sql` inserts customer-created complaint events into `public.srk_booking_complaint_events`; it also reads `public.srk_booking_complaints`.
- The inspected Feature Branch migration inventory and exact-name source search did not locate an authoritative `CREATE TABLE public.srk_booking_complaint_events` declaration. This is a separate prerequisite from the complaint parent table.
- The current support chain therefore has two unresolved base-table contracts: `public.srk_booking_complaints` and `public.srk_booking_complaint_events`. Do not infer columns, keys, status checks, append-only behavior, RLS or grants from the insert/read consumers.
- The unresolved clean-replay prerequisites are now four objects/columns: `service_bookings.amount_paid`, `electrician_profiles.auth_user_id`, `public.srk_booking_complaints`, and `public.srk_booking_complaint_events`. Push subscriptions are excluded from this list because their original migration source has been restored (static review only).
- No SQL was synthesized or applied; no Production migration history or catalog was queried.
