# SRK ELECTRONIC — Admin और Electrician Login

**मुख्य सेटअप के लिए `VERCEL_DEPLOY_HINDI.md` पढ़ें और केवल `COMPLETE_DATABASE_SETUP.sql` एक बार चलाएँ।** नीचे portal का व्यवहार है:

- `admin.html`: Supabase email/password से Admin login, booking management, electrician application approval, partner activation, commission summary.
- `electrician.html`: आवेदन में दिए verified mobile पर Supabase SMS OTP, अपने PIN/district के job offers, Accept/Decline.
- ग्राहक का नाम, फोन और पूरा पता केवल उसी electrician को मिलता है जिसे job assign हुआ है।
- एक job पर पहला valid accept सफल होता है; बाकी offers expire हो जाते हैं।

## चालू करने के जरूरी account steps
1. Supabase Authentication में Email provider enable करके अपना admin user बनाएं।
2. Authentication → Users से UUID लेकर `srk_admin_users` में डालें; exact SQL `VERCEL_DEPLOY_HINDI.md` में है।
3. Supabase Phone provider और SMS provider configure/test करें। SMS charges लागू हो सकते हैं।
4. Admin application approve करे। Profile अपने verified phone से link होगी; documents/skills की manual जाँच के बाद ही Active करें।
5. Electrician `/electrician.html` पर वही mobile number डालकर OTP login करे।

## लॉन्च से पहले जाँच
- दो approved electricians से एक ही PIN code की test booking पर offers verify करें।
- पहला accept करे तो दूसरे का offer expire होना चाहिए।
- Assigned electrician को ही ग्राहक का फोन और पूरा पता दिखना चाहिए।
- अनधिकृत account booking/application/provider records न पढ़ सके।
- Razorpay Test Mode payment verify करके database में `payment_status='paid'` देखें।

SMS/Push/WhatsApp job alerts इस package में अभी configured नहीं हैं; offers portal में उपलब्ध होंगे। Marketplace payout split, GST/invoices, refunds, legal terms और KYC अलग से configure/test करने होंगे।
