# SRK ELECTRONIC — Master Product & Business Requirements
**दस्तावेज़ की स्थिति:** मुख्य आवश्यकता-स्रोत (Source of Truth)  
**संस्करण:** 1.0  
**अंतिम समेकन:** 13 नवम्बर 2026  
**लागू शाखा:** `feature/platform-fee-cash-online-cycle`  
**मुख्य Supabase प्रोजेक्ट:** `gnqhoaqatmoiwwhgzkgm`

> इस दस्तावेज़ में मालिक द्वारा बातचीत में स्वीकृत वर्तमान नियम एक जगह समेकित हैं। जहाँ नया नियम पुराने नियम से टकराता है, वहाँ नया नियम प्रभावी होगा। पुराने UI, API, RPC, database columns या migrations को केवल इस दस्तावेज़ के आधार पर अंधाधुंध delete नहीं करना है; पहले dependency, payment, refund, wallet, reporting और audit प्रभाव जाँचकर सुरक्षित migration बनानी है। यह दस्तावेज़ अपने-आप किसी feature के लागू होने का प्रमाण नहीं है।

## 0. निर्णयों की प्राथमिकता और कार्य-सीमा
1. यह दस्तावेज़ SRK ELECTRONIC की नई product/business requirements का मुख्य संदर्भ है।
2. पुराने quotation/inspection-first flow और masked-calling प्रस्ताव जैसे विरोधी नियम नीचे दिए गए नए निर्णयों से superseded हैं।
3. पुराने तकनीकी ढाँचे, डेटा और सुरक्षा नियंत्रणों को बिना audit नष्ट नहीं करना है।
4. इस समय यह requirements consolidation है; code, production database, payment provider या deployment में कोई बदलाव इस commit से नहीं किया जा रहा।
5. पहले Feature Branch पर implementation, dependency audit और परीक्षण; फिर मालिक की अलग अनुमति के बाद ही एक consolidated production deployment।
6. Netlify production deploy paused/credits exhausted होने की स्थिति को ध्यान में रखें। Razorpay Route/Test Mode या वास्तविक धन-हस्तांतरण का live परीक्षण बिना अलग अनुमति नहीं होगा।

## 1. ग्राहक का बुकिंग अनुभव
1. ग्राहक OTP से login करेगा। बुकिंग में वही OTP-verified registered mobile number स्वतः उपयोग होगा; ग्राहक से अलग editable phone number नहीं लिया जाएगा।
2. ग्राहक अपना नाम, पता/location, PIN code और काम का प्रकार/विवरण देगा।
3. ग्राहक काम के अनुसार electrician category चुनेगा और 1 से 8 घंटे तक अपेक्षित अवधि चुनेगा।
4. Smart Matching उपयुक्त category सुझा सकता है, लेकिन अंतिम category ग्राहक चुनेगा।
5. बुकिंग से पहले ग्राहक को category, चुनी अवधि, लागू rate और दिखाई जाने वाली अनुमानित रकम स्पष्ट दिखनी चाहिए।
6. ग्राहक Cash या Online में से उपलब्ध payment method चुनेगा। सिस्टम ग्राहक की चुनी method को चुपचाप दूसरी method में नहीं बदलेगा।
7. Inspection के लिए घर जाकर बाद में अलग quotation देने की प्रक्रिया समाप्त होगी। कोई electrician quotation submit नहीं करेगा और customer quotation approve/reject नहीं करेगा।
8. Booking केवल उसी category के verified, approved और available electrician(s) को जाएगी जिसे ग्राहक ने चुना है। दूसरी category में स्वतः downgrade/upgrade नहीं होगा।
9. उसी category में कई योग्य electricians हों तो निकटतम उपलब्ध electrician को पहले offer जाएगा। तय offer-window में स्वीकार न होने पर अगला निकटतम योग्य electrician लिया जाएगा। Single-winner acceptance और duplicate assignment रोकना आवश्यक है।
10. यदि उस category में कोई योग्य electrician उपलब्ध न हो तो ग्राहक को साफ बताया जाएगा; बिना अनुमति category नहीं बदली जाएगी।

