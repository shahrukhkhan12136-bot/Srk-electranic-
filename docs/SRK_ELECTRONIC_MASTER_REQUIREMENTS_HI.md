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

## 1A. Customer App के 5 मुख्य मेनू
ग्राहक ऐप की bottom navigation में पाँच मुख्य मेनू इसी क्रम में होंगे:
1. **Home:** इलेक्ट्रिशियन बुक करें, पता/लोकेशन चुनें, काम/category और अपेक्षित अवधि चुनें, उपलब्धता/अनुमानित रकम देखें।
2. **My Bookings:** नई और पुरानी bookings, Pending/Accepted/In Progress/Completed status, live work timer, completion confirmation, bill और cancellation request status।
3. **Payments:** Cash/Online payment, payment history, booking-wise bill/receipt और payment status।
4. **Help & Support:** complaint/message, photo/document attachments, Admin replies, complaint status और history।
5. **My Profile:** नाम/photo, OTP-verified registered mobile, saved addresses/location, ratings/reviews, notifications, privacy/security और logout।

Home screen पर प्रमुख **“इलेक्ट्रिशियन बुक करें”** action साफ और आसानी से उपलब्ध होगा। ये पाँच मुख्य navigation items हैं; इनके अंदर आवश्यक sub-screens हो सकते हैं।

### Electrician location और live tracking
- ग्राहक को electrician का निजी घर/निवास पता कभी नहीं दिखेगा।
- Booking स्वीकार/assign होने के बाद, जब electrician ग्राहक के पते की ओर रवाना हो, customer को booking screen पर उसकी live location/map और उपलब्ध होने पर अनुमानित पहुँचने का समय (ETA) दिखेगा।
- Live location केवल संबंधित accepted booking के लिए और यात्रा/arrival तक सीमित होगी; booking cancel/close होने या electrician के ग्राहक के स्थान पर पहुँचने पर यात्रा tracking स्वतः बंद होगी। काम के दौरान अलग tracking की आवश्यकता हो तो उसके लिए स्पष्ट अनुमति और अलग नियम चाहिए—इसे स्वतः चालू न करें।
- Location permission बंद/अनुपलब्ध हो तो customer को साफ status दिखे; नकली या पुरानी location को live न बताएं।
- Location access केवल संबंधित customer, assigned electrician और अधिकृत Admin तक सीमित हो; अन्य customers/electricians को location न मिले।
- Location events/time का सीमित audit आवश्यक है; retention अवधि और background tracking व्यवहार implementation से पहले privacy/security review में तय होंगे।

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


## 2A. Electrician Panel की Rate List (केवल Electrician को मिलने वाली रकम)
1. Electrician के अपने dashboard/profile में उसकी approved category की rate list स्पष्ट दिखाई देगी।
2. Electrician की इस rate list में **केवल Platform Fee घटाने के बाद मिलने वाली final रकम** दिखाई जाएगी। इसमें Platform Fee का नाम, प्रतिशत, कटौती की रकम या ग्राहक का gross rate नहीं दिखाया जाएगा।
3. मौजूदा 8-hour category rates के अनुसार electrician को मिलने वाली रकम:

| Approved category | Electrician payable rate / 8h |
|---|---:|
| Electrical Assistant | ₹764.15 |
| Skilled Electrician | ₹1,019.15 |
| Expert Electrician | ₹1,359.15 |
| Premium Electrical Specialist | ₹1,699.15 |

4. ये रकम 8-hour reference rates हैं। Actual work का final labour payable server timer के वास्तविक billable minutes के आधार पर निकलेगा।
5. Electrician की rate list से अलग, booking/payment statement में उसके gross labour, लागू deductions/पुराने cash dues/अन्य अनुमत adjustments और final payout/net payable का हिसाब दिखाया जा सकता है; लेकिन **Rate List में Platform Fee का विवरण नहीं होना चाहिए**।
6. ग्राहक की rate list और electrician की net payable rate list अलग-अलग रहेंगी। Electrician की net list को ग्राहक का rate बताकर नहीं दिखाना है।
7. गणना integer paise में होगी और displayed amounts दो decimal places तक होंगे। Backend में gross amount, Platform Fee और electrician share का हिसाब सुरक्षित/सही रहेगा, भले ही Platform Fee electrician की Rate List में प्रदर्शित न हो।
8. Material/parts का कोई charge इस rate list या electrician labour payable में शामिल नहीं होगा।

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


## 14. Complete Platform Checklist — कोई सुविधा छूटनी नहीं चाहिए
यह checklist requirements, implementation, QA और release sign-off के लिए है। हर item के साथ owner, status, test evidence और release status track होगा। यहाँ दर्ज होना implementation पूरा होने का प्रमाण नहीं है।

### 14.1 Customer App और Website
- [ ] OTP login: expiry, resend cooldown/limits, wrong-attempt limits, abuse/rate limiting, secure session और logout।
- [ ] पाँच मुख्य मेनू: Home, My Bookings, Payments, Help & Support, My Profile।
- [ ] Booking form: verified mobile (editable नहीं), नाम, address, map pin, PIN/district/state, work description, category और 1–8 घंटे।
- [ ] PIN/district validation: authoritative PIN directory, mismatch warning/review queue; existing address स्वतः overwrite नहीं।
- [ ] Category, rate, duration और estimate का स्पष्ट विवरण; estimate और final actual-minute bill अलग।
- [ ] Submit confirmation, terms/fee disclosure और duplicate-submit protection।
- [ ] Booking timeline: pending/offers/accepted/en route/arrived/start approval/in progress/completion review/payment/closed।
- [ ] Accepted booking में assigned electrician का direct-call number; completion के बाद customer-facing UI/API/receipt/history में phone अनुपलब्ध।
- [ ] यात्रा के दौरान live location/ETA; permission-denied और stale-location states; arrival/cancel/close पर tracking बंद।
- [ ] Timer, completion approval और dispute/Admin review।
- [ ] Bill, receipt, payment history, cancellation request/fee और पुराने dues अलग line items।
- [ ] Help ticket, attachments, reference number, reply thread, status और history।
- [ ] Ratings/reviews, notification preferences, saved addresses, profile/photo और account security।
- [ ] Loading/empty/offline/error/retry states, accessibility, स्पष्ट हिंदी, responsive UI और low-bandwidth व्यवहार।

