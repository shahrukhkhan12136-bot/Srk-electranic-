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
- Customer picker अभी Dashboard preview-only है।
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
