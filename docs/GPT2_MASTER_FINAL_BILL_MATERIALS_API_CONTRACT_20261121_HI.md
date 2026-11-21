# GPT-2 Master Final Bill + Materials API Contract (2026-11-21)

Feature branch: `feature/master-technician-payment-cycle-20261121`

Migration: `supabase/migrations/20261121180000_master_final_bill_and_customer_material_approval.sql`

## Current scope

This migration adds the consolidated Master final-bill foundation and customer-approved material requests. It is source-only. It has **not** been applied to TEST or Production. The Master and legacy booking feature flags remain disabled.

The existing booking system is updated in place. This is not a second booking system.

## Materials flow

1. An assigned, accepted/active canonical Technician submits one itemized estimate through `srk_technician_submit_booking_materials(booking_id, items)`.
2. Each item uses:
   - `name`
   - `quantity`
   - `unit_price_paise`
3. Server validates the authenticated Technician identity and active booking assignment. The client cannot submit a material total independently.
4. Request status begins as `pending_customer`.
5. The customer who owns the booking approves or rejects through `srk_customer_decide_booking_materials(request_id, decision, note)`.
6. Only approved materials are included in the final bill. Rejected or unrequested materials contribute zero. A pending decision blocks final-bill creation.
7. Material request items and decision events are append-only; the final bill is immutable.

Only one material request is currently allowed per booking. This intentionally prevents silent replacement of an already submitted estimate. A later change-order workflow must use a separately versioned request/event design rather than mutating the original.

## Final bill

Service-role backend calls `srk_service_role_build_master_final_bill(booking_id)` after:
- canonical Master booking is customer-confirmed completed;
- every daily Technician workday is stopped;
- at least one immutable Technician daily labour-ledger row exists;
- any material request has been approved or rejected.

The function aggregates every row in `srk_booking_technician_labour_ledger`, including each Technician and their selected Helper, into one booking-level labour total. It is idempotent and refuses a replay if the saved bill does not match the current immutable ledger totals.

Commission uses the booking's `srk_commission_rate_snapshot` and applies to labour only. Material amount is passed through separately:
- Company commission = labour × snapshotted commission percentage.
- Technician labour payable = labour − company commission.
- Technician material reimbursement = customer-approved materials.
- Technician total payable = Technician labour payable + material reimbursement.

The rate is snapshotted at booking insertion and existing rows are backfilled from their stored `commission_rate`. Missing/invalid commission snapshots block final-bill creation; no rate is invented.

## RPC access

| RPC | Caller | Purpose |
|---|---|---|
| `srk_technician_submit_booking_materials(uuid,jsonb)` | Authenticated assigned Technician | Submit itemized material estimate |
| `srk_customer_decide_booking_materials(uuid,text,text)` | Authenticated booking customer | Approve/reject estimate |
| `srk_service_role_build_master_final_bill(uuid)` | Service role only | Build immutable consolidated bill |

Underlying tables have RLS enabled and direct anon/authenticated access revoked.

## Not yet integrated

This migration does not yet:
- expose customer/technician/Admin read RPCs for the new material and final-bill records;
- connect `create-order.js`, `verify-payment.js`, or Razorpay webhook to the Master final bill;
- refactor refund preparation/reconciliation away from legacy quotation assumptions;
- implement Master cash-payment recording or settlement reconciliation;
- add GST calculation/invoice/credit-note records.

Therefore, do not enable booking flags, create live orders, accept live payments, issue payouts, apply migrations, or deploy based on this foundation alone. Historical quote/payment records remain untouched.