### 14.2 Electrician App / Portal
- [ ] OTP login, verified mobile, secure session/logout और account status।
- [ ] Application, documents, experience, skills, service area, requested/approved category और unique digital ID।
- [ ] स्पष्ट navigation/dashboard: Home, New Booking Offers, My Bookings/Work, Earnings & Wallet, Profile/ID, Help & Support (अंतिम labels UI review में confirm)।
- [ ] Offer details: काम, category, approximate location/distance, duration/estimate और expiry; acceptance से पहले privacy-safe सीमित जानकारी।
- [ ] Accept/decline/expiry, next eligible offer, single-winner assignment और simultaneous acceptance tests।
- [ ] Accepted booking के दौरान ही customer phone का अनुमत access; public/unassigned context में नहीं।
- [ ] यात्रा/arrival status, location permission, ETA और tracking stop।
- [ ] Work-start request, customer approval, server timer, completion request और dispute/Admin review।
- [ ] Rate List में approved category की केवल net payable 8-hour reference amount; Platform Fee विवरण नहीं।
- [ ] Actual minutes, gross labour, Platform Fee, wallet dues/adjustments और net payable अलग statement; materials labour में नहीं।
- [ ] Cash/Online eligibility, cash-cycle status, Platform Fee due और verified top-up history।
- [ ] Payout status, provider reference जहाँ उचित हो, failed/reversed payout और support path।
- [ ] Help tickets, customer ratings/reviews, electrician द्वारा customer rating और booking history।
- [ ] Suspension/restriction, document re-verification और notification preferences।

### 14.3 Admin Panel और Company Operations
- [ ] Main Admin secure login, MFA/strong authentication विकल्प, session list/revoke और recovery controls।
- [ ] Customer/electrician/booking/address/PIN mismatch और verification management।
- [ ] Category/skill/document approval या rejection reason सहित।
- [ ] Offer queue, assignment, timeline, exceptions और duplicate/race protection visibility।
- [ ] Cancellation inbox, evidence, policy-based fee decision, reason, customer communication और dispute trail।
- [ ] Timer/completion dispute review; Admin override reason, evidence और immutable audit।
- [ ] Payment/provider events, refunds, wallet ledger, top-ups, cash dues, payout और reconciliation views।
- [ ] Support inbox, ticket assignment, replies, SLA/escalation और attachment access controls।
- [ ] Rating moderation with reason, audit and appeal path।
- [ ] Expense entry, receipt, permitted approval, accounting heads, exports और period reports।
- [ ] Staff roles, granular permissions, least privilege और backend/RLS enforcement।
- [ ] Staff tasks, internal communication, login/activity history, suspicious-login handling और session revocation।
- [ ] Dashboard metrics की स्पष्ट definitions, filters, drill-down और role-based exports।
- [ ] Emergency controls: confirmation, reason, audit, recovery safeguards और post-action reconciliation।
- [ ] सभी महत्वपूर्ण Admin/staff actions का actor, timestamp, before/after और reason audit।

### 14.4 Payment, Razorpay, Wallet और Accounting
- [ ] Razorpay Test Mode integration और webhook signature verification; duplicate/out-of-order webhook idempotency।
- [ ] Order, payment, booking और provider transaction IDs का सुरक्षित linkage।
- [ ] Created/pending/authorized/captured/failed/refunded/disputed जैसे payment states का स्पष्ट mapping।
- [ ] Online payment success केवल server-verified capture/signature के बाद।
- [ ] Cash confirmation, electrician cash collection acknowledgement और cash ledger reconciliation।
- [ ] Platform Fee 15% केवल labour पर; material/parts को fee base या electrician labour payout में शामिल नहीं करना।
- [ ] Wallet top-up केवल provider-verified; screenshot/manual claim से balance credit नहीं।
- [ ] Cash-cycle eligibility/reservation concurrency-safe; failed/expired/cancelled bookings का counter प्रभाव लिखित रूप से तय।
- [ ] Payout initiation, success/failure, retries, reversal और provider reference; Paid status केवल verified transfer पर।
- [ ] Refund/partial refund/duplicate payment/chargeback/dispute और cancellation-fee reversal के स्पष्ट workflows।
- [ ] Gross labour, Platform Fee, cancellation fees, electrician payable, wallet liabilities, refunds, expenses और net profit अलग ledgers।
- [ ] Daily settlement/reconciliation report और unmatched transaction exception queue।
- [ ] Live payments/transfers केवल अलग approval, provider readiness और production checklist के बाद।

### 14.5 Notifications और Communication
- [ ] Push notification permission, token registration/rotation/revocation और logout/device lifecycle।
- [ ] Booking created, offer/acceptance, electrician en route/arrival, start approval, timer/completion, payment/refund और cancellation updates।
- [ ] Help ticket received, Admin reply, status change और escalation notifications।
- [ ] Notification delivery failure, retry, deduplication और in-app notification inbox।
- [ ] SMS/OTP/push provider failure पर स्पष्ट fallback और user-facing status; secrets client में नहीं।
- [ ] Notification content में अनावश्यक personal data, पूरा पता या payment secrets नहीं।

### 14.6 Security, Privacy और Data Governance
- [ ] सभी private tables/storage objects पर RLS और server-side authorization; role/ownership negative tests।
- [ ] OTP abuse protection, rate limits, session expiry/revocation और brute-force safeguards।
- [ ] Secrets केवल सुरक्षित server environment में; repository, client bundle और logs में secrets/PII नहीं।
- [ ] Customer/electrician phone और location API/RPC स्तर पर least-privilege।
- [ ] Upload validation: file type/size, malware scanning जहाँ उपलब्ध, private storage और signed access।
- [ ] Audit logs tamper-resistant; financial ledgers append-only/reversal-based।
- [ ] Data retention/deletion/export, consent, privacy notice और grievance contact policy लागू करने से पहले legal/privacy review।
- [ ] Location collection केवल approved booking purpose और अवधि तक; access audit और retention limit।
- [ ] Staff IP/device metadata का न्यूनतम संग्रह, सीमित access और निर्धारित retention।
- [ ] Dependency/security scanning, vulnerable package review और incident response procedure।

