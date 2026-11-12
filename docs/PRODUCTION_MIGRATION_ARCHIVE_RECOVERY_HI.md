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

### SECURITY DEFINER ACL + RLS policy audit — extended Production snapshot
- Catalog query में public/private schemas के 61 SECURITY DEFINER functions मिले। `has_function_privilege` के अनुसार इनमें PUBLIC EXECUTE = 0 और anon EXECUTE = 0। यह effective privilege check है; authenticated EXECUTE कुछ user-facing और admin RPCs पर मौजूद है और उनके authorization bodies अलग से review किए गए।
- Empty `search_path` वाले 8 SECURITY DEFINER functions के पूरे definitions जाँचे गए: `private.srk_save_push_subscription`, `public.srk_admin_decide_booking_refund_request`, `public.srk_admin_finalize_manual_booking_refund`, `public.srk_admin_list_booking_refund_requests`, `public.srk_admin_prepare_booking_refund`, `public.srk_customer_create_booking_refund_request`, `public.srk_customer_list_booking_refund_requests`, `public.srk_service_reconcile_booking_refund`। इन bodies में table/function references schema-qualified हैं; push save/customer refund RPCs auth.uid() से identity/ownership जाँचती हैं; Admin refund RPCs `public.is_srk_admin()` guard करती हैं; service reconcile RPC `auth.role()='service_role'` check करती है।
- Important: `srk_service_reconcile_booking_refund` पर ACL सही तरह service_role-only है, लेकिन उसका current Production business logic पुराने audit में पहचानी गई refund-state monotonicity/provider-refund-ID समस्याओं से अभी भी प्रभावित है। सही grants अकेले RPC को safe नहीं बनाते; hardened replacement migration अभी Production में लागू नहीं है।
- Public schema की 25 base tables में RLS enabled = 25, disabled = 0। इनमें 10 tables पर कोई RLS policy नहीं है: admin audit events, complaint events/complaints, booking refund requests, electrician verification documents/events, manual payment/refund entries, Razorpay refunds और Razorpay webhook events। इन दसों पर anon तथा authenticated SELECT/INSERT/UPDATE/DELETE table privileges false और service_role के चारों privileges true मिले। RLS-with-no-policy + no client table grants का वर्तमान संयोजन default-deny/service-role-only access दिखाता है।
- यह catalog/SQL-body static review है; प्रत्येक RPC के hostile multi-user runtime authorization tests नहीं हुए। No-policy tables के access को production service_role code paths में भी least-privilege के आधार पर अलग से जाँचना होगा।
- कोई Production grant, policy, function, table, row या migration history modify नहीं की गई।
### RLS expression + refund integrity follow-up — Production read-only review
- Public RLS policy expression register के current snapshot में authenticated policies मुख्यतः Admin `is_srk_admin()` guard, customer booking ownership `customer_user_id=auth.uid()`, electrician profile identity (`user_id` OR `auth_user_id`), approved+active electrician द्वारा अपने offers की read, और wallet/payout ownership checks पर आधारित हैं। Public `services` और `states` केवल `is_active=true` rows पढ़ने देते हैं। `srk_route_transfers` पर anon/authenticated के लिए explicit deny-all policy है। Payment order locks और booking status history service_role-only policies रखते हैं।
- `srk_electrician_payouts` SELECT policy Admin या profile `user_id=auth.uid()` पर आधारित है; यह `auth_user_id` fallback नहीं करती, जबकि profile/offer policies दोनों identity columns स्वीकार करती हैं। वर्तमान Production में electrician_profiles केवल 1 row, payout rows 0; इसलिए अभी कोई observed user impact नहीं, लेकिन legacy identity relink scenarios में payout read inconsistency का संभावित जोखिम है। Policy change से पहले canonical identity model और intended owner mapping तय करें।
- Refund schema: `srk_razorpay_refunds` में booking_id UNIQUE, idempotency_key UNIQUE, refund_id UNIQUE; `srk_booking_refund_requests` में booking_id UNIQUE और refund_record_id UNIQUE; manual refunds में booking_id तथा payment_entry_id UNIQUE। यह मौजूदा one-full-refund-per-booking workflow से मेल खाता है; एक booking पर multiple partial refunds अभी schema में समर्थित नहीं। Razorpay एक payment पर multiple partial refunds सपोर्ट करता है, इसलिए भविष्य में partial refund feature चाहिए तो schema, cumulative amount guard, payout reversal और UI/workflow को साथ redesign करना होगा—अभी कोई बदलाव नहीं।
- `service_bookings.razorpay_order_id` पर partial UNIQUE index है, लेकिन `razorpay_payment_id` पर कोई unique index/constraint नहीं मिला। वर्तमान table में केवल 1 booking row और कोई non-null payment ID नहीं; refund ledger भी खाली (0 rows), इसलिए duplicate का live example नहीं मिला। फिर भी payment ID एक provider payment की पहचान है; production parity DB पर duplicate/backfill checks के बाद partial unique index का प्रस्ताव evaluate करें, और webhook payment binding में atomic conflict guard अनिवार्य रखें।
- Refund webhook ambiguity protection के बावजूद source table payment_id पर uniqueness enforce नहीं करती; दो अलग booking refund rows समान payment_id पर आ सकती हैं और webhook handler सही रूप से ambiguous match पर retryable 500 देता है। यह fail-safe है, पर operational retry/manual reconciliation आवश्यक होगा।
- Refund RPC ACL: customer create/list और Admin decide/prepare/finalize/manual-refund RPC authenticated role के लिए EXECUTE हैं और bodies में customer ownership या `is_srk_admin()` guards हैं; anon EXECUTE false। `srk_service_reconcile_booking_refund` केवल service_role EXECUTE है। एक legacy Admin RPC `srk_admin_prepare_razorpay_refund(uuid,text)` अभी भी authenticated EXECUTE है और नए `srk_admin_prepare_booking_refund(uuid)` से अलग code path/contract रखती है; दोनों Admin-guarded हैं, पर migration/UX consolidation और call-site inventory आवश्यक है।
- Refund audit trigger `srk_audit_razorpay_refunds` INSERT/UPDATE/DELETE पर audit row लिखता है; captured changed fields refund_id, amount, status, provider_status हैं। `reason`, `last_error`, `processed_at` और provider payload/audit context इस trigger snapshot में record नहीं होते। इसे audit sufficiency review में शामिल करें; raw sensitive provider payload सीधे audit table में जोड़ने की अनुशंसा नहीं।
- Current refund tables में कोई refund record नहीं; `service_bookings` में एक row और कोई non-null Razorpay payment ID नहीं। ये counts केवल वर्तमान Production snapshot हैं, historical usage/traffic का प्रमाण नहीं।
- सभी निष्कर्ष static catalog, policy-expression और function-definition review हैं। कोई authenticated adversarial runtime test, provider refund call, webhook replay, schema/row/ACL change या deployment नहीं हुआ।
### Timer Cash Refund UI ↔ Production RPC mismatch — verified 2026-11-12
- `admin.html` conditionally selects `srk_admin_finalize_timer_cash_refund` when `r.is_timer_booking===true`; otherwise it calls `srk_admin_finalize_manual_booking_refund`.
- Production `srk_admin_list_booking_refund_requests(integer)` currently returns 18 columns and does NOT return `is_timer_booking`. Its `has_manual_payment` flag checks only `srk_manual_payment_entries`; it does not include `srk_cash_receipts`.
- Production catalog has NO `srk_admin_finalize_timer_cash_refund(uuid,text,text)` function. Production migration history query found no `20261111160015` version or timer-refund migration name.
- Feature-branch migration `20261111160015_timer_snapshot_refund_support.sql` defines the missing `is_timer_booking` output, counts `srk_cash_receipts` in manual-payment evidence, creates `srk_timer_cash_refund_entries`, and defines the Admin timer-cash refund RPC. This source file exists on feature branch but is NOT reflected in Production migration history/catalog.
- Consequence: timer Cash refund action cannot reliably be selected or completed by the current Production Admin UI/RPC contract. This is a confirmed release blocker / migration-drift example, not a customer refund failure observed in live data. No refund rows currently exist.
- Do NOT manually add the missing RPC or apply this migration to Production while archive drift is unresolved. First recover exact intended migration lineage, compare all timer dependencies (`srk_cash_receipts`, payable snapshots, payout state) and validate the full ordered migration chain on a disposable Production-parity DB.
- Dependency check विस्तार: Production में `srk_cash_receipts`, `srk_booking_payable_snapshots`, `srk_razorpay_payments`, और `srk_timer_cash_refund_entries` नाम की कोई public relation नहीं मिली; `supabase_migrations.schema_migrations` में `2026111116%` timer release entries भी शून्य हैं। Feature branch के timer refund migration को अकेले चलाना सुरक्षित नहीं होगा—उसकी पूरी ordered timer foundation chain और संबंधित booking columns/functions/triggers Production में अनुपस्थित हैं या अलग नामों पर हो सकते हैं।

