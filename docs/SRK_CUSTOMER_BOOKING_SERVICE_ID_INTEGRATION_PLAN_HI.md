# SRK ELECTRONIC — Customer Booking Service ID Integration Plan

तारीख: 21-11-2026  
शाखा: `feature/playstore-mobile-apps-gpt1-20261121`

## 1. उद्देश्य

Customer app में चुनी गई सर्विस की एक स्थिर पहचान booking record में सुरक्षित हो और वही पहचान Technician offer तथा उसकी verified skill से match हो। यह योजना मौजूदा booking system को बदलने के बजाय उसके साथ सुरक्षित, चरणबद्ध integration के लिए है।

## 2. अभी का वास्तविक व्यवहार (source audit)

Customer app की मौजूदा `POST /api/create-booking` request में ये fields भेजे जाते हैं:

- `customer_name`, `phone`, `state`, `district`, `pincode`, `address`
- `service_type` (पुराना display/service text)
- `preferred_date`, `preferred_time`, `work_details`
- `payment_method`
- `location_lat`, `location_lng`

इस request में अभी `catalogue_version`, `category_id`, `subcategory_id`, `task_id` नहीं भेजे जाते। Dashboard का नया category picker अभी केवल preview है; वह पुराने booking form या submit payload से जुड़ा नहीं है।

## 3. प्रस्तावित नया service identity

Shared Core DTO: `SrkServiceSelection`  
File: `packages/srk_mobile_core/lib/srk_service_selection_contract.dart`

उदाहरण (draft IDs; production में अभी न भेजें):

```json
{
  "catalogue_version": "draft-2026-11-21.1",
  "category_id": "ac_fridge",
  "subcategory_id": "ac",
  "task_id": "gas_charging"
}
```

- IDs ही cross-app identity हैं।
- Labels केवल UI display के लिए हैं; server उन्हें authoritative identity न माने।
- Task ID selected subcategory के भीतर ही valid होना चाहिए।
- जिन services के task IDs अभी तय नहीं हैं, उन्हें task-specific request में शामिल न करें।
- Draft catalogue version backend-approved/deployed version नहीं है।

## 4. Backend contract — आवश्यक fields और response

Backend owner को final field names/version approve करने हैं। प्रस्तावित create-booking request में पुराने fields यथावत रहें और service identity के ये fields अतिरिक्त हों:

- `catalogue_version` (string, required for new structured-service requests)
- `category_id` (string, required)
- `subcategory_id` (string, conditional)
- `task_id` (string, conditional)

Backend को:
1. Authenticated customer, verified phone, address, date/time और existing validations पहले की तरह जाँचने हैं।
2. Catalogue version active/approved है या नहीं, server-side जाँचना है।
3. Category → subcategory → task hierarchy और active IDs validate करने हैं।
4. उसी request में legacy `service_type` field को backward compatibility के लिए स्वीकार करना है; वह नए IDs का विकल्प/authority नहीं होगा।
5. Booking पर validated service identity का immutable snapshot/version सहेजना है।
6. Response में booking ID और normalized service identity लौटानी है।
7. Offer बनाते समय booking से वही snapshot copy करना है; offer में नई या अनुमानित category नहीं बनानी।
8. Technician verified skill record को उसी canonical version/IDs से match करना है।

प्रस्तावित response का service भाग:

```json
{
  "booking": {
    "id": "server-booking-id",
    "service": {
      "catalogue_version": "backend-approved-version",
      "category_id": "ac_fridge",
      "subcategory_id": "ac",
      "task_id": "gas_charging"
    }
  }
}
```

ऊपर के IDs और version केवल उदाहरण हैं; वास्तविक canonical IDs backend और product owner की मंजूरी से तय होंगे।

## 5. सुरक्षित rollout — चरणबद्ध gates

### Gate A — Backend तैयारी
- Canonical catalogue/version freeze और migration।
- Booking columns/snapshot, validation और response contract।
- Existing legacy `service_type` bookings read/dispatch compatibility।
- Offer payload में booking का exact service snapshot।
- Verified-skill payload में समान IDs/version।
- Offer accept पर तथा हर protected work/material/payment action पर server-side active skill, ownership, assignment, expiry/revocation और state/version re-check।
- Staging में old और new booking flows के tests।

