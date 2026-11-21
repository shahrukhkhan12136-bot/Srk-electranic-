# SRK ELECTRONIC — Cash Commission Due and Online Recovery
Date: 21 November 2026
Migration: `supabase/migrations/20261121260000_master_cash_commission_due_and_online_offset.sql`

## Business rule
- Labour split remains 85% Technician / 15% SRK ELECTRONIC.
- If Technician directly collects a customer's cash payment, their 85% is recorded as cash already collected and the 15% SRK commission is recorded as a separate outstanding due.
- If customer pays the company through Razorpay, UPI or bank transfer, the Technician's 85% payable is first reduced by any older cash commission due. Recovery is applied oldest due first.
- Materials reimbursement remains separate and is not treated as commission-bearing labour.
- Razorpay gateway fees remain separate company expenses and do not change the 85/15 calculation.
- Admin manual payout continues to include only pending net payables. Wallet is cleared only after Admin records the real transfer UTR and confirms Paid.

## Wallet fields
`srk_master_wallet_summary()` now adds cash already collected, outstanding company commission due, recovered commission total, net offset total, and booking-level commission due history.

## Audit and concurrency
- Technician row is locked while cash dues or online offsets are processed, serializing concurrent booking entries for that Technician.
- Commission due/recovery events are append-only.
- Direct client table access is revoked; summary is returned through authenticated RPC.
- Existing payout UTR workflow remains unchanged.

## Scope / validation
Feature Branch source only. No DB migration applied. Node contract tests and pgTAP source are included; pgTAP still needs disposable PostgreSQL execution. Full DB replay and end-to-end testing remain deferred until the single Development Branch is created at the end, as previously agreed.