## 2026-11-12 — Timer migration chain dependency comparison (read-only)

Feature-branch recursive migration scan found 16 Timer-related migration files. The chain has two timestamp families: early exploratory files (202611110001/002/003/004/008/011 and 20261111150000) and forward-release copies (20261111160000/001/002/003/007/010/012/013/015). Production migration history contains none of the 2026111116% versions and contains no Timer-specific migration entries from the earlier family.

Dependency map from SQL source:
- 16000 foundation: adds 16 timer/category/arrival/billing columns to service_bookings; creates srk_booking_timer_decisions, srk_final_bills, srk_bill_material_items, srk_bill_material_approvals, srk_booking_cancellation_requests; adds FK and service-role-only ACL/RLS.
- 16001 integrity: creates srk_bill_material_revisions, srk_booking_payable_snapshots, srk_payment_webhook_events, srk_cash_receipts, srk_booking_audit_events, srk_final_bill_adjustments; links material revisions/items/approvals and adds integrity triggers/guards.
- 16002 timer RPCs: arrival + customer-approved start/stop requests and decisions; depends on 16000/16001 tables and booking audit events.
- 16003 scoped bill read RPC: reads timer decisions, final bills, materials/revisions, payable snapshots and cash receipts.
- 16007 payable snapshot RPC: writes immutable payable snapshots and booking audit events; 16010 repairs its rounding constraint.
- 16012 commission/cash/online integration: extends electrician payout schema; creates snapshot-aware commission/payable and cash commission remittance/admin confirmation/report RPCs; depends on payable snapshots, cash receipts, Razorpay payment ledger, manual payment entries and service_bookings.
- 16013 guards legacy quote/work-status RPC paths against timer-category bookings.
- 16015 refund support: creates srk_timer_cash_refund_entries, extends Admin refund list with is_timer_booking and cash-receipt detection, adds timer cash refund finalizer, and extends Razorpay refund preparation to payable snapshot + captured payment ledger.

