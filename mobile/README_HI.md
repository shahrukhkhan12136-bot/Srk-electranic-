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
यह पहला सुरक्षित source scaffold है, production app नहीं। Dashboard data/actions अभी मौजूदा website के verified RPC/API contracts से चरणबद्ध तरीके से जोड़े जाएँगे। पहले database/RLS/RPC contracts की जाँच होगी; फिर Customer, Electrician और Admin modules अलग-अलग implement होंगे। OTP delivery, device testing, Android build, signing और end-to-end tests बाकी हैं।

## सुरक्षा सीमाएँ
- Customer और Electrician के लिए phone OTP verification जरूरी है।
- Admin को dashboard से पहले `is_srk_admin()` RPC से verify किया जाता है; client-side email allowlist पर भरोसा नहीं है।
- Direct phone-number calling अभी नहीं जोड़ी गई है; masked calling provider और OTP-verified registered-device flow अलग से पूरा/टेस्ट होगा।
- कोई database migration, production deploy या live payment action इस scaffold से नहीं किया गया है।
