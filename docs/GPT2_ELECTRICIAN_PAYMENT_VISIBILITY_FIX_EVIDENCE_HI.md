# GPT-2 — Electrician Payment Visibility Fix / Evidence

तारीख: 2026-11-18  
शाखा: `feat/ai-rate-management-foundation-20261118`  
स्थिति: Source changes committed; Production verification अभी बाकी है।

## 1. Code Review के तीन मुद्दों पर किए गए source changes

### A. `buildElectricianJobAccounting()`
फाइल: `lib/electrician-rate-view.js`

- केवल `booking_status === completed` अब gross/customer/company breakdown दिखाने के लिए पर्याप्त नहीं।
- `completed_unpaid` पर केवल `electrician_payable_paise` लौटता है।
- `checkout_started` पर gross = electrician net + company residual की गणितीय जाँच के बाद breakdown लौटता है।
- `payment_verified` पर actual customer receipt दिखती है और payout status/amount अलग object में रहता है।
- Stage को server के persisted trusted records से निकालना अनिवार्य है; helper browser stage को trusted नहीं मानता।

### B. `electrician.html`
- Offer UI अब backend के `electrician_offer_paise` को सीधे दिखाती है; browser में दोबारा 85% काटकर 72.25% नहीं करती।
- Earnings screen अब RPC के `payment_stage` के आधार पर अलग sections दिखाती है।
- Checkout breakdown केवल `checkout_started` पर दिखता है।
- Verified payment पर actual receipt, labour gross, actual electrician earning और actual company commission दिखते हैं।
- Bank/UPI payout अलग ledger से आता है और अलग status में रहता है।
- अगर किसी category Booking का ऐतिहासिक `commission_rate` 15% नहीं है, Checkout breakdown छिपता है और reconciliation warning आती है।

### C. SQL migration / RPC
नई source migration:
`supabase/migrations/20261118033000_gate_electrician_financial_visibility.sql`

यह migration:
- `srk_get_my_offer_details()` को replace करती है।
- Offer RPC का gross `estimated_labour_paise` output हटाकर `electrician_offer_paise` (85% paise) देती है।
- `quoted_amount`, `service_charge`, `materials_amount`, `quote_status`, `quote_note` को completed + persisted checkout/verified-payment stage तक रोकती है।
- `srk_get_my_earnings()` में `payment_stage`, `customer_labour_gross`, `company_share`, `payout_amount`, `payout_status` जोड़ती है।
- Checkout stage `razorpay_order_id` और completed booking status से server-side निकाला जाता है।
- Payment verified stage के लिए `payment_status='paid'`, `payment_verified_at`, positive `amount_paid`, और Razorpay payment ID या matching manual payment evidence आवश्यक है।
- Manual payment में amount और payment method दोनों match होने चाहिए।
- Completed unpaid / checkout calculations immutable `srk_booking_labour_bills` से लेते हैं।
- Paid earning और actual company commission existing payout ledger/booking commission से लेते हैं।
- Existing commission trigger, payout trigger, ledger, historical booking snapshots या bill snapshots को rewrite नहीं करती।

## 2. 85% / 15% और पुराने commission की सुरक्षा

मौजूदा schema में `commission_rate` का default 15% है, लेकिन existing payout trigger उसी persisted `commission_rate` से commission बनाता है। इसीलिए:
- नई migration पुराने commission को दोबारा deduct नहीं करती।
- Checkout का 85/15 display तभी खुलता है जब selected-category Booking का persisted `commission_rate=15` हो।
- अगर किसी पुराने Booking पर rate अलग है, तो gross/net split दिखाने के बजाय `checkout_reconciliation_required` stage और warning मिलती है।
- Payment verified होने पर actual existing payout ledger amount और actual commission दिखते हैं; उन्हें 85/15 बताकर गलत नहीं दिखाया जाता।

## 3. Tests / प्रमाण

नए या बदले गए test files:
- `tests/electrician-rate-view.test.js` — 9 stage/helper cases.
- `tests/electrician-financial-visibility-migration.test.js` — RPC contract, checkout/payment gating, immutable bill source, payout ledger fields और UI contract के static assertions.
- `tests/electrician-payment-visibility.test.js` — 7 pure DTO cases (पहले से मौजूद).

इस turn में 9 helper test cases Node test harness में चलाए गए: **9 passed, 0 failed**। ये helper-level tests हैं; पूरे repository का `npm test` या Postgres migration execution नहीं है। Static migration test file जोड़ी गई है, लेकिन इसे अभी PostgreSQL पर चलाकर प्रमाणित नहीं किया गया है।

## 4. अभी क्या सत्यापित नहीं हुआ

- SQL migration Production या किसी live Supabase database पर लागू नहीं की गई।
- Live RPC response से gross leakage का runtime test नहीं हुआ।
- Authenticated electrician के साथ Offer/Earnings RPC integration test नहीं हुआ।
- Checkout order और Razorpay/manual verified payment का end-to-end test नहीं हुआ।
- इसलिए इसे **Complete नहीं** घोषित किया जा सकता। Backend RPC की live stage visibility और gross leakage verification बाकी है।

## 5. सुरक्षा सीमा

केवल GitHub source branch पर बदलाव किए गए। Production Database, migration execution, deployment, payment provider, paid database branch या PR merge में कोई कार्रवाई नहीं की गई। पुराने booking/bill snapshots और payout ledger untouched हैं।
