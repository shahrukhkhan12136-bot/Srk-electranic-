# Production Migration Disposition Matrix (read-only inventory)

Generated 2026-11-12 from the current Production Supabase migration history and recursive migration trees on 11 GitHub branches.

## Summary

- Production migration history rows: **78**.
- Exact version + name source files found: **13**.
- Same-name source candidates with timestamp/version mismatch: **26**.
- Unresolved history rows with no same-name source in the scanned branches: **39**.
- Distinct migration path strings across scanned branch trees: **99**.

## Disposition rules

1. Exact version+name means a source candidate exists; it is **not** proof that its bytes match the SQL applied to Production.
2. Same-name/timestamp mismatch is a candidate only. Compare full SQL, schema effects, dependencies, and current catalog before assigning a disposition.
3. Unresolved means no same-name source was found in these 11 branch trees; it does not prove no local archive, backup, CLI artifact, dashboard SQL, or deployment bundle exists.
4. Do not skip, rename, replay, mark-applied, or synthesize any migration based on this matrix alone.
5. The duplicate cash-payment history entries (20261111082515 and 20261111083811) remain separate unresolved decisions; a source with one timestamp must not be assumed to represent both.

## Per-row inventory

| Production version | Production migration name | Source disposition | Candidate file(s) | Branch evidence |
|---|---|---|---|---|
| 20261108092928 | `harden_srk_rls_policy_performance` | UNRESOLVED — source not found | — | — |
| 20261108093725 | `add_atomic_payment_order_lock` | UNRESOLVED — source not found | — | — |
| 20261108093757 | `add_service_role_policy_payment_order_locks` | UNRESOLVED — source not found | — | — |
| 20261108094007 | `harden_security_definer_function_search_paths` | UNRESOLVED — source not found | — | — |
| 20261108095224 | `add_missing_foreign_key_indexes` | UNRESOLVED — source not found | — | — |
| 20261108095928 | `add_actual_paid_amount_commission_and_status_history` | UNRESOLVED — source not found | — | — |
| 20261108102159 | `harden_payment_order_lock_search_paths` | UNRESOLVED — source not found | — | — |
| 20261108102323 | `harden_booking_broadcast_search_path` | UNRESOLVED — source not found | — | — |
| 20261108102612 | `harden_booking_guard_trigger_search_path` | UNRESOLVED — source not found | — | — |
| 20261108102837 | `enable_realtime_job_offer_updates` | UNRESOLVED — source not found | — | — |
| 20261108102951 | `enable_realtime_electrician_profile_updates` | UNRESOLVED — source not found | — | — |
| 20261108103531 | `guard_booking_assignment_and_amount_integrity` | UNRESOLVED — source not found | — | — |
| 20261108115205 | `tighten_legacy_definer_paths_and_history_grants` | UNRESOLVED — source not found | — | — |
| 20261108120608 | `add_public_api_rate_limiting` | EXACT version+name source | `20261108120608_add_public_api_rate_limiting.sql` | feature/business-finance-dashboard, feature/direct-upi-commission-15, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261108120658 | `enable_rls_public_api_rate_limits` | EXACT version+name source | `20261108120658_enable_rls_public_api_rate_limits.sql` | feature/business-finance-dashboard, feature/direct-upi-commission-15, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261108121115 | `add_customer_account_booking_access` | EXACT version+name source | `20261108121115_add_customer_account_booking_access.sql` | feature/business-finance-dashboard, feature/direct-upi-commission-15, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261108181453 | `restrict_public_form_inserts_to_server_functions` | UNRESOLVED — source not found | — | — |
| 20261108181538 | `combine_admin_customer_booking_read_policy` | UNRESOLVED — source not found | — | — |
| 20261108183027 | `add_google_maps_location_support` | SAME-NAME / timestamp mismatch | `20261109001000_add_google_maps_location_support.sql` | feature/business-finance-dashboard, feature/direct-upi-commission-15, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261108183324 | `expose_assigned_booking_map_pin` | SAME-NAME / timestamp mismatch | `20261109002000_expose_assigned_booking_map_pin.sql` | feature/business-finance-dashboard, feature/direct-upi-commission-15, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261108184254 | `electrician_earnings_summary` | UNRESOLVED — source not found | — | — |
| 20261108184815 | `protect_commission_columns_and_admin_report` | UNRESOLVED — source not found | — | — |
| 20261108184938 | `limit_booking_updates_and_correct_earnings_timestamp` | UNRESOLVED — source not found | — | — |
| 20261108190047 | `create_secure_wallet_ledger_foundation` | SAME-NAME / timestamp mismatch | `20261109010000_create_secure_wallet_ledger_foundation.sql` | feature/business-finance-dashboard, feature/direct-upi-commission-15, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261108193506 | `create_server_only_razorpay_route_transfer_ledger` | SAME-NAME / timestamp mismatch | `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql` | feature/business-finance-dashboard, feature/direct-upi-commission-15, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261109052929 | `harden_wallet_reporting_rpc_paths_and_route_recipient_index` | UNRESOLVED — source not found | — | — |
| 20261109053005 | `harden_wallet_and_commission_security_definer_paths` | UNRESOLVED — source not found | — | — |
| 20261109053301 | `grant_authenticated_select_service_bookings` | UNRESOLVED — source not found | — | — |
| 20261109053328 | `grant_authenticated_select_job_offers_for_rls_realtime` | UNRESOLVED — source not found | — | — |
| 20261109075837 | `electrician_inspection_quotes_and_service_only_commission` | SAME-NAME / timestamp mismatch | `20261109_electrician_inspection_quotes_and_service_only_commission.sql` | feature/business-finance-dashboard, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261109080121 | `lock_quote_workflow_rpcs_to_authenticated_users` | UNRESOLVED — source not found | — | — |
| 20261109080400 | `allow_quote_approval_booking_states` | SAME-NAME / timestamp mismatch | `20261109_allow_quote_approval_booking_states.sql` | feature/business-finance-dashboard, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261109081310 | `srk_manual_electrician_payout_ledger` | UNRESOLVED — source not found | — | — |
| 20261109082241 | `index_electrician_payout_foreign_keys` | UNRESOLVED — source not found | — | — |
| 20261109082620 | `lock_down_route_transfer_api_access` | UNRESOLVED — source not found | — | — |
| 20261109094209 | `add_secure_admin_booking_offer_flow` | UNRESOLVED — source not found | — | — |
| 20261109103038 | `customer_electrician_direct_call_contacts` | EXACT version+name source | `20261109103038_customer_electrician_direct_call_contacts.sql` | feature/business-finance-dashboard, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261109103143 | `move_customer_call_contact_lookup_to_private` | EXACT version+name source | `20261109103143_move_customer_call_contact_lookup_to_private.sql` | feature/business-finance-dashboard, feature/electrician-categories-hourly-booking, feature/flutter-mobile-apps, feature/production-push-notifications, gh-pages, main, predeploy/verified-electrician-booking-match, safe-payment-refund-implementation, security/masked-calling-hide-direct-numbers, work/separate-customer-electrician-portals |
| 20261109110140 | `align_electrician_payouts_with_booking_commission_rate` | UNRESOLVED — source not found | — | — |
| 20261109112032 | `allow_electricians_to_read_own_manual_payout_status` | UNRESOLVED — source not found | — | — |
| 20261109112105 | `consolidate_electrician_payout_read_policy` | UNRESOLVED — source not found | — | — |
| 20261109114000 | `protect_customer_and_electrician_phone_numbers_until_masked_calling` | UNRESOLVED — source not found | — | — |
| 20261109114642 | `enable_direct_customer_electrician_phone_calls` | UNRESOLVED — source not found | — | — |
| 20261109161539 | `customer_contact_after_completion` | SAME-NAME / timestamp mismatch | `20261109190000_customer_contact_after_completion.sql` | work/separate-customer-electrician-portals |
| 20261109161545 | `hide_customer_details_on_cancelled_bookings` | SAME-NAME / timestamp mismatch | `20261109193000_hide_customer_details_on_cancelled_bookings.sql` | work/separate-customer-electrician-portals |
| 20261109163755 | `fix_null_validation_quote_and_payout` | SAME-NAME / timestamp mismatch | `20261109210000_fix_null_validation_quote_and_payout.sql` | work/separate-customer-electrician-portals |
| 20261109164808 | `sync_electrician_auth_profile_link` | SAME-NAME / timestamp mismatch | `20261109223000_sync_electrician_auth_profile_link.sql` | work/separate-customer-electrician-portals |
| 20261109165802 | `harden_electrician_payable_trigger_search_path` | EXACT version+name source | `20261109165802_harden_electrician_payable_trigger_search_path.sql` | work/separate-customer-electrician-portals |
| 20261109170626 | `expire_job_offers_when_booking_cancelled` | SAME-NAME / timestamp mismatch | `20261109235500_expire_job_offers_when_booking_cancelled.sql` | work/separate-customer-electrician-portals |
| 20261109170937 | `secure_admin_booking_updates_and_profile_columns` | SAME-NAME / timestamp mismatch | `20261109235000_secure_admin_booking_updates_and_profile_columns.sql` | work/separate-customer-electrician-portals |
| 20261109171033 | `tighten_admin_booking_rpc_input_validation` | SAME-NAME / timestamp mismatch | `20261109235930_tighten_admin_booking_rpc_input_validation.sql` | work/separate-customer-electrician-portals |
| 20261109171621 | `add_admin_verified_manual_payment_workflow` | EXACT version+name source | `20261109171621_add_admin_verified_manual_payment_workflow.sql` | work/separate-customer-electrician-portals |
| 20261109171942 | `add_admin_verified_manual_refund_workflow` | EXACT version+name source | `20261109171942_add_admin_verified_manual_refund_workflow.sql` | work/separate-customer-electrician-portals |
| 20261109174234 | `allow_manual_payment_payout_settlement` | SAME-NAME / timestamp mismatch | `20261109173000_allow_manual_payment_payout_settlement.sql` | work/separate-customer-electrician-portals |
| 20261109175023 | `serialize_manual_refund_and_electrician_payout` | SAME-NAME / timestamp mismatch | `20261109234500_serialize_manual_refund_and_electrician_payout.sql` | work/separate-customer-electrician-portals |
| 20261109180001 | `fix_manual_payout_special_forms` | EXACT version+name source | `20261109180001_fix_manual_payout_special_forms.sql` | work/separate-customer-electrician-portals |
| 20261109202321 | `admin_audit_log` | SAME-NAME / timestamp mismatch | `20261110060000_admin_audit_log.sql` | work/separate-customer-electrician-portals |
| 20261109202355 | `razorpay_refund_tables_and_audit_type` | UNRESOLVED — source not found | — | — |
| 20261109202505 | `razorpay_refund_prepare_rpc` | UNRESOLVED — source not found | — | — |
| 20261109202511 | `razorpay_refund_list_rpc` | UNRESOLVED — source not found | — | — |
| 20261109202534 | `razorpay_refund_audit_trigger` | UNRESOLVED — source not found | — | — |
| 20261109203132 | `customer_admin_complaints` | SAME-NAME / timestamp mismatch | `20261110040000_customer_admin_complaints.sql` | work/separate-customer-electrician-portals |
| 20261109203137 | `electrician_verification_documents` | SAME-NAME / timestamp mismatch | `20261110050000_electrician_verification_documents.sql` | work/separate-customer-electrician-portals |
| 20261110080448 | `srk_business_finance_dashboard` | EXACT version+name source | `20261110080448_srk_business_finance_dashboard.sql` | feature/business-finance-dashboard, work/separate-customer-electrician-portals |
| 20261110133835 | `restore_missing_customer_booking_quote_columns` | SAME-NAME / timestamp mismatch | `20261110140000_restore_missing_customer_booking_quote_columns.sql` | feature/business-finance-dashboard, feature/electrician-categories-hourly-booking, feature/production-push-notifications, main |
| 20261110140719 | `add_electrician_offer_price_details_rpc` | SAME-NAME / timestamp mismatch | `20261110220000_add_electrician_offer_price_details_rpc.sql` | feature/flutter-mobile-apps |
| 20261110141125 | `add_assigned_booking_quote_ui_rpc` | SAME-NAME / timestamp mismatch | `20261110223000_add_assigned_booking_quote_ui_rpc.sql` | feature/flutter-mobile-apps |
| 20261110142310 | `add_order_accepted_phone_visibility` | SAME-NAME / timestamp mismatch | `20261110195000_add_order_accepted_phone_visibility.sql` | feature/flutter-mobile-apps |
| 20261110143332 | `add_admin_booking_contact_visibility` | SAME-NAME / timestamp mismatch | `20261110200000_add_admin_booking_contact_visibility.sql` | feature/flutter-mobile-apps |
| 20261111043852 | `srk_business_finance_reporting_dates` | EXACT version+name source | `20261111043852_srk_business_finance_reporting_dates.sql` | feature/business-finance-dashboard, work/separate-customer-electrician-portals |
| 20261111072823 | `add_electrician_push_subscriptions` | SAME-NAME / timestamp mismatch | `20261111020000_add_electrician_push_subscriptions.sql`<br>`20261111090000_add_electrician_push_subscriptions.sql` | feature/electrician-categories-hourly-booking, feature/production-push-notifications |
| 20261111072827 | `secure_push_subscription_upsert` | SAME-NAME / timestamp mismatch | `20261111120000_secure_push_subscription_upsert.sql` | feature/production-push-notifications |
| 20261111073357 | `enable_pg_net_for_electrician_push` | UNRESOLVED — source not found | — | — |
| 20261111075205 | `wire_job_offer_push_webhook` | UNRESOLVED — source not found | — | — |
| 20261111082515 | `add_assigned_electrician_cash_payment_status` | EXACT version+name source | `20261111082515_add_assigned_electrician_cash_payment_status.sql` | feature/production-push-notifications |
| 20261111083811 | `add_assigned_electrician_cash_payment_status` | SAME-NAME / timestamp mismatch | `20261111082515_add_assigned_electrician_cash_payment_status.sql` | feature/production-push-notifications |
| 20261111142316 | `retire_empty_legacy_electrician_booking_tables` | UNRESOLVED — source not found | — | — |
| 20261111153846 | `srk_booking_refund_requests_workflow` | EXACT version+name source | `20261111153846_srk_booking_refund_requests_workflow.sql` | feature/production-push-notifications |

