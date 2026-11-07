# SRK ELECTRONIC — Vercel पर Publish करने का तरीका

यह पैकेज Netlify के बदले Vercel के लिए तैयार किया गया है। वेबसाइट के Razorpay और Supabase API routes `/api/...` पर ही रहेंगे।

## 1. ZIP तैयार करें
ZIP को Extract करें। Vercel में पूरा Extract किया हुआ project folder upload/import करें; सिर्फ `index.html` या `api` folder अकेले upload न करें।

## 2. Vercel पर नया Project
1. https://vercel.com पर अपने ईमेल से Sign up / Log in करें।
2. Dashboard में **Add New → Project** चुनें।
3. यदि GitHub से जोड़ना नहीं चाहते, तो Vercel CLI या समर्थित Dashboard upload flow से पूरा project deploy करें। यदि स्क्रीन पर केवल Git import दिखे, तो GitHub repository बनाकर इस folder की सभी files उसमें upload करें और फिर Import करें।
4. Framework Preset: **Other** रखें। Root Directory project का यही folder हो। Build Command खाली/None और Output Directory खाली रखें; Vercel static files और `/api` functions अपने-आप पहचानता है।
5. Deploy दबाएँ।

## 3. Environment Variables (बहुत जरूरी)
Vercel Project → Settings → Environment Variables में ये चार नाम जोड़ें:
- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Values अपने Razorpay और Supabase Dashboard से लें। Service Role Key और Razorpay Secret किसी को न भेजें, चैट में भी नहीं। इन्हें वेबसाइट के HTML या `srk-config.js` में न डालें। Variables जोड़ने के बाद Redeploy करें।

## 4. Supabase
यदि पहले से इसी project का Supabase database और tables बने हुए हैं, तो वही credentials इस्तेमाल करें। नया database न बनाएँ। Tables/policies पहले configure न हों तो project के SQL setup documents को सही क्रम में चलाना होगा।

## 5. Test
पहले Razorpay Test Mode keys से test करें। Test payment, booking submission, electrician application और admin login जाँचें। Live Mode तभी चालू करें जब Razorpay account/site approval और सभी tests पूरे हों।

## जरूरी जानकारी
- यह Netlify की credit limit को bypass करने के लिए अलग hosting है; Vercel पर भी usage limits लागू हो सकती हैं।
- Netlify account या पुरानी website delete न करें। नई Vercel website ठीक चलने और domain switch होने तक पुरानी सुरक्षित रखें।
- Custom domain बाद में Vercel Project → Settings → Domains में जोड़ा जा सकता है।
- इस ZIP में Netlify के मूल handlers सुरक्षित रखे गए हैं और Vercel `/api` adapters जोड़े गए हैं।
