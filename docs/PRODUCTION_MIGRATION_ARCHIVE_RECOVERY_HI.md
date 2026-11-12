# Production Migration Archive Recovery — Updated 2026-11-12

## Read-only archive search

Production migration history की 78 entries को repository की सभी 11 branches के migration trees से मिलाया गया।

- Production history rows: **78**
- Branches inspected: **11**
- Matching migration-name source candidates: **39 rows / 38 unique names**
- Exact Production version + migration name filename candidates: **14 rows / 13 unique names**
- Same migration name, different filename version: **25 rows**
- No matching-name source in any inspected branch: **39 rows**

Historical branch commit used as a major source:
- `work/separate-customer-electrician-portals`
- Commit `0fe5ef479e3ce69e9b219721599ebd52f6ba73ee`
- Commit timestamp: 2026-11-11 05:11:33 UTC
- Other candidates also came from `feature/flutter-mobile-apps`, `feature/electrician-categories-hourly-booking`, and the current feature branch.

## Full Production history → best repository source candidate

| Production version | Production migration name | Candidate source | Classification |
|---|---|---|---|
| `20261108092928` | `harden_srk_rls_policy_performance` | अभी source नहीं मिला | Unresolved |
| `20261108093725` | `add_atomic_payment_order_lock` | अभी source नहीं मिला | Unresolved |
| `20261108093757` | `add_service_role_policy_payment_order_locks` | अभी source नहीं मिला | Unresolved |
| `20261108094007` | `harden_security_definer_function_search_paths` | अभी source नहीं मिला | Unresolved |
| `20261108095224` | `add_missing_foreign_key_indexes` | अभी source नहीं मिला | Unresolved |
| `20261108095928` | `add_actual_paid_amount_commission_and_status_history` | अभी source नहीं मिला | Unresolved |
| `20261108102159` | `harden_payment_order_lock_search_paths` | अभी source नहीं मिला | Unresolved |
| `20261108102323` | `harden_booking_broadcast_search_path` | अभी source नहीं मिला | Unresolved |
| `20261108102612` | `harden_booking_guard_trigger_search_path` | अभी source नहीं मिला | Unresolved |
| `20261108102837` | `enable_realtime_job_offer_updates` | अभी source नहीं मिला | Unresolved |
| `20261108102951` | `enable_realtime_electrician_profile_updates` | अभी source नहीं मिला | Unresolved |
| `20261108103531` | `guard_booking_assignment_and_amount_integrity` | अभी source नहीं मिला | Unresolved |
| `20261108115205` | `tighten_legacy_definer_paths_and_history_grants` | अभी source नहीं मिला | Unresolved |
| `20261108120608` | `add_public_api_rate_limiting` | `20261108120608_add_public_api_rate_limiting.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261108120658` | `enable_rls_public_api_rate_limits` | `20261108120658_enable_rls_public_api_rate_limits.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261108121115` | `add_customer_account_booking_access` | `20261108121115_add_customer_account_booking_access.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261108181453` | `restrict_public_form_inserts_to_server_functions` | अभी source नहीं मिला | Unresolved |
| `20261108181538` | `combine_admin_customer_booking_read_policy` | अभी source नहीं मिला | Unresolved |
| `20261108183027` | `add_google_maps_location_support` | `20261109001000_add_google_maps_location_support.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261108183324` | `expose_assigned_booking_map_pin` | `20261109002000_expose_assigned_booking_map_pin.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261108184254` | `electrician_earnings_summary` | अभी source नहीं मिला | Unresolved |
| `20261108184815` | `protect_commission_columns_and_admin_report` | अभी source नहीं मिला | Unresolved |
| `20261108184938` | `limit_booking_updates_and_correct_earnings_timestamp` | अभी source नहीं मिला | Unresolved |
| `20261108190047` | `create_secure_wallet_ledger_foundation` | `20261109010000_create_secure_wallet_ledger_foundation.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261108193506` | `create_server_only_razorpay_route_transfer_ledger` | `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109052929` | `harden_wallet_reporting_rpc_paths_and_route_recipient_index` | अभी source नहीं मिला | Unresolved |
| `20261109053005` | `harden_wallet_and_commission_security_definer_paths` | अभी source नहीं मिला | Unresolved |
| `20261109053301` | `grant_authenticated_select_service_bookings` | अभी source नहीं मिला | Unresolved |
| `20261109053328` | `grant_authenticated_select_job_offers_for_rls_realtime` | अभी source नहीं मिला | Unresolved |
| `20261109075837` | `electrician_inspection_quotes_and_service_only_commission` | `20261109_electrician_inspection_quotes_and_service_only_commission.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109080121` | `lock_quote_workflow_rpcs_to_authenticated_users` | अभी source नहीं मिला | Unresolved |
| `20261109080400` | `allow_quote_approval_booking_states` | `20261109_allow_quote_approval_booking_states.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109081310` | `srk_manual_electrician_payout_ledger` | अभी source नहीं मिला | Unresolved |
| `20261109082241` | `index_electrician_payout_foreign_keys` | अभी source नहीं मिला | Unresolved |
| `20261109082620` | `lock_down_route_transfer_api_access` | अभी source नहीं मिला | Unresolved |
| `20261109094209` | `add_secure_admin_booking_offer_flow` | अभी source नहीं मिला | Unresolved |
| `20261109103038` | `customer_electrician_direct_call_contacts` | `20261109103038_customer_electrician_direct_call_contacts.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261109103143` | `move_customer_call_contact_lookup_to_private` | `20261109103143_move_customer_call_contact_lookup_to_private.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261109110140` | `align_electrician_payouts_with_booking_commission_rate` | अभी source नहीं मिला | Unresolved |
| `20261109112032` | `allow_electricians_to_read_own_manual_payout_status` | अभी source नहीं मिला | Unresolved |
| `20261109112105` | `consolidate_electrician_payout_read_policy` | अभी source नहीं मिला | Unresolved |
| `20261109114000` | `protect_customer_and_electrician_phone_numbers_until_masked_calling` | अभी source नहीं मिला | Unresolved |
| `20261109114642` | `enable_direct_customer_electrician_phone_calls` | अभी source नहीं मिला | Unresolved |
| `20261109161539` | `customer_contact_after_completion` | `20261109190000_customer_contact_after_completion.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109161545` | `hide_customer_details_on_cancelled_bookings` | `20261109193000_hide_customer_details_on_cancelled_bookings.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109163755` | `fix_null_validation_quote_and_payout` | `20261109210000_fix_null_validation_quote_and_payout.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109164808` | `sync_electrician_auth_profile_link` | `20261109223000_sync_electrician_auth_profile_link.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109165802` | `harden_electrician_payable_trigger_search_path` | `20261109165802_harden_electrician_payable_trigger_search_path.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261109170626` | `expire_job_offers_when_booking_cancelled` | `20261109235500_expire_job_offers_when_booking_cancelled.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109170937` | `secure_admin_booking_updates_and_profile_columns` | `20261109235000_secure_admin_booking_updates_and_profile_columns.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109171033` | `tighten_admin_booking_rpc_input_validation` | `20261109235930_tighten_admin_booking_rpc_input_validation.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109171621` | `add_admin_verified_manual_payment_workflow` | `20261109171621_add_admin_verified_manual_payment_workflow.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261109171942` | `add_admin_verified_manual_refund_workflow` | `20261109171942_add_admin_verified_manual_refund_workflow.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261109174234` | `allow_manual_payment_payout_settlement` | `20261109173000_allow_manual_payment_payout_settlement.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109175023` | `serialize_manual_refund_and_electrician_payout` | `20261109234500_serialize_manual_refund_and_electrician_payout.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109180001` | `fix_manual_payout_special_forms` | `20261109180001_fix_manual_payout_special_forms.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261109202321` | `admin_audit_log` | `20261110060000_admin_audit_log.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109202355` | `razorpay_refund_tables_and_audit_type` | अभी source नहीं मिला | Unresolved |
| `20261109202505` | `razorpay_refund_prepare_rpc` | अभी source नहीं मिला | Unresolved |
| `20261109202511` | `razorpay_refund_list_rpc` | अभी source नहीं मिला | Unresolved |
| `20261109202534` | `razorpay_refund_audit_trigger` | अभी source नहीं मिला | Unresolved |
| `20261109203132` | `customer_admin_complaints` | `20261110040000_customer_admin_complaints.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261109203137` | `electrician_verification_documents` | `20261110050000_electrician_verification_documents.sql` — `work/separate-customer-electrician-portals` | Same name; version differs |
| `20261110080448` | `srk_business_finance_dashboard` | `20261110080448_srk_business_finance_dashboard.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261110133835` | `restore_missing_customer_booking_quote_columns` | `20261110140000_restore_missing_customer_booking_quote_columns.sql` — `feature/electrician-categories-hourly-booking` | Same name; version differs |
| `20261110140719` | `add_electrician_offer_price_details_rpc` | `20261110220000_add_electrician_offer_price_details_rpc.sql` — `feature/flutter-mobile-apps` | Same name; version differs |
| `20261110141125` | `add_assigned_booking_quote_ui_rpc` | `20261110223000_add_assigned_booking_quote_ui_rpc.sql` — `feature/flutter-mobile-apps` | Same name; version differs |
| `20261110142310` | `add_order_accepted_phone_visibility` | `20261110195000_add_order_accepted_phone_visibility.sql` — `feature/flutter-mobile-apps` | Same name; version differs |
| `20261110143332` | `add_admin_booking_contact_visibility` | `20261110200000_add_admin_booking_contact_visibility.sql` — `feature/flutter-mobile-apps` | Same name; version differs |
| `20261111043852` | `srk_business_finance_reporting_dates` | `20261111043852_srk_business_finance_reporting_dates.sql` — `work/separate-customer-electrician-portals` | Exact version+name |
| `20261111072823` | `add_electrician_push_subscriptions` | `20261111020000_add_electrician_push_subscriptions.sql` — `feature/electrician-categories-hourly-booking` | Same name; version differs |
| `20261111072827` | `secure_push_subscription_upsert` | `20261111120000_secure_push_subscription_upsert.sql` — `feature/production-push-notifications` | Same name; version differs |
| `20261111073357` | `enable_pg_net_for_electrician_push` | अभी source नहीं मिला | Unresolved |
| `20261111075205` | `wire_job_offer_push_webhook` | अभी source नहीं मिला | Unresolved |
| `20261111082515` | `add_assigned_electrician_cash_payment_status` | `20261111082515_add_assigned_electrician_cash_payment_status.sql` — `feature/production-push-notifications` | Exact version+name |
| `20261111083811` | `add_assigned_electrician_cash_payment_status` | `20261111082515_add_assigned_electrician_cash_payment_status.sql` — `feature/production-push-notifications` | Exact version+name |
| `20261111142316` | `retire_empty_legacy_electrician_booking_tables` | अभी source नहीं मिला | Unresolved |
| `20261111153846` | `srk_booking_refund_requests_workflow` | `20261111153846_srk_booking_refund_requests_workflow.sql` — `feature/production-push-notifications` | Exact version+name |