## 2. Electrician categories और प्रकाशित 8-hour rates
सभी categories गाँव और शहर दोनों जगह उपलब्ध होंगी। स्थान के आधार पर category सीमित नहीं होगी। Category काम की जटिलता, verified skill, अनुभव और ग्राहक के budget पर आधारित होगी।

| Category | 8 घंटे का प्रकाशित rate | सामान्य काम का दायरा |
|---|---:|---|
| Electrical Assistant | ₹899 | पंखा/लाइट/LED fitting, switch/socket, छोटे घरेलू electrical repairs, minor wiring और basic cooler fitting/connection—केवल उतना काम जिसके लिए उसकी skill जाँची गई हो। |
| Skilled Electrician | ₹1,199 | घर की wiring, switchboard, कई fan/light fittings, inverter connection, MCB replacement/installation और सामान्य electrical faults। |
| Expert Electrician | ₹1,599 | full-home wiring, DB/MCB panel, short-circuit diagnosis/repair, motor/pump connections, AC electrical connections और बड़े घर/दुकान के काम। |
| Premium Electrical Specialist | ₹1,999 | बड़े residential/commercial electrical काम, complex faults, AC service/repair, cooler repair, fridge inspection/repair और specialist installations। |

- Assistant केवल helper नहीं है; सामान्य wiring/fitting भी कर सकता है, बशर्ते उसकी वास्तविक क्षमता verify हो।
- Refrigerant/gas work और sealed-system fridge repair केवल उपयुक्त रूप से trained specialist को दिया जाएगा।
- Admin documents, experience और practical skills देखकर category approve करेगा। केवल ऊँची category चुन लेने से complex work की पात्रता नहीं मिलेगी।
- Customer task scope देखकर सही category चुन सकेगा; जरूरत से कम category चुनने पर app warning/recommendation दिखाएगा।
- 8-hour rate से प्रति-मिनट दर का आधार निकलेगा: `category_8h_rate × actual_billable_minutes ÷ 480`। पैसे की अंतिम rounding/precision (पैसा तक या अन्य नियम) implementation से पहले तय करनी है; floating-point arithmetic का उपयोग नहीं करना है।
- ग्राहक 1–8 घंटे चुनता है, पर अंतिम मेहनताना वास्तविक server-recorded minutes पर आधारित होगा। चुनी अवधि से अधिक काम होने की स्थिति में timer वास्तविक समय रिकॉर्ड करेगा; overtime cap/approval UX का सटीक नियम अलग से स्पष्ट करना बाकी है।
- पहले दिखाई जाने वाली booking amount और actual-minute final amount के बीच UI में स्पष्ट अंतर दिखाना होगा; pre-booking amount estimate/selected-duration amount है या कोई cap/advance, इसे code में लागू करने से पहले मालिक से स्पष्ट करना है। कोई hidden labour charge नहीं।


## 2A. Electrician Panel में Net Rate List (15% Platform Fee के बाद)
1. Electrician के अपने dashboard/profile में उसकी approved category की rate list स्पष्ट दिखाई देगी।
2. Rate list में ग्राहक से लिया जाने वाला gross labour rate, 15% Platform Fee और Platform Fee काटने के बाद electrician का net labour share—तीनों अलग-अलग दिखेंगे।
3. मौजूदा 8-hour category rates के अनुसार उदाहरण:

| Approved category | Customer gross rate / 8h | 15% Platform Fee | Electrician net share / 8h |
|---|---:|---:|---:|
| Electrical Assistant | ₹899.00 | ₹134.85 | ₹764.15 |
| Skilled Electrician | ₹1,199.00 | ₹179.85 | ₹1,019.15 |
| Expert Electrician | ₹1,599.00 | ₹239.85 | ₹1,359.15 |
| Premium Electrical Specialist | ₹1,999.00 | ₹299.85 | ₹1,699.15 |

