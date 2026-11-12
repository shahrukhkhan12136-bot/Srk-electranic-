# Production Supabase Schema Inventory — 2026-11-12

Project: `gnqhoaqatmoiwwhgzkgm`  
Method: read-only PostgreSQL catalog queries only. No schema/data/migration-history writes.

## Catalog totals

| Object | Count / observation |
|---|---:|
| Public base tables | 25 |
| Public constraints | 182 |
| Non-internal public triggers | 15 |
| Public indexes | 81 |
| Public RLS policies | 24 |
| Public tables with RLS disabled | 0 |
| Public tables with FORCE ROW LEVEL SECURITY | 0 |

All 25 public base tables currently have RLS enabled. FORCE RLS is false for all 25. This is a catalog snapshot, not a complete adversarial RLS runtime test.

## Public base tables

- `electrician_applications`
- `electrician_profiles`
- `job_offers`
- `service_booking_status_history`
- `service_bookings`
- `services`
- `srk_admin_audit_events`
- `srk_admin_users`
- `srk_booking_complaint_events`
- `srk_booking_complaints`
- `srk_booking_refund_requests`
- `srk_electrician_payouts`
- `srk_electrician_verification_documents`
- `srk_electrician_verification_events`
- `srk_manual_payment_entries`
- `srk_manual_refund_entries`
- `srk_payment_order_locks`
- `srk_push_subscriptions`
- `srk_razorpay_refunds`
- `srk_razorpay_webhook_events`
- `srk_route_transfers`
- `srk_wallet_accounts`
- `srk_wallet_bank_links`
- `srk_wallet_ledger`
- `states`

## Tables with no RLS policies

Ten tables have RLS enabled but no policies. Current table ACL check shows anon and authenticated lack SELECT and INSERT on all ten; service_role has SELECT/INSERT/UPDATE/DELETE. This is currently default-deny at the table ACL/RLS layer, not evidence of a direct client exposure. Keep this service-only posture unless an audited RPC path requires otherwise.

1. `srk_admin_audit_events`
2. `srk_booking_complaint_events`
3. `srk_booking_complaints`
4. `srk_booking_refund_requests`
5. `srk_electrician_verification_documents`
6. `srk_electrician_verification_events`
7. `srk_manual_payment_entries`
8. `srk_manual_refund_entries`
9. `srk_razorpay_refunds`
10. `srk_razorpay_webhook_events`

## Timer release gap reconfirmed

The current Production `service_bookings` table has the older booking/quote/payment columns, including nullable `preferred_date` and `preferred_time`, but lacks the Timer release additions and the newer duration-pricing contract. Specifically, no Timer booking category/snapshot/timer-start/timer-stop/final-bill columns were found; `duration_hours` is absent. The Timer foundation relations remain absent, including `srk_booking_timer_decisions`, `srk_final_bills`, `srk_bill_material_items`, `srk_bill_material_approvals`, `srk_booking_payable_snapshots`, `srk_cash_receipts`, and `srk_timer_cash_refund_entries`.

Production already has `srk_razorpay_webhook_events`, which is the existing payment/refund webhook event table with `event_id`, `event_type`, `processing_status`, `received_at`, and payment/refund identifiers. Do not rename or repurpose it. The feature-branch `srk_payment_webhook_events` Timer receipt ledger and the new `srk_razorpay_webhook_event_ledger` refund lease ledger are separate new release contracts and must be replayed/verified independently on disposable parity.

## Existing trigger observations

15 non-internal triggers were catalogued. They include:
- electrician application/profile audit triggers;
- job-offer push trigger `trg_srk_push_job_offer`;
- service booking guard, broadcast, audit, commission, cancellation-offer expiry, status-history and electrician-payable triggers;
- payout/manual-payment/manual-refund/razorpay-refund audit triggers.

All 15 were enabled in the catalog query. This inventory does not prove external webhooks or notifications were delivered; no live send was performed.

## Important RLS policy observations

The 24 current public policies include:
- customer/Admin booking SELECT and Admin UPDATE;
- electrician/Admin profile and offer reads;
- own push subscription CRUD policies;
- owner-read wallet policies;
- service-role-only payment-lock management;
- service-role-only booking-history management;
- explicit deny for anon/authenticated on Route transfers;
- public read of active services and states.

A complete expression/grant matrix and runtime adversarial tests are still required. In particular, verify the difference between `user_id` and `auth_user_id` across electrician-owned policies and RPCs, without making broad changes without evidence.

## Next steps

1. Complete object-level mapping of all 78 Production migration-history rows to current columns, constraints, indexes, triggers, functions, policies and grants.
2. Recover trusted source SQL for the 39 unresolved history rows; compare all 26 timestamp-mismatch candidates.
3. Review FK index coverage and migration provenance before proposing any index migration.
4. Build a disposable Production-parity database and replay only after source recovery and dependency ordering are resolved.
5. Keep Production read-only until separate explicit approval.