## Content comparison findings

Seven migration files were directly compared between the historical archive and the current feature branch; their Git blob SHAs were byte-identical:

1. Google Maps location support
2. Assigned booking map pin
3. Secure wallet ledger foundation
4. Server-only Razorpay Route transfer ledger
5. Quote approval booking states
6. Electrician inspection quotes and service-only commission
7. Restore missing customer booking quote columns

Important exception:
- Historical `20261111020000_add_electrician_push_subscriptions.sql` and current `20261111090000_add_electrician_push_subscriptions.sql` are **not byte-identical**.
- The historical version uses one broad owner policy, different endpoint/key checks, and includes `user_agent`.
- The current version has separate owner policies, different constraints, and no `user_agent`.
- Production records `20261111072823_add_electrician_push_subscriptions`. The exact Production-applied SQL remains unresolved.

The Production history also contains duplicate `add_assigned_electrician_cash_payment_status` entries at versions `20261111082515` and `20261111083811`. The current branch has only the first exact-version file. The second Production row must not be treated as duplicate/no-op without recovering its SQL or proving its effect.

## Unresolved Production sources

The following 39 Production history rows still have no matching-name SQL file in any inspected repository branch:

- `20261108092928` — `harden_srk_rls_policy_performance`
- `20261108093725` — `add_atomic_payment_order_lock`
- `20261108093757` — `add_service_role_policy_payment_order_locks`
- `20261108094007` — `harden_security_definer_function_search_paths`
- `20261108095224` — `add_missing_foreign_key_indexes`
- `20261108095928` — `add_actual_paid_amount_commission_and_status_history`
- `20261108102159` — `harden_payment_order_lock_search_paths`
- `20261108102323` — `harden_booking_broadcast_search_path`
- `20261108102612` — `harden_booking_guard_trigger_search_path`
- `20261108102837` — `enable_realtime_job_offer_updates`
- `20261108102951` — `enable_realtime_electrician_profile_updates`
- `20261108103531` — `guard_booking_assignment_and_amount_integrity`
- `20261108115205` — `tighten_legacy_definer_paths_and_history_grants`
- `20261108181453` — `restrict_public_form_inserts_to_server_functions`
- `20261108181538` — `combine_admin_customer_booking_read_policy`
- `20261108184254` — `electrician_earnings_summary`
- `20261108184815` — `protect_commission_columns_and_admin_report`
- `20261108184938` — `limit_booking_updates_and_correct_earnings_timestamp`
- `20261109052929` — `harden_wallet_reporting_rpc_paths_and_route_recipient_index`
- `20261109053005` — `harden_wallet_and_commission_security_definer_paths`
- `20261109053301` — `grant_authenticated_select_service_bookings`
- `20261109053328` — `grant_authenticated_select_job_offers_for_rls_realtime`
- `20261109080121` — `lock_quote_workflow_rpcs_to_authenticated_users`
- `20261109081310` — `srk_manual_electrician_payout_ledger`
- `20261109082241` — `index_electrician_payout_foreign_keys`
- `20261109082620` — `lock_down_route_transfer_api_access`
- `20261109094209` — `add_secure_admin_booking_offer_flow`
- `20261109110140` — `align_electrician_payouts_with_booking_commission_rate`
- `20261109112032` — `allow_electricians_to_read_own_manual_payout_status`
- `20261109112105` — `consolidate_electrician_payout_read_policy`
- `20261109114000` — `protect_customer_and_electrician_phone_numbers_until_masked_calling`
- `20261109114642` — `enable_direct_customer_electrician_phone_calls`
- `20261109202355` — `razorpay_refund_tables_and_audit_type`
- `20261109202505` — `razorpay_refund_prepare_rpc`
- `20261109202511` — `razorpay_refund_list_rpc`
- `20261109202534` — `razorpay_refund_audit_trigger`
- `20261111073357` — `enable_pg_net_for_electrician_push`
- `20261111075205` — `wire_job_offer_push_webhook`
- `20261111142316` — `retire_empty_legacy_electrician_booking_tables`

