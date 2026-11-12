# Production Migration History — Exact Comparison Register

**Checked:** 12 November 2026  
**Production project:** `gnqhoaqatmoiwwhgzkgm`  
**Repository branch:** `feature/production-push-notifications`  
**Production history entries:** 78  
**Branch migration files:** 57

## Result summary

- Exact version + name matches: **7**.
- Production entries whose name exists in branch but version differs: **10**.
- Production entries with no exact-name branch migration source: **61**.
- This is a filename/version comparison only. It does not prove SQL equivalence or permit migrations to be skipped, replayed, renamed, or marked applied.
- The Production history contains duplicate migration names at distinct versions (for example, `add_assigned_electrician_cash_payment_status` at two versions). Keep each version separate.

## All Production migration history entries

| Production version | Production migration name | Branch source status |
|---|---|---|
| `20261108092928` | `harden_srk_rls_policy_performance` | No exact-name source file in branch |
| `20261108093725` | `add_atomic_payment_order_lock` | No exact-name source file in branch |
| `20261108093757` | `add_service_role_policy_payment_order_locks` | No exact-name source file in branch |
| `20261108094007` | `harden_security_definer_function_search_paths` | No exact-name source file in branch |
| `20261108095224` | `add_missing_foreign_key_indexes` | No exact-name source file in branch |
| `20261108095928` | `add_actual_paid_amount_commission_and_status_history` | No exact-name source file in branch |
| `20261108102159` | `harden_payment_order_lock_search_paths` | No exact-name source file in branch |
| `20261108102323` | `harden_booking_broadcast_search_path` | No exact-name source file in branch |
| `20261108102612` | `harden_booking_guard_trigger_search_path` | No exact-name source file in branch |
| `20261108102837` | `enable_realtime_job_offer_updates` | No exact-name source file in branch |
| `20261108102951` | `enable_realtime_electrician_profile_updates` | No exact-name source file in branch |
| `20261108103531` | `guard_booking_assignment_and_amount_integrity` | No exact-name source file in branch |
| `20261108115205` | `tighten_legacy_definer_paths_and_history_grants` | No exact-name source file in branch |
| `20261108120608` | `add_public_api_rate_limiting` | Exact match — `20261108120608_add_public_api_rate_limiting.sql` |
| `20261108120658` | `enable_rls_public_api_rate_limits` | Exact match — `20261108120658_enable_rls_public_api_rate_limits.sql` |
| `20261108121115` | `add_customer_account_booking_access` | Exact match — `20261108121115_add_customer_account_booking_access.sql` |
| `20261108181453` | `restrict_public_form_inserts_to_server_functions` | No exact-name source file in branch |
| `20261108181538` | `combine_admin_customer_booking_read_policy` | No exact-name source file in branch |
| `20261108183027` | `add_google_maps_location_support` | Same name, different version — `20261109001000_add_google_maps_location_support.sql` |
| `20261108183324` | `expose_assigned_booking_map_pin` | Same name, different version — `20261109002000_expose_assigned_booking_map_pin.sql` |
| `20261108184254` | `electrician_earnings_summary` | No exact-name source file in branch |
| `20261108184815` | `protect_commission_columns_and_admin_report` | No exact-name source file in branch |
| `20261108184938` | `limit_booking_updates_and_correct_earnings_timestamp` | No exact-name source file in branch |
| `20261108190047` | `create_secure_wallet_ledger_foundation` | Same name, different version — `20261109010000_create_secure_wallet_ledger_foundation.sql` |
| `20261108193506` | `create_server_only_razorpay_route_transfer_ledger` | Same name, different version — `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql` |
| `20261109052929` | `harden_wallet_reporting_rpc_paths_and_route_recipient_index` | No exact-name source file in branch |
| `20261109053005` | `harden_wallet_and_commission_security_definer_paths` | No exact-name source file in branch |
| `20261109053301` | `grant_authenticated_select_service_bookings` | No exact-name source file in branch |
| `20261109053328` | `grant_authenticated_select_job_offers_for_rls_realtime` | No exact-name source file in branch |
| `20261109075837` | `electrician_inspection_quotes_and_service_only_commission` | Same name, different version — `20261109_electrician_inspection_quotes_and_service_only_commission.sql` |
| `20261109080121` | `lock_quote_workflow_rpcs_to_authenticated_users` | No exact-name source file in branch |
| `20261109080400` | `allow_quote_approval_booking_states` | Same name, different version — `20261109_allow_quote_approval_booking_states.sql` |
| `20261109081310` | `srk_manual_electrician_payout_ledger` | No exact-name source file in branch |
| `20261109082241` | `index_electrician_payout_foreign_keys` | No exact-name source file in branch |
| `20261109082620` | `lock_down_route_transfer_api_access` | No exact-name source file in branch |
| `20261109094209` | `add_secure_admin_booking_offer_flow` | No exact-name source file in branch |
| `20261109103038` | `customer_electrician_direct_call_contacts` | Exact match — `20261109103038_customer_electrician_direct_call_contacts.sql` |
| `20261109103143` | `move_customer_call_contact_lookup_to_private` | Exact match — `20261109103143_move_customer_call_contact_lookup_to_private.sql` |
| `20261109110140` | `align_electrician_payouts_with_booking_commission_rate` | No exact-name source file in branch |
| `20261109112032` | `allow_electricians_to_read_own_manual_payout_status` | No exact-name source file in branch |
| `20261109112105` | `consolidate_electrician_payout_read_policy` | No exact-name source file in branch |
| `20261109114000` | `protect_customer_and_electrician_phone_numbers_until_masked_calling` | No exact-name source file in branch |
| `20261109114642` | `enable_direct_customer_electrician_phone_calls` | No exact-name source file in branch |
| `20261109161539` | `customer_contact_after_completion` | No exact-name source file in branch |
| `20261109161545` | `hide_customer_details_on_cancelled_bookings` | No exact-name source file in branch |
| `20261109163755` | `fix_null_validation_quote_and_payout` | No exact-name source file in branch |
| `20261109164808` | `sync_electrician_auth_profile_link` | No exact-name source file in branch |
| `20261109165802` | `harden_electrician_payable_trigger_search_path` | No exact-name source file in branch |
| `20261109170626` | `expire_job_offers_when_booking_cancelled` | No exact-name source file in branch |
| `20261109170937` | `secure_admin_booking_updates_and_profile_columns` | No exact-name source file in branch |
| `20261109171033` | `tighten_admin_booking_rpc_input_validation` | No exact-name source file in branch |
| `20261109171621` | `add_admin_verified_manual_payment_workflow` | No exact-name source file in branch |
| `20261109171942` | `add_admin_verified_manual_refund_workflow` | No exact-name source file in branch |
| `20261109174234` | `allow_manual_payment_payout_settlement` | No exact-name source file in branch |
| `20261109175023` | `serialize_manual_refund_and_electrician_payout` | No exact-name source file in branch |
| `20261109180001` | `fix_manual_payout_special_forms` | No exact-name source file in branch |
| `20261109202321` | `admin_audit_log` | No exact-name source file in branch |
| `20261109202355` | `razorpay_refund_tables_and_audit_type` | No exact-name source file in branch |
| `20261109202505` | `razorpay_refund_prepare_rpc` | No exact-name source file in branch |
| `20261109202511` | `razorpay_refund_list_rpc` | No exact-name source file in branch |
| `20261109202534` | `razorpay_refund_audit_trigger` | No exact-name source file in branch |
| `20261109203132` | `customer_admin_complaints` | No exact-name source file in branch |
| `20261109203137` | `electrician_verification_documents` | No exact-name source file in branch |
| `20261110080448` | `srk_business_finance_dashboard` | No exact-name source file in branch |
| `20261110133835` | `restore_missing_customer_booking_quote_columns` | Same name, different version — `20261110140000_restore_missing_customer_booking_quote_columns.sql` |
| `20261110140719` | `add_electrician_offer_price_details_rpc` | No exact-name source file in branch |
| `20261110141125` | `add_assigned_booking_quote_ui_rpc` | No exact-name source file in branch |
| `20261110142310` | `add_order_accepted_phone_visibility` | No exact-name source file in branch |
| `20261110143332` | `add_admin_booking_contact_visibility` | No exact-name source file in branch |
| `20261111043852` | `srk_business_finance_reporting_dates` | No exact-name source file in branch |
| `20261111072823` | `add_electrician_push_subscriptions` | Same name, different version — `20261111090000_add_electrician_push_subscriptions.sql` |
| `20261111072827` | `secure_push_subscription_upsert` | Same name, different version — `20261111120000_secure_push_subscription_upsert.sql` |
| `20261111073357` | `enable_pg_net_for_electrician_push` | No exact-name source file in branch |
| `20261111075205` | `wire_job_offer_push_webhook` | No exact-name source file in branch |
| `20261111082515` | `add_assigned_electrician_cash_payment_status` | Exact match — `20261111082515_add_assigned_electrician_cash_payment_status.sql` |
| `20261111083811` | `add_assigned_electrician_cash_payment_status` | Same name, different version — `20261111082515_add_assigned_electrician_cash_payment_status.sql` |
| `20261111142316` | `retire_empty_legacy_electrician_booking_tables` | No exact-name source file in branch |
| `20261111153846` | `srk_booking_refund_requests_workflow` | Exact match — `20261111153846_srk_booking_refund_requests_workflow.sql` |

