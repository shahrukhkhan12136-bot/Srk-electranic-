# GPT-2 — Master GST, Tax Invoice, Credit Note & Gateway Fee GST (21-11-2026)

Feature branch: `feature/master-technician-payment-cycle-20261121`

## Design
- No statutory GST rate is hard-coded. Main Admin must explicitly configure company registration status, legal name, GSTIN/state (if registered), invoice prefix and effective date.
- Admin configures separate effective-dated labour and materials tax rules per service category + service/skill code. Taxable=false requires 0 basis points; taxable=true requires an explicit rate.
- Indian state-code map determines place of supply from the booking work address. Registered supplier in same state: CGST+SGST; different state: IGST. Unregistered company profile records no GST charged.
- Snapshot captures GSTIN/profile version, place of supply, taxable base, rate and each tax component in integer paise. Technician commission and payables remain calculated on labour only and exclude GST.
- जब तक Main Admin GST registration को स्पष्ट रूप से registered नहीं करता, कोई GST company profile न होने पर भी Master billing unregistered mode में चलेगी: GST शून्य, सामान्य Final Bill/भुगतान जारी, GST rate rules की जरूरत नहीं और GST tax invoice जारी नहीं होगा।
- GST registration registered करने के बाद ही supplier GSTIN/state और service/component rate rules अनिवार्य होंगे; registered mode में missing state/rate configuration tax snapshot को रोकेगी।

## Documents
- Registered GST mode में verified Master payment पर immutable tax invoice जारी होगा। Unregistered mode में GST tax invoice नहीं बनेगा; सामान्य payment receipt flow चलेगा।
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
- Unregistered mode में Final Bill और भुगतान GST profile/rate setup के बिना चलते हैं। Registered mode में GST company profile, state mapping या required service/component rule missing होने पर tax snapshot रुकेगा और Admin configuration के बाद retry होगा। Existing legacy bookings and historical quote/receipt paths remain untouched.

## वर्तमान स्थिति और Admin configuration
अभी SRK ELECTRONIC GST registered नहीं है। इसलिए कोई GST वसूली, GST tax invoice या GST rate configuration चालू नहीं है। Default unregistered mode में Final Bill और payment बिना GST चलते हैं। GST registration होने पर ही GST company profile और service tax rules Admin-only RPCs से configure होंगे। The reporting panel is connected; a dedicated visual form for GST registration and per-service rate configuration remains a Frontend/Admin UI follow-up. No tax rate or GST registration status is presumed. The current state mapping is seeded for Indian states/UTs and should be checked against the actual place-of-supply data. The accountant/tax professional must confirm GST registration, SAC/HSN, exemptions, materials classification, place-of-supply, invoice legal requirements, gateway input-credit eligibility and rates before operational use.

## Verification boundary
Source-only Feature Branch files. No database apply, no production changes, no live payments, no deployment. Node contracts and pgTAP source are added; CI execution, pgTAP runtime and isolated end-to-end replay remain pending. Obtain accountant/tax-professional confirmation of the actual registration, SAC/HSN classification, place-of-supply and applicable rates before operational use.
