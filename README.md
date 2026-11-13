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
- `RAZORPAY_WEBHOOK_SECRET` (Razorpay Dashboard में `/api/razorpay-webhook` के लिए configured webhook secret; केवल Netlify environment variable में रखें)

Service-role key और Razorpay secret को browser, GitHub या chat में कभी न रखें।

## Database
मुख्य Supabase project: `gnqhoaqatmoiwwhgzkgm`। मौजूदा database में bookings, applications, profiles और offers tables मौजूद हैं। Admin review, electrician profile linking, offer inbox और single-winner accept RPC configured हैं।

## महत्वपूर्ण सीमाएँ
- SMS/WhatsApp/push notifications अभी स्वचालित नहीं हैं; electrician dashboard में offer inbox है।
- OTP login के लिए Supabase phone provider/SMS setup आवश्यक है।
- Nationwide enquiry स्वीकार है, लेकिन हर PIN Code में तुरंत सेवा उपलब्ध होने की गारंटी नहीं है।
- Razorpay Test Mode में end-to-end test अभी बाकी है।
- Production से पहले KYC, refund/dispute, privacy/terms और support प्रक्रिया पूरी करें।

## Current payment and electrician settlement status

- The current main branch uses the standard Razorpay Orders API for online customer payments and records electrician payout obligations in the database. It does **not** implement Razorpay Route linked-account transfers.
- Admin can record an actual UPI/bank payout reference after making the transfer outside the website; this workflow records the transfer and does not send money itself.
- This standard online-payment flow does not guarantee that customer funds avoid the merchant settlement account. It does not meet the owner's requirement that customer money must not enter an owner-controlled bank account. Keep live online payments and production launch blocked until Razorpay Route or another approved settlement arrangement is confirmed and end-to-end tested.
- Never mark a payout Paid before the actual transfer succeeds. No live payment or payout test is performed by this code.

## Phone visibility after booking assignment

- Before an electrician accepts an offer and the booking is assigned, customer and electrician phone numbers remain hidden from each other.
- After acceptance and assignment, the customer and assigned electrician may see each other's full mobile numbers and call directly. No OTP is required to reveal numbers after assignment.
- Admin may view both numbers. Keep all phone access restricted to authenticated, booking-scoped RPCs; never expose numbers in public pages, unassigned offers, search results, or unauthenticated APIs.
- Do not implement masked calling or Exotel GreenPin unless the owner changes this approved decision.
