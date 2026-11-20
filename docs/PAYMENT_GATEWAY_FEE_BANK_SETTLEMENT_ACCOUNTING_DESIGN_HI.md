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


## 10. Payment code-path review — 20 नवम्बर 2026

Feature Branch पर वर्तमान source review:
- `verify-payment.js` Razorpay signature verify करता है, Payment API से captured status, order ID, INR और exact amount जाँचता है; फिर `srk_service_role_record_online_booking_payment` RPC के जरिए booking payment state/related fee settlement लिखता है। Payment ID, paid amount और verification timestamp booking में दर्ज होते हैं।
- `razorpay-webhook.js` signed webhook को verify करता है, `srk_razorpay_webhook_events` inbox claim/complete करता है और captured payment को booking/RPC में reconcile करता है।
- `20261118120000_harden_online_payment_settlement_state.sql` payment ID, expected paise amount और booking state validate करके `service_bookings` में `payment_status`, `amount_paid`, `razorpay_payment_id`, `payment_verified_at` लिखता है।
- इन verified capture paths में Gateway fee, fee-tax, settlement batch ID, settlement UTR और actual bank credit fields नहीं लिखे जाते।
- `20261115092149_retire_unused_razorpay_route_transfer_ledger.sql` स्पष्ट रूप से पुराने `srk_route_transfers` table को DROP करता है। इसलिए नए ledger को retired Route transfer integration के नाम/assumptions पर बनाना उचित नहीं।

## 11. Razorpay settlement data mapping — documented, not yet account-verified

Razorpay public Dashboard guidance बताती है कि:
- Settlements dashboard में settlement amount, fees/tax, date/time और status देखे जा सकते हैं; settlement detail का breakdown उपलब्ध है।
- Reports section से daily/monthly settlement report download की जा सकती है; उसमें transactions और corresponding settlement IDs map होते हैं।
- Payment detail से linked settlement_id पर जाकर breakdown देखा जा सकता है।
- Public Razorpay material settlement UTR, settlement ID, gateway fees और transaction-to-settlement mapping के उदाहरण देता है।

References:
- Razorpay Dashboard & Settlement Reports: https://razorpay.com/blog/how-to-use-razorpay-dashboard/
- Razorpay Payment details / settlement details: https://razorpay.com/docs/payments/payments/dashboard/?preferred-country=IN
- Razorpay settlement-to-bank matching explainer: https://razorpay.com/blog/instant-settlement-payment-gateway

ये public docs हमारे merchant account की actual CSV column names, enabled product, exact report version, fee/tax tax-invoice mapping या SRK account के UTR availability की पुष्टि नहीं करते। इसलिए implementation mapping के लिए वास्तविक Dashboard से एक redacted sample settlement report (CSV/XLSX) या merchant-specific report schema आवश्यक रहेगा।

## 12. Migration decision

अभी केवल design/contract source changes सुरक्षित हैं। Production-grade import migration तब बनाई जाएगी जब redacted sample report से exact column names, row identity, sign convention, fee/tax rows, refunds/adjustments, partial/multiple credits और UTR availability verify हो जाए। तब migration में raw report file नहीं, केवल file digest, source metadata और normalized rows रखे जाएँगे; original imported facts append-only रहेंगे। CSV parser को report version, size/row limits, formula injection, duplicate rows, encoding, malformed amounts और import authorization के साथ अलग server-side workflow में test करना होगा।

**अगला जरूरी input:** Razorpay Dashboard के Reports → Settlements से एक sample report export करके customer/account/bank details mask करके देना। कोई API key, secret, full bank number या customer PII साझा न करें।


## 13. मौजूदा वित्तीय ledgers का integration map — 20 नवम्बर 2026

अतिरिक्त migration-level source review के बाद निम्न सीमाएँ स्पष्ट हैं:

### A. Wallet ledger अलग internal balance है
- `srk_wallet_accounts` और `srk_wallet_ledger` में amount अभी `numeric(12,2)` रुपये है; entry types में booking_payment, refund, earning, commission, payout, adjustment, topup और cancellation_fee शामिल हैं।
- Wallet summary में customer top-up और electrician bank payout स्पष्ट रूप से disabled हैं। इसलिए wallet balance को Razorpay bank settlement या electrician के वास्तविक bank credit के बराबर नहीं दिखाना है।
- Wallet entries को नए gateway settlement ledger में दोबारा collection/payout के रूप में insert नहीं करना; आवश्यकता होने पर केवल source ledger reference और reconciliation relation रखें।
- Wallet schema की append-only/immutable स्थिति को हर entry type पर समान मानकर नहीं चलना चाहिए; संबंधित triggers/RPCs की पूरी समीक्षा और database test आवश्यक है।

