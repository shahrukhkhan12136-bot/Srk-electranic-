# Production Migration Archive Recovery — 2026-11-12

## उद्देश्य और स्रोत

Production migration history की तुलना के बाद पुराने Git branches में उपलब्ध migration SQL की read-only खोज की गई।

- Historical source branch: `work/separate-customer-electrician-portals`
- Source commit: `0fe5ef479e3ce69e9b219721599ebd52f6ba73ee`
- Commit timestamp: 2026-11-11 05:11:33 UTC
- उस branch में कुल 37 migration files मिलीं।
- Production history की 78 entries में से 28 migration names के लिए इस historical branch में matching-name SQL source candidate मिला।
- उनमें 11 files का filename Production version + migration name से exact match है।
- शेष 17 files का migration name match है, पर timestamp/version अलग है।

**महत्वपूर्ण:** Historical Git file मिलना Production में apply हुए exact SQL का प्रमाण नहीं है। Exact filename भी अकेले content authenticity सिद्ध नहीं करता। नीचे की सूची source-recovery lead है; इसे Production migration history में skip/mark applied करने, SQL replay करने या नया migration बनाने की अनुमति न माना जाए।

## Historical branch से मिले source candidates

| Production version | Production migration name | Historical source file | Filename match |
|---|---|---|---|
| 20261108120608 | add_public_api_rate_limiting | 20261108120608_add_public_api_rate_limiting.sql | Exact |
| 20261108120658 | enable_rls_public_api_rate_limits | 20261108120658_enable_rls_public_api_rate_limits.sql | Exact |
| 20261108121115 | add_customer_account_booking_access | 20261108121115_add_customer_account_booking_access.sql | Exact |
| 20261108183027 | add_google_maps_location_support | 20261109001000_add_google_maps_location_support.sql | Version differs |
| 20261108183324 | expose_assigned_booking_map_pin | 20261109002000_expose_assigned_booking_map_pin.sql | Version differs |
| 20261108190047 | create_secure_wallet_ledger_foundation | 20261109010000_create_secure_wallet_ledger_foundation.sql | Version differs |
| 20261108193506 | create_server_only_razorpay_route_transfer_ledger | 20261109020000_create_server_only_razorpay_route_transfer_ledger.sql | Version differs |
| 20261109075837 | electrician_inspection_quotes_and_service_only_commission | 20261109_electrician_inspection_quotes_and_service_only_commission.sql | Version differs |
| 20261109080400 | allow_quote_approval_booking_states | 20261109_allow_quote_approval_booking_states.sql | Version differs |
| 20261109103038 | customer_electrician_direct_call_contacts | 20261109103038_customer_electrician_direct_call_contacts.sql | Exact |
| 20261109103143 | move_customer_call_contact_lookup_to_private | 20261109103143_move_customer_call_contact_lookup_to_private.sql | Exact |
| 20261109161539 | customer_contact_after_completion | 20261109190000_customer_contact_after_completion.sql | Version differs |
| 20261109161545 | hide_customer_details_on_cancelled_bookings | 20261109193000_hide_customer_details_on_cancelled_bookings.sql | Version differs |
| 20261109163755 | fix_null_validation_quote_and_payout | 20261109210000_fix_null_validation_quote_and_payout.sql | Version differs |
| 20261109164808 | sync_electrician_auth_profile_link | 20261109223000_sync_electrician_auth_profile_link.sql | Version differs |
| 20261109165802 | harden_electrician_payable_trigger_search_path | 20261109165802_harden_electrician_payable_trigger_search_path.sql | Exact |
| 20261109170626 | expire_job_offers_when_booking_cancelled | 20261109235500_expire_job_offers_when_booking_cancelled.sql | Version differs |
| 20261109170937 | secure_admin_booking_updates_and_profile_columns | 20261109235000_secure_admin_booking_updates_and_profile_columns.sql | Version differs |
| 20261109171033 | tighten_admin_booking_rpc_input_validation | 20261109235930_tighten_admin_booking_rpc_input_validation.sql | Version differs |
| 20261109171621 | add_admin_verified_manual_payment_workflow | 20261109171621_add_admin_verified_manual_payment_workflow.sql | Exact |
| 20261109171942 | add_admin_verified_manual_refund_workflow | 20261109171942_add_admin_verified_manual_refund_workflow.sql | Exact |
| 20261109174234 | allow_manual_payment_payout_settlement | 20261109173000_allow_manual_payment_payout_settlement.sql | Version differs |
| 20261109175023 | serialize_manual_refund_and_electrician_payout | 20261109234500_serialize_manual_refund_and_electrician_payout.sql | Version differs |
| 20261109180001 | fix_manual_payout_special_forms | 20261109180001_fix_manual_payout_special_forms.sql | Exact |
| 20261109202321 | admin_audit_log | 20261110060000_admin_audit_log.sql | Version differs |
| 20261109203132 | customer_admin_complaints | 20261110040000_customer_admin_complaints.sql | Version differs |
| 20261109203137 | electrician_verification_documents | 20261110050000_electrician_verification_documents.sql | Version differs |
| 20261110080448 | srk_business_finance_dashboard | 20261110080448_srk_business_finance_dashboard.sql | Exact |
| 20261111043852 | srk_business_finance_reporting_dates | 20261111043852_srk_business_finance_reporting_dates.sql | Exact |

