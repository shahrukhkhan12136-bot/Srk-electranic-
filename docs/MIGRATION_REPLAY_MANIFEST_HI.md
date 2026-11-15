# SRK ELECTRONIC — Migration Replay Manifest (Static, Hindi)

**स्थिति:** Static inventory only — यह execution-ready replay plan नहीं है।  
**जाँचा गया commit:** `deb26b55384bf6276f36d9625f750cbce215773b`  
**कुल SQL migrations:** 71  
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

### D. Refund, KYC, accounting, Route, Push and final financial hardening (25)

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