## Branch migration files with no exact-name Production history entry

`20261108233500_restrict_public_form_inserts.sql`
`20261108234000_combine_booking_read_policy.sql`
`20261109003000_secure_commission_reporting.sql`
`202611110001_timer_billing_materials_foundation.sql`
`202611110002_timer_billing_integrity_extensions.sql`
`202611110003_customer_approved_timer_rpcs.sql`
`202611110004_scoped_timer_bill_read_rpc.sql`
`202611110005_server_authoritative_booking_creation.sql`
`202611110006_preserve_labour_calculation_precision.sql`
`202611110007_material_revision_customer_approval_rpcs.sql`
`202611110008_customer_payable_snapshot_rpc.sql`
`202611110009_razorpay_snapshot_order_ledger.sql`
`202611110010_cash_payment_intent_receipt_confirmation.sql`
`202611110011_repair_payable_snapshot_rounding_constraint.sql`
`20261111130000_customer_cancellation_admin_decision.sql`
`20261111150000_timer_commission_cash_online_integration.sql`
`20261111160000_timer_billing_materials_foundation.sql`
`20261111160001_timer_billing_integrity_extensions.sql`
`20261111160002_customer_approved_timer_rpcs.sql`
`20261111160003_scoped_timer_bill_read_rpc.sql`
`20261111160004_server_authoritative_booking_creation.sql`
`20261111160005_preserve_labour_calculation_precision.sql`
`20261111160006_material_revision_customer_approval_rpcs.sql`
`20261111160007_customer_payable_snapshot_rpc.sql`
`20261111160008_razorpay_snapshot_order_ledger.sql`
`20261111160009_cash_payment_intent_receipt_confirmation.sql`
`20261111160010_repair_payable_snapshot_rounding_constraint.sql`
`20261111160011_customer_cancellation_admin_decision.sql`
`20261111160012_timer_commission_cash_online_integration.sql`
`20261111160013_guard_legacy_quote_status_paths_from_timer_bookings.sql`
`20261111160014_keep_customer_call_contact_after_completion.sql`
`20261111160015_timer_snapshot_refund_support.sql`
`20261112100000_permanent_electrician_display_ids.sql`
`20261112110000_customer_booking_order_numbers.sql`
`20261112120000_electrician_offer_order_number_rpc.sql`
`20261112130000_customer_booking_date_only.sql`
`20261112140000_customer_booking_duration_pricing.sql`
`20261112150000_versioned_rate_catalogue.sql`
`20261112160000_admin_rate_catalogue_management.sql`
`20261112170000_public_customer_rate_catalogue_rpc.sql`
`20261112180000_razorpay_webhook_event_ledger.sql`

## Required reconciliation method

1. For each same-name/different-version entry, retrieve the corresponding source SQL from version control or another trusted migration archive; compare it to the branch SQL statement-by-statement and compare the resulting live schema objects.
2. For each Production-only history entry, recover its exact source SQL if possible. Do not fabricate a replacement migration from the migration name or current schema.
3. For each branch-only entry, identify whether it is genuinely pending, a forward-copy duplicate, superseded, or already represented by a different Production migration.
4. Inspect current schema definitions, constraints, indexes, triggers, RLS policies, grants, functions and relevant legacy data before deciding any migration disposition.
5. Test the proposed forward-only plan on a disposable Production-shaped database with a clean replay and a second replay. Preserve legacy data and assert no unintended changes.
6. Production remains read-only until this reconciliation is complete and the owner separately approves a release.

## Safety status

**NO-GO for Production.** This register was generated from the read-only Production migration list and GitHub branch tree. No Production schema or data was changed.