Production catalog check reconfirmed: none of srk_booking_timer_decisions, srk_final_bills, srk_bill_material_items, srk_bill_material_approvals, srk_booking_cancellation_requests, srk_bill_material_revisions, srk_booking_payable_snapshots, srk_payment_webhook_events, srk_cash_receipts, srk_booking_audit_events, srk_final_bill_adjustments, srk_timer_cash_refund_entries, or srk_razorpay_payments were present. Production service_bookings lacks timer/category/snapshot columns; payout table lacks timer settlement extensions. Therefore this is a complete Timer foundation release gap, not a standalone 16015 refund RPC omission.

Duplicate-family comparison: 001 vs 16000, 002 vs 16001, 008 vs 16007 have identical executable SQL after removing comments; 003 vs 16002, 004 vs 16003, and 011 vs 16010 are byte-identical. 15000 vs 16012 is materially different: 16012 rejects timer bookings lacking immutable payable snapshots and changes trigger/function wiring; do not substitute the earlier 15000 file for release. No migration should be applied in isolation or inferred as safe from matching filenames.

All checks read-only against Production. No migration/DDL/DML/ACL/policy/function changes, provider calls, refunds, or deployment performed.


## 2026-11-12 — Extended Timer release chain and CI coverage review

A second pass over the timer-billing CI workflow revealed that the complete forward-release chain is 16000 through 16015, not just the timer-named files initially grouped by filename. Additional migrations 16004–16014 include server-authoritative booking creation/rate snapshot, labour precision, material revision/customer approval RPCs, Razorpay snapshot order/payment ledger, cash payment intent/receipt confirmation, cancellation request/Admin decision, and post-acceptance customer call-contact access.

