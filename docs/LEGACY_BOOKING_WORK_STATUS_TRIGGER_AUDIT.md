# Legacy booking work-status and trigger audit

Date: 2026-11-11
Scope: read-only Production catalog inspection for timer-RPC safety.
Project: `gnqhoaqatmoiwwhgzkgm`
Branch: `feature/production-push-notifications`

## Existing `srk_update_booking_work_status(uuid,text)`

Verified function body:

- Rejects missing `auth.uid()`.
- Accepts only `inspection`, `in_progress`, and `completed`.
- Finds electrician profile only by `electrician_profiles.user_id = auth.uid()`, with `verification_status='approved'` and `active=true`. It does not check `auth_user_id`.
- Locks the assigned booking row using `FOR UPDATE`.
- Allows `assigned -> inspection`.
- Allows `quote_approved` + `quote_status='approved' -> in_progress`, and writes legacy `work_started_at=now()`.
- Allows `in_progress -> completed`.
- Rejects all other transitions.
- Function is SECURITY DEFINER, configured with `search_path = pg_catalog, public, auth, pg_temp`, and EXECUTE is granted to `authenticated`, `postgres`, and `service_role`.

### Timer migration implications

1. This function is incompatible with the approved timer contract: it lets the electrician move work to `in_progress` without customer timer approval and writes `work_started_at` itself.
2. It is not safe to repurpose this function as the timer RPC. Create narrow new RPCs and retire/revoke this legacy path only after a repository-wide caller audit and coordinated client/API release.
3. The profile identity lookup must support the approved `user_id OR auth_user_id` linkage in the new RPC, with ambiguity handled explicitly if both links match multiple profiles.
4. Legacy completion must not be callable as an alternative to customer-approved timer stop and final bill generation.

## Verified non-internal triggers on `service_bookings`

### `a_guard_booking` — BEFORE INSERT

Calls `guard_new_booking()`. It forces new status to `new`, payment status to `unpaid`, assigned electrician to NULL, commission rate to 15, commission amount to NULL, and created_at to now. No timer implications for updates.

### `broadcast_new_booking` — AFTER INSERT

Calls `broadcast_booking_job()`. It creates offers for active approved electricians matching PIN/state/district, or district/state fallback when there is no PIN match. It does not itself record an acceptance or set the booking's assigned electrician.

### `srk_audit_service_bookings` — AFTER INSERT/UPDATE/DELETE

Calls `srk_capture_admin_audit_event()`. For booking rows it currently audits only:
`status, payment_status, payment_method, amount_paid, quoted_amount, quote_status, service_charge, materials_amount, assigned_electrician_id, commission_amount`.
It does NOT include timer fields, arrival fields, final_bill_id, or timer state. New timer decisions and final bills therefore need their own immutable, append-only audit ledger; do not assume the generic admin audit captures timer events.

### `srk_calculate_booking_commission` — BEFORE INSERT or UPDATE OF status/payment_status/amount_paid/commission_rate

Calls `srk_calculate_booking_commission()`. It validates amount_paid, commission_rate, and service_charge; it computes commission only when status is completed and payment_status is paid, otherwise sets commission_amount NULL. A timer-only UPDATE statement that does not name these columns will not fire this trigger. A legacy status update to completed will fire it.

### `srk_cancel_booking_job_offers` — AFTER UPDATE OF status

Runs only when status changes to cancelled. It cancels offered/accepted job offers. Timer-only field updates do not fire it.

### `srk_log_service_booking_status` — AFTER INSERT or UPDATE OF status

Calls `srk_log_service_booking_status()`. It appends a status history row only when status changes. Timer-only updates do not fire it. It uses `auth.uid()` as changed_by; service/system calls may record NULL.

### `trg_srk_create_electrician_payable` — AFTER INSERT or UPDATE OF payment_status/status/quote_status/service_charge/materials_amount/assigned_electrician_id/payment_verified_at/razorpay_payment_id/amount_paid

Calls `srk_create_electrician_payable()`. It creates/updates the electrician payable only when payment is paid, booking is completed, quote is approved, electrician assigned, payment verified, and a Razorpay payment or matching manual payment entry exists. It calculates the legacy payout from service_charge + materials_amount and quote commission. Refunded payments can mark pending payouts refunded.

A timer-only UPDATE statement that does not name these listed columns will not fire this trigger. Do not update legacy payment/quote/status fields as part of timer RPCs until payout/commission migration is designed and tested.

## High-priority design consequences

- Keep timer RPC updates restricted to timer-specific columns; do not casually update `status`, `work_started_at`, quote fields, or payment fields.
- Add a separate immutable timer decision/final bill audit trail because the generic audit trigger omits all new timer columns.
- Existing `srk_update_booking_work_status` must be included in the legacy quote/workflow retirement plan; its current `in_progress` transition bypasses customer approval.
- The timer flow's arrival evidence must be independently recorded and validated; the inspected status function contains no arrival check.
- Assignment/acceptance must be validated using the actual job-offer/booking acceptance workflow. The insert broadcast trigger alone is not evidence that a particular electrician accepted.
- Do not assume status history or generic admin audit is a complete timer audit.

## What this audit did not do

- No SQL write, migration, function execution, or row mutation.
- No change to Production or shared TEST.
- No RPC implementation.
- No change to legacy function grants.
- No deployment.

## Next required read-only audit

Inspect job-offer acceptance functions and status constraints, all repository callers of `srk_update_booking_work_status`, generic Admin booking update paths, and table-level grants/RLS before drafting RPC SQL. Then implement and test in a disposable database reconstructed from a verified schema snapshot.