## Next verification gates

- Obtain original SQL or trusted backup/export for all 39 unresolved rows.
- For all 26 timestamp-mismatch rows, compare candidate file bytes and derive object-level effects against the Production catalog; retain a per-object evidence trail.
- Investigate both cash-payment versions independently, including migration file history and schema effects.
- Only after all source evidence is recovered, create a dependency-ordered replay plan for a disposable Production-parity database and replay twice.
- Production remains read-only until separate explicit approval.


## Cross-branch source consistency check (2026-11-12)

A second scan compared GitHub blob hashes for each candidate path across all 11 branches:

- All branch copies of a given candidate path had the same blob hash; branch repetition is not independent evidence of Production provenance.
- The 26 timestamp-mismatch rows resolve to 27 distinct candidate paths because the Production push-subscription row has two different historical candidate paths: `20261111020000_add_electrician_push_subscriptions.sql` and `20261111090000_add_electrician_push_subscriptions.sql`. These are not interchangeable; prior SQL comparison found material differences.
- The duplicate cash-payment history row `20261111083811` only has the `20261111082515_add_assigned_electrician_cash_payment_status.sql` source candidate. This is not proof that the second Production migration was a duplicate/no-op.
- Two exact version+name source rows have divergent branch blob copies: `srk_business_finance_dashboard` and `srk_business_finance_reporting_dates`. Therefore even an exact filename/version row requires branch-specific content provenance and SQL comparison before being called an exact applied source.
- The other exact-name copies were byte-identical by Git blob hash across scanned branches, but still have not been proven identical to Production-applied SQL.

**Disposition remains unchanged:** no migration is approved for skip/replay/mark-applied from GitHub filename or branch repetition alone. The Production schema-object comparison and trusted original archive recovery are still mandatory.
