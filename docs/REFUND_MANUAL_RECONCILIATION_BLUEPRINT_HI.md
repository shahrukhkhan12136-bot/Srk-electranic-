# Refund Manual Reconciliation Blueprint (Hindi)
तारीख: 2026-11-12
स्थिति: प्रस्तावित डिज़ाइन; अभी Production में लागू नहीं।

## उद्देश्य
ऐसे Refund को सुरक्षित रूप से सुलझाना जिसमें Razorpay ने अनुरोध स्वीकार किया हो सकता है, लेकिन SRK Database में अंतिम स्थिति दर्ज न हो पाई हो; या Razorpay webhook और API response अलग क्रम में आए हों। लक्ष्य duplicate refund रोकना और बिना प्रमाण के terminal state बदलने से बचना है।

## वर्तमान प्रमाणित व्यवहार
- Refund Handler पहले Admin authorization, approved request और `srk_admin_prepare_booking_refund` के माध्यम से business ledger record/lock तैयार करता है।
- Ledger पहले से `processed` हो तो handler Razorpay को call किए बिना सफल replay लौटाता है।
- अन्यथा captured payment, exact amount और `amount_refunded = 0` जाँचकर एक full refund request भेजता है।
- `X-Refund-Idempotency` उसी ledger idempotency key से भेजा जाता है।
- Provider refund ID bind हो जाने के बाद अलग ID स्वीकार नहीं होनी चाहिए।
- Hardened reconciliation में `failed` terminal है: बाद का stale `pending` ignore होता है; बाद का `processed` conflict के रूप में रोक दिया जाता है और manual review चाहिए।
- ये hardened protections अभी feature branch पर हैं; Production RPC अभी पुराना है।

## Razorpay API contract से निकला नियम
- Refund API का `409 Conflict` unresolved/in-progress पहले अनुरोध का संकेत हो सकता है। उसी business operation के लिए वही idempotency key और बिल्कुल वही request body दोबारा इस्तेमाल करनी है।
- Timeout या 409 पर नया idempotency key, नया refund record या अलग amount/body बनाकर retry नहीं करना है।
- Provider का `processed` status अकेले ग्राहक के बैंक खाते में credit होने का प्रमाण नहीं; ledger और provider refund record को reconcile करना है।
- Reference: Razorpay official refund idempotency guidance and API docs (reviewed 2026-11-12).

## प्रस्तावित Admin workflow
1. **Case खोलना:** Admin केवल उसी refund record को खोल सके जिसकी स्थिति `requested/processing/failed/unknown` है; साथ में booking, payment ID, approved amount, request ID, idempotency key, provider refund ID और audit history दिखें।
2. **Read-only provider lookup:** payment और refund details को Razorpay Dashboard/API से manually verify किया जाए। इस workflow में कोई automatic refund POST नहीं होना चाहिए।
3. **Evidence capture:** Admin provider refund ID, provider status, amount, currency, payment ID, provider timestamps और Dashboard evidence/reference दर्ज करे। राशि/payment mismatch पर case blocked रहे।
4. **Safe outcomes:**
   - Same provider refund ID + `processed` + exact amount/payment match: audited reconcile action के लिए eligible।
   - Same provider refund ID + `pending`: processing में रहे; कोई नया refund न भेजें।
   - `failed` + no provider refund ID: failed ही रहे; नया refund अपने-आप न बने।
   - `failed` + provider later says `processed`: terminal conflict; dual-control/manual escalation आवश्यक।
   - Different non-null provider refund ID, amount mismatch, payment mismatch, duplicate matches: hard block और escalation।
5. **Dual-control:** Terminal conflict में अलग अधिकृत Admin reviewer approval और immutable audit entry आवश्यक हो। Initiating Admin स्वयं अपने conflict को approve न कर सके।
6. **Idempotency:** Reconcile action का अपना unique audit/action ID हो; repeated Admin click वही result लौटाए, duplicate ledger mutation न करे।
7. **Customer communication:** केवल verified `processed` के बाद “Refund पूरा दर्ज” दिखे। `pending` या unresolved स्थिति में समय-सीमा का वादा न करें।

## Implementation से पहले अनिवार्य काम
- Production migration archive के 39 unresolved entries और 26 version mismatches की recovery पूरी करना।
- Disposable Production-parity database में सभी migrations दो बार replay करना।
- मौजूदा Admin refund UI, RPC response contract और refund webhook/API interaction की end-to-end SQL/handler tests।
- Dual-control identity model, permissions, audit schema और conflict-resolution authority पर owner approval।
- `failed -> processed` manual transition की स्पष्ट policy approval; इसे सामान्य webhook reconciliation में कभी न खोलें।
- अलग लिखित approval के बिना Production migration, live Razorpay call, real-money test या deployment नहीं।

## Test matrix (आवश्यक)
- Timeout after provider accepted request; same key/body retry.
- Provider 409; same key/body only.
- Duplicate webhook/event delivery.
- `processed` replay; no second provider POST.
- `failed -> pending` stale event ignored.
- `failed -> processed` automatic reconcile blocked; Admin dual-control path only.
- Conflicting provider refund IDs blocked.
- Amount/payment/currency mismatch blocked.
- Two Admins concurrently attempting same reconciliation; exactly one audited transition.
- Unauthorized/non-admin/initiating-admin self-approval blocked.

## वर्तमान निष्कर्ष
यह blueprint केवल डिज़ाइन दस्तावेज़ है। कोई Production बदलाव, provider API call या वास्तविक धन का लेन-देन नहीं हुआ।
