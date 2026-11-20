# SRK ELECTRONIC — Gateway Fee, Tax and Bank Settlement Reconciliation Design

**Status:** Design/audit only — not a migration or live integration.  
**Branch:** `feat/ai-rate-management-foundation-20261118`  
**Safety:** No hosted Supabase schema/data changed; no Razorpay API, real payment, refund, bank transfer, deployment or merge performed.

## 1. Finding

The current Admin booking reconciliation already combines booking collection evidence, refund amounts/status, labour/material amounts, the canonical platform commission and electrician payable, payout ledger, Route transfer details, wallet/cancellation-fee entries, and exception flags.

However, the reviewed SQL source does not establish a durable, transaction-linked ledger for the actual Payment Gateway fee and its tax, nor a complete bank-settlement batch/UTR reconciliation. The existing read-only booking reconciliation is not proof that those values are recorded at source.

This gap must be closed before claiming end-to-end automated accounting.

## 2. Provider evidence model

Razorpay's documentation distinguishes a payment from the later settlement and explains that a payment's settlement details can be opened through its settlement ID. Settlement reports map transactions to settlement IDs; the dashboard exposes fee and tax breakdowns. Route transfer responses separately expose transfer `fees`, `tax`, `amount`, `amount_reversed`, and `recipient_settlement_id`. These are different financial events and must not be conflated.

Required evidence types:

1. **Payment capture evidence:** booking ID, Razorpay order ID, payment ID, amount in paise, currency, payment method, capture status/time, source event/report reference.
2. **Gateway fee/tax evidence:** provider fee in paise, provider tax in paise, fee/tax source (settlement report/invoice/API), provider row/reference, evidence hash, observed/imported timestamp. Do not derive a gateway fee from an assumed percentage.
3. **Settlement batch evidence:** Razorpay settlement ID, gross/adjustment/fee/tax/net amounts in paise, settlement status/time, bank UTR/reference, bank credited date and reconciliation status.
4. **Settlement allocation evidence:** exact payment/refund/adjustment rows allocated to each settlement ID, preserving provider row identity and raw source evidence hash.
5. **Platform accounting:** retain the existing canonical booking calculation for 15% commission and electrician share. Do not recompute or change the commission base/rounding as part of gateway reconciliation.
6. **Route transfer evidence:** keep linked-account transfer IDs and recipient settlement IDs separate from the merchant's own bank settlement batch.

## 3. Proposed storage contract (not yet implemented)

Use separate append-only records for provider settlement batches and provider settlement line items, rather than adding mutable fee columns to `service_bookings`.

### Settlement batch

- Internal UUID primary key.
- Provider name and provider account/environment identifier (never API secret).
- Provider settlement ID, unique within provider/account/environment.
- Currency (INR), gross amount, adjustments, fee amount, tax amount, net amount — integer paise, non-negative where applicable.
- Provider settlement status and provider timestamps.
- Bank UTR/reference and bank-credit evidence/status (nullable until confirmed).
- Source report/file identifier, SHA-256 of original evidence, import observation ID (idempotency key), imported_at.
- Created by trusted server/service process; no browser direct writes.

### Settlement line

- Internal UUID primary key and FK to batch.
- Provider line identity / deterministic source-row key, unique within provider/account/environment.
- Payment ID and/or refund ID and/or adjustment ID (at least one valid provider transaction reference).
- Booking ID nullable only when the provider row is genuinely not yet matched; unmatched rows must enter an exception queue, not be discarded.
- Gross, refund/adjustment, fee, tax and net allocation in integer paise.
- Currency, provider event/settlement timestamp, source row hash and raw evidence JSON with secrets/PII excluded.
- Append-only correction model: a new observation/reversal/reconciliation event, never silent overwrite of imported source evidence.

## 4. Reconciliation invariants

