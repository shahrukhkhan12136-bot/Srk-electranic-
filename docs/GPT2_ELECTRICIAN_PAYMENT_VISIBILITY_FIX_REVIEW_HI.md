# GPT-2 — Electrician Payment Visibility Fix Review (Hindi)

तारीख: 2026-11-18  
शाखा: `feat/ai-rate-management-foundation-20261118`

## स्थिति
तीन पहचानी गई source-code समस्याओं पर सुधार commit किए गए हैं। यह अभी **source-branch fix है, Production में लागू/सत्यापित fix नहीं**। जब तक नई migration सुरक्षित रूप से लागू होकर वास्तविक authenticated RPC responses की जाँच नहीं होती, इसे Complete न माना जाए।

## 1. `buildElectricianJobAccounting()`
फाइल: `lib/electrician-rate-view.js`

अब केवल `booking_status === 'completed'` होने से ग्राहक gross या कंपनी share नहीं मिलता। अतिरिक्त trusted `paymentStage` जरूरी है:
- `completed_unpaid`: केवल electrician 85% payable।
- `checkout_started`: labour gross 100%, electrician 85%, company residual 15%।
- `payment_verified`: actual customer receipt, 100/85/15 breakdown और अलग payout status/amount।
- Unknown/missing stage: केवल सामान्य booking fields; finance नहीं।

इस helper का `paymentStage` caller server-side trusted records से निकाले; browser value कभी pass न करे।

## 2. Offer RPC और Offer UI
नई source migration:
`supabase/migrations/20261118030000_electrician_payment_stage_visibility.sql`

`srk_get_my_offer_details()` अब `estimated_labour_paise` gross column लौटाने के बजाय `electrician_offer_paise` देता है:
`round(estimated_labour_paise × 85 / 100)` paise, integer rounding के साथ।

Offer response में gross quote, service charge और materials fields तब तक NULL हैं जब तक persisted Razorpay order के साथ payment pending checkout stage न हो या verified payment evidence न हो। Verified evidence में `payment_verified_at` और Razorpay payment ID या matching manual payment entry जरूरी है।

`electrician.html` Offer card अब केवल RPC का `electrician_offer_paise` render करता है। Browser gross लेकर 85% calculate नहीं करता।

## 3. Earnings RPC और UI
उसी migration में `srk_get_my_earnings()` का नया response contract है:
- `payment_stage` server-side booking/payment records से derive होता है।
- Completed + unpaid में gross/company NULL, केवल 85% electrician earning।
- Checkout started में immutable labour bill से 100/85/15।
- Payment verified में वास्तविक `amount_paid`, 100/85/15 और payout ledger का अलग status/amount।
- Customer amount received तथा payout fields verified payment evidence के बिना NULL।

`electrician.html` अब row-by-row `payment_stage` के आधार पर values दिखाता है। Customer received amount केवल verified rows से aggregate होता है। Company share केवल checkout/verified rows से aggregate होता है। `srk_electrician_payouts` अलग ledger और अलग status के रूप में बना रहता है।

## 4. पुराना Commission और ऐतिहासिक रिकॉर्ड
- नई migration `commission_rate`, `platform_commission` या payout trigger formula को update नहीं करती।
- Payout table में कोई रकम लिखती/बदलती नहीं।
- Immutable `srk_booking_labour_bills` से display split निकलता है; पुराने booking/bill snapshots को update नहीं किया जाता।
- पुराने variable commission और नए fixed 15% display share के बीच वास्तविक समानता अभी Production data के बिना सिद्ध नहीं है। Payout ledger amount अलग से लौटता है; दोनों में अंतर होने पर reconciliation आवश्यक है। इसीलिए इसे payout formula change या final accounting reconciliation न समझें।

## 5. Tests / Source checks
- `tests/electrician-rate-view.test.js`: 9 unit cases; local Node run में 9 PASS, 0 FAIL।
- `tests/electrician-payment-stage-sql-contract.test.js`: SQL migration और UI के लिए 8 source-contract tests जोड़े गए। Current source content पर 8/8 static assertions सफल।
- PostgreSQL runtime / actual Supabase RPC integration test नहीं चला; कोई database connection या migration apply नहीं की गई।
- Production में RPC signature बदलने के बाद app compatibility, grants, SQL execution plan और वास्तविक response payload का authenticated test बाकी है।

## 6. निषिद्ध कार्रवाइयाँ — नहीं की गईं
Production DB query/write, migration apply, paid DB branch, deployment, payout/payment operation या PR merge नहीं किया गया। PR #8 Open, Draft और Unmerged रहना चाहिए।

## अगला अनिवार्य QA
1. Approved non-production database में migration review/apply के लिए अलग explicit approval लें।
2. Offer RPC response में gross column की अनुपस्थिति और 85% net value verify करें।
3. चारों stages के Earnings RPC payloads वास्तविक test bookings पर verify करें।
4. Razorpay order created/pending, captured/verified, invalid signature, manual payment evidence और refunded states test करें।
5. 85% display earning बनाम legacy payout ledger `platform_commission`/`electrician_payable` का per-booking reconciliation करें; double deduction या unexplained mismatch न हो।
6. उसके बाद ही review completion status बदले।
