# GPT-2 Backend/RPC सुरक्षा ऑडिट — 18 Nov 2026

स्थिति: source audit और implementation contract; production DB पर लागू नहीं। कोई migration edit/apply, deployment या PR merge नहीं किया गया।

## 1. निर्णायक निष्कर्ष: Offer RPC अभी gross उजागर करता है

मौजूदा source migration `20261114370000_electrician_offer_details_immediate_booking_fields.sql` में `public.srk_get_my_offer_details()` का return type `estimated_labour_paise bigint` है और SELECT सीधे `b.estimated_labour_paise` लौटाता है। यह customer gross labour estimate है। इसलिए केवल `electrician.html` में 85% दिखाना सुरक्षा नहीं है: authenticated electrician RPC payload में 100% पा सकता है।

मौजूदा offer RPC में `quoted_amount`, `service_charge`, `materials_amount`, `quote_status`, `quote_note` भी लौटते हैं। इन्हें नई 85% श्रेणी के लिए अलग-अलग stage/ownership rules से audit करना होगा; UI hide पर्याप्त नहीं।

## 2. Earnings RPC भी समय से पहले accounting देता है

मौजूदा migration `20261109003000_secure_commission_reporting.sql` का `srk_get_my_earnings()` हर assigned booking के लिए:
- `amount_received = coalesce(amount_paid,0)`
- `commission_amount = coalesce(commission_amount,0)`
- `electrician_earning` केवल completed + paid पर non-zero

लौटाता है। Gross और commission को pre-payment अवस्था में response से ही निकालना चाहिए; शून्य या CSS-hidden values लौटाना contract का विकल्प नहीं।

## 3. 15% commission बनाम 85% net: double deduction का जोखिम

मौजूदा payout source `20261114360000_new_category_electrician_payout_reconciliation.sql` में:
- `v_service` immutable labour bill से लिया जाता है।
- `v_commission = round(v_service * commission_rate / 100, 2)`
- `electrician_payable = labour + materials - commission`

Migration `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` booking commission और payout ledger के बीच parity जाँचती है।

अतः 85% net और मौजूदा 15% commission सम्भवतः एक ही 15% residual हैं, लेकिन इसे schema/data और Admin commission_rate की वास्तविक configuration से सत्यापित किए बिना कोई formula या trigger नहीं बदलना चाहिए। यदि दोनों अलग-अलग काटे गए तो double deduction होगा। यदि existing rate 15% नहीं है तो business owner की पुष्टि आवश्यक है।

## 4. सुरक्षित target contract

| अवस्था | Electrician RPC response में अनुमति |
|---|---|
| Offer / accept से पहले | केवल category, duration, rate version और electrician 85% |
| काम पूरा, customer payment शुरू नहीं | केवल electrician payable estimate |
| Verified checkout/payment stage | customer amount due, electrician amount और company share |
| Verified payment success | actual customer amount received, electrician earning, company share; payout अलग ledger/status |

Payment stage केवल trusted server-side payment intent / persisted verified checkout state से निकले। Client-supplied stage, query parameter या JavaScript flag भरोसेमंद नहीं।

## 5. Implementation के लिए GPT-1 handoff

1. `srk_get_my_offer_details()` का additive replacement migration बनाते समय gross `estimated_labour_paise` को electrician response से हटाएँ; electrician net को server-side integer paise rounding से निकालें। Function return type बदलने के कारण DROP/CREATE dependency और सभी callers जाँचें।
2. `srk_get_my_earnings()` से pre-payment `amount_received` और `commission_amount` response में न लौटाएँ; payment stage पर ही complete accounting fields उपलब्ध हों।
3. नई category bookings के लिए immutable booking rate snapshot और immutable labour bill को अलग रखें। Historical booking/bill values कभी वर्तमान Admin rate से recalculate न करें।
4. payout ledger को वास्तविक भुगतान success और existing commission parity के साथ reconcile करें। 85% net rule को मौजूदा 15% commission से दो बार deduct न करें।
5. RPC authorization, row ownership, approved electrician identity, verified payment evidence, refunds और cancellation-fee exclusions preserve करें।
6. Unit tests के साथ SQL integration tests में unauthorized user, wrong electrician, offer/pre-payment gross leakage, checkout transition, failed/pending payment, refunded booking, payout pending/paid और legacy quote paths जाँचें।
7. सभी source-only tests और migration replay validation staging/local disposable DB पर करें; Production DB rollout अलग explicit approval के बाद ही।

## 6. GPT-2 द्वारा अभी किए गए बदलाव

- `electrician.html` offer card अब 85% calculated estimate label दिखाता है; यह UI-only interim improvement है, RPC leak को ठीक नहीं करता।
- `lib/electrician-payment-visibility.js` और उसके सात tests source branch में हैं; live RPC/API में wired नहीं।
- इस document का उद्देश्य blocker और exact handoff स्पष्ट करना है, migration स्वयं लागू करना नहीं।


## 10. अतिरिक्त वित्तीय तालिका RLS audit — payout ledger

18 नवंबर की आगे की source जाँच में `20261114125844_restore_financial_audit_core_schema.sql` के `srk_electrician_payouts` access rules और दोनों app consumers देखे गए:

- Table पर RLS enabled है; PUBLIC/anon/authenticated से सभी privileges revoke हैं, फिर authenticated को केवल SELECT दिया गया है।
- मौजूदा SELECT policy Admin को अनुमति देती है, या उस Electrician profile को जिसकी `ep.id = payout.electrician_profile_id` और `ep.user_id = auth.uid()` है।
- Policy में `ep.auth_user_id = auth.uid()`, `ep.verification_status = 'approved'` और `ep.active = true` की शर्तें नहीं हैं।
- `electrician.html` payout ledger को सीधे SELECT करता है; इसलिए RPC के active/approved guards के बावजूद inactive या identity-link mismatch वाला पुराना profile session सीधे table से अपना payout row और उसके gross/commission fields पढ़ सकता है।
- Source में payout trigger नई category के लिए row तभी बनाता है जब booking completed, payment_status paid, payment_verified_at मौजूद और Razorpay/manual evidence match हो। इसलिए यह audit pre-payment row creation का प्रमाण नहीं है; यह payout table की independent authorization policy में profile-state gap है।