Important sequencing interaction: migration 16004's initial booking RPC still requires preferred_time. Later 20261112130000_customer_booking_date_only.sql makes preferred_time optional while preserving explicit legacy callers; 20261112140000_customer_booking_duration_pricing.sql then adds duration_hours (1–8) and estimated labour snapshot. Thus timer-chain parity replay alone does not establish the final date-only + duration booking contract. The release plan must include these later booking migrations in a deliberate ordered combined replay and verify the final RPC definition/constraints/UI contract. Do not reintroduce a required time selector or default time.

CI coverage found:
- timer-billing-math workflow builds a synthetic legacy baseline, replays release migrations 16000–16014 twice in a separate disposable Production-shaped database, and asserts preservation of a representative legacy paid quote payout/booking. It does not replay 16015 in that parity loop.
- refund-workflow.yml separately applies 16015 to a synthetic refund foundation harness and runs refund workflow assertions. This is useful but is not a single integrated timer+refund+production-parity replay.
- The isolated 16015 test harness does not replace the missing Production timer foundation and does not prove the complete combined chain on a Production-shaped baseline.

Additional migration dependencies:
- 16004 depends on timer booking columns from 16000 and creates the idempotent booking creation request table plus server-authoritative booking RPC and immutable rate snapshot guard.
- 16005 depends on final bills from 16000 and widens labour precision.
- 16006 depends on timer idempotency, audit, final-bill and material-revision tables from 16001/16002.
- 16008 depends on payable snapshots from 16001/16007 and creates Razorpay order/payment ledgers with immutable identity and reconciliation RPCs.
- 16009 depends on cash receipts and payable snapshots, adds cash payment intent and receipt confirmation RPCs, and extends scoped timer bill read RPC.
- 16011 adds customer cancellation request and Admin decision RPCs on the foundation cancellation table.
- 16014 changes customer call-contact RPC access after assignment; preserve the approved full-number visibility after electrician acceptance, including after completion.

Production still lacks the required timer schema and related booking columns; no Production changes were made. Next release-gate task is to create a single combined disposable parity replay that includes timer 16000–16015 plus the later date-only/duration booking contract, then run all relevant assertions and safe replays. No Production DDL/DML or deployment.


## 2026-11-12 — Post-acceptance phone visibility contract audit

Read-only Production function review confirmed public.srk_respond_to_offer(uuid,text) writes service_bookings.assigned_electrician_id and status='assigned' only when p_response='accepted', only for the authenticated active/approved electrician, and only while the booking is unassigned and new/confirmed. This validates assigned_electrician_id as the accepted-offer marker in the observed Production function.

