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

## Manual electrician payouts (UPI / Bank)
- Automatic Razorpay Route transfers are not required for the current manual payout workflow.
- After a customer's Razorpay payment is server-verified and the booking is completed, quote-approved, and assigned, the database creates a pending electrician payout ledger row using that booking's commission rate.
- An authorized Admin makes the actual UPI or bank transfer outside the website, then records the UTR / UPI reference in `/admin.html`. The website only records the transfer; it does not send money.
- The electrician can see their own pending/paid payout status and recorded reference in `/electrician.html`. RLS restricts payout rows to the owning electrician and authorized admins.
- Never mark a payout Paid before the actual transfer succeeds. No automatic payout or real-money test is performed by this code.

## Masked calling and phone privacy

- Customer and electrician phone numbers are not displayed to the other party in the customer/electrician dashboards or the corresponding contact RPC results.
- Direct phone-call buttons remain disabled until a compliant two-way masked-calling provider is enabled and end-to-end tested.
- The current provider candidate is Exotel Lead Assist (GreenPin): it supports virtual-number proxy calling and PIN verification, but it is an account-level feature that Exotel must enable and it uses separate credentials. Do not add provider credentials to GitHub or browser code.
- Before a call can start from a different mobile device, the caller must enter their registered account number and complete OTP ownership verification. Merely typing a number must never authorize a call.
- Until provider activation, both parties' real numbers remain hidden and calling is unavailable through the platform.


## Updated phone visibility decision (2026-11-09)
The owner has changed the calling requirement: do **not** implement masked calling or Exotel GreenPin for now. For an assigned booking, the customer may see the assigned electrician's phone number and use a direct Call button; the assigned, approved electrician may see the customer's booking phone number and use a direct Call button. Phone numbers must remain restricted to the authenticated booking owner / assigned electrician through the existing booking-scoped RPCs. Do not expose phone numbers in public pages, unassigned offers, search results, or unauthenticated APIs. This decision supersedes the earlier masked-calling requirement above.
