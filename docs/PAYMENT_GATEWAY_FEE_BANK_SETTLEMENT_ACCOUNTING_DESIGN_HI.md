# SRK ELECTRONIC — Payment, Gateway Fee & Bank Settlement Accounting Design (Hindi)

स्थिति: Design / implementation specification only. यह दस्तावेज़ किसी live provider, hosted database या bank operation को सक्षम नहीं करता।

## 1. उद्देश्य और सीमाएँ

एक ही booking के लिए निम्न घटनाओं को अलग-अलग और audit योग्य रखना है:
1. ग्राहक से payment capture/collection;
2. payment gateway की fee और उस fee पर लगा tax;
3. Razorpay Route transfer creation/processing/reversal;
4. Razorpay settlement batch और बैंक में वास्तविक credit;
5. electrician payout और उसका UTR/reference;
6. refund, chargeback, dispute और manual correction।

किसी एक status को दूसरे का प्रमाण न मानें। विशेष रूप से `transfer_status=processed` बैंक settlement का प्रमाण नहीं है। कोई database insert/update अपने-आप पैसा नहीं भेजेगा।

## 2. मौजूदा सिस्टम से मिली आधार-स्थिति

- `srk_route_transfers` में booking_id, razorpay_payment_id, recipient, transfer_id, idempotency_key, amount_paise, transfer_status और settlement_status मौजूद हैं।
- यह server-only ledger है; anon/authenticated access revoked है और service_role को access दिया गया है।
- इस Route table में gateway fee, fee tax, settlement batch/UTR और actual bank credit की अलग fields नहीं दिखीं।
- Admin UI में electrician due को स्पष्ट रूप से वास्तविक bank settlement से अलग बताया गया है।
- Payout reference पर normalized UNIQUE index migration मौजूद है; यह electrician payout reference को duplicate होने से बचाने का अलग नियंत्रण है।
- मौजूदा tables को बदलने से पहले सभी migrations, RPCs, edge functions और provider webhook flows की dependency map बनानी होगी।

## 3. प्रस्तावित append-only ledgers

Implementation से पहले exact provider report/API field mapping और मौजूदा schema का मिलान आवश्यक है। नीचे logical entities हैं; इन्हें अभी SQL migration न समझें।

### A. Payment collection events
प्रति provider event एक immutable row:
- internal id, booking_id, customer_user_id
- provider, provider_order_id, provider_payment_id
- event_type (authorized/captured/failed/refunded/chargeback आदि)
- amount_paise, currency, provider_event_id
- occurred_at, received_at, verified_at
- source (signed webhook / server API verification / manual evidence)
- payload_digest (raw sensitive payload नहीं), idempotency_key
नियम: provider event ID और उपयुक्त payment identity पर unique constraints; amount/currency/booking mismatch पर quarantine, overwrite नहीं।

### B. Gateway fee & tax components
हर payment/settlement से जुड़ी अलग component rows:
- provider, provider_fee_reference, payment_id/settlement_id
- component_type (gateway_fee, fee_tax, adjustment, withholding आदि)
- amount_paise, currency, tax_rate_basis_points (यदि source में हो)
- source_report_id, source_row_reference, source_digest
- assessed_at, imported_at
नियम: provider statement में fee/tax उपलब्ध न हो तो अनुमान न लगाएँ। Unknown/unsupported tax को unresolved exception में रखें। Fee tax को customer GST या SRK की output tax liability न मानें; accounting/tax professional से chart-of-accounts mapping अनुमोदित कराएँ।

### C. Settlement batches and bank credits
Settlement batch:
- provider, provider_settlement_id, settlement_date
- gross_amount_paise, fee_amount_paise, fee_tax_amount_paise
- adjustment_amount_paise, net_settlement_amount_paise, currency
- source_report_id/digest, imported_at
Bank credit match:
- settlement_id, bank_statement_reference/UTR, bank_credit_amount_paise
- bank_credit_date, bank_account_alias (masked/non-secret)
- match_status (unmatched/matched/partial/amount_mismatch/review)
नियम: एक settlement को partial bank credits मिल सकते हैं; इसलिए batch और bank-credit rows अलग रखें। UTR पर uniqueness तभी लगाएँ जब bank/provider evidence और वास्तविक uniqueness scope पुष्टि करें।

