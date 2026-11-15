# SRK ELECTRONIC — SOS तत्काल सहायता आवश्यकता
तारीख: 15 नवम्बर 2026
स्थिति: आवश्यकता उपयोगकर्ता द्वारा स्वीकृत; GPT-1 में दो-चरणीय UI source update किया गया है। Backend integration और runtime verification अभी बाकी हैं।

## स्वीकृत निर्देश
उपयोगकर्ता का स्पष्ट आदेश: SOS सुविधा दर्ज की जाए। SOS अलर्ट Admin/मालिक और अधिकृत Support Staff तक पहुँचे; पुलिस को ऐप की ओर से स्वतः कोई संदेश, कॉल या रिपोर्ट न भेजी जाए।

## GPT-1 UI integration contract (Feature Branch source)
- Customer और Electrician App में दो-चरणीय SOS UI जोड़ा गया: पहला tap केवल तीन कारण दिखाता है; कारण चुनने के बाद अलग “SOS भेजें” बटन सक्रिय होता है। Client `srk_create_sos_alert` को केवल `p_reason` भेजता है; booking/actor पहचान और समय backend को authenticated session/active booking से derive करना होगा।
- Client SOS request में booking ID, अतिरिक्त विवरण या location input नहीं भेजता। उपलब्ध/consented location का सुरक्षित server-side integration GPT-2 backend contract में तय और सत्यापित होना बाकी है।
- UI केवल confirmed success और case_id मिलने पर केस दर्ज दिखाता है; अन्यथा सफलता का दावा नहीं करता।
- GPT-2 को इसी RPC, booking/actor authorization, Admin/Support queue, SMS/Push delivery status और audit workflow को implement करना होगा। जब तक backend RPC उपलब्ध और सत्यापित न हो, SOS delivery की सफलता का दावा नहीं होगा।

## अपेक्षित व्यवहार
1. Customer App और Electrician App में स्पष्ट SOS / तत्काल सहायता बटन उपलब्ध हो।
2. SOS दबाने पर एक emergency case बने और Admin Panel तथा Support Staff Panel में तुरंत दिखाई दे।
3. उपयोगकर्ता के Admin मोबाइल पर SMS अलर्ट भेजने का प्रयास हो; Push Notification भी उपलब्ध हो तो भेजी जाए।
4. पुलिस/112/किसी बाहरी सरकारी एजेंसी को ऐप से स्वतः कॉल, SMS या सूचना न भेजी जाए। व्यक्ति स्वयं जरूरत पड़ने पर 112 पर कॉल कर सकता है।
5. अलर्ट में booking ID, SOS दबाने वाले पक्ष की भूमिका, नाम/संपर्क विवरण, समय, कारण/चुना गया खतरा और उपलब्ध/अनुमत लोकेशन शामिल हों।
6. लोकेशन केवल अधिकृत Admin और Support Staff को दिखे; न्यूनतम आवश्यक डेटा ही साझा हो।
7. SOS केस तब तक Pending/Awaiting Acknowledgement रहे जब तक Admin या अधिकृत Support Staff उसे स्वीकार न करे। स्वीकार करने वाले का नाम/ID और समय दर्ज हो।
8. केस की पूरी append-only activity/audit history सुरक्षित रहे; कौन-सी कार्रवाई कब हुई, दर्ज हो।
9. SOS विकल्पों में कम-से-कम: ग्राहक को खतरा, इलेक्ट्रिशियन को खतरा, मारपीट/अन्य आपात स्थिति।
10. SMS/Push delivery असफल होने, नेटवर्क न होने या नंबर/configuration अनुपलब्ध होने पर UI में झूठा “भेज दिया” न दिखे; delivery status और retry/fallback व्यवहार स्पष्ट हो।

## सुरक्षा और संचालन सीमाएँ
- SOS को वास्तविक दुनिया की लड़ाई/खतरे का स्वतः पता लगाने वाला feature न बताया जाए; यह user-triggered alert है।
- SOS अलर्ट केवल Admin और अधिकृत Support Staff को जाए; पुलिस को स्वतः नहीं।
- Admin SMS नंबर को सुरक्षित configuration से जोड़ा जाए; नंबर की पुष्टि और SMS provider/खर्च की मंजूरी implementation से पहले आवश्यक हो सकती है।
- लोकेशन अनुमति न हो तो SOS फिर भी भेजा जा सके; location unavailable स्पष्ट दिखे।
- False alarm/cancel प्रक्रिया, acknowledgement SLA, escalation policy, data retention और SMS provider details अभी तय/सत्यापित होने बाकी हैं।

## GPT जिम्मेदारी
- GPT-1: Customer App और Electrician App में SOS trigger/UI, user-facing status और integration contract।
- GPT-2: Admin/Support queues, database schema/RPC, permissions/audit, SMS provider/backend delivery और operational configuration।
- दोनों पक्षों के बीच end-to-end integration आवश्यक। किसी भी Production बदलाव/deployment से पहले अलग मंजूरी आवश्यक।

