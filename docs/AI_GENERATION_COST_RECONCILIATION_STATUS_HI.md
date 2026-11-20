# SRK ELECTRONIC — AI Generation Cost Reconciliation

**स्थिति:** Feature Branch पर source और tests जोड़े गए; live/deployed नहीं  
**तारीख:** 20 नवंबर 2026

## 1. क्या जोड़ा गया

- `supabase/functions/ai-generation-cost-reconcile/index.ts`: disabled-by-default Supabase Edge Function; Gateway generation ID से per-request cost lookup करता है।
- `netlify/functions/reconcile-ai-generation-costs.js`: हर 2 मिनट scheduled dispatcher; केवल `AI_COST_RECONCILIATION_ENABLED=true` पर call करता है।
- `supabase/migrations/20261118360000_ai_generation_cost_reconciliation_worker.sql`: atomic claim, two-minute lease, `FOR UPDATE SKIP LOCKED`, attempt fencing, bounded exponential retry, terminal unavailable status और Gateway generation timestamp।
- `supabase/migrations/20261118370000_ai_fbil_usd_inr_fx_snapshots.sql`: append-only FBIL rate snapshots, official-domain validation और generation के समय तक प्रकाशित नवीनतम rate से USD→INR conversion।
- `supabase/functions/_shared/ai-generation-cost.mjs`: USD cost और generation timestamp parsing; missing cost को zero नहीं मानता, generation ID mismatch और invalid/overflow values अस्वीकार करता है।
- `tests/ai-generation-cost.test.js`: explicit zero, positive cost, missing cost, mismatched generation ID और invalid values के tests।
- `supabase/tests/database/ai_generation_cost_reconciliation.test.sql`: private table, service-role-only RPC, RLS, claim fencing और finish checks के pgTAP assertions।
- `supabase/tests/database/ai_fbil_usd_inr_fx_snapshots.test.sql`: FX snapshot privacy, append-only guard, official FBIL source validation और INR conversion के pgTAP assertions।
- Deno type-check workflow जोड़ा गया।

## 2. सुरक्षित व्यवहार

- Generation ID नहीं हो तो पुरानी queue entry unavailable रहती है; कोई cost अनुमान नहीं लगाया जाता।
- Gateway usage ingestion देर से हो तो 404 सहित lookup failure retry होता है।
- केवल matching generation ID के साथ explicit `total_cost` / `totalCost` और valid generation timestamp स्वीकार होते हैं।
- Explicit numeric zero स्वीकार है; missing field zero नहीं बनता।
- Stale worker का finish lease/attempt count से reject होता है।
- Worker और Netlify dispatcher दोनों default OFF हैं।
- Netlify dispatcher Supabase Edge Function call पर service-role JWT और अलग worker-secret दोनों भेजता है।
- कोई user prompt, reply या conversation text cost job में नहीं रखा जाता।

## 3. अभी क्या प्रमाणित है

- Deno type-check workflow: सफल run #44743676819, commit `2204e2247610c09f706334fc515568ccc63223f8`।
- Feature Branch Node tests: सफल run #44743676839, उसी commit पर; इसमें explicit zero, छोटे USD decimal, matching generation ID और timestamp parsing शामिल हैं।
- Full migration replay और नया 27-assertion FBIL FX pgTAP run अभी pending/in progress हैं; अंतिम SQL प्रमाण अभी उपलब्ध नहीं है।

## 4. INR conversion — आधिकारिक FX स्रोत का सुधार

पहले की योजना में RBI daily USD/INR rate कहा गया था। यह नाम सही नहीं है: RBI ने 2018 में USD/INR reference-rate publication FBIL को सौंप दी थी। FBIL 10 जुलाई 2018 से USD/INR reference rate प्रकाशित करता है। इसलिए भविष्य के INR ledger में source **FBIL USD/INR Reference Rate** होना चाहिए, RBI rate नहीं।

- Source: FBIL official website — https://www.fbil.org.in/
- RBI handover confirmation: https://www.rbi.org.in/commonPerson/english/Scripts/PressReleases.aspx?Id=3111
- IMF metadata FBIL को daily USD/INR reference-rate publisher बताता है और benchmark methodology/dissemination का सार देता है: https://dsbb.imf.org/sdds/dqaf-base/country/IND/category/EXR00

हर FX snapshot में rate value, rate date, source name/URL, publication timestamp और retrieval timestamp सुरक्षित रखना होगा। Conversion RPC केवल वही नवीनतम FBIL rate चुनता है जो उस generation के timestamp तक प्रकाशित हो चुकी थी; इससे weekend/Mumbai holiday और दोपहर 1 बजे से पहले/बाद की generation में rate गलत तारीख से नहीं लगेगी। कोई rate hardcode नहीं होगी।

## 5. FBIL data licensing — automatic ingestion पर रोक

FBIL के आधिकारिक FAQ के अनुसार USD/INR Reference Rate एक significant benchmark है। FBIL के benchmark data का उपयोग pricing, loan servicing, valuation और समान उद्देश्यों में करने पर End-User License/fees लागू हो सकते हैं; बिना registration/license के उपयोग को unauthorized बताया गया है। इसलिए केवल वेबसाइट पर rate दिखाई देने के आधार पर उसे SRK ELECTRONIC के server में स्वतः scrape या store करना उचित नहीं होगा।

- FBIL FAQ: https://www.fbil.org.in/uploads/FAQ_s_updates_30th_Nov_2023_edited_version_1def7b65bb.pdf
- FAQ में registration process और fees के बारे में: पहले registration, फिर FBIL license agreement/quotation; registration form भरना निःशुल्क है।
- कोई FBIL subscription, API/SFTP access या paid data service इस समय खरीदी/मांगी/कनेक्ट नहीं की गई है।
- इसलिए अभी कोई automatic FBIL fetcher नहीं जोड़ा जाएगा। पहले FBIL से लिखित रूप में पूछना होगा कि internal AI service-cost accounting के लिए कौन-सा license/permission लागू होता है और क्या API/SFTP access उपलब्ध है। कोई शुल्क हो तो उपयोगकर्ता की अलग मंजूरी जरूरी होगी।
- यदि FBIL license जरूरी हो या बजट के अनुकूल न हो, तो उपयोगकर्ता की मंजूरी से वैकल्पिक permitted FX source या वास्तविक INR billing/settlement amount के आधार पर cost accounting चुना जाएगा। FX unavailable होने पर अनुमानित रुपये नहीं लिखे जाएंगे।

## 6. अभी शेष कार्य

1. नए timestamp-aware cost worker और FBIL FX migrations के pgTAP replay/test परिणाम देखना और failure ठीक करना।
2. FBIL से usage-license/API/SFTP संबंधी लिखित पुष्टि का रास्ता तय करना; तब तक automatic scraping/fetching बंद रहेगी।
3. स्वीकृत data source मिलने पर rate-date, publication-time, weekend/holiday selection और INR conversion का integration test करना।
4. इसके बाद अलग काम के रूप में ₹20 daily / ₹500 monthly atomic reservation guard लागू करना — लेकिन अभी नहीं, जब तक उपयोगकर्ता स्पष्ट रूप से budget implementation की अनुमति न दे।

## 7. सुरक्षा सीमा

कोई migration hosted Supabase पर लागू नहीं हुई। Edge Function deploy नहीं हुई। Netlify schedule deploy नहीं हुआ। कोई live Gateway call या live AI call नहीं हुई। `AI_GATEWAY_ENABLED`, `AI_COST_RECONCILIATION_ENABLED` और `AI_HANDOFF_PUSH_ENABLED` को enable नहीं किया गया। Budget limits अभी केवल planning हैं।