### 14.7 Backup, Reliability और Recovery
- [ ] Database backup schedule, retention और encryption की पुष्टि।
- [ ] Restore drill: backup से अलग सुरक्षित environment में वास्तविक restore test और evidence।
- [ ] Recovery Point Objective (RPO) और Recovery Time Objective (RTO) तय और दर्ज।
- [ ] Provider outage, webhook delay, network failure और partial transaction recovery runbooks।
- [ ] Monitoring/alerts: API errors, failed jobs, payment mismatch, queue backlog, suspicious access और service health।
- [ ] Emergency pause के बाद safe resume checklist और pending booking/payment reconciliation।

### 14.8 QA, Accessibility और Release Sign-off
- [ ] Unit tests: pricing/minute calculation, fee split, cash-cycle, cancellation, wallet और permissions।
- [ ] Integration tests: frontend/API/RPC/database/webhooks/storage/notifications।
- [ ] End-to-end tests: customer booking से electrician assignment, work timer, completion, payment, receipt और rating तक।
- [ ] Negative/security tests: unauthorized access, phone/location leakage, RLS bypass, duplicate requests और race conditions।
- [ ] Payment Test Mode cases: success, failure, pending, duplicate webhook, refund, payout failure और reconciliation।
- [ ] Device/browser tests: Android के प्रमुख screen sizes, mobile browsers और desktop responsive layout।
- [ ] Accessibility, readable Hindi, contrast, touch targets, keyboard navigation और clear error messages।
- [ ] Performance/load tests और slow/intermittent network tests।
- [ ] Staging/UAT sign-off, known-issues list, rollback plan और production readiness checklist।
- [ ] सभी migrations reversible/forward-safe योजना के साथ; schema drift और existing data compatibility audit।
- [ ] एक consolidated production deployment; अलग स्पष्ट अनुमति के बिना main merge, production DB migration, live payment या deploy नहीं।

## 15. अतिरिक्त खुले निर्णय और release blockers
नीचे के विषयों पर implementation से पहले निर्णय/प्रमाण आवश्यक हैं; checklist इन्हें स्वतः तय नहीं करती:
1. PIN/district के लिए authoritative source और mismatch correction का approval owner।
2. Electrician offer expiry duration, retry/offer sequence और electrician द्वारा decline करने के प्रभाव।
3. Electrician app के अंतिम menu labels तथा earnings/payout statement का exact format।
4. Push/SMS/OTP providers, delivery fallback, notification retention और खर्च सीमा।
5. OTP/MFA/session security thresholds और account recovery verification।
6. Refund, chargeback, payout retry/reversal और cancellation-fee reversal की accounting policy।
7. Backup frequency/retention, RPO/RTO और restore test cadence।
8. Privacy notice, consent, data retention/deletion और grievance/legal review।
9. Monitoring alert recipients, incident severity और response SLA।
10. QA acceptance thresholds, supported devices/browsers और release sign-off authority।

हर checkbox को implementation के दौरान evidence सहित complete mark करना है। बिना test evidence के checkbox complete नहीं माना जाएगा।


## 16. Public Website / Landing Page — न्यूनतम और साफ़ डिज़ाइन
- [ ] Public landing page पर केवल SRK ELECTRONIC का आधिकारिक लोगो, एक उच्च-गुणवत्ता वाली उपयुक्त मुख्य फोटो और उपलब्ध/वास्तविक panels के प्रवेश विकल्प दिखें।
- [ ] Landing page पर केवल तीन login विकल्प हों: **Customer Login**, **Electrician Login**, और **Admin Login**।
- [ ] कुल login प्रकार/भूमिकाएँ **3 (तीन)** हैं; लोगो और फोटो login नहीं हैं। कोई चौथा login विकल्प न दिखाया जाए।
- [ ] हर login अपने अलग role-based सुरक्षित authentication और सही dashboard/panel पर जाए; URL बदलकर दूसरे role का access न मिले।
- [ ] Public landing page पर अनावश्यक अतिरिक्त menus, dashboards, internal details या staff-only panels न दिखें।
- [ ] Admin के अंदर staff/sub-admin permissions हो सकती हैं, लेकिन public landing page पर अलग चौथा login विकल्प नहीं बनेगा; authorized staff access का तरीका Admin policy के अनुसार रहेगा।
- [ ] Mobile और desktop पर साफ़, professional, fast-loading और accessible layout; logo/photo optimized हों।


## 17. प्रारंभिक तकनीकी Audit — 13 नवम्बर 2026
**स्थिति: पहला read-only audit; नीचे लिखे निष्कर्षों के आधार पर अभी कोई production/code deletion या database change नहीं किया गया।** यह section implementation checklist का विकल्प नहीं है; यह वर्तमान स्थिति और blockers का evidence-based snapshot है।

### 17.1 Public Website और Panels
- [ ] index.html अभी SRK लोगो, tagline और चार promotional service cards दिखाता है; Master Section 16 के अनुसार एक high-quality hero photo और केवल तीन login actions (Customer, Electrician, Admin) वाला landing page अभी लागू नहीं है।
- [ ] customer-login.html, electrician.html, admin.html अलग-अलग मौजूद हैं; landing page से तीनों के सही, स्पष्ट और सुरक्षित entry links अभी verify/complete करने हैं।
- [ ] customer-login.html OTP success के बाद /#customer-login पर लौटता है; वास्तविक customer dashboard/panel route और authenticated navigation end-to-end verify करना बाकी है।
- [ ] booking.html एक पुराना single-page booking/marketing flow है; इसे Master के पाँच-menu Customer App में बदलना/समेकित करना होगा। इसे बिना route/session/dependency mapping delete न करें।
- [ ] electrician.html में पुराने inspection/quote buttons, quote submission UI और quote RPC calls अभी मौजूद हैं; Master में quote/inspection-first workflow superseded है।
- [ ] admin.html अभी quoted_amount/quote-era fields और legacy booking status update controls पढ़ता/लिखता है; इसे नए server-authoritative booking/timer/payment/Admin workflows के अनुसार बदलना होगा।
- [ ] policies.html में पुरानी contact/WhatsApp तथा ग्राहक से बाद में price तय करने वाली भाषा है; इसे वर्तमान OTP, estimate-vs-final billing, cancellation, refund, support और privacy rules के अनुरूप review करना होगा।
- [ ] push-test/index.html और supabase-connection-test.html test/diagnostic pages हैं; इन्हें public website navigation से बाहर रखना और access/exposure का security review करना है। इनके उपयोग/किसी provider setup पर निर्भरता जाँचे बिना delete न करें।

