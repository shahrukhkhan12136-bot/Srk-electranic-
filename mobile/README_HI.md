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
यह अभी development source है, production-ready app नहीं। Admin App में सर्वर-सत्यापित लॉगिन, वित्तीय सारांश, payout overview, wallet overview और commission summary के साथ Booking एवं Partner Management स्क्रीन जोड़ी गई है। Admin बुकिंग सूची देख सकता है और मौजूदा `srk_admin_offer_booking` RPC से PIN → district fallback के अनुसार ऑफर भेज सकता है। Electrician applications की समीक्षा `srk_admin_review_application` से होती है; approval पर backend OTP verification अनिवार्य करता है और profile को inactive रखता है। दस्तावेज़ `srk_admin_list_electrician_verification_documents` से सूचीबद्ध होते हैं तथा review/activation केवल मौजूदा सुरक्षित RPCs से होते हैं। Activation पर backend OTP-linked profile और नवीनतम identity/address proofs के approval की जाँच करता है। Booking सूची में ग्राहक का फोन नंबर select या display नहीं किया जाता। Customer App में नई बुकिंग फॉर्म जोड़ा गया है। यह मौजूदा rate-limited Netlify `/api/create-booking` endpoint को OTP session Bearer token के साथ कॉल करता है; server registered phone और booking phone match जाँचता है, service-role key केवल server पर रहती है। यह ऐप मौजूदा Netlify साइट `https://srk-electronic-india.netlify.app` को default API base URL मानता है; किसी दूसरे domain पर जाने पर `--dart-define=SRK_API_BASE_URL=https://YOUR_DOMAIN` से override किया जा सकता है। Customer की शुरुआती कीमत और electrician counter-offer के लिए अलग backend migration अब इसी branch में draft की गई है: `supabase/migrations/20261110210000_customer_price_suggestion_and_electrician_counter_offer.sql`। इसमें `customer_suggested_amount`, timestamp, quote classification, customer-only one-time suggestion RPC और phone/address रहित electrician price-details RPC शामिल हैं। मौजूदा labour/materials split और customer quote approve/reject workflow बरकरार रखा गया है। यह migration अभी production या किसी Supabase database पर apply नहीं की गई है। Netlify `/api/create-booking` endpoint अब OTP-verified session के बाद optional शुरुआती कीमत validate करके नई columns में सेव करने के लिए तैयार है। Customer App में optional कीमत field और booking summary में उसकी display जोड़ी गई है। Electrician App नया phone/address रहित `srk_get_my_offer_price_details()` RPC पढ़कर ग्राहक की शुरुआती कीमत और अपना labour/materials quote दिखाता है; ग्राहक की अलग-अलग मंजूरी मौजूदा `srk_customer_respond_booking_quote` से ही होती है। यह पूरा code अभी feature branch में है और migration apply होने से पहले किसी environment में चलाने पर नए columns/RPC उपलब्ध नहीं होंगे। SQL migration को isolated test database में verify करना, Flutter compile और end-to-end tests बाकी हैं। OTP delivery, Flutter compile, device testing, Android build, signing और end-to-end tests बाकी हैं। Admin booking/partner workflows अभी source-level implementation हैं; वास्तविक Admin account से सुरक्षित runtime testing बाकी है।

## सुरक्षा सीमाएँ
- Customer और Electrician के लिए phone OTP verification जरूरी है।
- Admin को dashboard से पहले `is_srk_admin()` RPC से verify किया जाता है; client-side email allowlist पर भरोसा नहीं है।
- Direct phone-number calling अभी नहीं जोड़ी गई है; masked calling provider और OTP-verified registered-device flow अलग से पूरा/टेस्ट होगा।
- नई price/counter-offer migration केवल GitHub feature branch में draft है; production database पर apply नहीं की गई। इस migration के बिना नए API/App code को deploy नहीं करना है। कोई production deploy या live payment action नहीं किया गया है।

## GitHub Actions में सुरक्षित मोबाइल Backend Configuration

नए APK को वास्तविक SRK backend से जोड़ने के लिए GitHub repository में ये तीन values configure करना अनिवार्य है। इन्हें source code या workflow log में hard-code/print न करें।

GitHub repository खोलें → **Settings → Secrets and variables → Actions**:

1. **Variables** में `SUPABASE_URL` नाम बनाएँ और value रखें: `https://gnqhoaqatmoiwwhgzkgm.supabase.co`
2. **Variables** में `SRK_API_BASE_URL` नाम बनाएँ और value रखें: `https://srk-electronic-india.netlify.app`
3. **Secrets** में `SUPABASE_ANON_KEY` नाम बनाएँ और मुख्य Supabase project की सक्रिय **legacy anon public key** रखें। केवल public anon/publishable key इस्तेमाल करें; `service_role`, secret API key, Razorpay secret या webhook secret कभी नहीं।

Workflow अब configuration की मौजूदगी जाँचेगा और तीनों ऐप में `SUPABASE_URL`, `SUPABASE_ANON_KEY` तथा `SRK_API_BASE_URL` compile-time dart-defines के रूप में देगा। कोई value अनुपस्थित या HTTPS validation fail हुई तो APK build रोक दिया जाएगा। Key और URL logs में print नहीं होंगे।

**महत्वपूर्ण:** पिछला CI build (Run #4) बिना इन dart-defines के बना था। इसलिए वे APK केवल compile/build proof हैं; उन्हें backend login या वास्तविक बुकिंग टेस्ट के लिए इस्तेमाल न करें। GitHub में ऊपर की तीन values सेट करने के बाद नया सफल CI build आने पर ही नया configured APK डाउनलोड करें।

इन configured APKs का परीक्षण पहले test accounts और नियंत्रित test bookings से करें। Customer price/counter-offer migration अभी केवल feature branch में है और किसी Supabase database पर लागू नहीं हुई है; उस नई सुविधा का end-to-end test migration की अलग सुरक्षित समीक्षा और isolated test के बाद ही होगा। Production database या Netlify deployment इस चरण में न करें।
