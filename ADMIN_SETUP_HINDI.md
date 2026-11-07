# SRK ELECTRONIC — Admin Email Login Setup (Hindi)

## इस अपडेट में क्या बदला
- Admin पेज अब Supabase email + password से लॉगिन करता है (SMS OTP नहीं)।
- लॉगिन के बाद `is_srk_admin()` से Admin allow-list की जाँच होती है।
- Admin booking/application/profile tables के लिए RLS policies और application-review RPC जोड़े गए हैं।

## लागू करने के चरण
1. ZIP को extract करें।
2. Supabase Dashboard → SQL Editor खोलें।
3. `ADMIN_EMAIL_LOGIN_SETUP.sql` की पूरी सामग्री एक बार चलाएँ।
4. SQL के अंतिम परिणाम में वही User ID दिखनी चाहिए जो Authentication → Users में आपके बनाए user की UID है।
5. `admin.html` को `/admin.html` पर वेबसाइट में deploy करें। `srk-config.js` में केवल Supabase URL और publishable key रखें। Secret/service_role key कभी ब्राउज़र में न रखें।
6. वेबसाइट पर `https://YOUR-SITE/admin.html` खोलें और उसी Auth email/password से लॉगिन करें।

## महत्वपूर्ण
- Admin record पहले से मौजूद होना चाहिए। इस प्रोजेक्ट में अपेक्षित Auth UID: `3fa1af52-2223-4203-b43d-ebd4798f8f17`। SQL चलाने के बाद अंतिम SELECT से पुष्टि करें।
- `is_srk_admin()` को SQL Editor में सीधे चलाने पर `false` आ सकता है, क्योंकि SQL Editor में सामान्य browser user session/auth.uid() सेट नहीं होता। असली जाँच वेबसाइट में लॉगिन के बाद होती है।
- यह पैकेज अपने-आप Netlify पर deploy नहीं होता। Netlify पर Production deploys paused होने के कारण deploy फिर शुरू करना होगा (billing/operational credits reset या Netlify की उपलब्ध resume/upgrade प्रक्रिया)।
- पहले से मौजूद Netlify Functions और Razorpay secrets को जस का तस रखें। कोई secret key ZIP या frontend में न डालें।
- आवेदन approve होने पर electrician profile inactive बनेगी; KYC/manual verification के बाद ही Admin उसे activate करे।
- कमीशन रिपोर्ट अभी completed bookings के `commission_amount` पर आधारित है; payment settlement/payout integration अलग काम है।