4. ये रकम 8-hour reference rates हैं। Actual work का final labour amount server timer के वास्तविक billable minutes के आधार पर निकलेगा; उसी actual labour amount पर 15% Platform Fee और 85% electrician share calculate होंगे।
5. Electrician को यह भी दिखेगा कि किसी booking में gross labour कितना बना, Platform Fee कितनी कटी, पुराने cash dues/अन्य अनुमत adjustments कितने समायोजित हुए और उसके payout/net payable में कितना बचा।
6. ग्राहक की rate list और electrician की net earning list अलग-अलग labels के साथ दिखाई जाएँगी। Electrician की net list को ग्राहक का rate बताकर नहीं दिखाना है।
7. गणना integer paise में होगी; displayed amounts दो decimal places तक होंगे। Platform Fee और electrician share का rounding एक ही server-side rule से होगा, जिससे दोनों का जोड़ gross labour amount के बराबर रहे।
8. Material/parts का कोई charge इस rate list या electrician labour share में शामिल नहीं होगा।

## 3. Electrician आवेदन, जाँच और डिजिटल ID
1. Electrician अपनी पसंद की category चुनकर आवेदन कर सकता है; यह केवल requested category होगी, approved category नहीं।
2. आवेदन में नाम, OTP-verified mobile, पता/कार्य क्षेत्र, अनुभव के वर्ष, काम/skills, पहचान दस्तावेज और योग्यता/प्रशिक्षण/अनुभव के प्रमाण माँगे जाएँ।
3. Admin दस्तावेज और skill/experience की जाँच करेगा और वास्तविक योग्यता के अनुसार एक approved category तय करेगा।
4. Approval से पहले electrician को काम/booking नहीं मिलेगी।
5. Approval के बाद unique SRK ELECTRONIC Electrician ID जारी होगी।
6. Digital ID/profile पर नाम, फोटो, unique ID, approved category, verified skills/experience और verification status दिखेगा।
7. Category बदलने/बढ़ाने के लिए पुनः review और Admin approval आवश्यक होगा; electrician स्वयं अपनी approved category नहीं बदल सकेगा।

## 4. Server-authoritative work timer और final labour charge
1. Timer मोबाइल/browser की local clock पर निर्भर नहीं होगा; start/end events और authoritative timestamps server पर दर्ज होंगे।
2. Electrician घर पहुँचकर **“काम शुरू करें”** दबाएगा। ग्राहक को start request जाएगी। ग्राहक Accept करेगा तभी server timer शुरू होगा।
3. काम पूरा होने पर electrician **“काम पूरा हुआ”** दबाएगा। ग्राहक को completion request जाएगी। ग्राहक Accept करेगा तभी timer बंद होगा।
4. Server start timestamp, completion-request timestamp, customer acceptance timestamp, actor और event history सुरक्षित रखेगा।
5. यदि ग्राहक completion request स्वीकार नहीं करता/उत्तर नहीं देता, तो मामला Admin review में जाएगा। Admin जाँचकर मंजूरी दे सकता है। ऐसी मंजूरी पर billing के लिए electrician की completion request server पर पहली बार प्राप्त होने का timestamp इस्तेमाल होगा—Admin के बाद के approval click का समय नहीं।
6. Admin override, request और approval का audit trail immutable/append-only होना चाहिए। कोई पक्ष मोबाइल clock बदलकर समय नहीं बदल सकेगा।
7. Final bill वास्तविक elapsed minutes पर बनेगा; 1 घंटा 17 मिनट = 77 मिनट। अधूरे घंटे को अगले पूरे घंटे में round-up नहीं करना है और कोई अतिरिक्त मिनट अपने-आप नहीं जोड़ना है।
8. Timer/charge calculation server-side और idempotent होगी; duplicate taps या retry से दोहरा समय/charge नहीं बनेगा।
9. Final amount ग्राहक को payment से पहले स्पष्ट दिखेगा।

