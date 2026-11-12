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


## Electrician identity-link consistency review (read-only)

Current Production function/policy definitions reveal an identity-key inconsistency:

- `srk_get_my_offer_details()` filters only `electrician_profiles.user_id = auth.uid()`.
- RLS policy `srk_read_authorized_electrician_payouts` authorizes the profile relation only through `ep.user_id = auth.uid()`.
- In contrast, `srk_electrician_confirm_cash_payment()`, `srk_get_my_assigned_cash_payment()`, `srk_get_my_offer_price_details()`, and the electrician profile SELECT policy accept either `user_id` or `auth_user_id`.

A read-only aggregate over current Production data found one electrician profile, active and approved, with both IDs set and equal; no current `auth_user_id`-only or mismatched identity record exists. Therefore this is a forward-compatibility/consistency gap, not evidence of a currently affected electrician or an authorization bypass. Keep the feature-branch v2 offer-details contract and payout access aligned with the dual-key identity model; do not modify Production or broaden policies without a separately reviewed migration and runtime tests.


## Refund cardinality and payment-ID lookup review (read-only)

Production `srk_razorpay_refunds` currently has a unique index on `booking_id`, a unique index on `idempotency_key`, and a unique index on nullable `refund_id`; there is no unique index and no ordinary index on `payment_id`. The current table contains zero refund rows, so no live duplicate-payment-ID case was observed. Schema semantics allow more than one refund row to reference the same provider payment ID, but only one refund row per booking. This is consistent with the webhook handler's safety behavior: if a payment-ID lookup matches multiple refund rows, it returns retryable ambiguity instead of reconciling an arbitrary row.

A feature-branch migration `20261112200000_index_refund_payment_lookup.sql` now adds a **non-unique** index on `payment_id`, preserving ambiguity detection while making the handler's lookup efficient as rows grow. It is replayed twice in the refund CI workflow; that workflow passed at run 43176559688. The integrated Timer parity workflow was extended too, but a shell continuation defect was found and corrected; its newest reruns are pending. This migration is not applied to Production.


### Final CI verification for refund payment lookup index — 2026-11-12
- Refund workflow run 43176559688: SUCCESS; applied `20261112200000_index_refund_payment_lookup.sql` twice and all refund/webhook handler and SQL tests passed.
- Integrated Timer parity workflow run 43176720772: SUCCESS; applied the same index migration twice after Timer 16000–16015, date-only/duration and refund chain; integrated assertions passed.
- An earlier run failed because the workflow shell loop omitted a continuation after the reconciliation migration; the defect was corrected, and the later run passed. No Production migration applied.