### 17.2 Deployment और Repository Hygiene
- [ ] मुख्य deployment requirement Netlify है, लेकिन repository में VERCEL_DEPLOY_HINDI.md, vercel.json, Vercel-नाम वाला package.json metadata और gh-pages पर GitHub Pages publish workflow भी मौजूद हैं। इन्हें Netlify-only release policy के अनुरूप retire/clean करना है; पहले active integrations/branch usage की पुष्टि करें।
- [ ] Netlify function adapters root-level handlers को import करते हैं; root handlers को duplicate/unused समझकर delete नहीं करना है।
- [ ] Feature Branch main से diverged है: तुलना में feature branch 58 commits आगे और 1 commit पीछे है। Merge/rebase केवल अलग समीक्षा और अनुमति के बाद।
- [ ] Feature Branch में 21 local migration files हैं; production Supabase migration history में 81 entries हैं; केवल 5 version identifiers exact match हैं। यह गंभीर migration-history/schema-drift blocker है। किसी migration को blind apply, delete, squash या reset न करें।

### 17.3 Production Supabase — read-only observations
- [ ] Primary project gnqhoaqatmoiwwhgzkgm ACTIVE_HEALTHY है; Postgres 17.11; public schema में 25 tables देखे गए और सभी पर RLS enabled दिखा। हर table की policy/grant/role behavior अलग से audit करना बाकी है।
- [ ] service_bookings में अभी quoted_amount, service_charge, materials_amount, quote_status, quote_note, quote timestamps और inspection/awaiting_quote_approval/quote_approved/quote_rejected status values मौजूद हैं।
- [ ] Production DB में srk_submit_booking_quote, srk_customer_respond_booking_quote, srk_get_my_assigned_booking_quote_details जैसे quote-era RPCs अभी मौजूद हैं। इन्हें UI से हटाने के साथ DB callers, triggers, policies, reports, refunds और historical records map करके ही staged migration करनी है।
- [ ] Security Advisor snapshot: 12 rls_enabled_no_policy informational findings, pg_net public-schema warning, 47 authenticated SECURITY DEFINER execution warnings और leaked-password protection disabled warning। हर finding की वास्तविक exposure/grants/required callers जाँचें; केवल warning देखकर blanket revoke या policy change न करें।
- [ ] Performance Advisor snapshot: 14 unindexed foreign-key findings और 13 unused-index findings; query plans/usage और write impact के बाद ही remediation।
- [ ] Health Advisor में इस snapshot पर कोई finding नहीं।
- [ ] ये advisor results audit snapshot हैं; प्रत्येक fix के बाद fresh advisor run और targeted permission/security tests आवश्यक हैं।

### 17.4 पहले Audit/Remediation क्रम
1. Customer, Electrician और Admin routes/auth/session तथा public landing page की route map।
2. Legacy quote/inspection UI → API/RPC → DB trigger/function → payment/refund/report dependencies की complete inventory।
3. Phone/location privacy, customer-after-completion visibility, role authorization और RLS negative tests।
4. Netlify-only deploy path; Vercel/GitHub Pages/test-only public artifacts की सुरक्षित cleanup सूची।
5. Production schema और 81 remote migrations बनाम 21 local files का authoritative reconciliation; missing migration SQL को recover/verify किए बिना schema changes नहीं।
6. Master के अनुसार नई booking/timer/minute-billing/cash-online/wallet/refund flows की implementation plan और regression test matrix।
7. पहले Feature Branch/staging/Test Mode पर validation; main/production/live payment/deployment अलग explicit approval के बिना नहीं।

**Deletion rule:** Master से टकराने वाला active user-facing behavior हटाया/बदला जाएगा; लेकिन database history, payment/refund ledger, audit trail, working Netlify handlers, secrets/configuration और rollback artifacts को dependency तथा data-retention review के बिना delete नहीं किया जाएगा।


### 17.5 Quotation/Inspection Dependency Audit — विस्तृत निष्कर्ष
यह जाँच 13 नवम्बर 2026 को Supabase production project पर read-only SQL और Feature Branch source inspection से की गई।