## What this recovery does and does not prove

- It recovers candidate source files from repository branches; it does **not** prove those bytes were the exact SQL executed in Production.
- Exact version + name filenames are stronger evidence but still need comparison with an owner-controlled deployment artifact, Supabase backup, CLI migration archive, or other trusted source.
- Same-name/different-version candidates require statement-by-statement comparison and schema-effect review.
- Current schema objects do not prove which historical migration created them.
- No migration may be skipped, replayed, renamed, inserted into history, or marked applied based only on this register.

## Required next steps

1. Recover exact Production SQL for all unresolved entries, prioritizing the early security, payment-lock, RLS, refund-foundation and push-webhook migrations.
2. Compare every candidate file with the trusted Production-applied SQL where available.
3. Compare resulting tables, columns, constraints, indexes, functions, triggers, RLS policies, grants and relevant data invariants.
4. Build a per-migration disposition: exact source verified, already represented, superseded, pending forward migration, or unresolved.
5. Run clean and second migration replays on a disposable Production-parity database.
6. Keep Production read-only until all release gates and explicit owner approval are satisfied.

**Release decision remains NO-GO.** No Production database, data, migration history, live payment, or deployment was changed by this archive search.

## अतिरिक्त स्रोत खोज + Production schema-effect inventory — 2026-11-12

