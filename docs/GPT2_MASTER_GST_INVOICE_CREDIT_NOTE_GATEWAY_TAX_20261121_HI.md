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
- `srk_customer_get_master_tax_invoice(p_booking_id)`: केवल उसी verified Customer को उसकी invoice snapshot और उपलब्ध full-refund credit note देता है।
- `srk_admin_get_master_gst_summary(p_from,p_to)`: Admin Panel की date-range report में invoice, credit note और gateway fee GST rows देता है।
- `srk_admin_configure_gst_company(...)`
- `srk_admin_upsert_gst_service_rule(...)`
- `srk_admin_record_master_gateway_fee_tax(...)`
- `srk_admin_get_master_gst_summary(p_from,p_to)`

## Payment integration
- Razorpay create-order, verify-payment and signed webhook now use the immutable `total_due_paise` tax snapshot and cross-check it against the pre-tax final bill plus tax.
- Online and Admin-recorded manual payment RPCs collect the tax-inclusive total. Technician commission and payable allocation remain labour-only and exclude GST.
- Master refund preparation checks the same tax-inclusive amount. Full refund issues one credit note from the immutable tax snapshot.
- Customer receipt now returns invoice number, taxable value, CGST, SGST, IGST and total tax. Customer invoice RPC returns the complete immutable invoice and linked credit note.
- Admin Panel has a GST invoice/credit-note/gateway-fee date-range reporting panel.
- Master final bill creation defers when GST company profile, state mapping or a required service/component rule is missing; it retries after Admin completes GST company/rate configuration. Existing legacy bookings and historical quote/receipt paths remain untouched.

## Admin configuration and professional validation
GST company profile and service tax rules are configured through Admin-only RPCs in this backend increment. The reporting panel is connected; a dedicated visual form for GST registration and per-service rate configuration remains a Frontend/Admin UI follow-up. No tax rate or GST registration status is presumed. The current state mapping is seeded for Indian states/UTs and should be checked against the actual place-of-supply data. The accountant/tax professional must confirm GST registration, SAC/HSN, exemptions, materials classification, place-of-supply, invoice legal requirements, gateway input-credit eligibility and rates before operational use.

## Verification boundary
Source-only Feature Branch files. No database apply, no production changes, no live payments, no deployment. Node contracts and pgTAP source are added; CI execution, pgTAP runtime and isolated end-to-end replay remain pending. Obtain accountant/tax-professional confirmation of the actual registration, SAC/HSN classification, place-of-supply and applicable rates before operational use.