### Gate B — Frontend contract integration
Backend staging response और API contract मिलने के बाद ही:
- Dashboard picker को existing booking form के वास्तविक service-selection state से जोड़ना।
- चुनी हुई identity को उसी existing submit request में अतिरिक्त fields के रूप में भेजना।
- Existing customer/address/date/time/payment/GPS fields को न हटाना।
- Backend normalized service response पढ़कर booking history में सही display करना।
- पुराने bookings जिनमें structured IDs नहीं हैं, उन्हें legacy display fallback से दिखाना।
- Unknown version/IDs पर booking submit रोकना और स्पष्ट error दिखाना; अनुमान लगाकर दूसरी category न चुनना।

### Gate C — Technician offer integration
- Backend offer response में booking का canonical service snapshot पढ़ना।
- Technician की server-approved verified skills दिखाना।
- UI preview mismatch/unknown को स्पष्ट रूप से informational रखना।
- Client-side preview से offer hide, accept या authorization न करना; backend ही eligibility तय करे।

### Gate D — Production rollout
- Staging contract tests, regression tests, Android device tests और payment/booking regression pass।
- Backend deploy version और rollback plan दर्ज।
- पहले सीमित rollout; server logs में invalid IDs/version monitor।
- उसके बाद ही production feature flag enable।

## 6. पुराने booking system की सुरक्षा

इन मौजूदा हिस्सों को इस काम में rewrite/remove नहीं करना है:
- OTP authentication और verified phone
- Existing booking form fields and submit flow
- Cash/online payment selection and Razorpay flow
- Booking history/status, cancellation and complaints
- Offer accept/reject, assigned booking, maps and authorized contacts
- Existing quote-dependent historical booking records until quote-free backend replacement is deployed

नई service identity केवल अतिरिक्त structured data होगी। Existing booking lifecycle/payment changes अलग backend-approved project और compatibility plan के बिना नहीं होंगे।

## 7. Acceptance checklist

- [ ] Backend canonical catalogue/version approved और deployed।
- [ ] API request/response schemas, error codes और version policy प्रकाशित।
- [ ] Legacy और structured booking दोनों staging में सफल।
- [ ] Booking snapshot से offer तक IDs/version अपरिवर्तित।
- [ ] AC/Fridge cross-task mismatch server पर reject।
- [ ] Pending/inactive/expired skill server पर reject।
- [ ] Offer accept race, duplicate request और version conflict tests।
- [ ] Customer booking history legacy + structured records दिखाती है।
- [ ] Existing cancellation/complaint/payment regression pass।
- [ ] Flutter analyzer/tests, Android build और physical-device tests pass।
- [ ] Rollback और monitoring evidence दर्ज।

## 8. वर्तमान implementation status

- Shared service selection DTO और Customer picker callback मौजूद हैं।
- Technician preview matcher उसी versioned ID shape को समझता है।
- Customer picker अब मौजूदा booking form के अंदर form-local preview है; यह submit payload में शामिल नहीं है।
- Existing `POST /api/create-booking` payload unchanged है।
- कोई Supabase query/RPC, backend, database, payment, dispatch या production code नहीं बदला।
- Flutter tests/analyzer/formatter/Android build/device tests इस चरण में execute/verify नहीं किए गए।

## 9. नवीनतम Customer form preparation update (21-11-2026)

- नया category picker Dashboard preview से हटाकर मौजूदा Customer Booking Form के अंदर रखा गया है।
- Form state में `SrkServiceSelection?` draft selection रखा जाता है; चयन का display name और draft catalogue version दिखते हैं।
- Picker को स्पष्ट रूप से preparation/preview बताया गया है। Backend approval से पहले यह booking payload में नहीं जाता।
- मौजूदा legacy electrical `service_type` dropdown अभी भी मौजूद और required है, क्योंकि deployed create-booking endpoint अभी उसी field पर निर्भर है।
- Existing customer details, OTP checks, date/time, work details, payment method, GPS, endpoint और response handling untouched हैं।
- नया category picker अभी legacy `service_type` को auto-fill नहीं करता। ऐसा करने से AC/Fridge/Plumber आदि की booking गलत legacy dispatch path पर जा सकती है।
- इसलिए यह form-level state/UI preparation है, live category booking integration नहीं।

## 10. Picker stale-selection safety (21-11-2026)

- Picker callback अब nullable selection देता है।
- Category या subcategory बदलते ही पुराना completed selection null से clear होता है; नया valid selection तभी emit होता है जब नया hierarchy choice पूरा हो।
- इससे AC से Fridge, Cooler से AC या किसी अन्य parent choice पर जाने पर form में पुरानी service ID/label गलती से selected नहीं रहती।
- नया reset व्यवहार UI state तक सीमित है; booking submit payload में कोई बदलाव नहीं।
- Widget regression test जोड़ा गया है; अभी execute नहीं किया गया।

