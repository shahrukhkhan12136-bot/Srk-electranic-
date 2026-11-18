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

## 7. निषिद्ध कार्य (अलग अनुमति तक)

Production DB query/write, migration apply/replay, schema deployment, paid DB branch, deployment, PR merge, पुराने migration rewrite, historical booking/bill update।
