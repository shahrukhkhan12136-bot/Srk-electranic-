# SRK ELECTRONIC — Netlify + Supabase + Razorpay

यह repository SRK ELECTRONIC की वेबसाइट और electrician booking marketplace के लिए है। वर्तमान deployment target Netlify है।

## मुख्य पेज
- `/` — Customer Login (`/customer-login.html`) पर redirect
- `/booking.html` — Customer Dashboard, सेवा बुकिंग और अकाउंट
- `/admin.html` — Admin / Support Staff portal
- `/electrician.html` — Electrician Partner phone OTP portal

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
- Electrician offer push notifications और durable delivery/retry का source implementation मौजूद है; इससे Production provider delivery चालू होने की पुष्टि नहीं होती। Main Supabase schema parity, worker/provider integration और वास्तविक delivery verification अभी अलग release gates हैं।
- SMS/WhatsApp alert delivery को स्वचालित/सक्रिय न मानें; OTP login के लिए Supabase phone provider और SMS configuration आवश्यक है।
- Nationwide enquiry स्वीकार है, लेकिन हर PIN Code में तुरंत सेवा उपलब्ध होने की गारंटी नहीं है; offer dispatch केवल eligible/available electrician मिलने पर आगे बढ़ता है।
- Razorpay payment/refund के source workflows मौजूद हैं; Test Mode और isolated end-to-end provider verification अभी बाकी है।
- Feature Branch के नए Customer profile/address/support, immutable labour bill, cancellation-fee, refund-recovery और durable Push schema को Main Supabase में उपलब्ध मानने से पहले migration parity verify करें। वर्तमान Main DB में इनमें से कई नए objects अभी अनुपस्थित हैं।
- Browser/mobile visual QA, isolated database actor/ownership tests और final release/owner approval अभी अलग चरण हैं। Feature Branch source या CI success को Production readiness न समझें।

## Manual electrician payouts (UPI / Bank)
- Automatic Razorpay Route transfers are not required for the current manual payout workflow.
- After a customer's Razorpay payment is server-verified and the booking is completed, quote-approved, and assigned, the database creates a pending electrician payout ledger row using that booking's commission rate.
- An authorized Admin makes the actual UPI or bank transfer outside the website, then records the UTR / UPI reference in `/admin.html`. The website only records the transfer; it does not send money.
- The electrician can see their own pending/paid payout status and recorded reference in `/electrician.html`. RLS restricts payout rows to the owning electrician and authorized admins.
- Never mark a payout Paid before the actual transfer succeeds. No automatic payout or real-money test is performed by this code.

## Customer / Electrician phone visibility — owner-approved rule

- Before an electrician accepts an offer, the customer and electrician must not see each other's phone numbers.
- Once the electrician accepts/receives the booking, both parties may see each other's full, unmasked mobile numbers and call directly.
- No additional OTP is required to reveal the numbers after acceptance.
- Admin may see both full numbers. Support Staff must not receive unrestricted private phone projections.
- Phone access must remain scoped to the authenticated booking owner, the assigned/accepted electrician, and authorized Admin workflows. Never expose numbers on public pages, unassigned offers, search results, or unauthenticated APIs.

This rule supersedes the older masked-calling / Exotel notes and the intermediate wording that said only "assigned booking".