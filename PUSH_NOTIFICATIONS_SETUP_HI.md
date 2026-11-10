# इलेक्ट्रिशियन बुकिंग Push Notification — सेटअप और टेस्ट

यह सुविधा अभी केवल `feature/electrician-categories-hourly-booking` ब्रांच में तैयार की जा रही है। Production पर लागू या Deploy नहीं की गई है।

## अभी कोड में क्या है
- इलेक्ट्रिशियन पेज पर अनुमति लेकर Web Push subscription सेव करने का विकल्प।
- Service Worker में बैकग्राउंड Push मिलने पर Android/browser notification दिखाना।
- नई बुकिंग के लिए अलग notification tag; ऑफर स्वीकार/समाप्त होने पर उसी notification को बंद करने का संदेश।
- Notification पर टैप करने से इलेक्ट्रिशियन पेज खुलेगा।
- Subscription table पर RLS: लॉगिन किया हुआ इलेक्ट्रिशियन केवल अपने डिवाइस की subscription देख/बदल सकता है।
- ऐप खुला होने पर अलग foreground रिंग भी है।

## सर्वर सेटअप अभी बाकी है
1. VAPID key pair सुरक्षित तरीके से बनाएँ। अपने भरोसेमंद कंप्यूटर पर `npx web-push@3.6.7 generate-vapid-keys` चलाएँ। यह public और private key देगा। Private key केवल Supabase Edge Function secret में रखें; उसे GitHub, `srk-config.js`, HTML या ग्राहक/इलेक्ट्रिशियन के browser में कभी न रखें।
2. `srk-config.js` में केवल VAPID public key को `PUSH_VAPID_PUBLIC_KEY` में सेट करें।
3. Supabase Dashboard → Project → Edge Functions → Secrets में ये values सेट करें:
   - `VAPID_PUBLIC_KEY`
   - `VAPID_PRIVATE_KEY`
   - `VAPID_SUBJECT` (आपका वास्तविक support email, जैसे `mailto:support@your-domain.in`; example placeholder email इस्तेमाल न करें)
   - `PUSH_WEBHOOK_SECRET` (लंबा random secret)
4. इस ब्रांच की `20261111020000_add_electrician_push_subscriptions.sql` migration को पहले अलग test database में जाँचें; अभी production में लागू न करें। Migration में RLS और authenticated role के grants मौजूद हैं।
5. Supabase Dashboard → Integrations → Data API में जाँचें कि `public` schema Exposed schemas में शामिल है। 30 अक्टूबर 2026 के बाद नए public tables अपने-आप Data API में expose नहीं होते। यदि ऐप को इस table तक REST access चाहिए, तो schema exposure और migration के grants दोनों आवश्यक हैं; RLS फिर भी हर row की सुरक्षा करेगा।
6. `supabase/functions/push-job-offer/index.ts` Edge Function को केवल test project में Deploy करें।
7. Supabase Database Webhooks में `public.job_offers` पर INSERT और UPDATE events के लिए इस Edge Function को जोड़ें। Header में `x-srk-push-secret` का वही secret और `Content-Type: application/json` दें। Webhook secret को VAPID private key से अलग रखें।

## जरूरी Android सीमाएँ
- फोन/ब्राउज़र में HTTPS, supported Android Chrome/PWA, इंटरनेट और notification permission जरूरी हैं।
- हर डिवाइस पर इलेक्ट्रिशियन को लॉगिन करके “बैकग्राउंड बुकिंग नोटिफिकेशन चालू करें” दबाना होगा।
- Notification की आवाज़ और vibration Android की App/Site notification settings से नियंत्रित होती है। Web Push किसी वेबसाइट को सिस्टम की असली incoming-call ringtone लगातार बजाने की गारंटी नहीं देता।
- ऐप foreground में हो तो पहले “बुकिंग रिंग चालू करें” दबाने के बाद in-app ringtone चलती है।
- Battery Saver, Do Not Disturb, browser force-stop और OEM background restrictions delivery में देरी/रोक लगा सकते हैं।

## टेस्ट योजना
- Android Chrome में अनुमति देकर subscription सेव हो।
- नई job offer पर बंद/बैकग्राउंड ऐप में notification आए।
- Notification टैप करने पर इलेक्ट्रिशियन डैशबोर्ड खुले।
- ऑफर स्वीकार या expire होने पर notification बंद हो।
- एक ही device पर duplicate subscription न बने।
- permission denied, invalid/expired subscription और offline स्थिति में ऐप crash न करे।
- Customer booking, admin booking row और electrician offer एक ही booking ID से match हों।


## वर्तमान Supabase बदलाव पर ध्यान दें
- Supabase के नए Data API exposure नियमों के अनुसार केवल SQL `GRANT` और RLS पर्याप्त नहीं हैं यदि `public` schema Data API में exposed नहीं है। Dashboard में schema exposure भी जाँचें।
- Edge Function में `SUPABASE_SECRET_KEYS.default` से secret key पढ़ी जाती है; यह key केवल server-side function environment में रहेगी, browser config में नहीं।
- यह setup अभी test-only है। VAPID keys, secrets, test DB migration, function deployment और webhook को वास्तविक test booking के साथ सत्यापित किए बिना इसे चालू न मानें।