### GitHub history खोज
- शुरुआती 13 unresolved security/payment-lock migrations के exact Production filename paths के लिए GitHub commit-history API जाँची गई। इन exact paths के लिए कोई commit history नहीं मिली; deleted-file recovery से भी SQL प्राप्त नहीं हुआ।
- सभी 11 branch tips के migration trees पुनः जाँचे; unresolved keywords (RLS, payment-order lock, search_path, FK indexes, realtime, booking guards) के alternate-name migration files नहीं मिले।
- इसका अर्थ यह नहीं कि SQL कहीं और मौजूद नहीं है; केवल inspected GitHub branches और exact paths में उपलब्ध नहीं मिला।

### Production में read-only catalog से सत्यापित प्रभाव
ये बातें live catalog की वर्तमान स्थिति हैं; ये migration source SQL या किस migration ने object बनाया, इसका प्रमाण नहीं हैं।

**RLS / policies**
- public की सभी 25 base tables पर RLS enabled है; FORCE ROW LEVEL SECURITY सभी पर false है।
- service_bookings, electrician_profiles, job_offers, service_booking_status_history और srk_payment_order_locks पर मौजूदा policies catalog से पढ़ी गईं।
- srk_payment_order_locks पर केवल service_role के लिए ALL policy दिखी; table का primary key booking_id है और booking FK मौजूद है।
- service_bookings पर Admin/customer SELECT policy तथा Admin UPDATE policy मौजूद है। job_offers और electrician_profiles पर authenticated owner/Admin read policies मौजूद हैं।
- यह वर्तमान policy set है, historical policy changes की पूरी श्रृंखला नहीं।

