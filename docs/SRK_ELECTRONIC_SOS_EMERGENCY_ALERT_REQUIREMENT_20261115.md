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
यह दस्तावेज़ स्वीकृत आवश्यकता दर्ज करता है, लागू feature का प्रमाण नहीं है। अभी कोई SOS UI, SMS, Push, database workflow या live notification चालू होने का दावा नहीं किया जा रहा।


## 2026-11-15 — Accidental SOS prevention (user-approved)
- Active Work screen पर SOS बटन काम शुरू होने के बाद से काम पूरा/बुकिंग रद्द होने तक उपलब्ध रहेगा।
- केवल SOS बटन छूने से alert नहीं भेजा जाएगा। पहला tap तीन स्वीकृत SOS कारण दिखाएगा।
- उपयोगकर्ता एक कारण चुनेगा; फिर अलग स्पष्ट “SOS भेजें” बटन दबाने पर ही emergency request बनेगी और Admin/authorized Support को भेजी जाएगी।
- कारण चुने बिना या अंतिम “SOS भेजें” दबाए बिना कोई alert, SMS या case create नहीं होगा। स्क्रीन बंद/वापस जाने पर अधूरा चयन discard होगा।
- तीन कारणों के अलावा कोई नया कारण या अतिरिक्त user-entered booking/details/location field नहीं जोड़ा जाएगा। Booking/order और actor विवरण सिस्टम authenticated session/active booking से server-side निकालेगा; उपलब्ध location केवल अनुमति/उपलब्धता के अनुसार ली जाएगी, और location न होने पर SOS भेजना block नहीं होगा।
- यह UX नियम स्वीकृत है; source implementation और runtime verification अभी बाकी हैं।