**Required source fix (अभी लागू नहीं):** additive migration में इसी policy को replace करें। Main Admin branch जस की तस रहे; Electrician branch में एक ही profile row के लिए `id`, `user_id = auth.uid()`, `auth_user_id = auth.uid()`, `verification_status = 'approved'` और `active = true` सभी अनिवार्य हों। Regression SQL test में approved+active सही दोनों IDs को अनुमति, inactive, unapproved, mismatched `auth_user_id`, दूसरे Electrician और anon को रोकना; Main Admin access preserve करना जाँचें। UI hide या RPC guard इस table policy का विकल्प नहीं है।

यह finding source-level है। कोई migration apply नहीं हुई और live database policy की स्थिति verify नहीं की गई।

## 7. निषिद्ध कार्य (अलग अनुमति तक)

Production DB query/write, migration apply/replay, schema deployment, paid DB branch, deployment, PR merge, पुराने migration rewrite, historical booking/bill update।

## 8. अतिरिक्त पुष्ट निष्कर्ष: Earnings RPC की पहचान और fields

मौजूदा `20261109003000_secure_commission_reporting.sql` में `srk_get_my_earnings()` का पूरा source दोबारा पढ़ा गया:
- RPC return signature में `amount_received`, `commission_amount`, `electrician_earning` हैं।
- SELECT हर assigned booking पर `coalesce(b.amount_paid,0)` और `coalesce(b.commission_amount,0)` भेजता है, चाहे payment stage कुछ भी हो।
- `electrician_earning` अभी completed + paid पर `amount_paid - commission_amount` है; यह पुराने commission model का payout estimate है, नई 85% policy का स्वतः प्रमाण नहीं।
- Ownership filter केवल `p.user_id=auth.uid()` है, जबकि offer-details RPC `p.user_id=auth.uid() OR p.auth_user_id=auth.uid()` स्वीकारता है। किसी भी replacement में इस identity-linking अंतर को जाँचना और approved canonical ownership rule अपनाना होगा; इसे चुपचाप बदलना नहीं।

इससे पहले बताए गए gross/commission leakage की पुष्टि होती है। यह source audit है, live database verification नहीं।

## 9. Frontend consumer audit

`electrician.html` में `loadEarnings()` सीधे `sb.rpc('srk_get_my_earnings')` बुलाता है। Summary calculation अभी केवल completed + paid rows जोड़ती है, लेकिन RPC payload की pre-payment `amount_received` और `commission_amount` fields फिर भी authenticated client तक पहुँचती हैं। इसलिए frontend का paid-only filter data exposure को नहीं रोकता।

यह UI existing payout ledger `srk_electrician_payouts` से electrician_payable और payout status भी पढ़ती है। किसी replacement में इस ledger की RLS/ownership policy और अलग payout lifecycle को preserve करना अनिवार्य है।

## 11. नया Earnings RPC split-leak audit — verified लेकिन unreconciled payout

18 नवंबर की migration chain में 20261118080000_align_offer_85_rate_and_payout_reconciliation.sql का अंतिम srk_get_my_earnings() body जाँचा। इसमें payout reconciliation का status अलग से निकाला जाता है, और commission_amount, electrician_earning, company_share, payout_amount, payout_status को reconciliation के अनुसार gate किया गया है। लेकिन एक शेष असंगति मिली:

- customer_labour_gross का CASE verified payment और labour bill मौजूद होने पर bill.labour_amount लौटा देता है; इसमें payout_check.reconciliation_status='reconciled' की शर्त नहीं है।
- इसलिए payment verified लेकिन payout ledger missing/mismatch/incomplete होने पर SQL RPC gross labour amount उजागर कर सकता है।
- lib/electrician-rate-view.js के buildElectricianJobAccounting() में इसी स्थिति में gross, materials, electrician earning और company share सभी null रखे जाते हैं; अतः SQL RPC और DTO visibility contract में अंतर है।
- Actual customer receipt (amount_received) को verified payment पर दिखाना अलग बात है; वह customer से प्राप्त वास्तविक राशि है, payout split नहीं।

आवश्यक additive source fix: अगली migration में customer_labour_gross को भी केवल verified.is_verified AND payout_check.reconciliation_status='reconciled' AND bill.labour_amount IS NOT NULL पर लौटाएँ। Checkout-started branch का वर्तमान gross display नियम जस का तस रहे। payment_stage='payment_verified' को reconciliation status से अलग रखें, ताकि payment सत्यापन और payout reconciliation दो अलग अवस्थाएँ रहें।

आवश्यक regression test: verified payment + missing payout row, mismatch, incomplete ledger—तीनों में amount_received वास्तविक verified receipt रहे, पर customer_labour_gross, company_share, electrician_earning, payout_amount और payout_status withheld रहें। Reconciled case में ही split खुले। Existing tests/customer-electrician-payment-history-contract.test.js में latest earnings SQL body के लिए assertion जोड़ें।

यह अभी source-level finding है। कोई migration बनाई या लागू नहीं गई। इस वातावरण में Supabase CLI उपलब्ध नहीं है; Supabase workflow के अनुसार नई migration को supabase migration new से बनाना आवश्यक है, इसलिए migration filename/SQL हाथ से बनाकर commit नहीं किया गया। Production DB और deployment अछूते हैं।