**Payment-order lock / booking integrity**
- srk_payment_order_locks की वर्तमान संरचना: booking_id PK/FK, lock_token, locked_until, created_at।
- srk_claim_payment_order_lock(uuid) और srk_release_payment_order_lock(uuid,uuid) SECURITY DEFINER functions मौजूद हैं; दोनों का search_path=pg_catalog, public, pg_temp है।
- service_bookings पर booking guard, booking broadcast, commission calculation, status history, cancellation-offer expiry और electrician-payable triggers मौजूद हैं।
- कुछ FK/search indexes मौजूद हैं; उदाहरण: job_offers(booking_id,created_at DESC), service_booking_status_history(booking_id,changed_at DESC), srk_electrician_payouts(electrician_profile_id)। यह संपूर्ण FK-index coverage का प्रमाण नहीं है।

**SECURITY DEFINER / search_path**
- वर्तमान catalog में कई SECURITY DEFINER functions के search_path explicitly pg_catalog से शुरू होते हैं।
- कुछ privileged functions में search_path खाली है; उदाहरण के लिए refund reconciliation और कुछ refund admin/customer RPCs। Empty search_path अपने-आप में सुरक्षित या असुरक्षित होने का अंतिम निष्कर्ष नहीं है—function bodies में object qualification और EXECUTE grants भी जाँचना आवश्यक है।
- private.srk_save_push_subscription में search_path खाली; private.srk_notify_job_offer_push में search_path=pg_catalog है।
- इस inventory से शुरुआती harden_security_definer_function_search_paths या tighten_legacy_definer_paths_and_history_grants migrations की exact SQL recover नहीं होती।

