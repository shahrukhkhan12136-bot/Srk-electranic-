# GPT-2 Booking Rate Source Audit (Hindi)

तारीख: 2026-11-18  
कार्य-शाखा: `feat/ai-rate-management-foundation-20261118`

## उद्देश्य
ग्राहक Rate Catalogue, Booking estimate, immutable historical snapshot और इलेक्ट्रिशियन के 85% हिस्से के बीच वास्तविक source flow की जाँच। यह source-only audit है; Production Database, migration, deployment या payment configuration में कोई बदलाव नहीं किया गया।

## 1. अभी वास्तविक authoritative rate कहाँ है?

### ग्राहक Booking UI — `booking.html`
`customerRateCard` में चार 8-hour rates hard-code हैं:
- electrical_assistant: 89900 paise
- skilled_electrician: 119900 paise
- expert_electrician: 159900 paise
- premium_electrical_specialist: 199900 paise

`updateLabourEstimate()` duration के अनुसार अनुमान दिखाता है। यह केवल browser preview है; इसे authoritative billing source नहीं मानना चाहिए।

### Server Booking API — `create-booking.js`
Netlify handler में वही चार rates फिर से hard-code हैं और version:
`SRK-CUSTOMER-LABOUR-2026-11-13-V1`

Server selected tier और duration validate करके:
`estimatedLabourPaise = round(rate8hPaise * hours / 8)`
गणना करता है और `service_bookings.estimated_labour_paise` तथा `estimate_rate_card_version` लिखता है। इसलिए वर्तमान Booking का वास्तविक server-side estimate इसी API के hard-coded map से आता है, Admin-managed catalogue से नहीं।

## 2. Rate List Management में मुख्य gaps

1. Browser और server दोनों में एक ही Rate Catalogue की अलग-अलग copies हैं; mismatch का जोखिम है।
2. Admin UI में इस audit के दौरान customer labour rate publish/version controls नहीं मिले। Admin page पर electrician category approval और payout/commission reporting मौजूद है, पर वह customer Rate Catalogue का विकल्प नहीं है।
3. Server API में active published rate version पढ़ने का flow नहीं है।
4. Rate बदलने पर नए Booking में नया version और पुराने Booking में पुराना snapshot सुरक्षित रखने की पूरी versioned catalogue व्यवस्था अभी wired नहीं है।
5. Idempotent replay path existing Booking की पहचान पढ़ता है, लेकिन estimate response वर्तमान request के rate map से दोबारा बनाता है। Dynamic rates आने पर replay response को मौजूदा catalogue से नहीं, पहले से सेव Booking snapshot से लौटना चाहिए।

## 3. 85% नियम और मौजूदा Commission का अंतर

Admin UI के Commission विवरण में मौजूदा नियम यह बताया गया है:
- Commission प्रत्येक Booking के `commission_rate` के अनुसार service charge पर calculate होता है।
- Materials पर commission नहीं लगता।
- Commission केवल Completed + Paid booking पर बनता है।

यह मौजूदा accounting rule अपने-आप fixed 15% of gross labour के बराबर सिद्ध नहीं होता। इसलिए 85% net rule लागू करने से पहले यह तय करना जरूरी है कि:
- 15% fixed company share नया approved commercial rule है; या
- मौजूदा variable `commission_rate` ही लागू रहना है; या
- 85% labour share और मौजूदा service-charge commission अलग-अलग आधार हैं।

इनका मिलान किए बिना नया 15% घटाना double deduction या ledger mismatch बना सकता है। इस audit में कोई formula या payout calculation नहीं बदला गया।

## 4. सुरक्षित अगला implementation क्रम

1. Admin द्वारा publish किए जाने वाले versioned customer Rate Catalogue का server-side source तय करें।
2. Booking API केवल authenticated/authorized server-side catalogue से rate/version पढ़े; browser से भेजी रकम स्वीकार न करे।
3. Booking create करते समय rate version, 8-hour rate, duration और calculated labour amount immutable snapshot में सुरक्षित करें।
4. Idempotent replay हमेशा उसी Booking के stored snapshot से estimate लौटाए।
5. Customer UI preview published catalogue endpoint से पढ़े; endpoint unavailable हो तो stale hard-coded rate को authoritative बताकर न दिखाए।
6. Electrician 85% amount server-side integer paise arithmetic से निकले और Offer RPC/API में केवल net amount expose करे।
7. Commission/payout ledger reconciliation और payment-stage visibility को backend authorization/RPC में लागू करें; केवल HTML hiding पर्याप्त नहीं।
8. Tests में published-version selection, future/draft exclusion, rate change vs historic Booking, idempotent replay, rounding, 85/15 reconciliation, commission conflict और payment-stage leakage cover हों।

## 5. GPT-1 handoff

GPT-1 कृपया इन findings को backend/database implementation में ध्यान में रखें। विशेष रूप से:
- `booking.html` और `create-booking.js` के duplicate hard-coded maps हटाने से पहले published catalogue endpoint/server source तैयार करें।
- Existing Booking snapshots को कभी current rate से overwrite न करें।
- Replay path stored snapshot से ही estimate लौटाए।
- Existing `commission_rate` और `srk_electrician_payouts` formula को verify किए बिना 15% दूसरी बार न काटें।
- Payment visibility server-side enforce हो।
- Production DB/migrations/deployment/paid branch के लिए अलग explicit approval आवश्यक है।

## 6. सुरक्षा सीमा
यह दस्तावेज़ source audit और implementation plan है। कोई Production Database query, migration execution, schema mutation, paid branch, deployment या payment operation नहीं किया गया।
