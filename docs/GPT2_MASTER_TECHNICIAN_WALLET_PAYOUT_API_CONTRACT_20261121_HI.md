# GPT-2 — Master Technician Wallet & Payout API Contract (21-11-2026)

Feature branch: `feature/master-technician-payment-cycle-20261121`

## RPCs
- `srk_master_wallet_summary()`: authenticated canonical Technician; returns INR totals in paise for earned, pending, requested, paid, blocked, refunded and recent payable rows. It aggregates across all service categories by `srk_technicians.id`.
- `srk_technician_request_master_payout(p_destination_type,p_destination_reference,p_idempotency_key)`: `upi|bank`; creates one request against every currently pending payable row, records immutable request-item references, and changes those payable rows to requested. Same idempotency key returns the existing request. Only one open request per Technician.
- `srk_admin_confirm_master_company_settlement(p_payment_id,p_settlement_reference,p_settled_amount_paise,p_evidence_note)`: Admin-only evidence record for an actually settled Razorpay collection. Amount must cover that payment. It does not infer a settlement timeline.
- `srk_admin_list_master_payout_requests()`: Admin-only queue with Technician ID/name, requested amount, destination reference, payable count and per-collection settlement status.
- `srk_admin_mark_master_payout_paid(p_request_id,p_method,p_transfer_reference,p_note)`: Admin-only; records a real UPI/bank transfer after settlement gate. Duplicate UTR is blocked. Cash-collected bookings do not require Razorpay settlement evidence.

## Safety
- Master payable rows remain the accounting source; payout request items link exact payable IDs.
- Request creation is idempotent and serialized on canonical Technician row.
- Online payout cannot be marked paid until every linked Razorpay payment has confirmed company settlement evidence.
- Cash/UPI/bank manual customer collection is separately identified; no false Razorpay settlement gate.
- Legacy `srk_electrician_payouts`, wallet and payout RPCs are not dropped or replaced.
- This change is source-only. No database migration was applied, no Main Branch or production change, no live transfer or deployment.
- Important: settlement and transfer evidence are Admin attestations in this version; automated bank/provider reconciliation is still required before production rollout.
