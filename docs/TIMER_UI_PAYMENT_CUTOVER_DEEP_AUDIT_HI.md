# SRK ELECTRONIC — Timer UI एवं Payment Cutover विस्तृत जाँच

दिनांक: 2026-11-12  
Branch: `feature/production-push-notifications`  
जाँचा गया आधार commit: `410cd75e354d556c2a7e3b9ffa124a4aa3c050cf`

## इस जाँच का दायरा
Customer `index.html`, Electrician `electrician.html`, Admin `admin.html`, snapshot payment server handlers, legacy payment handlers, refund handler और timer SQL assertions का source-level निरीक्षण। यह static source audit है; browser, disposable PostgreSQL replay, hosted Supabase, Razorpay sandbox, device या production E2E test नहीं है।

## महत्वपूर्ण सुधार: Timer UI अनुपस्थित नहीं है
पहले inventory note में Customer timer approval UI और Electrician timer actions को अनुपस्थित बताया गया था। इस commit में source inspection से यह निष्कर्ष सही नहीं पाया गया। UI मौजूद है:

- Customer: `customerTimerCardHtml`, `customerTimerDecision`, `customerCreatePayableSnapshot`, `customerPaySnapshot`, `customerSelectCashPayment`, `customerDecideMaterialRevision`।
- Electrician: `electricianTimerCardHtml`, `electricianTimerAction`, `electricianMaterialFormHtml`, `electricianConfirmSnapshotCash`, cash commission remittance flow।
- Admin: `renderTimerAdmin` immutable timer/bill/material/snapshot/receipt read view देता है; Timer booking के लिए legacy Save path रोकता है।

अतः UI का basic cutover source में लागू दिखता है; अभी इसका वास्तविक authenticated browser/mobile E2E प्रमाण उपलब्ध नहीं है।

## Payment cutover — source findings

### Timer Snapshot online path
1. Customer UI `/api/create-snapshot-order` को `snapshot_id` और verified Supabase bearer session के साथ बुलाता है।
2. Server customer session, booking ownership/verified phone, timer stopped state, final_bill_id ↔ snapshot bill_id, currency और amount paise की जाँच करता है।
3. `srk_claim_razorpay_snapshot_order` से idempotent order creation claim लेकर Razorpay order बनता है और `srk_bind_razorpay_snapshot_order` से immutable snapshot से bind होता है।
4. Checkout callback signature HMAC सत्यापित करता है; order row, snapshot amount/currency, booking final bill, verified customer और Razorpay captured payment का मिलान होता है।
5. `srk_reconcile_razorpay_snapshot_payment` RPC ledger reconciliation करता है।
6. Legacy `create-order.js` और `verify-payment.js` timer category bookings को स्पष्ट रूप से reject करते हैं; legacy flow केवल quote-based bookings के लिए है।

यह architecture source में snapshot-based payment cutover दिखाता है। फिर भी SQL migration replay और provider sandbox E2E के बिना production-ready प्रमाणित नहीं है।

### Webhook
`razorpay-webhook.js` में legacy service_bookings payment reconciliation timer bookings को `snapshot_payment_required` के साथ रोकती है। Snapshot webhook event ledger/reconciliation path भी मौजूद है। इस path की full webhook signature, duplicate delivery, delayed event, conflicting payment और concurrent checkout के साथ disposable DB + Razorpay test-mode E2E जाँच अभी आवश्यक है।

### Refund
- Admin UI timer refund को अलग `srk_admin_finalize_timer_cash_refund` RPC में भेजता है; Razorpay refund server अलग verified provider flow है।
- `process-refund.js` Admin session/role, approved request, captured payment, exact amount और idempotency key जाँचता है।
- Timer cash refund SQL RPC receipt, exact amount और commission settlement state जाँचता है।
- Refund UI/provider paths के लिए automated tests सीमित हैं; मौजूदा Node test `process-refund-handler.test.js` legacy Razorpay refund path के कुछ positive/negative cases cover करता है। Timer cash refund RPC, timer Razorpay snapshot refund और webhook replay के end-to-end tests अलग से चाहिए।

## Panel boundaries

| Panel | Source में मौजूद जिम्मेदारी | शेष सत्यापन |
|---|---|---|
| Customer | Arrival के बाद Start/Stop approval; final labour bill; materials approval; snapshot; Cash/Online selection; refund request | वास्तविक OTP session, pending/declined/retry UI, mobile layout, race/reload behavior |
| Electrician | Arrival evidence; start/stop request; materials itemization/receipt; cash receipt confirmation; commission remittance | offer acceptance के बाद ही phone visibility; real-time refresh; double-submit और failure recovery |
| Admin | Timer read-only audit; booking assignment; timer bookings पर legacy Save block; refunds, payout/commission views | role-negative tests; Admin direct table write/RLS; 300 booking limits; audit logs; no mutation of final bill/snapshot |
| Staff | अभी वास्तविक Staff panel/role surface नहीं मिला | individual auth, least privilege, assigned complaint/support work, audit/SLA |

## शेष जोखिम / काम
1. Snapshot payment handler tests: `create-snapshot-order`, `verify-snapshot-payment`, webhook snapshot path — success, unauthorized owner, unverified phone, stale final bill, cash intent conflict, amount/currency mismatch, duplicate order claim, replay, concurrent callback, captured vs authorized, webhook delayed/duplicate/conflicting event।
2. SQL release validation: दोनों timer migration families को canonical क्रम में disposable Production-parity DB पर replay; फिर दूसरी बार replay/clean rebuild; historical legacy payout fixture assertions।
3. Timer customer/electrician/Admin panel role matrix को authenticated और unauthenticated SQL roles से validate करना।
4. Customer/electrician phone reveal timing को accepted-offer transition से जोड़कर verify करना; UI offer rendering alone पर्याप्त नहीं।
5. Admin timer records read-only रहें; SQL-level grants/RLS/RPC permissions से यह साबित करना कि generic table updates final_bill_id, payable snapshots, timer state या verified payment ledger को mutate नहीं कर सकते।
6. वास्तविक Browser/Android device E2E, Razorpay Test Mode और CI evidence के बिना किसी UI या payment flow को complete/production-ready न कहें।
7. Staff panel, दो native Android apps और founder original photo binary अभी अलग deliverables हैं; इस source audit ने इन्हें implement नहीं किया।

## Release decision
**NO-GO for Production.** यह commit-level source audit है, deployment approval नहीं। Production Supabase migration, Netlify deployment, live Razorpay, real money, paid services या Play Store पर कोई कार्रवाई नहीं की गई।
