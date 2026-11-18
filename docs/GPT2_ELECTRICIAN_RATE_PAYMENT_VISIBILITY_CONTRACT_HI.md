# GPT-2 — Electrician Rate & Payment Visibility Contract (Source-only)

Status: contract and source-audit specification. This document does NOT claim production implementation.
No database migration, production database mutation, deployment, or PR merge is authorized by this document.

## Confirmed source findings

1. `booking.html` defines a client-side `customerRateCard` with four hard-coded 8-hour rates.
2. `create-booking.js` independently defines the same four hard-coded rates and a static `rateCardVersion`. It calculates and persists `estimated_labour_paise` as the full customer labour estimate.
3. `electrician.html` renders `estimated_labour_paise` directly in the job-offer card. This is the gross customer labour amount, not the electrician's 85% offer.
4. The existing `srk_get_my_earnings()` migration returns `amount_received` and `commission_amount` for assigned rows without gating those fields on the payment stage. UI filtering cannot repair an RPC disclosure.
5. Pure helpers for 85% calculation, rate-version resolution, booking snapshots, and electrician rate views exist, but are not wired into the live booking/offer/payment API flow.

## Required invariant

For a booking with customer labour gross G (paise):
- electrician net E = round-half-up(G * 8500 / 10000)
- company residual C = G - E
- G = E + C
Use integer paise arithmetic. Preserve any existing platform commission only after its relationship to C has been reconciled; never subtract the same 15% twice.

## Visibility state machine

| State | Electrician may receive | Must not receive |
|---|---|---|
| Offer / before acceptance | E, category, duration, rate version | G, C, commission |
| Accepted / work in progress | own job details and E where appropriate | G, C, commission |
| Completed, checkout not started | E as payable estimate | G, C, commission, actual customer receipt |
| Verified checkout/payment stage started | G due, E, C | other bookings' accounting |
| Payment succeeded | actual customer amount received, E, C, separate payout status | another electrician's data |

The payment-stage transition must be derived server-side from a verified payment-intent/checkout record. Never trust a browser flag or client-supplied payment status.

## API contract for GPT-1

### Customer rate catalogue
`GET /api/customer/rates`
Returns the currently published version and full customer prices for display. The server remains authoritative at booking creation; browser-sent amounts are ignored.

### Electrician rate catalogue
`GET /api/electrician/rates`
Returns only the authenticated electrician's server-derived approved categories, 8-hour baseline, 85% net amounts, version ID and effective timestamp. No gross/customer/company fields.

### Job offers
Offer DTO exposes `electrician_offer_paise` (85% net) and safe job fields only. It must not serialize `estimated_labour_paise` from the booking row to the electrician client.

### Completed unpaid accounting
Returns only `electrician_payable_paise` and payment status. No gross, company share, commission, or customer receipt fields.

### Checkout-started accounting
Only after server verifies the associated checkout/payment intent has started, return:
- `customer_payment_due_paise`
- `electrician_earning_paise`
- `company_share_paise`

### Paid accounting
After verified payment success, return:
- `customer_amount_received_paise`
- `electrician_earning_paise`
- `company_share_paise`
- separate `electrician_payout.payout_status` and `payout_amount_paise`

All endpoints/RPCs must authenticate the caller, verify booking ownership/assignment, and enforce the same visibility state machine on the server.

## Required backend changes (not yet applied)

1. Replace hard-coded booking rates with server-side resolution of the active published Admin catalogue/version. Do not accept a customer amount from the browser as authority.
2. Persist an immutable booking snapshot containing rate version, customer gross, electrician net, company residual, duration and currency. Existing bookings/bills must remain unchanged.
3. Build a safe offer DTO that exposes only electrician net. Remove gross amount from the electrician-facing offer select/response, not merely from HTML rendering.
4. Change `srk_get_my_earnings()` or replace it with a backward-compatible secured RPC contract that omits gross/company fields before verified checkout start. Verify grants, RLS and direct table access as well as RPC output.
5. Make checkout-started and payment-succeeded transitions server-derived from verified payment records; keep customer receipt and electrician payout as separate accounting records.
6. Reconcile the existing 15% commission against the company residual before changing any formula. No double deduction.
7. Add tests for every visibility state, unauthorized booking IDs, category allowlisting, rate version changes, immutable old snapshots, payment replay/idempotency and rounding.

## Safe rollout boundary

This branch work is source-only until separately authorized. Do not apply migrations, mutate production data, create a Paid DB branch, deploy, or merge PR #8 without explicit approval. GPT-1 should integrate only against this contract and must not assume endpoints above are already deployed.