## 11. Task selection visual state (21-11-2026)

- Task chips अब selected task को स्पष्ट highlight करते हैं।
- AC/Fridge या अन्य subcategory बदलने पर task highlight reset होता है।
- Parent category बदलने पर subcategory और task दोनों state reset होते हैं।
- Widget regression test में selected highlight और subcategory reset assertions जोड़े गए हैं; tests अभी execute नहीं हुए।
- यह UI-only सुधार है; booking payload, API और backend flow नहीं बदले।


## 12. Customer booking form compatibility audit (21-11-2026)

### सुरक्षित पाए गए मौजूदा fields और checks
- OTP session तथा `phoneConfirmedAt` की जाँच submit से पहले होती है; फोन नंबर OTP account से read-only लिया जाता है।
- नाम, राज्य, जिला, पता, तारीख, समय और सर्विस आवश्यक हैं; PIN Code के लिए 6 अंक और काम की जानकारी के लिए कम-से-कम 5 अक्षर validate होते हैं।
- GPS optional है। लोकेशन मिलने पर latitude/longitude दोनों साथ request में जाते हैं; न मिलने पर दोनों null रहते हैं।
- Cash/online payment selection पुराने `payment_method` field में ही जाता है।
- Secure HTTPS endpoint, bearer session token, response status/success validation, loading lock, timeout और error feedback मौजूद हैं।
- सफल response में booking ID दिखती है; इसके बाद form बंद होता है।

### पुराने सिस्टम के साथ संगतता
- Legacy `service_type` dropdown अभी required है और `POST /api/create-booking` में वही पुराना field जाता है।
- नए category picker का `SrkServiceSelection` केवल draft state/display तक सीमित है। `catalogue_version/category_id/subcategory_id/task_id` payload में नहीं जाते।
- Picker बदलने पर nullable callback पुराने draft selection को clear करता है; यह legacy `service_type` को auto-select या बदलता नहीं।
- तारीख/समय की जाँच submit के अलग guard में है, Form validator में नहीं; वर्तमान व्यवहार फिर भी submit रोकता है।
- कोई booking payload, payment choice, GPS behavior, endpoint, backend या database बदलाव नहीं किया गया।

### सीमाएँ और अगली आवश्यकताएँ
- मौजूदा आठ legacy service विकल्प electrical-only हैं। इसलिए नए छह-category picker को legacy dropdown से जोड़ना सुरक्षित नहीं; Backend canonical service contract और legacy-to-new dispatch compatibility पहले चाहिए।
- Location permission permanently denied होने पर उपयोगकर्ता को Settings खोलने का सीधा मार्ग अभी नहीं दिया गया; इसे अलग UX सुधार के रूप में जाँचा जा सकता है, पर manual address fallback मौजूद है।
- Widget/regression tests, formatter, analyzer, Android build और device test इस audit में execute नहीं किए गए।
- Backend-approved schema और staging contract आने तक draft picker को केवल preview ही रखें।

**निष्कर्ष:** मौजूदा submit path और पुराने booking fields को सुरक्षित रखा गया है। कोई runtime code परिवर्तन इस audit में नहीं किया गया।


## 13. Booking history, cancellation और complaint compatibility audit (21-11-2026)

- Booking history query authenticated customer's own `customer_user_id` पर scoped है, newest-first है और अधिकतम 50 rows पढ़ती है।
- Status display में मौजूदा booking और legacy quote states शामिल हैं; unknown status raw fallback है।
- Cancellation UI केवल `new/confirmed` states में दिखता है। Server RPC को अंतिम ownership/state validation करनी चाहिए; client visibility को authorization न मानें।
- Complaint create/list RPCs और Technician contact RPC पुराने dashboard flow का हिस्सा हैं; quote-free migration में इन्हें compatibility matrix में सुरक्षित रखें।
- Complaint/contact list load failure अभी चुपचाप empty/no-contact जैसा दिख सकता है; अलग load/error states UX सुधार के लिए दर्ज हैं।
- Complaint text line-break rendering और unknown-status fallback की targeted UI जाँच बाकी है।
- Quote-related approve/reject और status display ऐतिहासिक records के लिए तब तक रखें जब तक नया backend lifecycle और migration/compatibility path deployed तथा tested न हो।
- कोई runtime या backend बदलाव नहीं किया गया; Flutter tests/analyzer/build execute नहीं हुए।