## 5. Payment, Platform Fee और wallet
### 5.1 ग्राहक payment method
- Timer बंद/स्वीकृत होने और final amount बनने के बाद ग्राहक को उपलब्ध Cash और Online विकल्प दिखेंगे।
- ग्राहक उपलब्ध विकल्पों में से स्वयं चुनेगा; कोई silent switch नहीं।
- Online payment तभी सफल मानी जाएगी जब server-side provider signature/capture verification पूरा हो। Pending/Failed/Unverified online transaction रहते अगली booking electrician को offer नहीं होगी।
- Cash चुने जाने पर cash receipt confirmation की प्रतीक्षा के कारण अगली booking को block नहीं करना है; cash settlement/Platform Fee ledger अलग से संभाला जाएगा।
- Payment, booking और provider transaction IDs idempotently link होंगे; duplicate capture/recording रोकनी है।

### 5.2 Cash booking cycle
- Electrician के लिए एक cycle में पहली दो eligible bookings पर Cash उपलब्ध हो सकता है।
- तीसरी booking में Cash बंद और Online अनिवार्य होगा।
- यदि electrician के wallet/ledger में Platform Fee का बकाया है, तो Cash उपलब्ध नहीं होगा।
- Electrician Google Pay/PhonePe आदि से wallet top-up कर सकता है। केवल server/provider से सत्यापित top-up के बाद Platform Fee due समायोजित होगा।
- सत्यापित top-up से Cash cycle counter reset होगा; उसके बाद अगली दो eligible bookings में Cash फिर उपलब्ध हो सकता है, और तीसरी पर Online अनिवार्य होगा।
- केवल screenshot या user claim को top-up/payment proof नहीं मानना है।
- Booking counter और eligibility server-side, race-safe और transactionally reserved होनी चाहिए ताकि एक साथ आई pending offers नियम bypass न करें। Eligible booking की सटीक counting/locking implementation से पहले वर्तमान DB logic के साथ reconcile करनी है।

### 5.3 Platform Fee और सामग्री
- नाम केवल **Platform Fee** होगा; “SRK/SRA Commission” शब्द नहीं।
- Platform Fee labour/service charge का 15% है।
- ग्राहक सामग्री/parts स्वयं उपलब्ध कराएगा। Electrician का labour amount और material charge कभी मिलाए/छिपाए नहीं जाएँगे।
- Customer booking flow में materials option/charge नहीं होगा। Electrician labour/service ही देगा।
- यदि सामग्री की अलग व्यवस्था कभी आवश्यक हो, तो अलग itemized bill और ग्राहक की पूर्व स्वीकृति जरूरी होगी; unauthorized markup/charge नहीं।
- Cash booking की Platform Fee देनदारी wallet ledger में सुरक्षित और idempotent होगी। पुराने cash dues केवल निर्धारित labour/service share से settle हों; materials से नहीं।
- Online booking में Platform Fee और electrician payout अलग ledger entries हों। Payout Paid तभी हो जब वास्तविक transfer सफल हो और reference दर्ज हो।
- Cash payment के कारण अगली booking को online verification की तरह block न करें; लेकिन Platform Fee due होने पर cash eligibility रोकने वाला नियम लागू रहेगा।

## 6. Cancellation policy और carry-forward dues
1. Customer और electrician स्वयं booking cancel/finalize नहीं कर सकते। Cancellation का अंतिम निर्णय केवल Admin करेगा।
2. Customer app में **Cancel Booking** button दबाएगा तो request सीधे Admin Dashboard में जाएगी।
3. Electrician self-cancel नहीं करेगा; cancellation की जरूरत हो तो Admin/support workflow में मामला भेजेगा।
4. Admin request के समय electrician की सत्यापित स्थिति के अनुसार customer cancellation fee तय करेगा:
   - Electrician घर से निकला नहीं: ₹0
   - रास्ते में है: ₹49
   - ग्राहक के घर पहुँच चुका है: ₹99