## Content comparisons already performed

Seven same-name files present in both the historical archive branch and current feature branch were byte-identical (Git blob SHA identical):

1. Google Maps location support
2. Assigned booking map pin
3. Secure wallet ledger foundation
4. Server-only Razorpay Route transfer ledger
5. Quote approval booking states
6. Electrician inspection quotes and service-only commission
7. Restore missing customer booking quote columns

One important exception was found:

- Historical `20261111020000_add_electrician_push_subscriptions.sql` and current feature `20261111090000_add_electrician_push_subscriptions.sql` are **not byte-identical**.
- The historical file includes a single broad owner policy and endpoint/key checks; the current file uses separate SELECT/INSERT/UPDATE/DELETE owner policies, different constraints and removes `user_agent`.
- Production history records `20261111072823_add_electrician_push_subscriptions`, which is between the historical and current filename timestamps. Neither branch copy can be assumed to be the exact Production-applied SQL without further evidence.

## Remaining Production entries without a matching-name source in this archive

The following 33 Production migration names were not found in this historical branch and still require another trusted source/archive:

- harden_srk_rls_policy_performance
- add_atomic_payment_order_lock
- add_service_role_policy_payment_order_locks
- harden_security_definer_function_search_paths
- add_missing_foreign_key_indexes
- add_actual_paid_amount_commission_and_status_history
- harden_payment_order_lock_search_paths
- harden_booking_broadcast_search_path
- harden_booking_guard_trigger_search_path
- enable_realtime_job_offer_updates
- enable_realtime_electrician_profile_updates
- guard_booking_assignment_and_amount_integrity
- tighten_legacy_definer_paths_and_history_grants
- restrict_public_form_inserts_to_server_functions
- combine_admin_customer_booking_read_policy
- electrician_earnings_summary
- protect_commission_columns_and_admin_report
- limit_booking_updates_and_correct_earnings_timestamp
- harden_wallet_reporting_rpc_paths_and_route_recipient_index
- harden_wallet_and_commission_security_definer_paths
- grant_authenticated_select_service_bookings
- grant_authenticated_select_job_offers_for_rls_realtime
- lock_quote_workflow_rpcs_to_authenticated_users
- srk_manual_electrician_payout_ledger
- index_electrician_payout_foreign_keys
- lock_down_route_transfer_api_access
- add_secure_admin_booking_offer_flow
- align_electrician_payouts_with_booking_commission_rate
- allow_electricians_to_read_own_manual_payout_status
- consolidate_electrician_payout_read_policy
- protect_customer_and_electrician_phone_numbers_until_masked_calling
- enable_direct_customer_electrician_phone_calls
- enable_pg_net_for_electrician_push
- wire_job_offer_push_webhook
- razorpay_refund_tables_and_audit_type
- razorpay_refund_prepare_rpc
- razorpay_refund_list_rpc
- razorpay_refund_audit_trigger
- retire_empty_legacy_electrician_booking_tables

Note: the list above contains 39 names as transcribed from the 78-row history comparison, not 33; the count should be treated as 39 until reconciled against the full source register.

## Required next steps

1. Retrieve exact Git blobs for all 11 exact-version candidates and compare them with any available database migration archive or deployment artifact.
2. For all 17 timestamp-mismatch candidates, compare SQL statement-by-statement against the exact Production source if recoverable; compare live schema effects separately.
3. Recover the remaining Production-only migrations from Git commit history, CI artifacts, Supabase backups or another owner-controlled archive. Do not reconstruct SQL from names alone.
4. Inspect schema state and data effects in a disposable Production-parity database.
5. Build a migration disposition matrix: exact source/replay, already represented, superseded, pending forward migration, or unresolved.
6. Perform clean replay and second replay on the disposable Production-parity database before any release proposal.

**Current release decision: NO-GO.** This investigation was read-only against Production. No Production SQL, schema, data, migration history, live payment, or deployment was changed.