### शेष कार्य / निष्कर्ष
1. 13 शुरुआती unresolved migrations के exact GitHub paths पर history search खाली रही। इनके लिए owner-controlled local migration archive, Supabase CLI migration artifact, backup/export या deployment bundle आवश्यक है।
2. अगले catalog pass में SECURITY DEFINER functions के complete definitions, EXECUTE grants (PUBLIC/anon/authenticated/service_role), FK index coverage और RLS policy expressions का per-object register बनाना होगा।
3. Live catalog effect को candidate source के रूप में उपयोग किया जा सकता है, लेकिन historical SQL का विकल्प नहीं बनाया जाएगा।
4. Production पर कोई SQL/DDL/DML, migration-history update, payment call या deployment नहीं किया गया।

**NO-GO जारी है।** Exact historical SQL और disposable Production-parity replay मिलने तक release approval नहीं।

### SECURITY DEFINER grants और function-body checks — read-only follow-up
- Catalog ACL inventory में audited SECURITY DEFINER functions पर PUBLIC या anon EXECUTE grant नहीं दिखा। Admin RPCs पर authenticated EXECUTE grant मौजूद है, लेकिन inspected refund Admin RPC bodies शुरुआत में auth.uid() null check और public.is_srk_admin() check करती हैं।
- srk_customer_create_booking_refund_request authenticated caller की auth.uid() से booking ownership मिलाती है; customer refund-list RPC केवल उसी customer_user_id की rows लौटाती है।
- srk_service_reconcile_booking_refund पर EXECUTE केवल postgres और service_role को मिला; body service_role assertion भी करती है।
- Empty search_path वाले refund functions के bodies में table/function references schema-qualified हैं; यह inspected functions के लिए सकारात्मक evidence है, पर सभी SECURITY DEFINER functions का पूर्ण code audit अभी बाकी है।
- यह current-state security evidence है; इससे historical hardening migration SQL का exact source या उस migration का पूरा effect साबित नहीं होता।

### Foreign-key index coverage — current catalog snapshot
Read-only FK-to-leading-index comparison में कुछ वर्तमान FK columns के लिए matching leading index नहीं मिला:
- srk_admin_audit_events.actor_user_id
- srk_booking_complaint_events.actor_user_id
- srk_booking_complaints.customer_user_id, resolved_by, updated_by
- srk_booking_refund_requests.customer_user_id, decided_by
- srk_electrician_verification_documents.application_id, reviewed_by
- srk_electrician_verification_events.actor_user_id, electrician_profile_id
- srk_manual_payment_entries.recorded_by
- srk_manual_refund_entries.recorded_by
- srk_razorpay_refunds.admin_user_id
यह सूची वर्तमान Production schema के सभी FK constraints पर आधारित है। इसे तत्काल index बनाने की अनुमति या migration defect का निष्कर्ष न समझें: कुछ tables बाद के feature migrations से आए हो सकते हैं, और index की उपयोगिता/डेटा cardinality तथा query workload भी देखना होगा। शुरुआती add_missing_foreign_key_indexes migration का exact scope इस snapshot से निर्धारित नहीं किया जा सकता।

### Repository-wide migration-directory commit history
- GitHub commit-history API में supabase/migrations directory को छूने वाले commits भी जाँचे गए। उपलब्ध repository history में directory के लिए 22 commits लौटे; उनमें कई बाद की migrations/renames मौजूद हैं, लेकिन शुरुआती unresolved security/payment-lock SQL के commits नहीं मिले।
- इससे संकेत मिलता है कि शुरुआती Production migrations संभवतः Supabase dashboard/CLI से सीधे लागू हुईं या इस GitHub repository में कभी commit नहीं हुईं। यह केवल inference है—जब तक deployment logs या original migration archive न मिले, exact execution path तय नहीं है।

