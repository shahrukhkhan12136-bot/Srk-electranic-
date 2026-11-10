# SRK ELECTRONIC — Flutter Mobile Apps

यह मोबाइल workspace मौजूदा SRK ELECTRONIC वेबसाइट और उसी Supabase project के साथ काम करने के लिए है। कोई नया backend/database नहीं बनाया गया है।

## तीन अलग Android apps
- `apps/customer_app` — Customer login और customer workflows
- `apps/electrician_app` — Electrician OTP login और partner workflows
- `apps/admin_app` — Admin email/password login; सफल login के बाद मौजूदा `is_srk_admin()` RPC से server-side authorization अनिवार्य

तीनों का display name **SRK ELECTRONIC** होगा। App IDs अलग होंगे ताकि तीनों फोन में अलग-अलग install हो सकें:
- `in.srkelectronic.customer`
- `in.srkelectronic.electrician`
- `in.srkelectronic.admin`

## Shared code
`packages/srk_mobile_core` में Supabase initialization, OTP/password authentication और common login UI है। केवल Supabase URL और publishable/anon key client apps में दिए जा सकते हैं। **service_role key, Razorpay secret या webhook secret कभी mobile app में न डालें।**

## Local setup
Flutter SDK और Android SDK install होने के बाद हर app directory में:
1. `flutter create . --platforms=android` चलाएँ (पहले से मौजूद source files को सुरक्षित रखें; overwrite prompt आए तो मौजूदा files न बदलें)।
2. `flutter pub get`
3. नीचे के dart-defines के साथ run/build करें:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

APK के लिए `flutter build apk --release`; Play Store bundle के लिए `flutter build appbundle --release` (release signing अभी configure/test करना बाकी है)।

## वर्तमान स्थिति
यह अभी development source है, production-ready app नहीं। Admin App में सर्वर-सत्यापित लॉगिन, वित्तीय सारांश, payout overview, wallet overview और commission summary के साथ Booking एवं Partner Management स्क्रीन जोड़ी गई है। Admin बुकिंग सूची देख सकता है और मौजूदा `srk_admin_offer_booking` RPC से PIN → district fallback के अनुसार ऑफर भेज सकता है। Electrician applications की समीक्षा `srk_admin_review_application` से होती है; approval पर backend OTP verification अनिवार्य करता है और profile को inactive रखता है। दस्तावेज़ `srk_admin_list_electrician_verification_documents` से सूचीबद्ध होते हैं तथा review/activation केवल मौजूदा सुरक्षित RPCs से होते हैं। Activation पर backend OTP-linked profile और नवीनतम identity/address proofs के approval की जाँच करता है। Booking सूची में ग्राहक का फोन नंबर select या display नहीं किया जाता। Customer App में नई बुकिंग फॉर्म जोड़ा गया है। यह मौजूदा rate-limited Netlify `/api/create-booking` endpoint को OTP session Bearer token के साथ कॉल करता है; server registered phone और booking phone match जाँचता है, service-role key केवल server पर रहती है। Build के समय `--dart-define=SRK_API_BASE_URL=https://YOUR_NETLIFY_SITE_DOMAIN` देना जरूरी है। Customer की शुरुआती कीमत अभी जानबूझकर submit नहीं होती, क्योंकि वर्तमान schema में उसके लिए अलग field नहीं है और `quoted_amount` final electrician quote/payment total के लिए उपयोग होता है। Counter Offer के लिए भी सुरक्षित backend field/RPC उपलब्ध नहीं है; इसे बिना DB schema approval के नकली UI/API से नहीं जोड़ा गया। OTP delivery, Flutter compile, device testing, Android build, signing और end-to-end tests बाकी हैं। Admin booking/partner workflows अभी source-level implementation हैं; वास्तविक Admin account से सुरक्षित runtime testing बाकी है।

## सुरक्षा सीमाएँ
- Customer और Electrician के लिए phone OTP verification जरूरी है।
- Admin को dashboard से पहले `is_srk_admin()` RPC से verify किया जाता है; client-side email allowlist पर भरोसा नहीं है।
- Direct phone-number calling अभी नहीं जोड़ी गई है; masked calling provider और OTP-verified registered-device flow अलग से पूरा/टेस्ट होगा।
- कोई database migration, production deploy या live payment action इस scaffold से नहीं किया गया है।