### D. Route transfers
मौजूदा `srk_route_transfers` को authoritative transfer intent/status ledger मानें। Settlement proof को अलग settlement/bank ledger से link करें; पुराने transfer rows पर अनुमानित settlement UTR backfill न करें।

### E. Electrician payouts
- payout_id, electrician_profile_id, booking_id, payable_amount_paise
- payout_reference_normalized, transfer/provider reference
- initiated_at, provider_status, bank_settled_at, bank_utr
- evidence source, reconciliation status
Payout payable, payout initiated, provider processed और bank settled चार अलग अवस्थाएँ हों। Existing unique payout-reference protection कायम रहे।

### F. Accounting exceptions and adjustments
Append-only exception records:
- exception_type, entity reference, expected vs observed amount
- severity, detected_at, status, assigned_admin, resolution_reason
- resolution event as a new row; original evidence never deleted
Manual journal adjustment केवल अनुमोदित Main Admin flow से, maker-checker policy और reason/evidence के साथ। Support Staff को finance/payout/refund अधिकार नहीं।

## 4. Reconciliation rules

1. Payment captured: provider payment ID, booking, INR currency और exact amount verify हों।
2. Gateway fee: provider statement/API से sourced; fee और tax अलग components।
3. Route transfer: payment recipient pair और idempotency key पर duplicate रोकें।
4. Settlement: provider settlement batch का gross-to-net arithmetic reconcile हो।
5. Bank credit: net settlement और bank statement credit का exact/partial match; mismatch पर exception।
6. Electrician payout: payable ledger से अलग payout instruction और फिर bank-settled evidence।
7. Refund/reversal: मूल payment/transfer को overwrite न करें; compensating events जोड़ें।
8. Duplicate webhook/import: stable provider event/report row identity पर idempotent।
9. Out-of-order events: event occurrence time और receive time दोनों रखें; invalid backward state transition reject/quarantine।
10. Monthly close: unresolved exceptions, pending settlements, outstanding payouts और fee/tax totals अलग रिपोर्ट हों।

## 5. पैसे की गणना और rounding

- सभी financial amounts integer paise में।
- मौजूदा canonical commission policy कायम: gross commission = round-half-up(gross × 15%); electrician net = gross − rounded commission।
- ₹899 → ₹134.85 commission / ₹764.15 electrician net।
- ₹1,199 → ₹179.85 / ₹1,019.15।
- ₹1,599 → ₹239.85 / ₹1,359.15।
- ₹1,999 → ₹299.85 / ₹1,699.15।
- Gateway fee/tax को 15% commission calculation में चुपचाप शामिल न करें; अलग accounting components रखें।
- Provider statement arithmetic और tax classification के लिए accountant approval आवश्यक है।

## 6. Security and data retention

- All provider ingestion and financial writes server-side only.
- Verify Razorpay webhook signature against raw request body before parsing/processing; protect against replay with provider event ID and idempotency.
- Service-role secrets server-only; never expose in browser/client bundles.
- RLS enabled; no direct client writes to financial ledgers.
- SECURITY DEFINER RPCs: fixed search_path, explicit role checks, revoke PUBLIC/anon/authenticated unless narrowly needed.
- Audit actor, timestamp, reason, source, digest and before/after references.
- Do not store full card/bank credentials, CVV, UPI PIN, passwords or unnecessary raw personal data.
- Preserve historical test data. No destructive backfill; unresolved old rows stay exceptions.

## 7. PostgreSQL test plan (disposable CI only)