### सभी SECURITY DEFINER RPCs के EXECUTE grants — विस्तृत read-only pass
- Production project में कोई Supabase development branch मौजूद नहीं है (`list_branches` खाली लौटा); इसलिए इस जाँच में कोई branch create नहीं की गई और कोई compute cost नहीं हुई।
- Catalog query में `public` और `private` schemas के सभी SECURITY DEFINER functions के EXECUTE ACLs जाँचे गए। `anon` role को किसी भी ऐसे function पर EXECUTE grant नहीं मिला।
- जिन SECURITY DEFINER functions पर `authenticated` EXECUTE grant है, उनके bodies में `auth.uid()` का उपयोग मिला। सभी `srk_admin_*` RPCs में `public.is_srk_admin()` guard भी मिला। Customer/Electrician RPCs में auth.uid() आधारित ownership/identity checks मौजूद हैं; यह static body scan है, प्रत्येक function का adversarial runtime test नहीं।
- `private.srk_get_customer_call_contacts_impl()` पर authenticated EXECUTE grant है, लेकिन body auth.uid() null check करती है और केवल उसी user की assigned booking के electrician contacts लौटाती है; booking status allowlist भी लागू है।
- `private.srk_save_push_subscription()` पर authenticated EXECUTE grant है और body auth.uid() से user identity लेती है।
- निष्कर्ष: इस catalog pass में कोई SECURITY DEFINER RPC `anon` के लिए खुला नहीं मिला। फिर भी authenticated RPCs के complete ownership checks, nested function calls, object qualification और grants की function-by-function review बाकी है।
- यह current Production ACL/body snapshot है, historical migration SQL की recovery या end-to-end authorization proof नहीं। कोई Production परिवर्तन नहीं किया गया।

### Phone-contact authorization RPCs — current Production body review
- `srk_customer_get_my_booking_contacts()` केवल auth.uid() के customer_user_id वाली booking और assigned electrician का phone लौटाती है; booking status allowlist `assigned`, `inspection`, `awaiting_quote_approval`, `quote_approved`, `quote_rejected`, `in_progress`, `completed` है।
- `srk_electrician_get_my_assigned_booking_contacts()` केवल उसी authenticated electrician profile की assigned bookings और customer phone लौटाती है; समान post-assignment status allowlist लागू है।
- `private.srk_get_customer_call_contacts_impl()` भी customer ownership और assigned electrician की शर्तें जाँचती है।
- Current Production body review में इन तीनों RPCs पर unassigned/new/confirmed bookings से phone return करने का path नहीं दिखा। यह static SQL review है; वास्तविक दो-account browser/device E2E अभी नहीं हुआ।
- `accept_electrician_job()` और `srk_respond_to_offer()` offer owner/approved active electrician जाँचकर booking को assigned करते हैं; उसके बाद contact RPCs phone दिखाती हैं।
- यह current Production implementation का observation है। User-approved contact rule में बदलाव नहीं; कोई schema/function update नहीं किया गया।

### Duplicate cash-payment migration — Production effect comparison
- Production history contains two entries with the same name `add_assigned_electrician_cash_payment_status`: versions `20261111082515` and `20261111083811`. Repository source found for the first entry is `20261111082515_add_assigned_electrician_cash_payment_status.sql`; no exact source file for the second version has been recovered.
- Read-only `pg_get_functiondef` of Production `public.srk_get_my_assigned_cash_payment(uuid)` matches the function body in the recovered first candidate, including `auth.uid()` identity, approved/active electrician check, assigned-booking ownership, and `can_confirm_cash` eligibility calculation. Function config also matches `search_path=pg_catalog, public, auth, pg_temp`.
- This proves the current Production function effect is consistent with the recovered first candidate. It does **not** prove the second history entry was a no-op, duplicate replay, or the same SQL; the second source may have changed another object or replaced the function again.
- Do not mark the second migration as safely duplicated/skippable. Keep its disposition unresolved until original SQL, Supabase backup/restore artifact, or a trusted deployment artifact is found and all possible side effects are compared.