### B. Cancellation-fee ledger स्वतंत्र sub-ledger है
- `srk_customer_cancellation_fee_debts`, `srk_booking_cancellation_fee_items` और `srk_cancellation_fee_ledger` ₹99 cancellation fee carry-forward, reservation, collection और reversal को track करते हैं।
- Cancellation ledger integer paise में और append-only है। Online payment पर fee item settlement तथा cancellation-fee ledger credit payment RPC transaction में जुड़ते हैं।
- Full refund पर original cancellation-fee collection के विरुद्ध अलग reversal entry बनाई जाती है; partial refund path इस contract में fail-closed है।
- Monthly report में cancellation-fee collection को gross service payment/merchant settlement में बिना mapping के जोड़ना नहीं है। इसे अलग line item तथा original booking/refund reference के साथ reconcile करना होगा।

### C. Refund workflow को दोबारा नहीं बनाना
- Refund intent `srk_razorpay_refunds` में एक booking पर unique record और unique idempotency key के साथ है।
- Refund recovery audit अलग append-only provider evidence रखता है: provider refund ID, payment ID, amount paise, INR, provider status, acquirer reference, payload digest, observation ID और Admin evidence note।
- Refund finalize workflow मौजूदा booking/payment state और payout/cancellation-fee reversal logic से जुड़ा है। नया accounting import केवल provider report से मिले refund/adjustment facts को source IDs से link करेगा; refund initiate या finalize नहीं करेगा।
- Refund report row और refund recovery observation को दो अलग आर्थिक refunds न गिनें। वे एक ही refund घटना के अलग प्रमाण हो सकते हैं।

### D. Electrician payout ledger वास्तविक बैंक settlement नहीं है
- `srk_electrician_payouts` प्रति booking एक payable record बनाता है। Payout paid mark करने के लिए Admin UPI/Bank method और reference दर्ज करता है।
- Paid status Admin द्वारा दर्ज payout evidence है; अभी कोई प्रमाणित bank feed/statement importer नहीं मिला। इसे “bank statement matched” न कहें।
- Normalized payout reference uniqueness का database index मौजूद है; accounting import में इसे बदलने या दोबारा लागू करने की जरूरत नहीं। Payout और Razorpay merchant settlement अलग cash-flow हैं।

### E. Payment capture और order linking
- Payment order creation से पहले booking-level short-lived lock तथा exact amount/category/approved quote validation है।
- Capture verification और signed webhook दोनों booking payment state को reconcile करते हैं; ये source paths capture/payment state के लिए authoritative हैं।
- Gateway fee/tax और merchant settlement के लिए इन booking fields से कोई राशि derive नहीं करनी। Report source से अलग evidence आवश्यक है।

### F. अगला accounting design decision
- नई accounting layer को पहले read-only reconciliation/import projection के रूप में रखना चाहिए: provider report batch → source rows → linked internal payment/refund/payout/cancellation references → exceptions/monthly totals।
- Existing operational ledgers (booking, wallet, cancellation fee, refund, payout, webhook inbox) ही अपनी-अपनी state के owner रहेंगे।
- कोई नया “cash received” या “bank paid” event केवल imported/verified source evidence पर बने; UI status, wallet balance, provider refund observation या payout admin reference अकेले पर्याप्त प्रमाण नहीं।
- इस अतिरिक्त review में कोई migration, hosted database, provider API, refund, payout या bank action नहीं किया गया। यह source-only integration map है।


## 14. Admin Panel की मौजूदा Accounting स्क्रीन — source verification

`admin.html` और migration `20261115150000_admin_readonly_booking_accounting_reconciliation.sql` को साथ पढ़कर पुष्टि हुई:

