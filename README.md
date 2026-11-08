# SRK ELECTRONIC — Netlify + Supabase + Razorpay

यह repository SRK ELECTRONIC की वेबसाइट और electrician booking marketplace के लिए है। वर्तमान deployment target Netlify है।

## मुख्य पेज
- `/` ग्राहक सेवा बुकिंग और इलेक्ट्रिशियन आवेदन
- `/admin.html` Admin email/password portal
- `/electrician.html` Electrician phone OTP portal

## Netlify Functions
- `/api/create-booking` — बुकिंग सेव करना और Supabase broadcast trigger से बने offers पढ़ना
- `/api/apply-electrician` — इलेक्ट्रिशियन आवेदन सेव करना
- `/api/create-order` — Razorpay order बनाना
- `/api/verify-payment` — signature और captured INR payment सत्यापित करना

## Server-side environment variables
Netlify Site configuration → Environment variables में:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RAZORPAY_KEY_ID` (पुराना alias `APIKEY` भी समर्थित)
- `RAZORPAY_KEY_SECRET` (पुराना alias `SECRETAPIKEY` भी समर्थित)

Service-role key और Razorpay secret को browser, GitHub या chat में कभी न रखें।

## Database
मुख्य Supabase project: `gnqhoaqatmoiwwhgzkgm`। मौजूदा database में bookings, applications, profiles और offers tables मौजूद हैं। Admin review, electrician profile linking, offer inbox और single-winner accept RPC configured हैं।

## महत्वपूर्ण सीमाएँ
- SMS/WhatsApp/push notifications अभी स्वचालित नहीं हैं; electrician dashboard में offer inbox है।
- OTP login के लिए Supabase phone provider/SMS setup आवश्यक है।
- Nationwide enquiry स्वीकार है, लेकिन हर PIN Code में तुरंत सेवा उपलब्ध होने की गारंटी नहीं है।
- Razorpay Test Mode में end-to-end test अभी बाकी है।
- Production से पहले KYC, refund/dispute, privacy/terms और support प्रक्रिया पूरी करें।