### 39 unresolved migration rows — renewed 11-branch scan and live effect mapping
- 11 repository branches के recursive Git trees दोबारा scan किए गए: कुल 99 migration paths का union मिला। Production के 78 history rows में 13 exact version+name files, 26 same-name/different-version candidates और 39 ऐसे rows हैं जिनका नाम किसी scanned branch के migration path में नहीं मिला। पहले के निष्कर्ष की पुष्टि हुई; कोई नया exact original source नहीं मिला।
- Missing refund source files `20261109202355_razorpay_refund_tables_and_audit_type`, `20261109202505_razorpay_refund_prepare_rpc`, `20261109202511_razorpay_refund_list_rpc`, `20261109202534_razorpay_refund_audit_trigger` और push files `20261111073357_enable_pg_net_for_electrician_push`, `20261111075205_wire_job_offer_push_webhook` के exact-path GitHub commit history में भी कोई commit नहीं मिला। यह केवल queried GitHub repository history का प्रमाण है, किसी external backup का नहीं।
- Production push effect read-only snapshot: `pg_net` extension version 0.20.4 installed; `private.srk_notify_job_offer_push()` SECURITY DEFINER function मौजूद; `job_offers` पर AFTER INSERT OR UPDATE trigger `trg_srk_push_job_offer` मौजूद; `PUSH_WEBHOOK_SECRET` नाम का Vault secret मौजूद (उसका value read या expose नहीं किया गया); Edge Function `push-job-offer` ACTIVE, version 4, `verify_jwt=false`; `electrician_profiles` और `job_offers` दोनों `supabase_realtime` publication में हैं।
- Production push function केवल `job_offers` trigger से call होती दिखी; `electrician_profiles` पर अलग push trigger नहीं मिला। `cron.job` catalog relation उपलब्ध नहीं है, इसलिए इस project में cron jobs की स्थिति इस query से निर्धारित नहीं हुई।
- Edge Function source review: POST में shared webhook secret अनिवार्य, payload size 32 KB तक सीमित, payload type/schema/table और offer row shape validate, केवल newly offered INSERT तथा offered→closed UPDATE को process, electrician profile active+approved check, linked user_id पर subscriptions fetch, expired 404/410 subscriptions cleanup। GET public VAPID public key लौटाता है; diagnostic fields के लिए secret header आवश्यक। Function secrets की values कभी retrieve नहीं की गईं।
- यह current Production behavior का effect mapping है, missing migrations के exact SQL का substitute नहीं। `pg_net`, Vault secret, trigger, function deployment और Realtime publication मौजूद होने से यह सिद्ध नहीं होता कि missing migration source में और कौन-से statements थे या exact order क्या था।
- Production refund tables पर manual refund audit trigger और Razorpay refund audit trigger मौजूद हैं। यह live effect `razorpay_refund_audit_trigger` migration के उद्देश्य से मेल खाता है, लेकिन original SQL अभी भी absent है।
- कोई Production DDL/DML, migration history edit, Edge Function deploy, webhook send, secret read, या deployment नहीं किया गया।


### Push subscription RLS — Production snapshot
- `public.srk_push_subscriptions` पर RLS enabled है। Authenticated users के SELECT, INSERT, UPDATE और DELETE policies चारों `user_id = (select auth.uid())` ownership predicate लगाती हैं; UPDATE में USING और WITH CHECK दोनों मौजूद हैं।
- यह user-owned subscription table की वर्तमान policy state का evidence है। Edge Function service-role client से subscriptions पढ़ती/expired entries delete करती है; client-side policy bypass को केवल trusted server function तक सीमित रखना आवश्यक है।
- इस read-only pass में subscription table पर कोई policy, grant, row या schema change नहीं किया गया।