Feature branch phone-visibility paths:
- Electrician RPC srk_get_my_offer_details_v2 returns customer_name/customer_phone/address only when assigned_electrician_id matches the authenticated electrician profile and booking status is in assigned/inspection/awaiting_quote_approval/quote_approved/in_progress/completed. Before acceptance, fields remain null; electrician UI displays the call button only when customer_phone exists.
- Customer RPC srk_get_customer_call_contacts delegates to a private implementation and returns the assigned electrician phone only when the customer owns the booking and assigned_electrician_id is non-null. Migration 16014 deliberately removes the former status cutoff so contact remains available after completion.
- Customer and electrician UIs both render direct tel: call controls after the RPC provides the accepted counterpart number. No OTP/masked relay is required after acceptance, consistent with approved project rule.

Added automated source/UI contract assertions to tests/timer-panel-contract.test.js. Commit a8e4a41. CI run was not yet visible at the time of this note; test execution remains pending CI confirmation. This static contract does not prove device-level E2E or every database identity edge case. No Production changes.


## 2026-11-12 — Contact privacy contract CI result

Added contact-visibility assertions to tests/timer-panel-contract.test.js and corrected timer-billing workflow push path filters so a test-only change triggers CI. GitHub Actions run 43175321207 completed SUCCESS at workflow commit d04f039fcd6810823e03e3fb387d738994da69fe. The job passed inline JS syntax checks, timer panel contract tests (including post-acceptance contact visibility), timer billing SQL tests, migration replay checks, and Production-shaped legacy parity replay for migrations 16000–16014. This remains synthetic PostgreSQL CI, not hosted Production migration replay or mobile/device E2E. 16015 is separately covered by refund-workflow harness; integrated all-in-one 16000–16015 plus final date-only/duration parity replay remains a release gate.


## 2026-11-12 — Integrated Timer + refund replay: collision found and corrected

The first combined disposable parity replay exposed a real migration collision: 16001 creates public.srk_payment_webhook_events as the Timer payment-receipt event ledger (received_at, processed_at, attempt_count, provider/order/payment fields). The later 18000 Razorpay refund event lease migration attempted CREATE TABLE IF NOT EXISTS against the same relation name but expected a different shape (created_at, updated_at, processing_started_at). Because the table already existed, PostgreSQL skipped table creation and failed when the later migration indexed missing created_at. This was not a fixture-only typo; the two distinct event streams must not share one table.

Correction:
- Renamed the dedicated Razorpay refund webhook event ledger to public.srk_razorpay_webhook_event_ledger in migration 20261112180000.
- Updated razorpay-webhook.js REST paths and refund webhook ledger SQL assertions to use the dedicated table.
- Added integrated assertions that both event ledgers coexist with their separate column contracts and that the Timer ledger was not overwritten.
- Added disposable parity overlay for the legacy refund tables and extended timer-billing workflow to replay 16000–16015, then date-only (12130000) + duration pricing (12140000), then refund request + webhook ledger + reconciliation hardening migrations twice.

Verification: GitHub Actions Timer billing run 43175857392 completed SUCCESS at commit 9cbdd761f8ab7a7632ec84f3be3bf6cb43b754b3. It passed the integrated Production-shaped disposable parity replay, including timer foundation, timer cash/online/refund support, date-only/duration booking contract and webhook ledger separation assertions. A newer workflow run 43175948589 is also queued/running to include the snapshot webhook contract test in this same workflow. Independent refund workflow run after the rename is still pending at time of this note.

No Production schema/data/history changes, no provider calls, no live refunds, and no deployment. CI is synthetic PostgreSQL parity, not Production rollout approval.


### Final CI confirmation — 2026-11-12
- Integrated Timer + date-only/duration + refund parity workflow run 43175948589: SUCCESS. This run also executed tests/snapshot-payment-contract.test.js.
- Independent SRK Refund Workflow run 43175929837: SUCCESS, including refund handler, snapshot payment/webhook contracts, refund webhook ledger contract, ambiguous refund handler behavior, and SQL webhook ledger assertions.
- Together these confirm the renamed event ledger and integrated disposable migration replay pass in CI. They do not establish that missing Production migrations were applied, that hosted Production schema matches the synthetic fixture exactly, or that Android/device E2E passed.