- Main Admin स्क्रीन में Booking UUID आधारित Read-only reconciliation card मौजूद है।
- यह RPC `srk_admin_get_booking_accounting_reconciliation(uuid)` को बुलाता है; SQL function `STABLE SECURITY DEFINER`, खाली `search_path`, Main Admin check, और authenticated EXECUTE grant के साथ है।
- स्क्रीन customer collection, confirmed तथा requested/unconfirmed refund, net collection, labour, materials, expected commission, expected electrician payable, payout status/reference, cancellation-fee allocations/ledger, posted wallet entries और exceptions दिखाती है।
- RPC के exception checks में missing/mismatched verified payment, immutable labour bill missing, payout missing/assignment/amount mismatch, duplicate refund records, provider payment ID mismatch, pending/failed/unconfirmed refund, partial/over-refund, cancellation fee ledger imbalance, wallet refund mismatch और refund/payout state mismatch शामिल हैं।
- Route transfer status स्पष्ट रूप से retired दिखाया जाता है; UI Route transfer को payout का प्रमाण नहीं मानती।
- यह स्क्रीन per-booking snapshot है। इसमें Razorpay merchant settlement batch, gateway fee, fee GST/tax, settlement deductions/adjustments, actual bank credit, UTR match, date-range/monthly consolidated report या CSV import workflow नहीं है।
- अलग payout table और commission summary मौजूद हैं, लेकिन UI स्वयं बताती है कि commission expected/calculated amount है, bank cash receipt नहीं; electrician payable भी actual bank settlement नहीं है।
- अतः अगली Accounting delivery में मौजूदा Booking reconciliation को जस का तस रखते हुए अलग Merchant Settlement reconciliation layer चाहिए। वह read-only imported report evidence से payment/refund rows को link करेगी और bank statement/UTR match अलग status में रखेगी।

यह UI/RPC source inspection है; hosted runtime में इसे execute करके नहीं देखा गया। कोई code या database change इस जाँच में नहीं किया गया।


## 15. मौजूदा Commission Report और Admin totals — अतिरिक्त source review

Migration `20261109003000_secure_commission_reporting.sql` का `srk_admin_commission_report()` और `admin.html` का उपयोग जाँचा गया:

- RPC केवल Main Admin के लिए है और `service_bookings` में `status='completed'` तथा `payment_status='paid'` वाली बुकिंग का aggregate बनाता है।
- यह कुल verified-paid collection, दर्ज commission, electrician payable और electrician-wise jobs/totals देता है।
- RPC में date range, month parameter, Razorpay-only filter, refund-adjusted merchant settlement, gateway fee/tax, settlement batch या bank-credit matching नहीं है। इसलिए यह मासिक रिपोर्ट या Merchant Settlement रिपोर्ट नहीं है; इसे all-time completed+paid operational summary की तरह ही समझना चाहिए।
- Admin UI commission amount को स्पष्ट रूप से “गणना किया गया कंपनी कमीशन (प्राप्त नकद नहीं)” कहती है और electrician due को वास्तविक बैंक भुगतान नहीं बताती।
- Admin booking table latest 300 bookings तक सीमित है; commission RPC aggregate अलग से सभी matching rows पर चलता है। इस वजह से table row count और aggregate report की अवधि/coverage एक जैसी नहीं समझनी चाहिए।
- Existing payout list में latest 300 rows दिखाई जाती हैं, जबकि pending/paid totals pagination के जरिए सभी payout rows से calculate होते हैं। फिर भी यह merchant settlement या monthly report नहीं है।

### सुरक्षित आगे का reporting विभाजन

1. **Operational Commission Summary:** मौजूदा RPC/UI; इसकी मौजूदा semantics को न बदलें।
2. **Per-booking Reconciliation:** मौजूदा Main Admin read-only RPC/UI; इसे सुरक्षित रखें।
3. **Merchant Settlement Reconciliation:** नई अलग read-only projection — imported settlement report batches/rows, linked Razorpay payment/refund IDs, provider fees/tax/adjustments, settlement ID, bank-credit/UTR evidence, unmatched exceptions और month-wise totals।

नई layer में तारीख/समय के लिए merchant report का settlement date और timezone स्पष्ट रूप से store करना होगा; booking creation date से settlement month infer नहीं करना है। Imported source file और row-level provenance सुरक्षित रखनी होगी। Duplicate import रोकने के लिए report batch/file digest तथा stable row identity चाहिए। जब तक वास्तविक merchant export schema उपलब्ध न हो, CSV/XLSX parser या import migration final न करें।