- schema replay from clean baseline and migration replay twice where supported;
- payment provider event duplicate and same ID/different payload conflict;
- amount/currency/booking mismatch quarantine;
- gateway fee and tax sourced independently; absent fee/tax never fabricated;
- settlement gross − fee − fee tax ± adjustment = net arithmetic;
- settlement split across multiple bank credits and partial match;
- duplicate bank statement row import idempotency;
- UTR collision behavior within confirmed uniqueness scope;
- Route transfer processed but settlement pending must not show bank-settled;
- payout pending → initiated → provider processed → bank settled guarded transitions;
- duplicate payout reference normalized case/whitespace rejection;
- refund/reversal creates compensating event, never mutates original event;
- concurrent duplicate webhook/import sessions;
- unauthorized anon/authenticated writes and RPC execution rejected;
- immutable ledgers reject UPDATE/DELETE/TRUNCATE;
- transaction rollback leaves no half-written payment/settlement state;
- exception creation and append-only resolution audit;
- monthly report totals reconcile to source ledger totals.

## 8. Implementation gates

Do not create/apply migration until:
1. existing payment, refund, route, payout, wallet and webhook schema/RPC dependency inventory complete;
2. official Razorpay report/API fields and sample (sensitive data masked) mapped;
3. exact UTR/reference uniqueness scope confirmed;
4. accountant approves fee/tax classification and monthly report;
5. disposable PostgreSQL tests pass;
6. user explicitly approves any hosted TEST mutation or paid Developer Branch creation.

No Production migration, live provider API call, real refund, payout, bank transfer, deployment or merge is authorized by this design document. AI Gateway remains disabled until separate explicit authorization.


## 9. Feature Branch schema inventory correction — 20 नवम्बर 2026

यह section बाद की migration-level source review के आधार पर जोड़ा गया है; पुराने Route-ledger संबंधी कथन को वर्तमान schema न माना जाए।

- `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql` ने पहले `srk_route_transfers` बनाया था, लेकिन `20261115092149_retire_unused_razorpay_route_transfer_ledger.sql` उसे DROP करता है। वर्तमान Feature Branch final schema में `srk_route_transfers` मौजूद नहीं होना चाहिए। पहले के दस्तावेज़/पुराने migrations का उल्लेख historical है।
- वास्तविक payout base `20261114125844_restore_financial_audit_core_schema.sql` में `srk_electrician_payouts` है: एक booking पर एक payout; gross service, materials, commission और electrician payable; pending/paid/blocked/refunded status; Admin द्वारा UPI/Bank method, reference, actor और paid timestamp। Amount columns अभी numeric रुपये में हैं, integer paise में नहीं।
- Razorpay refund intent `srk_razorpay_refunds` में booking, payment ID, provider refund ID, amount/amount_paise, INR, unique idempotency key और refund status है। Refund recovery evidence अलग append-only audit table में provider response digest, amount, payment/refund ID, status, acquirer reference और admin evidence रखता है।
- Signed webhook inbox `srk_razorpay_webhook_events` में event ID, event type, payload SHA-256, state, attempts और lease/claim token हैं। यह webhook delivery idempotency है; payment collection accounting ledger नहीं।
- Payment capture अभी `service_bookings` में `payment_status`, `amount_paid`, `razorpay_payment_id`, `razorpay_order_id` और `payment_verified_at` के रूप में दर्ज होता है। `verify-payment.js` payment API से captured status, order ID, INR और exact amount verify करता है। `razorpay-webhook.js` signed webhook और durable inbox के बाद booking/refund RPC reconcile करता है।
- मौजूदा refund, payout, wallet, cancellation-fee और webhook mechanisms पहले से कई अलग migrations/RPC/triggers में जुड़े हैं। नया accounting schema इन्हें duplicate या replace नहीं करेगा; केवल verified source event references से reconciliation projection/append-only import records बनाएगा।
- इस inventory से अभी Gateway Fee, Fee GST, Razorpay settlement batch, settlement net amount और actual bank-credit UTR का authoritative source contract प्रमाणित नहीं हुआ। इसलिए इन fields की provider report mapping और masked sample evidence के बिना SQL table/migration बनाना सुरक्षित नहीं है।
- Route settlement को live product capability मानना गलत होगा: Route table retired है, कोई active transfer integration नहीं है। Electrician payout अभी Admin के बाहरी bank/UPI transfer के बाद reference दर्ज करने का workflow है।