- [ ] तीन quote RPC मौजूद हैं: srk_submit_booking_quote, srk_customer_respond_booking_quote और srk_get_my_assigned_booking_quote_details। तीनों SECURITY DEFINER हैं; ACL snapshot में anon EXECUTE=false और authenticated EXECUTE=true मिला। इन्हें revoke/drop करने से पहले सभी वैकल्पिक timer/payment flows deploy और verify करना अनिवार्य है।
- [ ] Electrician UI में inspection शुरू करना, service/material quote बनाना और quote-approved होने पर work शुरू करना मौजूद है। यह Master के customer-approved start/timer/completion flow से बदलना है।
- [ ] Booking UI customer payment button को completed + quote_status approved + quoted_amount पर निर्भर करती है; booking submit में amount शून्य रखकर inspection के बाद final quote बनने की टिप्पणी है।
- [ ] create-order.js, verify-payment.js और razorpay-webhook.js सभी completed + approved quote तथा quoted_amount = service_charge + materials_amount validation पर निर्भर हैं। केवल UI हटाने से online payment flow टूटेगा।
- [ ] Admin UI quoted_amount पढ़ती/लिखती है और पुराने status/amount को सीधे update करती है; इसे server-authoritative billing और Admin audit workflow से बदलना होगा।
- [ ] Production DB में quote columns: quoted_amount, quote_status, quote_note, quote_submitted_at, quote_responded_at और electrician_quote_kind। इसके अलावा service_charge, materials_amount, customer_suggested_amount और commission_amount जैसे fields का भी नए labour-only ledger से mapping आवश्यक है।
- [ ] service_bookings constraints अभी inspection, awaiting_quote_approval, quote_approved और quote_rejected statuses को अनुमति देते हैं; assignment check भी इन्हें assigned booking मानता है। इन्हें तभी बदलें जब नया lifecycle सभी callers में लागू और historical data mapped हो।
- [ ] Quote fields का उपयोग अन्य SECURITY DEFINER financial/admin functions में भी मिला: srk_admin_mark_electrician_payout_paid, srk_admin_prepare_booking_refund, srk_admin_prepare_razorpay_refund, srk_admin_record_manual_payment, srk_capture_admin_audit_event, srk_create_electrician_payable, srk_electrician_confirm_cash_payment और srk_get_my_assigned_cash_payment; साथ ही srk_get_my_offer_details तथा srk_update_booking_work_status में quote-status references हैं। हर function की पूरी definition और business logic को migration design में शामिल करना होगा।
- [ ] Refund RPCs अभी quote approval और quote amount reconciliation अनिवार्य करते हैं; एक function timer/non-quote refund को अलग reconciliation की जरूरत बताकर रोकता है। नई actual-minute billing, partial refund और cancellation reversal के लिए अलग सुरक्षित refund calculation/ledger path आवश्यक है।
- [ ] Admin audit trigger quote-related columns को allow-list में रखता है। नई financial fields और timer events को audit में शामिल करना होगा; पुरानी audit history मिटानी नहीं है।
- [ ] इस snapshot में service_bookings पर एक historical completed + approved + paid Cash booking मिली, जिसमें quoted_amount ₹20, service_charge ₹10 और materials_amount ₹10 थे। यह केवल historical evidence है; record को बदलना/मिटाना नहीं है। नई policy के अनुसार materials labour/fee base से अलग होंगे, इसलिए पुराने record को historical schema/version के साथ सुरक्षित रखना होगा।
- [ ] वर्तमान query में service_bookings पर quote-specific trigger या quote-named policy नहीं मिली; फिर भी generic audit trigger और financial functions quote fields इस्तेमाल करते हैं। Dependency analysis केवल नाम-आधारित trigger/policy खोज तक सीमित नहीं रहेगा।

**निर्णय:** अभी quote columns, quote RPCs, पुराने status values, financial records या audit entries को production से delete/drop नहीं करना है। पहले नई server-authoritative timer/minute-billing/payment/refund implementation Feature Branch और staging/Test Mode में तैयार व test करें। फिर backward-compatible migration, historical data preservation, dependency re-scan, advisor checks और regression tests के बाद ही legacy elements को phased retirement दें।


### 17.6 Three Login / Panel Authentication Audit — 13 नवम्बर 2026
यह source inspection और read-only Supabase policy/function queries पर आधारित है। किसी live login credential, OTP या user session से sign-in करके access test नहीं किया गया; इसलिए यह code/config audit है, पूर्ण penetration test नहीं।

- [ ] Login roles की संख्या तीन ही है: Customer, Electrician और Admin। कोई चौथा business login role नहीं मिला। लेकिन Customer के लिए दो अलग login entry implementations मौजूद हैं (`customer-login.html` और `booking.html` के अंदर embedded OTP login); इन्हें एक ही Customer Login flow में समेकित करना है, चौथा login नहीं मानना है।
- [ ] `index.html` पर इस समय कोई login button/link नहीं है; यह केवल SRK लोगो, tagline और चार service promo cards दिखाता है। Master Section 16 के अनुसार hero photo और ठीक तीन login actions जोड़ना बाकी है।
- [ ] Customer `customer-login.html` OTP verify के बाद `/#customer-login` पर redirect करता है, जबकि root `index.html` में `customer-login` element नहीं है। इसलिए यह redirect वास्तविक customer panel तक नहीं पहुँचाता। Customer panel/booking flow अभी `booking.html` में embedded है।
- [ ] `booking.html` में customer OTP login, dashboard, booking form, service promo cards और payment UI एक ही page में हैं; यह Master के न्यूनतम landing page और पाँच-menu customer app से मेल नहीं खाता। Customer dashboard को अलग authenticated panel में बनाकर पाँच menu क्रम लागू करना है।
- [ ] Customer OTP flow में client-side 60-second resend cooldown और OTP length check है। यह server-side OTP expiry, abuse/rate limit या failed-attempt lock का प्रमाण नहीं; Supabase Auth provider configuration और server-side limits की अलग जाँच जरूरी है।
- [ ] Electrician login SMS OTP है। OTP के बाद authenticated session बनने पर app shell दिखता है; approved/active electrician profile न मिलने पर profile message दिखता है और RLS/RPC access पर निर्भरता है। Login handler में role/profile को स्पष्ट रूप से verify करके non-electrician account को panel में प्रवेश न देना और rejected/pending स्थिति का सुरक्षित अलग view बनाना है।
- [ ] Electrician profile SELECT policy में केवल `auth_user_id`/`user_id` का match या Admin अनुमति है। Snapshot में 1 electrician profile, 1 approved+active profile और दोनों identity link columns set थे; कोई mismatched identity link नहीं मिला। यह सीमित production data count है, सभी edge cases का प्रमाण नहीं।
- [ ] Admin login email/password है और panel खोलने से पहले `is_srk_admin()` RPC जाँची जाती है; RPC `auth.uid()` के विरुद्ध `srk_admin_users` membership देखती है। Snapshot में 1 Admin allowlist row थी। Admin panel के महत्वपूर्ण RPCs में `auth.uid()` तथा Admin guard checks देखे गए।
- [ ] Admin login flow में MFA enforcement दिखाई नहीं दिया; Master की strong authentication/MFA requirement के अनुसार MFA enablement/enforcement और recovery testing बाकी है।
- [ ] `service_bookings` SELECT RLS policy Admin या `customer_user_id = auth.uid()` को अनुमति देती है; Admin UPDATE policy Admin guard पर आधारित है। Electrician के लिए booking table की direct read policy नहीं दिखी; electrician workflow server RPCs पर निर्भर है। हर RPC की identity/booking assignment checks अलग से audit/test हों।
- [ ] Customer call-contact RPC authenticated-only है और सामान्य (non-SECURITY DEFINER) wrapper है; underlying private implementation में assignment/status checks और completed booking पर phone छिपाने की वास्तविक behavior test करनी बाकी है।
- [ ] `customer-login.html` और `booking.html` में duplicate customer OTP code, session behavior और logout behavior को एक shared, consistent implementation में समेकित करना है।
- [ ] Public route hardening: सीधे `/admin.html`, `/electrician.html`, `/booking.html` खोलने पर unauthenticated state, wrong-role session, expired session और disabled/suspended account की negative tests करनी हैं। सिर्फ UI hide करना authorization नहीं है; backend RLS/RPC enforcement निर्णायक रहेगा।