5. Status evidence (arrival/travel events, timestamps, location where permitted) और Admin decision का audit record रखना है।
6. Cancellation fee customer की देनदारी होगी; customer wallet balance हो या न हो, fee waive नहीं होगी।
7. Unpaid cancellation fee अगली customer booking के bill में जुड़ जाएगी। कई unpaid cancellation fees हों तो सभी अलग-अलग line items के रूप में जुड़ेंगी। पुराना बकाया और नई service fee अलग दिखेंगे।
8. यदि अगली booking Online paid हो, तो cancellation-fee हिस्सा सीधे SRK ELECTRONIC के cancellation-fee ledger/account में जाएगा; service labour और cancellation fee अलग दर्ज हों।
9. यदि अगली booking Cash हो, तो customer total cash electrician को देगा और cancellation-fee के बराबर रकम electrician wallet से debit/negative ledger में जाएगी, ताकि SRK की देनदारी दर्ज हो। Cash और wallet ledger एक ही transaction में consistent/idempotent हों।
10. उदाहरण: ₹500 service + ₹49 prior cancellation fee = ₹549 total. Online में ₹49 SRK cancellation-fee component; Cash में ₹549 electrician को, और electrician wallet में ₹49 debit.
11. Cancellation fee को Platform Fee या service labour revenue में मिलाना नहीं है; अलग accounting head रहेगा।
12. Refund, fee payer exceptions, duplicate cancellation, dispute और failed payment cases को implementation से पहले policy/RPC स्तर पर जाँचना है; Admin बिना reason के fee बदल न सके।

## 7. Phone-number visibility and privacy
1. Customer का OTP-verified number स्वतः booking में उपयोग होगा; editable arbitrary number नहीं।
2. Assigned electrician booking accept कर ले, उसके बाद customer को उसी assigned electrician का पूरा mobile number और direct call option दिखेगा।
3. काम completed होते ही customer view से electrician number हर जगह हटेगा: dashboard, booking detail/history, receipt, invoice, downloadable/printed receipt और अन्य screens।
4. यह केवल UI hide नहीं होगा; completed booking के बाद customer-facing API/RPC payload में भी electrician phone वापस नहीं आना चाहिए।
5. पुराने approved rule के अनुसार assigned/approved electrician को accepted booking के दौरान customer का booking phone दिख सकता है। Public pages, unassigned offers, search results और unauthenticated APIs में किसी का phone नहीं दिखना चाहिए।
6. Masked-calling/Exotel GreenPin अभी implement नहीं करना है; मौजूदा direct-call rule लागू होगा। यह नियम पहले के masked-calling proposal को supersede करता है।

## 8. Help, complaints, communication और ratings
### 8.1 Customer और electrician Help
- Customer और electrician दोनों के अलग Help & Support entry points होंगे।
- लिखित complaint/message, category/subject, detailed text, आवश्यक photo/document attachment, submission status और reference number उपलब्ध हों।
- Admin को अलग Customer Support और Electrician Support inbox मिलें।
- Admin लिखित reply दे सके; user replies, full conversation history, timestamps और status (new/in progress/resolved/closed) दिखें।
- Customer/electrician अपनी पुरानी शिकायत, Admin reply और resolution देख सकें।
- Complaint hearing/resolution और escalation का audit trail रहे।

### 8.2 Two-way ratings
- काम/booking complete होने के बाद customer electrician को और electrician customer को 1–5 star rating दे सके।
- Written review और उपयुक्त dimensions (काम की quality, समयपालन, व्यवहार/सहयोग, payment/communication) दिए जा सकते हैं।
- प्रति booking प्रत्येक पक्ष की एक rating; केवल वास्तविक booking पर।
- Average rating profile पर दिखे।
- Admin abusive/fraudulent review की जाँच कर सकता है; review हटाने/छिपाने की कार्रवाई reason और audit trail के साथ हो। वैध आलोचना को मनमाने ढंग से न हटाएँ।

