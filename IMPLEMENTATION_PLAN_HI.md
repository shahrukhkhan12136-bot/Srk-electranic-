# SRK ELECTRONIC — वर्तमान तकनीकी स्थिति

## इस चरण में पूरा / जोड़ा गया
- ग्राहक बुकिंग Netlify Function से Supabase `service_bookings` में सेव होती है।
- Supabase का `broadcast_new_booking` trigger PIN Code पर matching approved/active electrician को offer बनाता है; PIN match न मिले तो उसी राज्य और जिले में fallback करता है।
- बुकिंग Function अब trigger द्वारा बने offers को केवल पढ़ता है; duplicate offer insert नहीं करता।
- इलेक्ट्रिशियन आवेदन `/api/apply-electrician` से `electrician_applications` में सेव होता है।
- Admin email/password portal: `/admin.html`; Admin allowlist `srk_admin_users` और RPC `is_srk_admin` से सुरक्षा।
- Admin approval पर inactive electrician profile बनती है; KYC जाँच के बाद Admin उसे Active कर सकता है।
- Electrician OTP portal: `/electrician.html`; approved profile फोन OTP सत्यापन के बाद Auth user से link होती है।
- Electrician offer inbox, Accept/Decline और एक booking को केवल एक electrician द्वारा स्वीकार करने के लिए atomic database RPC मौजूद है।
- ग्राहक का नाम, फोन और पूरा पता केवल assigned electrician को दिखाने वाला सुरक्षित RPC मौजूद है।
- Razorpay order creation और payment verification के Netlify handlers जोड़े गए: order amount saved booking से लिया जाता है, HMAC signature और Razorpay captured payment/INR/amount जाँचे जाते हैं।
- Netlify routes `/api/create-booking`, `/api/apply-electrician`, `/api/create-order`, `/api/verify-payment` configured हैं।

## लाइव उपयोग से पहले जरूरी कॉन्फ़िगरेशन / सीमाएँ
1. Netlify environment variables: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`। Secret values केवल Netlify में रहें।
2. Supabase Auth में electrician phone OTP provider/SMS setup होना चाहिए; SMS provider configuration अभी account में सत्यापित नहीं की गई है।
3. Razorpay Test Mode keys डालकर एक वास्तविक test payment flow जाँचना बाकी है। अभी कोई payment test नहीं किया गया।
4. एक वास्तविक electrician आवेदन, Admin approval, verified phone login और controlled test booking के साथ end-to-end test बाकी है। बिना अनुमति कोई नकली/वास्तविक booking नहीं बनाई जाएगी।
5. SMS/WhatsApp/push notifications अपने-आप नहीं भेजे जाते; फिलहाल electrician dashboard में offer inbox उपलब्ध है।
6. Matching PIN Code और उसी राज्य/जिले पर है; GPS दूरी आधारित खोज नहीं है।
7. Nationwide enquiry स्वीकार हो सकती है, लेकिन हर PIN Code पर सेवा उपलब्ध होने की गारंटी नहीं है।

## सुरक्षा / संचालन
- Service-role key और Razorpay secret browser, GitHub या WhatsApp में न रखें।
- आवेदन की मंजूरी से पहले पहचान/दस्तावेज़ की मानवीय जाँच करें।
- Commission rate 15% database default है; इसे commercial/legal review के बिना final pricing न मानें।
- Production चालू करने से पहले Razorpay merchant KYC, refund/dispute प्रक्रिया, privacy/terms और customer support workflow पूरा करें।