**Panel audit का निष्कर्ष:** कुल तीन login roles सही हैं, पर अभी landing page से तीनों panels का सुव्यवस्थित प्रवेश नहीं है; Customer login duplicate है और customer panel route गलत/अधूरा है। Electrician role gating को स्पष्ट करना, Admin MFA जोड़ना/verify करना और सभी role-bound RPC/RLS का negative testing करना बाकी है। इस चरण में कोई code, user, auth setting या production database बदला नहीं गया।


### 17.7 Customer OTP Redirect — सुरक्षित छोटा सुधार
- `customer-login.html` में OTP verification success के बाद redirect पहले `/#customer-login` था, जबकि landing `index.html` में ऐसा panel/anchor मौजूद नहीं था।
- Feature Branch पर redirect को `/booking.html#customer-login` किया गया ताकि verified customer session मौजूदा embedded customer panel तक पहुँचे।
- बदलाव commit `128dd33c47d630960082e6ef98d5e2d1fcd45a59` में है। GitHub से file दोबारा fetch करके redirect string verify की गई।
- यह केवल route correction है; वास्तविक SMS OTP, browser session persistence, post-login booking list और mobile-browser end-to-end test अभी नहीं किए गए। Duplicate Customer OTP implementation को नए पांच-menu Customer App के निर्माण के दौरान ही हटाना/समेकित करना है।
- Production deploy या database/auth setting में कोई बदलाव नहीं हुआ।


### 17.8 — Customer/Electrician phone-contact RPC: completed-booking privacy finding (13 Nov 2026)
Read-only inspection of the live Supabase function definition found a confirmed mismatch with the Master Requirement that customers must not see an electrician's phone number after work is completed:
- The authenticated customer wrapper `srk_get_customer_call_contacts()` delegates to `private.srk_get_customer_call_contacts_impl()`.
- The private implementation checks `auth.uid()` and customer ownership, requires an assigned electrician, but its allowed status list explicitly includes `completed`.
- It returns `ep.phone` for every row in that list. Therefore, the RPC can return the electrician's phone number for a completed booking; this is a server/API-level privacy issue, not merely a UI display issue.
- The function is `SECURITY DEFINER`, with a fixed search_path. The wrapper's authenticated-only EXECUTE grant was observed in the earlier audit; the private implementation definition itself confirms no completed-state exclusion.

Required safe correction (NOT applied): remove `completed` from the customer contact RPC's allowed statuses, and verify that only currently active/accepted booking states return a phone number. Add negative tests proving that completed, cancelled, rejected, unassigned, and another customer's bookings return no contact details, while a valid accepted booking returns the intended contact. Review the electrician-side customer-contact path separately against the same lifecycle rules.

Safety boundary: no production SQL, function, grant, table, or customer data was changed. Do not hot-edit production. Prepare a versioned, backward-compatible migration on the Feature Branch only after migration-history drift is reconciled; test it in an isolated staging/Test Mode environment, inspect function ACLs and wrapper behavior, then rerun contact-privacy regression tests before any production release. This finding is high priority because the current implementation appears to expose a number after completion contrary to the approved requirement.


### 17.9 — Customer-contact privacy root cause और migration-history reconciliation blocker (13 Nov 2026)
अतिरिक्त जाँच से ये बातें पुष्ट हुईं:
- Feature Branch की मूल migrations `20261109103038_customer_electrician_direct_call_contacts.sql` और `20261109103143_move_customer_call_contact_lookup_to_private.sql` में ग्राहक-contact RPC केवल active workflow states (`assigned`, पुराने inspection/quote states, `in_progress`) लौटाता है; `completed` मूल allow-list में नहीं था।
- Production migration history में बाद में `20261109161539_customer_contact_after_completion` नाम की migration दर्ज है। वर्तमान live private function में `completed` status जोड़कर `ep.phone` लौटाया जा रहा है। यह production behavior के root-cause की ओर मजबूत संकेत है; उस remote-only migration का SQL source अभी Feature Branch में उपलब्ध नहीं है, इसलिए उसके exact statements का दावा नहीं किया जा रहा।
- Live public wrapper `SECURITY INVOKER` है; private implementation `SECURITY DEFINER` है। दोनों functions के ACL snapshot में `anon`/PUBLIC execute नहीं है; `authenticated` execute मौजूद है। Private schema usage भी authenticated को मिला है।
- Supabase migration history में 81 entries दिखाई दीं; Feature Branch में 21 SQL migration files हैं। पहले के version comparison में केवल 5 exact migration versions match हुए थे। कई production-only migrations और Feature Branch-only newer migrations हैं। यह schema/migration drift blocker है; किसी एक तरफ की history को reset, squash, replay या blind-apply करना सुरक्षित नहीं है।