## सत्यापन स्थिति
यह दस्तावेज़ स्वीकृत आवश्यकता और नीचे दर्ज GPT-1 source implementation/Node-test evidence दोनों को दर्ज करता है। UI source में SOS flow मौजूद है; इससे वास्तविक database workflow, SMS/Push delivery या live notification चालू होने का दावा नहीं किया जाता।


## 2026-11-15 — Accidental SOS prevention (user-approved)
- Active Work screen पर SOS बटन काम शुरू होने के बाद से काम पूरा/बुकिंग रद्द होने तक उपलब्ध रहेगा।
- केवल SOS बटन छूने से alert नहीं भेजा जाएगा। पहला tap तीन स्वीकृत SOS कारण दिखाएगा।
- उपयोगकर्ता एक कारण चुनेगा; फिर अलग स्पष्ट “SOS भेजें” बटन दबाने पर ही emergency request बनेगी और Admin/authorized Support को भेजी जाएगी।
- कारण चुने बिना या अंतिम “SOS भेजें” दबाए बिना कोई alert, SMS या case create नहीं होगा। स्क्रीन बंद/वापस जाने पर अधूरा चयन discard होगा।
- तीन कारणों के अलावा कोई नया कारण या अतिरिक्त user-entered booking/details/location field नहीं जोड़ा जाएगा। Booking/order और actor विवरण सिस्टम authenticated session/active booking से server-side निकालेगा; उपलब्ध location केवल अनुमति/उपलब्धता के अनुसार ली जाएगी, और location न होने पर SOS भेजना block नहीं होगा।
- यह UX नियम स्वीकृत है; source implementation और runtime verification अभी बाकी हैं।


## 2026-11-15 — GPT-1 source implementation status
- Customer App और Electrician App के SOS controls Active Work card के भीतर रखे गए हैं; UI condition केवल `in_progress` booking पर है।
- दोनों ऐप में केवल तीन स्वीकृत reason codes और अलग final “SOS भेजें” action है; cancel/back करने पर चयन discard होता है।
- RPC call केवल `p_reason` भेजती है; booking/actor identity client से नहीं भेजी जाती।
- पुराने static/support-page SOS controls और पुराने duplicate handlers हटाए गए हैं।
- Source-level Node test assertions को नए handler locations के अनुसार सुधारा गया है।
- यह source-level implementation है; CI run #43725977680 cancelled हुआ और उसके test step में failure दर्ज है। बाद के commits पर नई CI सफलता अभी प्रमाणित नहीं है।
- PR changed-file inventory में अभी SOS backend migration/RPC, Admin/Support queue या SMS/Push delivery implementation नहीं मिला। इसलिए end-to-end SOS alert delivery अधूरी और GPT-2 backend work पर निर्भर है।
- कोई database migration apply नहीं की गई; production deploy/merge नहीं किया गया।

- Follow-up correction: पिछली CI log में stale `customerSosBooking` selector reference customer support booking loader में मिला था। उसे हटाया गया; सामान्य support booking selector सुरक्षित है और SOS flow Active Work card से चलता है।
- Commit `bf765ca26f47e020817362243131d8da3db5e73e` के workflow run `43726275569` को rerun किया गया। Latest attempt में job `132849770691` सफल रहा: **163/163 Node tests पास, 0 failed, 0 cancelled**। इसमें SOS दो-चरणीय UI contract test भी शामिल है।
- Customer/Electrician source में पुराने SOS booking/details selector references नहीं मिले। यह source/Node-contract verification है; browser/mobile runtime QA अभी अंतिम consolidated QA चरण के लिए स्थगित है।
- Backend RPC, Admin/Support queue, SMS/Push delivery और live end-to-end SOS अभी GPT-2 integration पर निर्भर हैं; इन्हें पूर्ण घोषित नहीं किया गया।


## 2026-11-15 — GPT-1 और GPT-2 SOS integration handoff स्थिति
- वर्तमान Customer/Electrician files में SOS का दो-चरणीय flow source स्तर पर मौजूद है: कारण चयन, अलग final send, cancel पर discard, और reason-only `srk_create_sos_alert` RPC call। Active Work visibility `in_progress` booking से gated है।
- Latest recorded Node CI verification: 163/163 tests पास; यह browser/mobile runtime या backend delivery का प्रमाण नहीं है।
- इस verification pass में उपलब्ध source evidence से GPT-2 के backend RPC, Admin/Support queue, SMS/Push provider delivery और acknowledgement flow का runtime सत्यापन नहीं हुआ। इनका काम GPT-2 ownership में pending माना जाएगा, जब तक संबंधित migration/RPC/UI/CI evidence उपलब्ध न हो।
- GPT-1 की अगली integration gate: GPT-2 backend contract/commit उपलब्ध होने पर RPC signature, response fields, failure states और case ID handling को source-level पर मिलाना; फिर अंतिम consolidated browser/mobile/E2E QA।
- Production DB, SMS provider, merge/deploy या mobile QA नहीं किया गया।