- A provider settlement ID cannot be imported twice for the same provider/account/environment.
- A source row cannot be allocated twice; repeated import of the same observation is idempotent.
- All monetary values are integer paise in storage; convert to rupees only for display.
- For each settlement batch, the provider-reported net must reconcile to the provider's gross less fees, tax, refunds/adjustments/other deductions according to the actual report schema. Do not assume every report uses one universal formula; encode the report version and source fields.
- Sum of allocated line amounts must equal the provider batch totals for the fields that the report actually supplies. Any mismatch remains an explicit exception.
- A payment capture is not a bank settlement. Do not mark funds bank-settled until settlement evidence and bank UTR/credit evidence are matched.
- Missing fee/tax values are unknown, not zero.
- Razorpay fee tax is separate from SRK's own GST/tax obligations. Do not label gateway tax as SRK output GST or input-tax credit without invoice and accountant review.
- Refunds do not automatically reverse the original gateway fee/tax. Preserve the provider's actual refund/fee adjustment evidence.
- Route transfer fees/tax and recipient settlement evidence are tracked independently from the merchant bank settlement.
- Existing 15% commission and electrician payable formulas remain unchanged.

## 5. Security and audit requirements

- RLS enabled on every public-schema table; browser roles receive no direct INSERT/UPDATE/DELETE on settlement evidence.
- Trusted import/finalization functions use tightly scoped service-role access, fixed search_path, explicit grants/revokes, input bounds, provider/account scoping and idempotency.
- Append-only source evidence protected against UPDATE/DELETE, with correction events rather than destructive edits.
- Admin read-only reconciliation RPC reports matched, unmatched, pending, disputed and bank-confirmed totals and exposes exception reasons.
- Do not store API secrets, card data, bank account numbers, or unnecessary personal data in raw evidence.
- Run security advisors and disposable PostgreSQL migration/pgTAP tests before considering a migration ready.

## 6. Required database/runtime tests before approval

1. Duplicate settlement ID rejected for same provider/account.
2. Duplicate source row rejected; exact repeated import is idempotent.
3. Same provider ID in a different account/environment is handled according to scoped uniqueness.
4. Missing fee/tax stays NULL/unknown, not zero.
5. Batch arithmetic matches exact source fields and currency.
6. Unmatched payment/refund/adjustment creates a visible exception.
7. Payment capture alone never marks bank settlement complete.
8. Missing/mismatched UTR remains pending or exception.
9. Route transfer settlement is not confused with merchant bank settlement.
10. UPDATE/DELETE of source evidence rejected.
11. Browser roles cannot read restricted provider evidence or write any settlement rows.
12. Unauthorized service/admin calls fail; valid trusted import succeeds.
13. Concurrent duplicate imports serialize safely.
14. Rollback leaves no partial batch/line rows.
15. Existing bookings, payouts, refunds and historical wallet rows remain unchanged.

## 7. Next implementation sequence

1. Inspect the authoritative full schema and current provider/webhook ingestion paths, including any existing payment-fee or settlement tables not surfaced by the initial targeted search.
2. Confirm which Razorpay settlement report/API version will be used and obtain a sample with secrets/customer data removed.
3. Finalize the batch/line schema against that exact source format.
4. Add a new migration and pgTAP tests on the feature branch only.
5. Run full deterministic migration replay, pgTAP, duplicate/concurrency tests and security review.
6. Only after explicit approval, consider applying to the hosted TEST project. Production remains separately gated.

## 8. Official provider references reviewed

- Razorpay Dashboard: payment details link to settlement details; settlement ID opens breakdown; settlement reports map transactions to settlement IDs.
- Razorpay Route transfer API: response includes `fees`, `tax`, `amount`, `amount_reversed`, and `recipient_settlement_id`.
- Razorpay terms: fees are separate from applicable taxes; the actual charges and tax must be grounded in provider evidence/invoices.

**Important:** This document is a design contract. It does not claim the proposed tables, import process, bank matching, or live accounting are implemented.