निर्णय/अगला सुरक्षित रास्ता:
1. अभी कोई production SQL/function edit नहीं करना।
2. पहले production migration history के सभी 81 versions को repository migration files/commit history से reconcile करना; remote-only migration source को उपलब्ध होने पर सुरक्षित रूप से recover करना।
3. Supabase CLI उपलब्ध वातावरण में `supabase migration new <descriptive_name>` से नई migration बनानी है (timestamp स्वयं invent नहीं करना), फिर migration में private implementation की status allow-list से `completed` हटाना; बाकी ownership, assignment और active-state predicates यथावत रखना।
4. Isolated staging/Test Mode पर apply करके authenticated customer-owned active booking, completed booking, cancelled/rejected/unassigned booking, और दूसरे customer की booking के positive/negative tests चलाने हैं। यह भी जाँचना है कि completed state में phone UI, API response, receipt/history और cached data से न निकले।
5. ACL/search_path, Supabase Security Advisor और संबंधित customer/electrician contact flows का regression test पूरा होने के बाद ही release plan बनाना। Production deploy/DB migration के लिए अलग स्पष्ट अनुमति आवश्यक रहेगी।

यह जाँच read-only थी। कोई live database, migration history, function, grant, customer data या production deployment बदला नहीं गया।


### 17.10 — Migration source recovery और अतिरिक्त phone-contact RPC exposure (13 Nov 2026)

आज की read-only reconciliation में पिछली जाँच से आगे महत्वपूर्ण तथ्य मिले:

**Migration source recovery**
- Production Supabase history: 81 migration entries; Feature Branch tree: 21 SQL migration files।
- Numeric migration-version comparison: केवल 5 versions दोनों में match; 76 production versions के लिए उसी version वाली file Feature Branch में नहीं मिली; Feature Branch की 16 files के versions production history में नहीं मिले। यह version-level comparison है; नाम/SQL equivalence अलग से verify करनी होगी।
- पहले अज्ञात 20261109161539_customer_contact_after_completion का SQL source दूसरी Git branch work/separate-customer-electrician-portals में मिला: supabase/migrations/20261109190000_customer_contact_after_completion.sql (blob SHA fd0dac906baed04c517ea50876c8fd4c5162b4df)। उस source में वही private function replacement है जो live Production function में मिला: completed status allow-list में जोड़ा गया और ep.phone लौटाया गया। Branch file का timestamp production migration version से अलग है; इसलिए इसे production history entry की exact file identity नहीं मानना है, लेकिन SQL body live definition से मेल खाती है। Source recover हुआ, मगर पूरे 81-version migration drift का reconciliation अभी पूरा नहीं हुआ।
- अन्य 11 branches में इस exact migration name की file नहीं मिली; उपर्युक्त alternate branch में मिली। Source को Feature Branch में अभी copy/apply नहीं किया गया।

- अतिरिक्त Git branch sweep: repository की 14 उपलब्ध branches में कुल 296 migration-file tree entries और 109 unique migration filenames मिले। Production के 81 migration names में से 40 के समान नाम वाली SQL file कम-से-कम एक branch में मिली; केवल 13 production version numbers के exact timestamp वाली file मिली। अतः 41 production migration names अभी इन branches में exact filename से नहीं मिले। समान नाम मिलना SQL equivalence या Production में वही SQL apply होने का प्रमाण नहीं है; हर candidate source की content review/hash comparison और commit provenance बाकी है। इससे स्पष्ट है कि 21-file Feature Branch अकेले पूरी migration history का प्रतिनिधित्व नहीं करती।

**अतिरिक्त live phone-contact RPC audit**
- public.srk_customer_get_my_booking_contacts() नाम का एक और SECURITY DEFINER RPC live Production में है। यह customer ownership check करता है, लेकिन status list में completed और quote_rejected शामिल हैं और ep.phone लौटाता है। इसलिए primary private RPC ठीक होने पर भी यह दूसरा RPC customer phone privacy bypass कर सकता है।
- public.srk_electrician_get_my_assigned_booking_contacts() भी SECURITY DEFINER है; electrician identity को profile user_id/auth_user_id से बाँधता है, पर status list में completed और quote_rejected शामिल हैं और b.phone लौटाता है। Master Requirement में electrician को customer number केवल accepted/active booking के दौरान दिखना चाहिए; completed के बाद इसकी अनुमति भी पुनः जाँचना/सीमित करना होगा।
- public.srk_admin_get_booking_contacts() Admin guard auth.uid() + is_srk_admin() जाँचता है; यह Admin operational access path है, इसे customer/electrician RPC की तरह blanket remove नहीं करना है।
- ACL snapshot: इन customer/electrician/admin public RPCs पर anon_execute=false, authenticated_execute=true; private implementation पर भी anon_execute=false, authenticated_execute=true; public wrapper SECURITY INVOKER है। यह authenticated callers के लिए API-level authorization/row predicates की जाँच को जरूरी बनाता है।
- Feature Branch booking.html में customer UI srk_get_customer_call_contacts call करता मिला। Electrician UI में customer phone offer detail से render होता है; अलग electrician contact RPC call उस file में नहीं मिला। यह UI scan पूरे app की exhaustive call-site proof नहीं है।

**अगला सुरक्षित कदम**
1. Migration reconciliation को सभी 81 entries तक जारी रखें: version, name, SQL source, source branch/commit, equivalent-content hash, और target schema state की mapping बनाएं। Version-only mismatch को अकेले missing schema change का प्रमाण न मानें।
2. एक single migration में सिर्फ एक RPC ठीक करना पर्याप्त नहीं होगा। Customer के दोनों contact RPCs में completed (और rejected/cancelled states) से phone response रोकें; electrician RPC को accepted/active lifecycle तक सीमित करें; ownership/assignment/identity checks सुरक्षित रखें। Admin contact RPC को Admin-only रखें।
3. सभी RPCs की ACL, SECURITY DEFINER/search_path, frontend/API call sites, receipts/history/cache और negative/positive tests की समीक्षा करें।
4. इस environment में Supabase CLI/स्थानीय migration-generation shell उपलब्ध नहीं मिला। इसलिए supabase migration new से generated migration file अभी नहीं बनाई गई। कोई timestamp invent नहीं किया गया। Supabase development branch बनाने पर hourly cost हो सकती है; उपयोगकर्ता की cost approval के बिना branch नहीं बनाया गया।
5. Production DB पर कोई SQL/function/grant/migration परिवर्तन नहीं किया गया। Staging/Test Mode पर test अभी नहीं हुआ; production release के लिए अलग explicit approval आवश्यक है।

