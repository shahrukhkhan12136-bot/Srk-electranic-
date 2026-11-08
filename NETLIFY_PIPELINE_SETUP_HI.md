# SRK ELECTRONIC — Netlify pipeline patch (Phase 1)

## यह patch क्या करता है
- Netlify को बताता है कि वेबसाइट की static files repository root से publish हों।
- Serverless functions `netlify/functions` से चलें।
- मौजूदा frontend के `/api/...` endpoints को Netlify Functions से जोड़ता है।
- Node.js 20 और Razorpay dependency के लिए root `package.json` का उपयोग करता है।

## लगाने का तरीका (GitHub मोबाइल ऐप/ब्राउज़र)
1. पहले repository का backup/ZIP डाउनलोड रखें।
2. इस ZIP को extract करें।
3. इसके अंदर का `netlify.toml` repository के root में upload करें।
4. `netlify` folder को repository के root में upload करें; उसके अंदर `functions` folder और चार JS files होंगी।
5. मौजूदा `index.html`, `admin.html`, `electrician.html`, `package.json`, root handlers और `srk-config.js` को delete या replace न करें।
6. GitHub commit करें। कोई existing file overwrite करने की जरूरत नहीं है; ये नई files हैं।
7. Netlify में site के Deploys tab पर जाकर deploy status देखें।

## Netlify Environment Variables
Netlify → Site configuration → Environment variables में ये variables server-side set होने चाहिए:
- `SUPABASE_URL` = `https://gnqhoaqatmoiwwhgzkgm.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY` = Supabase का service-role secret (इसे केवल Netlify में डालें; किसी को चैट/कोड में न भेजें)
- `RAZORPAY_KEY_ID` = Razorpay Test Mode key ID
- `RAZORPAY_KEY_SECRET` = Razorpay Test Mode secret

`SUPABASE_SERVICE_ROLE_KEY` और `RAZORPAY_KEY_SECRET` को `srk-config.js`, HTML, GitHub या ग्राहक के browser में कभी न रखें।

## जरूरी रोक
- इस patch में website source या database schema शामिल नहीं है; यह केवल Netlify routing/deployment config है।
- यह अभी live deploy नहीं करता।
- Netlify account पर credits/deploy block हो तो deploy तब तक नहीं होगा जब तक account issue ठीक न हो।
- Phase 2 में booking API और database trigger के दोहरे job-offer creation को ठीक से reconcile करना बाकी है।
- Deploy के बाद test booking/payment किए बिना production-ready न मानें।
