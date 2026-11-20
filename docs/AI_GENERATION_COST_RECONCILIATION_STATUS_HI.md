# SRK ELECTRONIC — AI Generation Cost Reconciliation

**स्थिति:** Feature Branch पर source और tests जोड़े गए; live/deployed नहीं  
**तारीख:** 20 नवंबर 2026

## 1. क्या जोड़ा गया

- `supabase/functions/ai-generation-cost-reconcile/index.ts`: disabled-by-default Supabase Edge Function; Gateway generation ID से per-request cost lookup करता है।
- `netlify/functions/reconcile-ai-generation-costs.js`: हर 2 मिनट scheduled dispatcher; केवल `AI_COST_RECONCILIATION_ENABLED=true` पर call करता है।
- `supabase/migrations/20261118360000_ai_generation_cost_reconciliation_worker.sql`: atomic claim, two-minute lease, `FOR UPDATE SKIP LOCKED`, attempt fencing, bounded exponential retry और terminal unavailable status।
- `supabase/functions/_shared/ai-generation-cost.mjs`: USD cost parsing; missing cost को zero नहीं मानता, generation ID mismatch और invalid/overflow values अस्वीकार करता है।
- `tests/ai-generation-cost.test.js`: explicit zero, positive cost, missing cost, mismatched generation ID और invalid values के tests।
- `supabase/tests/database/ai_generation_cost_reconciliation.test.sql`: private table, service-role-only RPC, RLS, claim fencing और finish checks के pgTAP assertions।
- Deno type-check workflow जोड़ा गया।

## 2. सुरक्षित व्यवहार

- Generation ID नहीं हो तो पुरानी queue entry unavailable रहती है; कोई cost अनुमान नहीं लगाया जाता।
- Gateway usage ingestion देर से हो तो 404 सहित lookup failure retry होता है।
- केवल matching generation ID के साथ explicit `total_cost` / `totalCost` स्वीकार होता है।
- Explicit numeric zero स्वीकार है; missing field zero नहीं बनता।
- Stale worker का finish lease/attempt count से reject होता है।
- Worker और Netlify dispatcher दोनों default OFF हैं।
- Netlify dispatcher Supabase Edge Function call पर service-role JWT और अलग worker-secret दोनों भेजता है।
- कोई user prompt, reply या conversation text cost job में नहीं रखा जाता।

## 3. अभी क्या प्रमाणित है

- Deno type-check workflow: सफल run #44742944827, commit `5db041879069dbc2828d760eb69e0bfec6b024ea`।
- Feature Branch Node tests: सफल run #44742955096, commit `01cbd6a90915cdc649f1dc52dd9ad3d38ffd6a1b`। इसमें छोटे USD costs, missing cost और generation ID matching के tests शामिल हैं।
- Full migration replay, AI idempotency pgTAP, Rate List snapshot और Rate Catalogue pgTAP workflows commit `20698868b8afa8f33469c86b8868d847d48d49cb` पर चल रहे हैं; अंतिम परिणाम अभी pending है।

## 4. INR conversion — आधिकारिक FX स्रोत का सुधार

पहले की योजना में RBI daily USD/INR rate कहा गया था। यह नाम सही नहीं है: RBI ने 2018 में USD/INR reference-rate publication FBIL को सौंप दी थी। FBIL 10 जुलाई 2018 से USD/INR reference rate प्रकाशित करता है। इसलिए भविष्य के INR ledger में source **FBIL USD/INR Reference Rate** होना चाहिए, RBI rate नहीं।

- Source: FBIL official website — https://www.fbil.org.in/
- RBI handover confirmation: https://www.rbi.org.in/commonPerson/english/Scripts/PressReleases.aspx?Id=3111
- IMF metadata FBIL को daily USD/INR reference-rate publisher बताता है और benchmark methodology/dissemination का सार देता है: https://dsbb.imf.org/sdds/dqaf-base/country/IND/category/EXR00

हर FX snapshot में rate value, rate date, source name/URL और retrieval timestamp सुरक्षित रखना होगा। Weekend/Mumbai holiday के लिए पिछली उपलब्ध FBIL business-day rate का नियम स्पष्ट रूप से लागू होगा। कोई rate hardcode नहीं होगी।

## 5. अभी शेष कार्य

1. pgTAP migration replay/test run का अंतिम परिणाम देखना और किसी failure को ठीक करना।
2. FBIL reference rate को भरोसेमंद तरीके से ingest करने का तरीका तय करना; वेबसाइट की उपलब्धता/format की जाँच के बिना scraping/API मानकर नहीं चलना।
3. FX snapshot table और service-role-only insert/read RPC जोड़ना।
4. USD cost × captured FBIL USD/INR rate से exact INR cost निकालना; original USD, FX rate, rate date, source और INR amount सब संरक्षित हों।
5. इसके बाद अलग काम के रूप में ₹20 daily / ₹500 monthly atomic reservation guard लागू करना — लेकिन अभी नहीं, जब तक उपयोगकर्ता स्पष्ट रूप से budget implementation की अनुमति न दे।

## 6. सुरक्षा सीमा

कोई migration hosted Supabase पर लागू नहीं हुई। Edge Function deploy नहीं हुई। Netlify schedule deploy नहीं हुआ। कोई live Gateway call या live AI call नहीं हुई। `AI_GATEWAY_ENABLED`, `AI_COST_RECONCILIATION_ENABLED` और `AI_HANDOFF_PUSH_ENABLED` को enable नहीं किया गया। Budget limits अभी केवल planning हैं।