**इस चरण का सत्यापन:** live function definitions, five RPC ACLs, migration list, Feature Branch migration tree, alternate branch migration source और दो मुख्य HTML UI files read-only fetch/inspection से जाँचे गए। कोई code, database, migration history, grant, customer data या deployment बदला नहीं गया।


### 17.11 — Phone visibility migration lineage: conflicting branch implementations (13 Nov 2026)

अगली जाँच में phone-contact behavior से जुड़ी अतिरिक्त migrations मिलीं। इनका source अलग-अलग branches में है; अभी इन्हें Feature Branch में merge/copy/apply नहीं किया गया।

- Production migration history में `20261110142310_add_order_accepted_phone_visibility` और `20261110143332_add_admin_booking_contact_visibility` हैं। दूसरी branch `feature/flutter-mobile-apps` में इनके समान नाम/logic वाली files क्रमशः `20261110195000_add_order_accepted_phone_visibility.sql` और `20261110200000_add_admin_booking_contact_visibility.sql` के नाम से मिलीं। Timestamp अलग है, इसलिए exact migration identity/history equivalence अभी सिद्ध नहीं है।
- Order-accepted phone visibility वाली recovered SQL में दोनों public SECURITY DEFINER RPCs बनाए गए हैं। Customer RPC के status allow-list में `completed` और `quote_rejected` हैं और वह electrician phone लौटाता है। Electrician RPC भी वही statuses स्वीकार करके customer phone लौटाता है। यह दो अतिरिक्त completed-contact exposure paths की SQL-level पुष्टि करता है।
- Admin contact RPC अलग migration में है; उसमें `auth.uid()` और `is_srk_admin()` guard है। इसे Admin-only operational function के रूप में अलग रखा जाए।
- दूसरी branch `feature/production-push-notifications` में `20261111160014_keep_customer_call_contact_after_completion.sql` मिली। यह private customer implementation से status allow-list और payment-status filter दोनों हटा देती है; केवल customer ownership और assigned electrician पर निर्भर रहती है। इससे completed ही नहीं, assigned booking के अन्य statuses पर भी phone return हो सकता है। इस file का timestamp/name Production history में contact-related migration के रूप में नहीं मिला; इसे Production में लागू हुआ मानना गलत होगा।
- तीसरी branch `fix/customer-otp-gated-booking-no-public-contact` में `20261112162000_hide_customer_electrician_contact_after_payment.sql` मिली। यह private customer RPC में active states तक सीमित करती है और `payment_status = paid` पर phone रोकती है। लेकिन यह alternate branch source है, Feature Branch या live Production state का प्रमाण नहीं। यह केवल private customer RPC बदलती है; दोनों public contact RPCs को ठीक नहीं करती।
- निष्कर्ष: repository branches में mutually conflicting phone visibility policies हैं—एक completion के बाद access जारी रखती है, दूसरी paid booking पर रोकती है, जबकि Master Requirement completion पर हमेशा phone visibility रोकने की माँग करता है। किसी alternate branch migration को बिना dependency/content/history review अपनाना सुरक्षित नहीं है।

**सुधार का target behavior (Master Requirement):**
1. Customer: electrician का phone केवल assigned/accepted active booking states में; `completed`, `cancelled`, `rejected`, unassigned और अन्य customer की booking में कोई contact row/number नहीं।
2. Electrician: customer का phone केवल assigned/accepted active booking states में; `completed`, `cancelled`, `rejected`, unassigned और दूसरे electrician की booking में कोई contact row/number नहीं।
3. Admin: अलग Admin guard के साथ operational access; सामान्य customer/electrician role से कभी नहीं।
4. Paid/unpaid status को completed-state privacy का substitute न बनाएं। Work completion lifecycle ही निर्णायक है; फोन नंबर receipts, booking history, browser cache/local storage और UI में भी हटना चाहिए।
5. Existing identity, customer ownership, assigned electrician, approved/active electrician, SECURITY DEFINER search_path और ACL checks बनाए रखें। केवल status list बदलकर बिना call-site और data-flow review के release न करें।

इस चरण में चार recovered candidate migrations की SQL content पढ़ी गई और Production history के contact-related entries से तुलना की गई। कोई source file Feature Branch में copy नहीं की गई, कोई production/staging SQL नहीं चलाई गई और कोई deployment नहीं हुआ।


### 17.12 — Customer booking UI और Service Worker cache का read-only निरीक्षण (13 Nov 2026)

- Feature Branch `booking.html` में customer booking list सीधे authenticated customer की `service_bookings` rows पढ़ती है और अलग से `srk_get_customer_call_contacts` RPC call करके contact map बनाती है।
- UI में `row.status === 'completed'` होने पर electrician phone number का call button/number नहीं दिखाया जाता और “काम पूरा हो चुका है…” संदेश दिखता है। यह अच्छा presentation guard है, लेकिन server RPC अभी completed booking पर phone लौटाता है; API leak इससे ठीक नहीं होता। इसलिए UI guard को अकेला security control नहीं मानना है।
- UI पहले contact RPC से पूरा contact result memory में लेता है, फिर booking row के status के आधार पर render करता है। Status transition के समय stale page/tab में पहले से दिखा number हटने का real-time/refresh behavior अभी browser E2E से verify नहीं हुआ।
- Customer booking list में contact RPC के अतिरिक्त सीधे customer phone field select नहीं की जाती। यह इस एक UI path का निरीक्षण है, पूरे app/data flow की exhaustive guarantee नहीं।
- Feature Branch `sw.js` में navigation GET responses cache किए जाते हैं; non-navigation GET भी cache-first है। Supabase contact RPC POST request होने के कारण वर्तमान service worker fetch handler उसे cache नहीं करता। इस निरीक्षण में कोई explicit phone-number localStorage/sessionStorage persistence नहीं मिली। फिर भी authenticated page/browser memory, browser history, screenshots, logs और अन्य app pages का full audit बाकी है।
- कोई UI, service worker, cache, database या API code बदला नहीं गया। यह source inspection है; real browser/session/cache behavior का test नहीं हुआ।
