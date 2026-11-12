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
