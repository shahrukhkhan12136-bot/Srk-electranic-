# SRK ELECTRONIC — Admin और Electrician Login सेटअप

## नए पेज
- `admin.html`: Admin OTP Login, बुकिंग, आवेदन, पार्टनर और कमीशन रिपोर्ट।
- `electrician.html`: इलेक्ट्रिशियन OTP Login, काम के ऑफर, Accept/Decline।
- `PORTAL_SCHEMA.sql`: सुरक्षा नियम, Admin allowlist, प्रोफाइल लिंक और काम स्वीकार करने की प्रक्रिया।

## चालू करने के लिए जरूरी कदम
1. Supabase में Phone OTP चालू करें और SMS Provider सेट करें। SMS OTP का खर्च हो सकता है।
2. Supabase SQL Editor में क्रम से `SUPABASE_SCHEMA.sql`, `PORTAL_SCHEMA.sql`, फिर `PORTAL_SECURITY_UPDATE.sql` चलाएँ।
3. `srk-config.example.js` की कॉपी `srk-config.js` नाम से बनाएँ और उसमें Supabase Project URL तथा anon/publishable key भरें। Service Role Key यहाँ कभी न डालें।
4. मालिक के मोबाइल से Supabase OTP लॉगिन पूरा करें। Supabase Authentication → Users से उस अकाउंट का UUID कॉपी करें। फिर SQL Editor में चलाएँ:

```sql
insert into public.srk_admin_users(user_id)
values ('यहाँ-मालिक-का-auth-user-UUID');
```

5. Netlify पर पूरा फ़ोल्डर deploy करें। फिर `/admin.html` खोलें।
6. Admin आवेदन जाँचे, अप्रूव करे और दस्तावेज़/कौशल जाँच के बाद ही पार्टनर को Active करे।
7. इलेक्ट्रिशियन `/electrician.html` पर उसी verified मोबाइल नंबर से OTP लॉगिन करे जो आवेदन में दिया था।

## अभी क्या लाइव नहीं है
- इस ZIP को deploy करने से पहले वेबसाइट पर कुछ नहीं बदलेगा।
- SMS/Push/WhatsApp job notification अभी नहीं जुड़ा; ऑफर electrician dashboard में दिखेंगे।
- सुरक्षा अपडेट के बाद ऑफर देखने वाले इलेक्ट्रिशियन को ग्राहक का नाम, फोन और पूरा पता तभी दिखेगा जब काम उसी को असाइन हो जाए।
- 15% कमीशन केवल completed booking और quoted amount दर्ज होने पर गणना होगा; अपने-आप बैंक से वसूली या payout नहीं होगा।
- सार्वजनिक लॉन्च से पहले OTP provider, CAPTCHA/rate limits, privacy policy, terms, refunds, KYC और payout की जाँच जरूरी है।


## सुरक्षा सुधार — ग्राहक की जानकारी
`PORTAL_SECURITY_UPDATE.sql` को बाकी दोनों SQL फाइलों के बाद चलाएँ। यह पुराने electrician booking-read policy को हटाता है और `srk_get_my_offer_details()` RPC देता है। इससे सभी offer recipients को केवल काम का सारांश, जिला और PIN दिखता है; ग्राहक का नाम, फोन और पूरा पता केवल assigned electrician को मिलता है। इसे लागू किए बिना सार्वजनिक electrician portal लॉन्च न करें।

## रिलीज़ जाँच सूची
- [ ] तीनों SQL फाइलें इसी क्रम में सफलतापूर्वक चलीं।
- [ ] Admin OTP से लॉगिन कर पा रहा है और केवल allowlisted Admin ही डेटा देख पा रहा है।
- [ ] दो अलग-अलग approved electrician accounts से एक ही booking का offer देखा; दोनों को ग्राहक का फोन/पूरा पता नहीं दिखा।
- [ ] पहले electrician के Accept करने पर booking उसी को assign हुई और दूसरे offer expire हुए।
- [ ] Assigned electrician को ही ग्राहक का फोन और पूरा पता दिखा।
- [ ] Unauthorized user booking, application या दूसरे electrician का data नहीं पढ़ सकता।
- [ ] Test booking के बाद Netlify function logs में कोई secret या पूरा customer payload log नहीं हुआ।
