# GPT-2 — Master GST, Tax Invoice, Credit Note & Gateway Fee GST (21-11-2026)

Feature branch: `feature/master-technician-payment-cycle-20261121`

## Design
- No statutory GST rate is hard-coded. Main Admin must explicitly configure company registration status, legal name, GSTIN/state (if registered), invoice prefix and effective date.
- Admin configures separate effective-dated labour and materials tax rules per service category + service/skill code. Taxable=false requires 0 basis points; taxable=true requires an explicit rate.
- Indian state-code map determines place of supply from the booking work address. Registered supplier in same state: CGST+SGST; different state: IGST. Unregistered company profile records no GST charged.
- Snapshot captures GSTIN/profile version, place of supply, taxable base, rate and each tax component in integer paise. Technician commission and payables remain calculated on labour only and exclude GST.
- Missing company profile, state mapping or applicable rate rule blocks final-bill creation/payment rather than silently assuming 0% or 18%.

## Documents
- On verified Master payment, one immutable tax invoice is issued with invoice JSON snapshot.
- On full refund, one immutable credit note is issued and invoice is marked credited_full. Partial refunds are not supported by this credit-note flow.
- Gateway fee and gateway-fee GST are recorded separately with provider reference, rate, amount, supplier invoice reference and Admin input-tax-credit eligibility flag. No automatic ITC claim is made.
- Admin GST summary RPC returns invoices, credit notes and gateway-fee entries for a bounded date range.

## RPCs
- `srk_admin_configure_gst_company(...)`
- `srk_admin_upsert_gst_service_rule(...)`
- `srk_admin_record_master_gateway_fee_tax(...)`
- `srk_admin_get_master_gst_summary(p_from,p_to)`

## Important integration gate
This migration creates immutable tax snapshots and documents but the existing Master Razorpay create-order, verify-payment, webhook, manual payment, refund and customer receipt paths still need a coordinated update to use `total_due_paise` instead of pre-tax `subtotal_paise`. Do not enable Master payments until that follow-up is completed and validated. Existing legacy bookings and historical quote/receipt paths remain untouched.

## Verification boundary
Source-only Feature Branch files. No database apply, no production changes, no live payments, no deployment. Node contracts and pgTAP source are added; pgTAP runtime and isolated end-to-end replay remain pending. Obtain accountant/tax-professional confirmation of the actual registration, SAC/HSN classification, place-of-supply and applicable rates before operational use.