## 9. Admin Panel और Company Operations
### 9.1 Company Expenses
- सभी कंपनी खर्चे private/authorized database में सुरक्षित हों: date, category, description, amount, receipt/document, entered_by और audit timestamps.
- Expense add/edit (जहाँ अनुमति हो), list, monthly/yearly reports और totals।
- Revenue, Platform Fee, cancellation fees, electrician payouts, expenses और net profit/loss अलग accounting heads हों; double-count न हो।
- Finance/expense data केवल authorized roles को दिखे।

### 9.2 Main Admin और Authorized Staff
- Main Admin सर्वोच्च और non-delegable authority है। कोई staff Main Admin role/permissions प्राप्त या बदल नहीं सकता।
- Preset staff roles उपलब्ध हों: Customer Support, Electrician Support, Booking Manager, Electrician Verification, Finance/Payment, Complaint Manager आदि।
- Main Admin custom role बना सके और individual permissions भी दे सके।
- Permission levels: View, Add, Edit, Manage; module-wise permissions अलग हों—customers, electricians, bookings, cancellation, verification, payments, wallet, complaints, ratings, expenses, reports, staff, settings.
- Staff को केवल granted permissions वाला dashboard/module दिखे और backend/API/RLS भी वही enforce करे; केवल UI hiding पर्याप्त नहीं।
- Main Admin staff add, activate/deactivate, suspend, permissions edit/revoke और sessions revoke कर सके।
- Staff अपने permissions नहीं बढ़ा सकेगा और दूसरे staff को अधिकार नहीं दे सकेगा।
- Staff-to-staff access default से सीमित हो; जरूरत हो तो Main Admin explicit permission दे।
- Staff communication: internal written messages, announcements, task assignment और notifications।
- Staff login/activity history: login/logout times, session duration, failed login attempts, device/browser, IP/security metadata (privacy/legal limits के अनुसार), और महत्वपूर्ण actions का audit log।
- Main Admin daily tasks, responsibilities, deadlines, reminders और task status (Pending/In Progress/Completed) assign/monitor कर सके।
- Staff performance reports task completion और response/activity data पर आधारित हों; केवल online time को productivity का अकेला माप न मानें।

### 9.3 Main Admin Master Dashboard
एक जगह पर summary और drill-down:
- Customers/new customers
- Electricians, category, verification/approval status
- Bookings: pending, offered, accepted, in progress, completed, cancelled
- Timer and actual minutes
- Gross labour, Platform Fee, cancellation-fee collections/due
- Online/Cash payments, pending/failed/verified transactions
- Electrician wallet dues/top-ups/payouts
- Company expenses, profit/loss
- Complaints, ratings/reviews
- Staff tasks, login/activity and performance
- Reports by date/category/area/status with role-based access

### 9.4 Emergency Control Panel
केवल Main Admin:
- New bookings pause/resume
- किसी electrician account को temporarily block/unblock
- Online payments temporarily pause/resume (पहले से authorized payment reconciliation और customer communication सहित)
- suspicious customer/electrician account restrict/unrestrict
- whole service pause/resume
- हर action के लिए reason, actor, timestamp, scope और audit log; accidental lockout से बचने के लिए confirmation/recovery guardrails।

### 9.5 Full Booking History
Main Admin को हर booking का timeline और linked evidence दिखे:
- customer and booking details
- offer recipients, delivery/accept/reject/expiry
- assigned electrician and acceptance
- travel/arrival state
- start request, customer acceptance, server timer start
- completion request, customer acceptance या Admin review/override
- actual minutes and final charge calculation
- payment method, provider transaction ID, verification status
- Platform Fee, cancellation fee, wallet entries, payout
- receipt, ratings, complaints, cancellation/refund events
- हर बदलाव का actor, timestamp और before/after audit record
पुराने records को staff/admin सामान्य UI से delete या silently edit नहीं कर सकेगा।

