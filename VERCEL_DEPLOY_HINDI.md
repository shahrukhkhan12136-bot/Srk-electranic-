# SRK ELECTRONIC — अंतिम Vercel सेटअप (हिंदी)

## पैकेज में क्या तैयार है
- ग्राहक बुकिंग और इलेक्ट्रिशियन आवेदन Supabase में सेव होते हैं।
- PIN Code में पहले approved + active पार्टनर को job offer; वहाँ कोई न हो तो उसी राज्य/जिले में fallback।
- Admin panel: `/admin.html`; electrician portal: `/electrician.html`।
- Razorpay INR order सर्वर पर बनता है; signature + captured status जाँचने के बाद booking को `paid` किया जाता है।
- ग्राहक का पूरा पता/फोन electrician को केवल job accept करके assign होने के बाद दिखता है।

## 1) GitHub पर अपलोड और Vercel Import
1. ZIP को Extract करें। अंदर `srk_migrate` folder की सभी files repository के root में रखें (folder के अंदर का content, nested folder नहीं)।
2. GitHub में नया खाली repository बनाकर सभी extracted files upload/commit करें।
3. Vercel में **Add New → Project → Import Git Repository** चुनें और वही repository Import करें।
4. Framework: **Other**; Root Directory: repository root; Build Command खाली; Output Directory खाली; फिर Deploy।

## 2) Vercel Environment Variables
Project → Settings → Environment Variables में ये चार variables जोड़ें:
- `SUPABASE_URL` = `https://gnqhoaqatmoiwwhgzkgm.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY` = Supabase Dashboard से service_role/secret key (केवल Vercel में; चैट या HTML में कभी नहीं)
- `RAZORPAY_KEY_ID` = Razorpay Test Mode Key ID
- `RAZORPAY_KEY_SECRET` = Razorpay Test Mode Secret (केवल Vercel में)
फिर **Redeploy** करें। Live keys तभी लगाएँ जब merchant KYC और website approval पूरे हों।

## 3) Supabase SQL — एक ही बार
Supabase → SQL Editor → New query में `COMPLETE_DATABASE_SETUP.sql` की पूरी सामग्री चलाएँ। यह base schema, portal access, privacy rules, admin email login और payment tracking को सही क्रम में सेट करता है। पुराने data को drop नहीं करता।

## 4) Admin account
1. Supabase Authentication में Email provider चालू करें और अपना admin email/password user बनाएँ।
2. Authentication → Users से उस user का UUID कॉपी करें।
3. SQL Editor में चलाएँ (UUID बदलें):
   `insert into public.srk_admin_users(user_id) values ('YOUR_AUTH_USER_UUID') on conflict do nothing;`
4. `/admin.html` पर उसी email/password से login करें।

## 5) Electrician OTP
Supabase Authentication → Phone provider चालू करें और SMS provider configure/test करें। OTP SMS provider की availability/charges पर निर्भर है। Admin आवेदन approve करे, identity/skill जाँचे, फिर partner को Active करे। Partner उसी आवेदन वाले verified mobile number से `/electrician.html` पर OTP login करे।

## 6) जरूरी परीक्षण
- एक test booking बनाएं और देखें कि `service_bookings` में row बनी।
- test electrician application approve करके profile Active करें।
- उसी PIN code से test booking करें; `job_offers` में offer बनना चाहिए। दो electricians हों तो एक accept करे; दूसरे offer expire होने चाहिए।
- Razorpay Test Mode payment करें; `payment_status` केवल server verification के बाद `paid` होना चाहिए।
- Admin panel और electrician portal अलग-अलग login से जाँचें।

## सीमाएँ जो अभी account setup पर निर्भर हैं
- वास्तविक push/SMS/WhatsApp job alerts इस build में configured नहीं हैं; offer portal में दिखाई देता है और refresh/polling से देखा जा सकता है। SMS OTP के लिए Supabase phone provider जरूरी है।
- हर PIN code में सेवा तभी उपलब्ध होगी जब वहाँ verified/approved/active electrician हो।
- Standard Razorpay Checkout अपने-आप electrician payout split नहीं करता। Marketplace split settlement, GST/invoices, refunds और कानूनी terms अलग से configure होंगे।
- यह ZIP खुद से आपके GitHub/Vercel account में publish नहीं हो सकता। GitHub/Vercel login और private secrets केवल account owner ही सेट कर सकता है।