## 10. सुरक्षा, audit और data integrity
- RLS और server-side authorization सभी private/customer/electrician/admin data पर लागू होंगे।
- Price, timer, payment, wallet, cancellation, category eligibility और staff permission का authoritative निर्णय server-side होगा।
- Payment/timer/wallet/cancellation operations transactional और idempotent हों।
- Sensitive data least-privilege से उपलब्ध हो; secrets browser/GitHub में नहीं।
- Admin/staff actions audit log में; financial ledger append-only या reversal-based हो, historical rows silently rewrite नहीं।
- Customer/electrician phone concealment API/RPC स्तर पर हो।
- गलत PIN/district जैसे data inconsistencies स्वतः overwrite न हों; review queue में जाएँ।

## 11. पुराने नियमों में स्पष्ट supersession
नीचे के पुराने flow/निर्णय अब लागू नहीं होंगे:
1. Electrician पहले घर जाकर inspection करे और उसके बाद अलग quotation दे — **हटाया गया**।
2. Customer quote approve/reject करे — **हटाया गया**।
3. Quote approval के बिना payment/booking lifecycle न चले — **नए timer-based actual-minute billing और payment rules से superseded**।
4. Masked calling/Exotel GreenPin और दोनों असली नंबर हमेशा छिपाने वाला प्रस्ताव — **नया direct-call-after-acceptance और customer-side post-completion concealment rule लागू**।
5. किसी category के न मिलने पर अपने-आप दूसरी category में भेजना — **अनुमति नहीं**।
6. Customer या electrician को स्वतंत्र cancellation अधिकार — **अनुमति नहीं; Admin-only cancellation**।
7. Service labour में materials/parts मिलाना या hidden material markup — **अनुमति नहीं**।

यह सूची पुराने database columns, functions या migration files को तत्काल delete करने की अनुमति नहीं है। पहले सभी consumers और accounting/refund dependencies map करें; फिर सुरक्षित staged migration करें।

## 12. Implementation से पहले खुले निर्णय (बिना पुष्टि अनुमान न लगाएँ)
1. 8-hour rate से actual-minute total की अंतिम monetary rounding precision।
2. Customer द्वारा चुनी 1–8 घंटे की अवधि estimate, cap, या booking commitment है? वास्तविक काम अवधि उससे आगे जाए तो क्या customer approval/extension चाहिए?
3. Booking screen पर pre-booking price को estimate/selected-duration amount के रूप में कैसे label करना है, ताकि actual-minute final amount से भ्रम न हो।
4. Customer completion request accept न करे तो Admin review की SLA, evidence standard और customer dispute/appeal path।
5. Cash-cycle counter में eligible booking की exact definition और concurrent offer reservation—वर्तमान DB implementation से मिलाकर final करना।
6. Cancellation fee cash route में wallet debit और online route में SRK collection का exact settlement/reversal/refund handling।
7. Travel/en-route status और arrival proof के authoritative signals।
8. Staff login/IP/device retention duration, data access and privacy controls।
9. Ratings visibility, reply window and appeal/moderation workflow।
10. Help response SLA/escalation policy।

## 13. वर्तमान implementation status / deployment guardrails
- यह document requirements का consolidated source है; इसमें लिखी किसी feature को implemented/verified न मानें।
- Quote/inspection removal, category/duration selection, Smart Matching, server timer, minute billing, electrician digital ID, cancellation carry-forward, two-way ratings, Help messaging, staff RBAC, Master Dashboard और Emergency Control को implementation तथा tests चाहिए।
- वर्तमान branch पर पहले read-only technical audit करें: frontend pages, Netlify functions, Supabase RPC/functions/triggers, tables, RLS, payment webhook, manual payment, wallet, payout, refund, reports.
- Quote-related columns/functions को dependency mapping और migration plan के बिना drop न करें।
- Work केवल Feature Branch पर; `main` merge, production database migration, Netlify deployment या live payment action अलग explicit approval के बिना नहीं।
- पहले unit/integration/security/payment/timer/wallet/cancellation tests, फिर end-to-end staging/Test Mode verification, फिर consolidated deployment plan।
- कोई भी feature “complete” तभी कहा जाए जब code, DB policy, UI, API/RPC, regression tests और relevant end-to-end behavior verify हो।
