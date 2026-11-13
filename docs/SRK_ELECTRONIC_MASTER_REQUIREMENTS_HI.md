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
- [x] OTP login — **Source/CI जाँच Verified**: OTP send/verify source, दोनों customer pages के cooldown/duplicate-action markers, OTP input/source checks, inline JavaScript syntax, logout guards/error handling और GitHub Actions Run #9 success दर्ज। **वास्तविक OTP/Auth परीक्षण बाकी**; Production OTP expiry, server-side resend/wrong-attempt limits, CAPTCHA, abuse controls, session lifecycle/revocation और browser/device E2E अभी अंतिम batch test/config verification में लंबित हैं।
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


**Production history में मौजूद, लेकिन 14 scanned Git branches में समान filename से नहीं मिली 41 migrations (version + name):**
```text
20261108092928 harden_srk_rls_policy_performance
20261108093725 add_atomic_payment_order_lock
20261108093757 add_service_role_policy_payment_order_locks
20261108094007 harden_security_definer_function_search_paths
20261108095224 add_missing_foreign_key_indexes
20261108095928 add_actual_paid_amount_commission_and_status_history
20261108102159 harden_payment_order_lock_search_paths
20261108102323 harden_booking_broadcast_search_path
20261108102612 harden_booking_guard_trigger_search_path
20261108102837 enable_realtime_job_offer_updates
20261108102951 enable_realtime_electrician_profile_updates
20261108103531 guard_booking_assignment_and_amount_integrity
20261108115205 tighten_legacy_definer_paths_and_history_grants
20261108181453 restrict_public_form_inserts_to_server_functions
20261108181538 combine_admin_customer_booking_read_policy
20261108184254 electrician_earnings_summary
20261108184815 protect_commission_columns_and_admin_report
20261108184938 limit_booking_updates_and_correct_earnings_timestamp
20261109052929 harden_wallet_reporting_rpc_paths_and_route_recipient_index
20261109053005 harden_wallet_and_commission_security_definer_paths
20261109053301 grant_authenticated_select_service_bookings
20261109053328 grant_authenticated_select_job_offers_for_rls_realtime
20261109080121 lock_quote_workflow_rpcs_to_authenticated_users
20261109081310 srk_manual_electrician_payout_ledger
20261109082241 index_electrician_payout_foreign_keys
20261109082620 lock_down_route_transfer_api_access
20261109094209 add_secure_admin_booking_offer_flow
20261109110140 align_electrician_payouts_with_booking_commission_rate
20261109112032 allow_electricians_to_read_own_manual_payout_status
20261109112105 consolidate_electrician_payout_read_policy
20261109114000 protect_customer_and_electrician_phone_numbers_until_masked_calling
20261109114642 enable_direct_customer_electrician_phone_calls
20261109202355 razorpay_refund_tables_and_audit_type
20261109202505 razorpay_refund_prepare_rpc
20261109202511 razorpay_refund_list_rpc
20261109202534 razorpay_refund_audit_trigger
20261111073357 enable_pg_net_for_electrician_push
20261111075205 wire_job_offer_push_webhook
20261111142316 retire_empty_legacy_electrician_booking_tables
20261112092620 grant_admin_booking_update_columns
20261112182839 increase_schema_export_role_connection_limit
```
यह सूची filename-level inventory है, missing schema objects की final list नहीं। इनमें से कुछ SQL दूसरे नाम/timestamp से मौजूद हो सकते हैं; content hash और target schema state compare किए बिना इन्हें replay या recreate नहीं करना है।


### 17.13 — Full live database phone-returning function inventory (13 Nov 2026)

Live Production PostgreSQL function catalog में `public` और `private` schemas की सभी ordinary functions के source में `phone` शब्द की read-only खोज की गई। इससे एक अतिरिक्त महत्वपूर्ण Electrician-side exposure मिला:

- `public.srk_get_my_offer_details()` — `SECURITY DEFINER`, anon EXECUTE नहीं, authenticated EXECUTE है। यह `p.user_id = auth.uid()`, approved और active electrician profile की जाँच करता है; फिर assigned booking के लिए customer name, phone, address, coordinates और quote details लौटाता है। लेकिन assigned booking status allow-list में `completed` भी शामिल है। इसलिए electrician completed booking के बाद भी इस RPC से customer phone और location/address पा सकता है। यह सीधे Master Requirement के विरुद्ध है।
- Feature Branch `electrician.html` इसी `srk_get_my_offer_details` RPC से आए `o.customer_phone` को UI में render करता है और `tel:` link बनाता है। इस UI path में completed status पर phone छिपाने का अलग guard नहीं मिला। यह live function और Feature Branch UI दोनों की source-level पुष्टि है।
- इस प्रकार अब customer-facing paths के अलावा कम-से-कम दो Electrician-facing paths में completed booking contact exposure मिला: (1) `srk_electrician_get_my_assigned_booking_contacts()`, (2) `srk_get_my_offer_details()`।
- `srk_admin_get_booking_contacts`, `srk_admin_list_booking_complaints`, `srk_admin_list_booking_refund_requests`, `srk_admin_list_electrician_verification_documents` जैसे phone-bearing functions भी मिले; इनके definitions में Admin guard `auth.uid()` और `is_srk_admin()` मौजूद है। ये Admin-only operational functions हैं; इनको सामान्य user contact RPC से अलग review करना है, blanket revoke नहीं।
- सभी मिले ordinary functions में ACL scan ने संबंधित phone-bearing public/private RPCs के लिए anon EXECUTE false और authenticated EXECUTE true दिखाया; Admin functions में भी authenticated role execute कर सकता है, लेकिन function body Admin authorization gate लगाता है। SECURITY DEFINER के कारण body guard/identity predicates अनिवार्य हैं।
- Live Production में `service_bookings` status counts query ने केवल एक `completed` row लौटाई। यह सीमित production sample है; इससे सभी lifecycle states या सभी customers/electricians के व्यवहार का अनुमान नहीं लगाना है। कोई phone number या customer PII रिपोर्ट में copy नहीं किया गया।

**सुधार का विस्तारित target:**
1. Customer contact paths: `srk_get_customer_call_contacts`, `private.srk_get_customer_call_contacts_impl`, `srk_customer_get_my_booking_contacts` — completed/cancelled/rejected/unassigned पर कोई electrician contact नहीं।
2. Electrician contact paths: `srk_electrician_get_my_assigned_booking_contacts` और `srk_get_my_offer_details` — completed/cancelled/rejected/unassigned पर customer phone/address/coordinates नहीं। केवल currently assigned/accepted active booking पर contact data।
3. Offer history/list behavior अलग से तय करना होगा: completed booking की non-sensitive summary दिख सकती है, लेकिन customer phone, address और exact coordinates वापस न हों।
4. Admin contact/complaint/refund/verification workflows में Admin guard और least-privilege review बनाए रखें।
5. API tests में सीधे authenticated RPC calls से negative tests जरूरी हैं; केवल HTML में button छिपाना पर्याप्त नहीं।

यह inventory SQL catalog और Feature Branch source inspection पर आधारित है। कोई database function, grant, frontend file, customer record या deployment बदला नहीं गया; browser/API regression tests अभी नहीं चले हैं।


### 17.14 — Cross-branch SQL source integrity: duplicate-name content variants (13 Nov 2026)

14 branches की migration trees के file SHA को compare करके Production के 81 migration names से मिलान किया गया:
- 40/81 Production migration names के लिए कम-से-कम एक branch में same-name SQL file मिली; 41 names किसी scanned branch tree में नहीं मिलीं।
- 40 same-name candidates में 37 नामों के लिए सभी मिले branch copies का Git blob SHA समान था। यह repository copies की content consistency है, Production में applied SQL का proof नहीं।
- 3 same-name migrations के लिए अलग-अलग branches में अलग SQL blob SHA मिला:
  - `srk_business_finance_dashboard` — 2 distinct blobs।
  - `srk_business_finance_reporting_dates` — 2 distinct blobs।
  - `add_electrician_push_subscriptions` — 2 distinct blobs; filenames में timestamps भी अलग हैं (`20261111020000` और `20261111090000`) जबकि Production history में उसी नाम की entries `20261111072823` पर है।
- कुछ same-name source files का timestamp Production history से अलग है। उदाहरण: `add_google_maps_location_support`, `expose_assigned_booking_map_pin`, `create_secure_wallet_ledger_foundation`, `create_server_only_razorpay_route_transfer_ledger`, quote workflow, और कई manual payout/admin migrations। इसलिए migration name match को version match या SQL identity नहीं मानना है।
- Production में `add_assigned_electrician_cash_payment_status` नाम की दो अलग history versions (`20261111082515`, `20261111083811`) हैं, जबकि scanned branches में candidate filename एक version (`20261111082515`) के साथ मिली। दोनों remote history entries की SQL/provenance अलग से verify करनी होगी।

**निर्णय:** migration reconciliation अब केवल filename/version count नहीं रह गया; branch-level content divergence भी मिली है। किसी migration को timestamp rename करके, SQL hash assume करके, या alternate branch से सीधे Feature Branch में copy करके reconcile नहीं करना है। हर remote version के लिए applied schema effect, source commit, SQL body और dependency order की evidence mapping आवश्यक है। कोई migration apply/rename/delete/squash/reset नहीं की गई।


### 17.15 — Direct table RLS बनाम SECURITY DEFINER contact paths (13 Nov 2026)

Live Production `pg_policies` का read-only निरीक्षण:
- `service_bookings` SELECT policy authenticated users को केवल Admin या उसी customer (`customer_user_id = auth.uid()`) की booking पढ़ने देती है। Electrician के लिए direct SELECT policy नहीं दिखी।
- `electrician_profiles` SELECT policy केवल linked electrician (`auth_user_id/user_id = auth.uid()`) या Admin को profile पढ़ने देती है।
- `job_offers` SELECT policy केवल Admin या approved+active linked electrician की अपनी offers तक सीमित है।
- इसलिए इन तीन tables पर inspected direct RLS predicates customer/electrician cross-user contact access को सीमित करते हैं। पर SECURITY DEFINER RPCs owner privileges के साथ चल सकते हैं; उनके अपने identity/assignment/status predicates निर्णायक हैं। इसी कारण ऊपर पहचाने गए RPC return paths RLS से अलग high-priority review हैं।
- यह केवल SELECT policy snapshot है; INSERT/UPDATE/DELETE grants, column-level grants, सभी related tables, actual role/session negative tests और function owner/bypass behavior का पूरा audit अभी बाकी है।

**निष्कर्ष:** अभी direct table RLS में इन तीन tables पर कोई broad cross-user SELECT policy नहीं दिखी; पर यह completed booking phone leakage को neutralize नहीं करती। कोई policy, grant या database object बदला नहीं गया।


### 17.16 — Booking status constraint और contact lifecycle mapping blocker (13 Nov 2026)

Live Production `service_bookings` check constraints से status list पढ़ी गई:
- Allowed statuses: `new`, `confirmed`, `assigned`, `inspection`, `awaiting_quote_approval`, `quote_approved`, `quote_rejected`, `in_progress`, `completed`, `cancelled`।
- Assignment-required constraint में `assigned`, `inspection`, `awaiting_quote_approval`, `quote_approved`, `quote_rejected`, `in_progress`, `completed` पर `assigned_electrician_id` non-null होना जरूरी है।
- अलग `accepted` status इस live constraint में मौजूद नहीं है। Master Requirements के नए offer-acceptance flow में “electrician accepts” और “assigned booking” का exact state mapping तय किए बिना नई contact allow-list तय नहीं करनी है।
- पुरानी quote/inspection states Master Requirements में superseded हैं; लेकिन Production में अभी status constraint और RPCs इन्हें allow करते हैं। केवल contact RPC से quote states हटाने पर legacy booking/payment paths प्रभावित हो सकते हैं, इसलिए नए lifecycle migration और UI/payment dependency plan के साथ ही बदलाव करना होगा।
- `completed`, `cancelled`, `quote_rejected` को customer/electrician phone-contact response में रोकना चाहिए। कौन-से remaining states वास्तव में accepted active booking का प्रमाण हैं, इसे current offer acceptance RPC/trigger और booking status transition evidence से verify करना बाकी है।

इस जाँच में केवल constraint definitions पढ़ी गईं; कोई status constraint, booking row या RPC नहीं बदला गया।


### 17.17 — Offer acceptance से booking status mapping सत्यापित (13 Nov 2026)

Live Production में `public.srk_respond_to_offer(p_offer_id, p_response)` function definition पढ़ी गई:
- Function authenticated electrician की approved+active profile और उसी electrician की `offered` job offer जाँचता है।
- `accepted` response पर booking को `assigned_electrician_id = v_electrician_id` और `status = 'assigned'` करता है; अन्य offers को `expired` करता है।
- इसलिए वर्तमान Production schema में offer acceptance का durable booking marker `assigned` + matching `assigned_electrician_id` है; अलग booking status `accepted` नहीं।
- पुराना `accept_electrician_job` RPC भी offer accepted होने पर booking को `assigned` करता है, लेकिन दोनों RPCs का frontend/caller और ACL use अलग से audit करना है।
- वर्तमान work-status RPC में `assigned → inspection → quote_approved → in_progress → completed` legacy quote path है। Master Requirements में quote/inspection flow superseded है; नया timer lifecycle बनने पर active contact states को उसी नए, tested state machine से जोड़ना होगा।
- इस evidence के आधार पर provisional lifecycle interpretation: offer acceptance/active assignment का entry point `assigned`; active work `in_progress`; terminal `completed` पर phone visibility बंद। लेकिन legacy `inspection`/quote states को हटाने का timing तभी तय होगा जब booking/timer/payment replacement लागू और regression-tested हो।

इससे “accepted” शब्द का status mapping blocker स्पष्ट हुआ; कोई status/RPC/function/database object नहीं बदला गया।


**Recovered source commit provenance (GitHub path history):**
- `20261109190000_customer_contact_after_completion.sql` की branch commit history में commit `4de560f1db0402899126b7a47d05fe09534e525e` मिला; commit message: “Keep customer electrician contact visible after completion”; author timestamp 2026-11-09 16:06:08 UTC।
- यह commit उसी alternate branch `work/separate-customer-electrician-portals` में है। Production migration history में दर्ज version `20261109161539` है; branch filename version `20261109190000` अलग है। Commit message और SQL body मिलकर root-cause hypothesis को मजबूत करते हैं, लेकिन commit/version mismatch के कारण Production में exactly कौन-सा file/version apply हुआ, इसकी अंतिम provenance अभी भी reconcile करनी है।
- इसी branch में cancellation privacy migration `20261109193000_hide_customer_details_on_cancelled_bookings.sql` commit `12057a1fb9f84996e8828359b2be3185ac14a064` (“Protect customer details on cancelled electrician bookings”) भी मिली। इसका SQL और live function/table effects अलग से compare करने हैं।


### 17.18 — Contact RPC के वास्तविक ACL और SECURITY DEFINER owner की पुष्टि (13 Nov 2026)

Production catalog से छह संबंधित functions के owner, security mode, search_path और ACL पढ़े:
- पाँच phone/contact RPCs (private.srk_get_customer_call_contacts_impl, public.srk_admin_get_booking_contacts, public.srk_customer_get_my_booking_contacts, public.srk_electrician_get_my_assigned_booking_contacts, public.srk_get_my_offer_details) सभी owner postgres, SECURITY DEFINER, fixed search_path pg_catalog, public, auth, pg_temp हैं।
- इन functions में PUBLIC EXECUTE = false, anon EXECUTE = false; संबंधित contact RPCs में authenticated EXECUTE = true है। इसलिए anonymous API call से direct access नहीं दिखा; authenticated user के लिए ownership/assignment/status checks ही मुख्य सीमा हैं।
- Private implementation पर भी authenticated EXECUTE है, इसलिए इसकी internal body में customer ownership और assigned electrician checks महत्वपूर्ण हैं। इसे केवल private schema में रखने से authenticated role का execute अधिकार स्वतः समाप्त नहीं होता।
- public.accept_electrician_job भी SECURITY DEFINER है, लेकिन ACL में केवल postgres और service_role हैं; authenticated execute false है। इसके विपरीत srk_respond_to_offer authenticated execute true है और live acceptance path के रूप में अलग से मौजूद है।
- Admin contact RPC पर authenticated execute true है, पर function body में auth.uid() और is_srk_admin() gate है। Admin workflow को सुरक्षित रखते हुए इसी तरह role guard बनाए रखना है।
- इस snapshot में PUBLIC/anon execute बंद है, लेकिन authenticated callers को contact RPC access मिलता है। SECURITY DEFINER होने के कारण body predicates को API boundary मानकर कठोर परीक्षण करना होगा।

यह catalog/ACL-only inspection है; कोई GRANT/REVOKE, function definition या database setting बदली नहीं गई। वास्तविक authenticated customer/electrician JWT से negative/positive runtime tests अभी शेष हैं।


### 17.19 — Phone columns वाले tables, views और direct SELECT grants की जाँच (13 Nov 2026)

Live Production schema inspection:
- public schema में phone column केवल तीन tables पर मिला: electrician_applications.phone, electrician_profiles.phone, service_bookings.phone। public/private में phone को reference करने वाला कोई ordinary SQL view pg_views में नहीं मिला। यह view inventory है; materialized views और API-generated JSON/edge logs की अलग जाँच बाकी है।
- इन तीनों tables पर authenticated role को table-level SELECT grant है; anon/PUBLIC को SELECT grant इस snapshot में नहीं मिला। Table grant अपने-आप row access नहीं देता; RLS policy भी लागू होती है।
- electrician_applications SELECT policy केवल Admin (is_srk_admin()) को अनुमति देती है।
- electrician_profiles SELECT policy केवल उसी linked electrician (auth_user_id/user_id = auth.uid()) या Admin को अनुमति देती है। इसलिए सामान्य electrician दूसरे electrician profile का phone direct SELECT से नहीं पढ़ सकता।
- service_bookings SELECT policy केवल Admin या उसी customer_user_id वाले customer को अनुमति देती है; assigned electrician को direct table SELECT policy नहीं है। Customer अपनी booking row में अपना ही phone पढ़ता है; दूसरे customer का phone नहीं।
- इन policies के कारण inspected direct-table route पर broad cross-user phone read नहीं दिखा। फिर भी SECURITY DEFINER RPCs अलग privileged path हैं और completed-state exposure पहले से confirmed है।
- यह table-level grants + SELECT policy snapshot है; column-level grants, inherited roles, materialized views, storage, logs, realtime payloads और सभी edge functions का exhaustive audit अभी शेष है।

कोई grant, RLS policy, view या table बदला नहीं गया।


### 17.20 — Netlify API adapters, booking/payment endpoints और UI contact exposure audit (13 Nov 2026)

Feature Branch के API handlers और उनके call-sites का source audit:
- netlify/functions/create-booking.js, create-order.js, verify-payment.js और razorpay-webhook.js केवल root-level handler modules को import/forward करते हैं। इसलिए वास्तविक business logic root files create-booking.js, create-order.js, verify-payment.js और razorpay-webhook.js में है; adapters में अलग phone filtering logic नहीं है।
- create-booking.js Customer Supabase session की पुष्टि करता है, verified Auth phone को submitted booking phone से match करता है और फिर booking insert करता है। यह server-side match उपयोगी है; पर UI में phone field editable है, इसलिए UX को verified number से auto-fill/lock करने की जरूरत बनी रहती है।
- create-order.js और verify-payment.js booking phone को customer session phone से मिलाते हैं। इन handlers में phone को response body में लौटाने का संकेत नहीं मिला। create-order अभी quote-era amount fields और completed/approved quote dependency पढ़ता है।
- verify-payment.js केवल status=completed और quote_status=approved पर online payment verify करता है। यह Master के नए server timer/actual-minute billing flow से अभी मेल नहीं खाता; इसे पुराने payment dependency audit में शामिल रखना है।
- razorpay-webhook.js booking row पर payment status update करता है; inspected matching lines में phone response/render नहीं मिला। Full handler review में signature verification, idempotency और state transition अलग से test होने चाहिए।
- Customer booking.html own booking rows में address और location दिखाता है, और contact RPC से electrician phone map बनाता है। UI completed status पर call button छिपाता है, लेकिन server RPC completed booking में phone लौटा सकता है—UI guard अकेले पर्याप्त नहीं।
- Electrician electrician.html srk_get_my_offer_details() से मिले customer_phone को बिना completed-status UI guard के render करता है और tel: link बनाता है। यह completed booking पर ग्राहक का फोन UI में दिखाने का सीधा जोखिम है; server RPC में भी completed allow-list पहले से confirmed है।
- Electrician UI में assigned offer पर customer name, phone, full address और map directions दिखते हैं। Target lifecycle में यह जानकारी केवल assigned/active booking के दौरान उपलब्ध होनी चाहिए; completed/cancelled/rejected/unassigned पर server response और UI दोनों में हटे।
- booking.html में WhatsApp message builder customer द्वारा भरे phone/address/location सहित booking विवरण को WhatsApp message में डालता है। यह legacy/manual path है और Master के in-app authenticated booking + verified phone + privacy workflow के साथ reconcile करना होगा; इसे चुपचाप live booking का विकल्प नहीं मानना चाहिए।
- इस source scan में अलग receipt/invoice/history renderer का कोई अतिरिक्त Netlify endpoint नहीं मिला। Customer booking history स्वयं booking.html में है; बाकी receipts, exports, admin views, push payloads और logs का exhaustive scan अभी शेष है।

सिर्फ source पढ़ा गया; कोई API/UI/DB code बदला नहीं गया। निष्कर्ष: Electrician UI completed booking पर customer_phone render कर सकता है; RPC और UI दोनों में सुधार आवश्यक है। Payment handlers भी अभी quote-era workflow पर निर्भर हैं।


### 17.21 — Production Edge Functions, Push Payload और Legacy Cancellation Migration audit (13 Nov 2026)

Production Edge Function inventory:
- `push-job-offer` ACTIVE, version 4, `verify_jwt=false`; POST path custom `x-srk-push-secret` check, allowed payload केवल `public.job_offers` INSERT/UPDATE, row shape में offer id/electrician id/booking id/status की जाँच। Push message generic है; customer phone, name, address या coordinates push body में नहीं भेजे जाते।
- Push delivery केवल eligible electrician profile (`active`, `approved`, linked `user_id`) और उसी user की subscriptions पर होती है। Notification में offerId और `/electrician.html?offerId=...` URL है; PII नहीं। VAPID public key GET intentionally public; private key/service key/webhook secret response में expose नहीं होते। Authorized diagnostic response केवल webhook secret header से खुलता है।
- Production DB trigger `private.srk_notify_job_offer_push()` `job_offers` row का पूरा JSON webhook को भेजता है। यह row shape वर्तमान Edge Function द्वारा सीमित रूप से validate होती है और payload में customer contact fields नहीं दिखे। फिर भी future schema expansion के लिए trigger payload को allow-listed fields तक सीमित करना बेहतर होगा; अभी कोई बदलाव नहीं किया गया।
- `send-sms-2factor` ACTIVE, version 8, `verify_jwt=false`; request पर signed Standard Webhooks signature verify करता है, फिर Indian phone और OTP format validate करके 2Factor provider को भेजता है। Provider response/log में OTP या phone print नहीं किया जाता। Endpoint में API key server env से आती है। यह custom delivery route है; वास्तविक OTP authentication Supabase Auth verification से ही होना चाहिए। Runtime provider delivery test नहीं किया गया।

Production DB function findings:
- `srk_customer_get_my_booking_contacts()` और `srk_electrician_get_my_assigned_booking_contacts()` दोनों completed status को allow करते हैं; customer/electrician ownership binding है, पर Master lifecycle से टकराव है। दोनों में `quote_rejected` भी allow है।
- `srk_get_my_assigned_booking_quote_details()` completed सहित legacy statuses में assigned electrician को address, location, payment/quote details देता है। इसे भी lifecycle scope में लाना होगा।
- `srk_admin_get_booking_contacts()` पूरे recent booking set के customer/electrician phone देता है, लेकिन पहले `auth.uid()` और `is_srk_admin()` guard करता है। Admin operational access को अलग सुरक्षित Admin policy के तहत बनाए रखना है।
- `srk_log_service_booking_status()` status changes पर `service_booking_status_history` में actor UID और old/new status लिखता है; inspected function में phone/address fields history payload में नहीं डाले जाते। History table की direct RLS/grants और other triggers अलग से जाँचने हैं।
- `broadcast_booking_job()` approved+active electricians को job offers बनाता है; inspected definition matching के लिए PIN/state/district उपयोग करती है, customer phone/address को job_offers में copy नहीं करती। Smart Matching के nearest-distance/availability priority नियम से यह legacy logic अभी मेल नहीं खाता।

Legacy migration `20261109193000_hide_customer_details_on_cancelled_bookings.sql` का recovered alternate-branch source पढ़ा:
- Comment कहता है कि customer PII केवल actively assigned booking में उपलब्ध हो, पर SQL status allow-list में `completed` शामिल है। इसलिए migration केवल cancelled booking छिपाता है; completed booking पर customer name/phone/address/coordinates/quote fields फिर भी लौटाता है।
- Allow-list में पुराने inspection/quote statuses भी हैं, जो Master Requirements के नए lifecycle से reconcile होने चाहिए।
- यह alternate branch का source है; Production में इसी exact file/blob के लागू होने का प्रमाण अभी नहीं है। इसे Production पर replay या copy नहीं करना है।

कुल निष्कर्ष: inspected push notification content में customer PII नहीं मिला; प्रमुख confirmed privacy gaps अभी contact RPCs, quote-details RPC और Electrician UI के completed state पर हैं। Edge Functions केवल पढ़े गए; कोई deploy, DB बदलाव या provider call नहीं किया गया।


### 17.22 — Booking History, Admin Audit, Realtime और Storage access audit (13 Nov 2026)

Production catalog/policy snapshot:
- `service_booking_status_history` में booking id, old/new status, note, actor UID, timestamp हैं; phone/address columns नहीं हैं। Authenticated role को SELECT grant है, लेकिन SELECT RLS policy केवल `is_srk_admin()` को अनुमति देती है। Service-role ALL policy अलग है। सामान्य Customer/Electrician को direct history-table read नहीं मिलना चाहिए; UI अगर history दिखाता है तो सुरक्षित owner/assignment-scoped RPC की आवश्यकता होगी। Runtime JWT negative test अभी बाकी है।
- `srk_admin_audit_events` में entity/action/actor/changed_fields और before/after JSONB हैं। इस table पर authenticated role का table grant या सामान्य user policy snapshot में नहीं मिला; service_role और postgres grants मौजूद हैं। Admin read RPC/UI path अलग से सत्यापित होना बाकी है।
- `srk_capture_admin_audit_event()` केवल allow-list fields लिखता है। Booking allow-list में अभी status, payment_status, payment_method, amount_paid, quoted_amount, quote_status, service_charge, materials_amount, assigned_electrician_id, commission_amount हैं। नए timer timestamps, actual minutes, labour amount, platform fee, wallet/cash-cycle/refund fields इसमें शामिल नहीं हैं; नए financial/timer सिस्टम से पहले allow-list और event model का versioned विस्तार आवश्यक है। फोन/पता/coordinates इस allow-list में नहीं हैं, इसलिए यह trigger उन PII fields को audit JSON में नहीं डालता।
- `srk_push_subscriptions` में user_id और Web Push endpoint/keys हैं। RLS policies SELECT/INSERT/UPDATE/DELETE को केवल `user_id=auth.uid()` तक सीमित करती हैं। Endpoint और push keys संवेदनशील तकनीकी credentials हैं; authenticated user को केवल अपनी subscription देखनी/बदलनी चाहिए। Edge Function service role से eligible electrician की subscriptions पढ़ती है।
- Realtime publication में केवल `electrician_profiles` और `job_offers` पाए गए; `service_bookings` और booking history publication में नहीं हैं। `electrician_profiles` SELECT policy linked user या Admin तक सीमित है; `job_offers` SELECT policy Admin या उसी approved+active electrician के अपने offers तक सीमित है। इसलिए वर्तमान policy snapshot में दूसरे users के profile phone या offer rows का broad Realtime access नहीं दिखता। JWT session आधारित runtime subscription test अभी बाकी है।
- Storage bucket `srk-electrician-verification` private है; 5 MiB सीमा और केवल PDF/JPEG/PNG MIME allow-list है। SELECT policy uploader की UID folder या Admin तक सीमित; upload policy UID folder और linked profile check करती है; DELETE policy own folder में और document table में referenced न होने पर ही अनुमति देती है। Signed URL expiry, document metadata RLS, path traversal/foreign UID negative tests अभी बाकी हैं।
- Trigger inventory में `service_bookings` पर booking guard, offer broadcast, admin audit, commission calculation, offer cancellation, status history और electrician payable triggers हैं। यह स्पष्ट dependency cluster है; नए timer/actual-minute billing को लागू करने से पहले इन trigger order/side effects और legacy commission/payable triggers की concurrency/idempotency जाँच अनिवार्य है।

निष्कर्ष:
- Status history direct RLS, private verification storage और own-user push subscriptions के अच्छे नियंत्रण मिले, पर runtime negative tests बाकी हैं।
- Audit trigger नई financial/timer fields को अभी capture नहीं करेगा; इसे नए billing model से पहले update करना होगा।
- Realtime publication में booking table नहीं है; current row-level policies profile/offer data को account scope में सीमित करती हैं।
- केवल read-only catalog/policy inspection हुई; कोई policy, grant, trigger, table, storage object, realtime publication या production data नहीं बदला।

### 17.23 — Billing Triggers, Wallet Ledger, Payout और Refund/Cancellation dependency audit (13 Nov 2026)

Production catalog का read-only inspection:

**Booking triggers और legacy billing**
- `service_bookings` पर BEFORE INSERT `guard_new_booking()` status को `new`, payment को `unpaid`, assignment को NULL, commission_rate को 15% और created_at को server time पर सेट करता है। यह नए workflow के insert defaults के साथ reconcile होना चाहिए।
- `srk_calculate_booking_commission()` trigger केवल `status='completed'` और `payment_status='paid'` पर `service_charge × commission_rate` से `commission_amount` निकालता है। यह labour-only आधार के अनुकूल है, लेकिन अभी पुराने service_charge/commission नाम और payment lifecycle पर निर्भर है।
- `srk_create_electrician_payable()` trigger केवल completed + paid + approved quote + verified payment पर चलता है। यह amount_paid को service_charge + materials_amount से मिलाता है, platform commission केवल service_charge पर निकालता है, और electrician payable में materials जोड़ता है। इससे पुराना quote-approved भुगतान नए timer/actual-minute billing से जुड़ा नहीं है।
- Payable insert में booking_id पर UPSERT है और existing row केवल payout_status='pending' होने पर update होती है। यह कुछ replay protection देता है, लेकिन पूरे booking/payment/refund cycle की end-to-end idempotency या concurrent webhook व्यवहार का प्रमाण नहीं है।
- `srk_cancel_booking_job_offers()` केवल booking cancelled होने पर offered/accepted job_offers को cancelled करता है। यह cancellation fee, wallet debit, customer debt, electrician travel stage या platform cancellation ledger नहीं बनाता।
- `srk_log_service_booking_status()` status history लिखता है; `srk_capture_admin_audit_event()` booking financial allow-list में अभी timer/actual-minute/platform-fee/wallet/cash-cycle fields नहीं हैं।

**Wallet**
- `srk_wallet_accounts` में user + wallet_type unique है; customer/electrician wallet, INR और active/restricted/closed states हैं।
- `srk_wallet_ledger` में credit/debit, entry_type, pending/posted/reversed/failed, reference और idempotency_key है। idempotency_key पर UNIQUE constraint मौजूद है, लेकिन nullable है; इसलिए हर posting caller को non-null deterministic key देना और duplicate retry को सुरक्षित संभालना आवश्यक है।
- Wallet tables पर इस trigger scan में कोई ledger-posting/append-only trigger नहीं मिला। Wallet accounts और ledger पर authenticated users के लिए केवल own-user SELECT policies मिलीं; direct INSERT/UPDATE/DELETE policies नहीं मिलीं। इससे server-side posting route की जरूरत स्पष्ट होती है, पर सभी grants/role inheritance और RPC callers की runtime जाँच बाकी है।
- `srk_get_my_wallet_summary()` जरूरत पड़ने पर wallet account INSERT करता है और posted ledger entries का balance जोड़ता है। यह read-जैसे summary RPC के भीतर write side effect है; concurrency, account status और access/ACL review जरूरी है। यह भी स्पष्ट करता है कि current wallet summary top-ups और payouts को disabled बताती है।

**Cash payment और payout**
- `srk_electrician_confirm_cash_payment()` assigned approved+active electrician और assigned booking verify करता है; completed + approved quote + cash method + unpaid/pending payment के बाद quoted_amount को paid mark करता है। यह timer-derived final amount या actual-minute billing नहीं पढ़ता।
- `srk_get_my_assigned_cash_payment()` भी cash confirmation eligibility को completed + approved quote + quoted_amount पर आधारित करता है।
- `srk_admin_mark_electrician_payout_paid()` Admin-only है; booking-first फिर payout row lock करता है और verified payment, completed/approved quote, service/material breakdown तथा payout ledger amount का reconciliation करता है। यह पुरानी quote fields पर निर्भर है।
- `srk_electrician_payouts` में booking_id unique है; payout paid करने पर method/reference/paid_by/paid_at आवश्यक हैं। payout table पर Admin audit trigger मौजूद है।

**Refund और cancellation**
- Refund request table में booking_id unique है; Razorpay refund table में booking_id और idempotency_key unique हैं। Provider refund reconciliation processed state पर replay को पहचानती है।
- Admin refund preparation verified Razorpay payment मांगता है, लेकिन अभी quote_status='approved', quoted_amount और service_charge + materials_amount का exact match भी अनिवार्य है। Timer/non-quote refund को स्पष्ट रूप से अलग reconciliation error से रोकता है।
- Refund processed होने पर booking payment_status='refunded' किया जाता है; payable trigger केवल pending payout को refunded करता है। Paid payout की recovery अलग Admin reconciliation मांगती है।
- इस जाँचे गए booking schema में cancellation/timer/actual-minute/platform-fee/wallet/cash-cycle नाम वाले booking columns नहीं मिले। इस finance-table scan में अलग cancellation-fee ledger/table भी नहीं मिला। इससे यह निष्कर्ष नहीं निकालना कि पूरे database में कोई अन्य cancellation implementation नहीं है; सभी functions, edge handlers और app callers की cross-reference बाकी है।

**Master Requirements के अनुसार आवश्यक सुधार-पूर्व शर्तें**
1. Timer-approved actual minutes से server-calculated labour total और 15% labour-only Platform Fee का एक authoritative calculation source बने; materials अलग रहें।
2. Cash cycle reservation, eligible booking count और wallet fee posting को एक transaction/locking strategy और non-null idempotency keys से सुरक्षित करना होगा।
3. Customer cancellation request और Admin-only decision के लिए stage-based ₹0/₹49/₹99 rule, customer debt carry-forward, electrician wallet debit और SRK cancellation ledger के अलग, auditable entries चाहिए।
4. Online refund, cash settlement, cancellation reversal और पहले से paid electrician payout के लिए partial/full amount reconciliation और duplicate webhook/retry tests आवश्यक हैं।
5. पुराने quote-based trigger/RPCs को हटाने से पहले सभी app/API/RPC callers migrate हों; ऐतिहासिक payout/refund/ledger records सुरक्षित रहें।

**सीमा:** यह Production catalog, function definitions, constraints और RLS policy का read-only audit था। कोई trigger, function, table, policy, grant, wallet entry, payout, refund, customer record या deployment नहीं बदला। वास्तविक user JWT, concurrent transaction, Razorpay webhook replay और UI E2E tests अभी नहीं किए गए।

### 17.24 — Customer Cancellation RPC, Wallet access, Admin Finance reporting और ledger audit (13 Nov 2026)

Production पर अतिरिक्त read-only verification:

**Customer cancellation RPC**
- `srk_customer_cancel_my_booking(p_booking_id)` SECURITY DEFINER है; केवल authenticated customer को अपनी `customer_user_id` वाली booking पर अनुमति देता है।
- यह row को `FOR UPDATE` lock करता है; केवल unassigned और `new/confirmed` booking cancel कर सकता है। Assigned booking या अन्य status पर app cancellation रोकता है।
- Function सीधे `status='cancelled'` करता है। इसमें electrician के `left home / en route / arrived` stage, ₹0/₹49/₹99 calculation, Admin decision, customer debt carry-forward, electrician wallet debit, या SRK cancellation-fee ledger posting नहीं है।
- अतः यह मौजूदा सीमित pre-assignment cancellation path है; इसे Master के पूर्ण cancellation model का implementation नहीं माना जा सकता। नए flow में customer request और Admin-only final decision को अलग रखना होगा; existing ownership और row-lock checks सुरक्षित रखें।

**Wallet read/access**
- Wallet accounts और ledger पर authenticated role को table-level SELECT है; RLS policies केवल अपने `user_id=auth.uid()` की rows पढ़ने देती हैं।
- इस snapshot में authenticated के लिए इन tables पर direct INSERT/UPDATE/DELETE grant नहीं मिला। `service_role` और postgres के पास operational write privileges हैं; इन्हें सामान्य client के लिए expose न करें।
- `srk_get_my_wallet_summary()` SECURITY DEFINER और authenticated EXECUTE है; यह wallet account न होने पर customer account तथा approved electrician के लिए electrician account create करता है। यानी नाम summary है लेकिन RPC read call के भीतर account-creation side effect है। Concurrent first-call व्यवहार और wallet status handling का staging test आवश्यक है।
- यही RPC साफ कहता है कि customer top-ups और electrician bank payouts disabled हैं जब तक regulated payment flow / Razorpay Route linked-account onboarding और live approval पूरा न हो। इन्हें UI में उपलब्ध या चालू बताना गलत होगा।
- Wallet ledger में UNIQUE idempotency_key nullable है; client-supplied arbitrary key को trusted नहीं मानना चाहिए। Server-generated deterministic, non-null key और append-only correction/reversal model जरूरी है।

**Admin Finance Dashboard**
- `srk_admin_finance_dashboard()` SECURITY DEFINER है और function body में `auth.uid()` + `is_srk_admin()` check करता है; anon EXECUTE false, authenticated EXECUTE true। Admin guard को बनाए रखना होगा।
- Dashboard paid+completed bookings से customer payments, commission, electrician share, paid/pending payout और private expense totals निकालता है। अभी यह पुराने `amount_paid`, `commission_amount`, `service_charge`, `commission_rate` और `srk_electrician_payouts` पर निर्भर है।
- `net_profit` फिलहाल platform commission minus recorded expenses है। इसमें नए cancellation receipts/debts, wallet fee due/collection, cash-vs-online settlement, refund/reversal और unpaid liabilities के अलग totals नहीं हैं। इसे पूर्ण accounting profit न माना जाए।
- Finance dashboard का `electrician_share = gross customer payments - platform commission` में materials भी शामिल हो सकते हैं; यह customer-to-electrician payable का gross share है, actual payout paid नहीं। UI में इसे वास्तविक paid payout से स्पष्ट अलग label करना होगा।

**Audit trail**
- `service_bookings` audit trigger केवल allow-list में status, payment, amount_paid, quote, service/material, assignment और commission fields रखता है। नए timer start/stop request, approval timestamps, actual minutes, cancellation stage/decision, platform fee, cash-cycle count/reservation और wallet debt fields शामिल नहीं हैं।
- `srk_electrician_payouts` और Razorpay refunds पर audit triggers मौजूद हैं। इस inspection में `srk_wallet_ledger` और `srk_wallet_accounts` पर कोई audit trigger नहीं मिला। Wallet ledger को append-only ledger बनाना और हर posting/reversal को actor, source, booking, idempotency key और timestamp सहित audit करना आवश्यक है।
- Status history trigger booking status परिवर्तन दर्ज करता है, लेकिन उससे अलग timer/cancellation/financial sub-events की पूरी history सिद्ध नहीं होती।

**अगले सुधार के लिए blocking requirements**
1. Existing customer cancellation RPC को Master cancellation request + Admin decision state machine में migrate करें; पुराने unassigned cancellation behavior का backward-compatible mapping तय करें।
2. Wallet writes केवल trusted server-side RPC/service path से हों; ledger mutation रोकने, reversal entry से correction और mandatory idempotency key के नियम तय हों।
3. Cash-cycle eligibility, reservation, release-on-failure और Platform Fee due को booking row/account lock के साथ एक transaction में लागू करें।
4. Admin finance report में labour revenue, materials pass-through, platform fee earned/collected/due, cash collection, online settlement, cancellation fees/debt, refunds, payouts, expenses और net profit अलग reconcile हों।
5. वास्तविक customer/electrician JWT, role negative tests, parallel cancellation/payment requests, duplicate webhook, duplicate ledger posting और refund-vs-payout race tests staging में चलें।

**सीमा:** यह Production database catalog, function definitions, grants, RLS policies और triggers का read-only निरीक्षण था। कोई cancellation, wallet, ledger, payout, refund, permission, trigger, function, table, customer record या deployment बदला नहीं।

### 17.25 — Booking/Payment API से Admin UI तक End-to-End mutation path audit (13 Nov 2026)

Feature Branch source inspection; live production API requests या user sessions चलाए नहीं गए:

**Customer Booking API — `create-booking.js`**
- API verified Supabase Customer session और confirmed phone को submitted booking phone से match करता है; यह आवश्यक सुरक्षा check है।
- IP hash आधारित public rate-limit RPC भी लागू है; rate-limit service विफल हो तो API fail-closed होकर booking रोकता है।
- फिर भी API request body से `payment_method` और `quoted_amount` स्वीकार करके service-role key से सीधे `service_bookings` में insert करता है। Browser/client द्वारा भेजी गई कीमत या payment choice को authoritative नहीं मानना चाहिए।
- Service-role insert RLS को bypass करता है; इसलिए API में explicit allow-list, payment-method enum, category/service eligibility, pricing server-side derivation, booking idempotency और client-controlled quote fields को reject/ignore करना जरूरी है।
- Booking insert के बाद trigger-generated job offers पढ़े जाते हैं; offer read विफल होने पर booking पहले से saved रहती है और response इसे स्पष्ट बताता है। Retry पर duplicate booking रोकने के लिए request idempotency अभी अलग से प्रमाणित नहीं है।

**Online Order API — `create-order.js`**
- Customer session, confirmed phone, booking ownership और चुने हुए Razorpay payment method की जाँच होती है।
- प्रति-booking order lock RPC और existing order reuse का प्रयास है; lock के बाद booking दोबारा पढ़कर stale amount रोकने का प्रयास भी है।
- लेकिन पात्रता अभी `status='completed'`, `quote_status='approved'`, `quoted_amount = service_charge + materials_amount` पर आधारित है। यह Master के Customer-approved timer completion और actual-minute labour billing से मेल नहीं खाता।
- इसलिए नया Timer/Billing path बनने तक इस API को नया billing authority नहीं मानना चाहिए। पुराने quote flow हटाने से पहले इसका replacement और duplicate/concurrent order tests जरूरी हैं।

**Payment Verification और Webhook**
- `verify-payment.js` legacy quote-approved completion और quoted amount reconciliation पर निर्भर है; इसे timer-derived amount, payment intent binding, signature verification, amount/currency/booking reconciliation तथा idempotent finalization के साथ बदलना होगा।
- `razorpay-webhook.js` root handler ही वास्तविक webhook logic है; Netlify adapter केवल उसे forward करता है। Signature, event deduplication, order/payment mismatch, out-of-order events और refund-vs-capture race को अलग integration tests से प्रमाणित करना बाकी है।
- किसी webhook retry को duplicate ledger, duplicate payable या duplicate customer receipt नहीं बनाना चाहिए।

**Admin UI — `admin.html`**
- Admin login के बाद `is_srk_admin()` RPC से Admin role check करता है; लेकिन UI सीधे Supabase tables से booking list, application, profile और payout data पढ़ता है।
- Admin booking row पर status और `quoted_amount` को सीधे table UPDATE से बदलता है; address/district/state/PIN भी सीधे UPDATE करता है। Paid booking amount बदलने और Razorpay payment status बदलने पर UI रोक लगाता है, पर direct table mutation का वास्तविक server-side policy/trigger enforcement अलग से परीक्षण योग्य है।
- Manual payment के लिए `srk_admin_record_manual_payment` RPC और payout marking के लिए `srk_admin_mark_electrician_payout_paid` RPC इस्तेमाल होते हैं; यह direct status/payment edit से बेहतर controlled route है।
- Admin payout table में customer/booking phone सहित related profile data दिखाई देता है; Admin-only authorization और least-privilege review जारी रखना होगा।
- Admin UI अभी पुरानी quote राशि संपादित कर सकता है। नए system में timer-approved amount को सीधे edit नहीं करना चाहिए; केवल documented Admin adjustment workflow, reason, before/after और immutable audit event से correction हो।

**API/UI consistency और blocking risks**
1. Customer booking API में client-supplied `quoted_amount` को स्वीकार करना और service-role insert करना server-authoritative pricing के विपरीत है।
2. Payment create/verify अभी quote-based है; इसे actual-minute labour amount, separate materials, 15% labour-only fee और selected payment method से bind करना होगा।
3. Admin UI status/quote direct update कर सकता है; नया lifecycle केवल guarded Admin RPCs से बदले और invalid state transition database में भी reject हो।
4. Booking create, order create, payment verify, webhook capture, cash confirmation, wallet fee posting, payout और refund सभी के लिए एक booking/payment idempotency model और deterministic ledger keys चाहिए।
5. API response, error, logs, notification और browser cache में phone/address/payment identifiers की अनावश्यक वापसी रोकें; प्रत्येक endpoint का auth/role/ownership negative test करें।

**सीमा:** यह Feature Branch source-code inspection था। कोई source file, API, UI, database, payment provider, customer booking, Admin record या deployment नहीं बदला। वास्तविक Netlify runtime secrets, HTTP request tests, Razorpay Test Mode transactions और browser E2E अभी बाकी हैं।

### 17.26 — Master Requirements बनाम वर्तमान Production/Feature Branch: Consolidated Gap List और सुरक्षित कार्य-क्रम (13 Nov 2026)

यह सूची Sections 17.1–17.25 के अब तक के read-only निरीक्षणों का संकलन है। यह implementation-complete प्रमाणपत्र नहीं है। प्रत्येक gap को code, database, API/RPC, UI और staging tests से बंद करना होगा।

#### P0 — सुरक्षा और धन-सुरक्षा के blockers

1. **Completed/terminal booking contact leak:** Customer और Electrician के कई SECURITY DEFINER RPCs completed तथा कुछ rejected/अन्य terminal states में phone लौटाते हैं। दोनों पक्षों के सभी RPC, offer details, UI, receipts/history, cache और API outputs में terminal-state contact removal लागू व negative-tested होना बाकी है। Admin-only contact path अलग सुरक्षित रहे।
2. **Server-authoritative booking price:** `create-booking.js` client-supplied `quoted_amount` स्वीकार करता है और service-role insert करता है। Client amount को reject/ignore कर category, rate, time और allowed options server से derive करने होंगे।
3. **Timer and completion approval:** Server-side timer start/stop request, Customer approval, immutable server timestamps, Admin exception handling और actual-minute calculation अभी पुराने quote/payment flow से end-to-end जुड़े नहीं हैं।
4. **Online payment integrity:** Create-order/verify अभी quote-approved amount पर निर्भर हैं। Timer-derived labour total, अलग materials, 15% labour-only Platform Fee, selected payment method, Razorpay order/payment identity, INR amount/currency, signature और webhook event idempotency को एक authoritative flow में जोड़ना बाकी है।
5. **Wallet/ledger integrity:** Mandatory server-generated non-null idempotency key, append-only posting/reversal, concurrent balance safety, actor/source/booking references और wallet status enforcement लागू व tested होना बाकी है। Client को ledger write privilege नहीं देना है।
6. **Cash fee/cycle:** पहले दो eligible Cash bookings, तीसरी Online requirement, wallet top-up से cycle reset, cash reservation/expiry/release, parallel booking protection और fee due collection का transactional implementation व tests बाकी हैं।
7. **Cancellation and refunds:** Customer request, Admin-only decision, ₹0/₹49/₹99 stage rule, customer debt carry-forward, Electrician wallet debit, SRK cancellation ledger, online refund, partial/full reversal और paid-payout recovery का complete state machine मौजूद होने का प्रमाण नहीं मिला।
8. **Admin mutation control:** Admin UI के direct status/quote edits को guarded server-side commands में बदलना है। Timer-approved amount पर silent direct edit न हो; हर adjustment में reason, before/after, actor और audit event जरूरी हो।
9. **Role/session enforcement:** Customer/Electrician/Admin direct routes, wrong-role, suspended/disabled user, expired session और Admin MFA enforcement का वास्तविक JWT/browser negative test बाकी है। UI hiding अकेले authorization नहीं है।

#### P1 — Core product behavior और operational correctness

10. **Landing page और तीन login roles:** Landing page को एक premium hero image और केवल Customer, Electrician, Admin login actions के अनुरूप बनाना; duplicate Customer OTP implementation हटाने से पहले shared auth/session route test करना।
11. **Customer App:** पाँच bottom menus (Home, My Bookings, Payments, Help & Support, My Profile), authenticated panel, booking history, timer approval, payment state और support history का पूर्ण E2E verification बाकी।
12. **Electrician App:** Home, New Booking Offers, My Work/Bookings, Earnings & Wallet, Profile/ID और Help & Support; verified category, unique digital ID, offer acceptance और completed-state contact/data removal का पूर्ण verification बाकी।
13. **Smart Matching:** Approved skill/category, nearest eligible available Electrician, no automatic category downgrade/upgrade, offer progression, expiry और concurrent acceptance tests बाकी।
14. **Labour/material separation:** Customer labour billing और 15% Platform Fee को materials से अलग रखना; customer-supplied material default, exceptional electrician-supplied material के लिए prior approval और itemized receipt लागू व tested होना बाकी।
15. **Cash/online selection:** Customer की चुनी payment method को server पर persist करना; silent switching रोकना और हर failure/retry पर वही choice सुरक्षित रखना।
16. **Support and ratings:** Customer/Electrician Help & Support messages, attachments, Admin replies/history और दोनों तरफ one-per-real-booking 1–5 rating, moderation/audit की implementation व access tests बाकी।
17. **Admin finance/accounting:** Labour revenue, materials pass-through, Platform Fee earned/collected/due, Cash collected, online settlement, cancellation fee/debt, refunds/reversals, payout paid/pending, expenses और actual net profit अलग-अलग reconcile करने हैं। मौजूदा dashboard को पूर्ण profit report न माना जाए।
18. **Company expenses और receipts:** Expense categories, attachment/receipt, approval, reports तथा ledger reconciliation का पूर्ण परीक्षण बाकी।
19. **Emergency Control Panel और staff permissions:** Booking/service/payment pause, Electrician block/unblock, suspicious-account restrictions, granular View/Add/Edit/Manage permissions, staff task/deadline/activity और Admin audit का implementation व negative tests बाकी।

#### P0/P1 के लिए shared technical prerequisites

20. **Migration history reconciliation:** Production history 81 entries बनाम Feature Branch में 21 local migration files; केवल 5 exact version matches की शुरुआती तुलना। 14 branches में 40 Production names के same-name candidates मिले, 41 exact filenames नहीं मिले; तीन matched names में divergent SQL blobs भी मिले। हर remote migration के लिए source, content hash, applied effect और dependency order प्रमाणित किए बिना कोई replay/reset/squash/apply नहीं।
21. **Backward-compatible data model:** Existing quote, payment, payout, refund और audit history सुरक्षित रखकर नए timer/actual-minute model की additive migration और dual-read/transition plan बनाना। Historical rows को नए rules से दोबारा calculate या overwrite न करना।
22. **Audit coverage:** Timer events, actual minutes, approvals, fee calculations, cash-cycle reservation/count, wallet posting/reversal, cancellation stage/decision, refund, payout और Admin adjustment को append-only audit/event history में जोड़ना।
23. **RLS/ACL/SECURITY DEFINER:** सभी exposed functions की identity, ownership, assignment, role, status predicates, fixed search_path, PUBLIC/anon/authenticated/service_role grants और direct-table grants की समीक्षा। Blanket revoke/grant नहीं।
24. **Privacy sweep:** Edge Functions, Netlify adapters, Realtime, Storage, push payloads, receipts, exports, logs, service worker/browser cache, local/session storage और Admin screens में phone/address/location/payment secrets की जरूरत-आधारित access जाँच।
25. **Deployment architecture cleanup:** Netlify primary path और Vercel/GitHub Pages remnants के active references/integrations पहले map हों। कोई alternate deployment/workflow हटाने से पहले branch, domain, webhook, secret और rollback dependencies प्रमाणित हों।

#### अनिवार्य क्रम — बिना Production परिवर्तन के

A. **Inventory freeze:** Production migration history, live schema/functions/triggers/policies/grants और Feature Branch source के reproducible snapshots/hash सुरक्षित करें; migration discrepancy सूची पूर्ण करें।  
B. **State-machine specification:** Booking, offer, timer, payment, cash-cycle, wallet, cancellation, refund और payout के valid states/transitions तथा actor permissions लिखित रूप में तय करें।  
C. **Additive implementation:** Feature Branch में server-side calculation और नए RPC/API contracts; पुरानी quote path को अभी न हटाएँ।  
D. **Isolated test environment:** Migration source reconciliation के बाद ही अलग staging/Test Mode पर लागू करें। कोई paid Supabase branch/resource बिना लागत बताए और अनुमति लिए न बनाएँ।  
E. **Automated tests:** Unit, integration, RLS/JWT negative tests, concurrency/locking, duplicate/reordered webhook, duplicate ledger posting, refund-vs-payout race और historical-data regression।  
F. **UI/E2E:** तीनों roles के mobile/desktop flows, contact privacy before/after completion, OTP/session, timer approvals, Cash/Online, receipts, support और Admin emergency controls।  
G. **Release gate:** Security/Performance/Health advisors, migration diff, financial reconciliation, rollback plan और सभी critical tests पास होने के बाद ही अलग से explicit Production approval माँगें। एक consolidated Netlify production deployment से पहले कोई production cutover नहीं।

**अभी की स्थिति:** यह consolidated gap analysis और sequencing है। किसी gap को इस दस्तावेज़ में लिख देने से वह implemented नहीं हो जाता। Production database, live payment provider, user records, app source behavior और deployment में इस चरण पर कोई बदलाव नहीं किया गया।

### 17.27 — Production Migration History बनाम वर्तमान Feature Branch: पुनःगणना और lineage blockers (13 Nov 2026)

इस चरण में Supabase Production migration history को दोबारा पढ़कर वर्तमान Feature Branch के वास्तविक `supabase/migrations` tree से version-level तुलना की गई। यह read-only reconciliation है।

**पुनः सत्यापित गिनती**
- Production migration history: **81 entries**।
- वर्तमान Feature Branch tree: **21 SQL migration files** (पिछले 21-file snapshot से मेल; earlier rough note में दिखी 23 संख्या tree parse की गलती थी, सही count 21 है)।
- Exact 14-digit version match: केवल **5** — `20261108120608`, `20261108120658`, `20261108121115`, `20261109103038`, `20261109103143`।
- Production history की **76 entries** के लिए इस branch में उसी exact version वाला SQL file नहीं मिला।
- Branch के 21 files में 2 legacy filenames में 14-digit prefix नहीं है; शेष 19 में से **16 versions** Production history में exact version के रूप में नहीं मिले।
- Production history में एक ही migration name `add_assigned_electrician_cash_payment_status` दो अलग versions पर है: `20261111082515` और `20261111083811`। यह duplicate name अपने आप duplicate SQL या safe no-op सिद्ध नहीं करता; दोनों के applied effects अलग से reconstruct करने होंगे।

**Exact version overlap का अर्थ**
- ये पाँच version matches केवल version/name alignment दिखाते हैं; Production में लागू SQL body और Feature Branch file content की equivalence अपने आप सिद्ध नहीं होती।
- Production migration history में SQL source body उपलब्ध नहीं है। इसलिए history row को source-of-truth SQL मानना या उसी नाम वाली दूसरी branch file को exact source मान लेना सुरक्षित नहीं।
- पहले 14-branch sweep में 40 Production migration names के same-name candidates किसी न किसी branch में मिले थे; 41 exact filenames उस sweep में नहीं मिले। उस sweep में 3 matched names के अलग-अलग Git blob SHA भी मिले थे। यह cross-branch filename discovery है, Production-applied SQL equivalence का प्रमाण नहीं।

**ताज़ा blockers**
1. 76 remote version entries की exact source recovery या applied-schema-effect reconstruction आवश्यक है।
2. दो duplicate-name cash-payment versions के लिए दोनों version-specific SQL bodies, commit ancestry और resulting function/constraint/trigger state का मिलान आवश्यक है।
3. बिना timestamp वाली दो Feature Branch migration filenames की CLI/parser compatibility और migration-history behavior अलग जाँचना होगा; उन्हें मनमाने timestamp से rename नहीं करना।
4. Feature Branch-only cash-cycle, labour-only material separation, customer payment choice, explicit cash-to-online switch और cash-fee settlement migrations Production history में exact version से अनुपस्थित हैं। ये branch files अभी Production में लागू नहीं मानी जाएँगी; इनके SQL body, dependencies, tests और Master policy compatibility का review बाकी है।
5. Remote history में मौजूद migration के लिए source नहीं मिलने पर live schema से अनुमान लगाकर पुरानी migration को दोबारा चलाना नहीं। पहले schema effect, object definitions, grants, data impact और dependencies का evidence pack बनाना होगा।

**सुरक्षित निष्कर्ष**
- Production migration history को reset, squash, rebase या replay नहीं करना।
- Existing remote migration rows को delete/rename/repair नहीं करना।
- Production पर कोई migration apply नहीं करना।
- नई migration file अभी नहीं बनाई गई; Supabase CLI migration generator उपलब्ध नहीं है, और सही CLI workflow के बिना timestamp/file format गढ़ना मना है।
- अगला सुरक्षित काम: 76 remote-only versions के नामों को cross-branch source candidates, Git commit ancestry, blob SHA और live schema object changes से एक-एक करके map करना; पहले highest-risk security/contact/payment migrations की lineage पूरी करना।

**सीमा:** Production पर केवल migration history read की गई और GitHub Feature Branch tree पढ़ा गया। कोई migration apply/repair/delete/rename नहीं हुई; कोई schema/data/auth/payment/deployment बदलाव नहीं हुआ।

### 17.28 — 14 Branches में Migration Source Recovery का दूसरा sweep (13 Nov 2026)

Production के 81 migration records को repository की सभी 14 उपलब्ध branches के migration trees से दोबारा मिलाया गया। यह filename/version discovery है; SQL equivalence या Production में वही body apply होने का प्रमाण नहीं।

**नया cross-branch परिणाम**
- Exact 14-digit version वाली source file **13/81** Production records के लिए मिली। पहले current Feature Branch में केवल 5 exact matches थे; अन्य branches में 8 अतिरिक्त exact-version candidates मिले।
- समान migration name वाली कोई source candidate **38/81** records के लिए मिली (इनमें exact-version records भी शामिल हैं)।
- कुल **43/81** Production migration names के लिए 14 scanned branches में exact version या same-name candidate नहीं मिला।
- इसलिए “76 source files गायब” कहना सटीक नहीं: 76 का अर्थ केवल current Feature Branch में exact version absent था। Cross-branch sweep के बाद 13 exact-version candidates, 38 same-name candidates (overlap सहित), और 43 पूर्णतः unmatched names हैं।
- यह 14-branch scan वर्तमान GitHub branch set पर आधारित है; deleted branches, tags, forks, private backups या developer local clones इसमें शामिल नहीं हैं।

**विशेष lineage जोखिम**
1. `20261111082515_add_assigned_electrician_cash_payment_status` का exact-version SQL केवल `feature/production-push-notifications` में मिला। Production में उसी नाम की दूसरी version `20261111083811` का अलग exact-version source नहीं मिला। इसलिए दूसरी migration का प्रभाव अलग से live function/trigger/constraint definition और commit history से reconstruct करना होगा।
2. `20261110080448_srk_business_finance_dashboard` के same exact-version नाम के दो अलग Git blobs मिले: `69f15bf8...` और `b479f89c...`। दोनों का SQL content अलग हो सकता है; किसी एक को Production source मानना अभी सुरक्षित नहीं।
3. `20261111043852_srk_business_finance_reporting_dates` के लिए भी दो अलग blobs मिले: `3166714b...` और `d1224b3f...`। Production-applied body प्रमाणित नहीं।
4. `20261111072823_add_electrician_push_subscriptions` के same-name candidates दो अलग timestamps और blobs पर हैं: `20261111020000` blob `33ea8450...`, तथा `20261111090000` blob `831485c5...`। दोनों में SQL difference और live applied effect का मिलान जरूरी।
5. `20261109161539_customer_contact_after_completion` और अन्य कुछ records के लिए same-name source केवल अलग timestamp पर मिली। नाम समान होना migration identity या exact SQL equivalence नहीं है।

**अगला recovery batch**
- पहले तीन divergent same-name migrations के दोनों blobs fetch करके SQL diff और object-by-object effect matrix बनाना।
- फिर exact-version candidates के Git commit ancestry और production live object definitions की तुलना।
- जिन 43 names के candidates नहीं मिले, उनके लिए commit history, alternate repository references और schema effects की targeted खोज; बिना source के historical migration replay नहीं।
- सभी recovered SQL को केवल evidence archive/analysis में रखना; Production में apply नहीं करना।

**स्थिति:** कोई migration apply, delete, rename, repair या reset नहीं हुई। कोई Production schema/data/payment/auth change नहीं। Feature Branch में केवल यह documentation section जोड़ा गया।

### 17.29 — Divergent Migration SQL blobs बनाम Live Production object evidence (13 Nov 2026)

17.28 में मिले तीन divergent migration families के छह SQL blobs पढ़े गए और Push Subscription के live Production columns/constraints/policies का read-only catalog snapshot लिया गया।

**A. `20261110080448_srk_business_finance_dashboard` — दो अलग SQL bodies**
- Blob `69f15bf8...`: private expense table, Admin expense add/list और dashboard functions बनाता है। Expense add function में `p_category NOT IN (...)` check है, पर explicit `p_category IS NULL` guard नहीं है; SQL NULL के कारण यह validation branch bypass हो सकती है।
- Blob `b479f89c...`: उसी feature का reproducible baseline है; इसमें explicit `p_category IS NULL` rejection मौजूद है। Dashboard calculation मूलतः paid+completed bookings, customer gross, platform commission, electrician share, payout paid/pending और expenses पर आधारित है।
- दोनों blobs को एक migration name/version के तहत मिला है; Production में लागू exact body अभी निश्चित नहीं। Live function hashes catalog snapshot में दर्ज हुए, लेकिन इस चरण पर source-to-live byte-level equivalence प्रमाणित नहीं की गई।
- सुरक्षा निष्कर्ष: `b479...` में category NULL validation बेहतर है, पर यह अपने आप Production source सिद्ध नहीं करता। Live function definition को पूर्ण रूप से fetch/hash compare करना आवश्यक है।

**B. `20261111043852_srk_business_finance_reporting_dates` — दो अलग SQL bodies**
- Blob `3166714b...`: India-local reporting date boundaries, booking-created count, paid payout को `paid_at` date से गिनना, pending payout को created date से गिनना, expense/index support और expense input length validations जोड़ता है।
- Blob `d1224b3f...`: reporting dashboard function का अलग source है; इसमें India-local date handling, bookings-created और payout paid_at date logic है, पर expense-date/recorded_by/paid_at indexes तथा expense function validations वाला पूरा बदलाव इसमें नहीं है। Comment इसे intermediate reporting calculation बताता है।
- दोनों bodies अलग हैं; सही क्रम और Production में कौन-सा हिस्सा लागू है, इसे migration timestamps के बजाय live definitions/index catalog और commit ancestry से तय करना होगा।

**C. `20261111072823_add_electrician_push_subscriptions` — दो अलग SQL bodies**
- Blob `33ea8450...` (branch timestamp 02:00): endpoint 20–4096, p256dh 20–256, auth 10–128, optional user_agent; एक broad own-row `FOR ALL` policy; authenticated CRUD grants।
- Blob `831485c5...` (branch timestamp 09:00): endpoint 1–2048, p256dh/auth 1–256; अलग SELECT/INSERT/UPDATE/DELETE own-user policies; user_agent column नहीं।
- Live Production `public.srk_push_subscriptions` में endpoint 1–2048, p256dh/auth 1–256 constraints, user_agent column अनुपस्थित, और चार अलग own-user policies मौजूद हैं। यह live structure दूसरे blob `831485c5...` के design से मेल खाता है; लेकिन Production migration version `20261111072823` है, जबकि source candidate filename `20261111090000` है। यह schema-effect corroboration है, exact applied migration identity का प्रमाण नहीं।
- Live table columns/constraints/policies केवल catalog से पढ़े गए; push subscription records या endpoint/token values नहीं पढ़े गए।

**अगली प्राथमिकता**
1. Live `srk_admin_finance_dashboard`, `srk_admin_finance_add_expense`, `srk_admin_finance_list_expenses` की पूर्ण `pg_get_functiondef` को recovered SQL bodies के साथ compare करना।
2. Reporting indexes और payout date semantics को `pg_indexes`/function body से verify करना।
3. Push subscription lineage को live schema corroboration के साथ mark करना, पर remote migration history को rewrite नहीं करना।
4. दोनों cash-payment migration versions के function/constraint/trigger effects अलग-अलग reconstruct करना।

**सीमा:** केवल GitHub blob contents और Production system catalogs पढ़े गए। कोई SQL apply नहीं, कोई function/table/policy/index बदला नहीं, कोई push token/PII record नहीं पढ़ा, कोई deployment नहीं।

### 17.30 — Finance Migration की Live Function Definitions और Indexes से तुलना (13 Nov 2026)

Production पर केवल catalog definitions और index metadata पढ़कर recovered migration candidates से तुलना की गई।

**1. Expense Add Function**
- Live `srk_admin_finance_add_expense` में `p_category IS NULL` guard मौजूद है।
- यह कमजोर पुराने candidate blob `69f15bf8...` से अलग और मजबूत candidate blob `b479f89c...` तथा reporting hardening blob `3166714b...` के validation behavior से मेल खाता है।
- Live function में amount, description, provider, reference और notes length checks भी मौजूद हैं; ये reporting hardening source में हैं।
- निष्कर्ष: Live function behavior reporting hardening candidate के साथ corroborate होता है; लेकिन remote migration record का exact SQL source अभी भी केवल history row से प्रमाणित नहीं किया जा सकता।

**2. Finance Dashboard**
- Live `srk_admin_finance_dashboard` में Asia/Kolkata date boundaries, `bookings_created`, paid payout को `paid_at` से गिनना और pending payout को `created_at` से गिनना मौजूद है।
- Live body recovered `3166714b...` reporting-date migration के मुख्य calculation से मेल खाती है; यह intermediate `d1224b3f...` से आगे का payout/date calculation है।
- Live dashboard अब भी legacy fields `amount_paid`, `commission_amount`, `service_charge`, `commission_rate` पर आधारित है। `net_profit = platform_commission - total_expenses`; cancellation, wallet fee due/collection, cash settlement, refunds/reversals और materials pass-through का पूरा ledger reconciliation इसमें शामिल नहीं।
- `electrician_share` gross customer payment minus commission है; इसे actual payout paid नहीं समझना चाहिए। Dashboard के अलग payout fields ही payout table से आते हैं।

**3. Live Index Evidence**
- `private.srk_business_expenses`: `expense_date DESC` और `recorded_by` indexes मौजूद।
- `public.srk_electrician_payouts`: partial `paid_at DESC` index मौजूद, केवल paid rows और non-null paid_at पर।
- साथ में payout booking unique, electrician profile, paid_by और status/created_at indexes मौजूद।
- ये indexes recovered reporting migration के index definitions से मेल खाते हैं।

**4. ACL/Execution safety boundary**
- इस audit में function body और index definitions पढ़े गए। कोई function call/expense insert नहीं किया गया।
- पहले के ACL snapshot में Finance RPCs Admin guard के साथ SECURITY DEFINER और authenticated EXECUTE थे; इस चरण में grants बदलने या व्यापक रूप से revoke करने का कोई कारण नहीं मिला।
- Runtime Admin/non-Admin JWT negative tests अभी आवश्यक हैं।

**Migration lineage निष्कर्ष**
- Finance dashboard/expense reporting के लिए recovered SQL और live object behavior में मजबूत corroboration है; `3166714b...` सबसे अच्छा available source candidate है।
- इसे remote migration history की exact applied-body proof या migration history repair authorization नहीं माना जाए।
- कमजोर/पुराने finance blob को Production में दोबारा चलाना या history rows बदलना आवश्यक/अनुमत नहीं।

**अगला चरण:** cash-payment status की दोनों Production migration versions (`20261111082515`, `20261111083811`) के source, function bodies, constraints और triggers का अलग-अलग प्रभाव map करना; साथ ही finance RPCs के Admin/non-Admin JWT tests को staging में plan करना।

**सीमा:** Production पर केवल `pg_get_functiondef` और `pg_indexes` metadata read हुआ। कोई function, index, grant, row, migration history, payment या deployment बदला नहीं।

### 17.31 — Duplicate Cash Payment Status migrations: Live Function, Trigger, Constraint और ACL audit (13 Nov 2026)

Production migration history में एक ही नाम की दो entries हैं:
- `20261111082515_add_assigned_electrician_cash_payment_status`
- `20261111083811_add_assigned_electrician_cash_payment_status`

**Source recovery**
- 14-branch sweep में केवल पहली version के लिए exact-version candidate मिली: `feature/production-push-notifications/supabase/migrations/20261111082515_add_assigned_electrician_cash_payment_status.sql`, blob `091b1176...`।
- इस SQL में `public.srk_get_my_assigned_cash_payment(uuid)` function बनता/बदलता है। यह authenticated approved+active electrician की assigned booking जाँचता है और Cash confirmation की eligibility बताता है। यह legacy `status='completed'`, `quote_status='approved'`, Cash payment method और positive `quoted_amount` पर निर्भर है।
- दूसरी version `20261111083811` के लिए exact-version या same-name SQL source उपलब्ध scanned branches में नहीं मिला। इसका अलग SQL effect अभी recover नहीं हुआ। दोनों versions का एक ही नाम होना duplicate history entries की व्याख्या नहीं करता।

**Live Production functions**
1. `srk_get_my_assigned_cash_payment(uuid)`
   - SECURITY DEFINER, owner postgres, fixed search_path.
   - `auth.uid()` से linked approved+active electrician profile ढूँढता है।
   - Booking पर `assigned_electrician_id` match करता है।
   - Response में status, payment method/status, quote status, quoted amount और `can_confirm_cash` देता है।
   - Eligibility अभी भी completed + approved quote + Cash + unpaid/pending + positive quoted_amount पर आधारित है।
2. `srk_electrician_confirm_cash_payment(uuid)`
   - SECURITY DEFINER, owner postgres, fixed search_path.
   - Linked approved+active electrician और उसी की assigned booking की जाँच करता है; booking row `FOR UPDATE` lock होती है।
   - केवल completed + approved quote + Cash + unpaid/pending + positive quoted_amount स्वीकार करता है।
   - `payment_status='paid'`, `amount_paid=quoted_amount`, `payment_verified_at=now()` लिखता है।
   - पहले से paid होने पर idempotent-style already_paid response देता है; यह उसी row पर repeat confirmation रोकता है।
   - Actual-minute/timer-approved billing amount का उपयोग नहीं करता।
3. दोनों functions पर PUBLIC/anon execute नहीं; authenticated और service_role execute मौजूद। Runtime JWT role tests अभी बाकी हैं।

**Live trigger और constraint प्रभाव**
- `srk_calculate_booking_commission` BEFORE INSERT/UPDATE trigger: completed + paid होने पर commission `service_charge × commission_rate` से निकालता है; अन्यथा commission null करता है।
- `trg_srk_create_electrician_payable` AFTER payment/status/quote/amount/assignment/payment-verification बदलाव पर payout trigger चलाता है। यह completed + paid + approved quote + verified payment + Razorpay/manual payment evidence मांगता है; total को service_charge + materials_amount से मिलाता है; electrician payable में materials जोड़ता है और commission केवल service_charge पर लगाता है।
- `service_bookings_payment_status_check` में allowed states: unpaid, pending, paid, refunded, failed।
- अलग payment_method check constraint इस catalog query में नहीं मिला।
- Cash confirmation update के बाद commission और payable triggers fire हो सकते हैं; payout creation के लिए manual payment evidence की exact shape/amount match भी आवश्यक है। इस वजह से Cash confirmation, manual-payment record और payout ledger को साथ में integration-test करना होगा।

**Master Requirements से mismatch**
- Cash confirmation actual timer minutes से निकली approved labour amount पर आधारित नहीं।
- Legacy quote approval अनिवार्य है।
- Customer द्वारा Cash amount electrician को देने और उसके बाद electrician द्वारा app में receipt confirmation के लिए independent evidence/reconciliation अभी स्पष्ट नहीं।
- Cash cycle के पहले दो eligible Cash bookings, तीसरे Online booking, wallet top-up द्वारा fee due clear/reset और concurrent reservation/release का कोई logic इन दो functions में नहीं है।
- Platform Fee 15% labour-only policy का नया timer-based calculation यहाँ लागू नहीं।
- Cash paid state से payout trigger का legacy path quote + service/material total पर निर्भर है।

**Migration निष्कर्ष**
- पहली migration का source candidate live `srk_get_my_assigned_cash_payment` function के साथ conceptually मेल खाता है।
- दूसरी duplicate migration का source/effect unresolved है। Current live function bodies से यह निश्चित नहीं किया जा सकता कि दूसरा migration no-op था, function update था या अन्य object change।
- इसलिए migration history repair, replay, delete या rename नहीं किया जाएगा। अगला कदम Git commit ancestry/PR references और live schema object chronology से दूसरी version का source/effect खोजना है।

**सीमा:** Production पर केवल function definitions, ACL, service_bookings constraints और trigger definitions पढ़े गए। कोई Cash booking/payment row, payout record, wallet record या customer PII नहीं पढ़ा; कोई function execute, SQL apply, grant change, migration-history edit या deployment नहीं हुआ।



## 17.32 — Feature Branch Cash Cycle और Platform Fee Ledger: source-level audit (13 Nov 2026)

यह जाँच केवल Feature Branch `feature/platform-fee-cash-online-cycle` के source/migrations की है। नीचे वर्णित migrations Production में लागू होने का प्रमाण नहीं हैं। Production का live Cash confirmation path Section 17.31 में दर्ज legacy quote-based path ही है। कोई migration apply, SQL execution, payment, wallet mutation या deployment नहीं किया गया।

### मिले हुए Feature Branch source
- `20261112170000_enforce_electrician_third_booking_online_payment.sql` (blob `5cd370a996195056222044c9c9568ed2ca148962`) `srk_respond_to_offer` को बदलता है। यह electrician profile row lock लेकर उसी electrician के offer acceptance को serialize करता है; prior count केवल `completed + quote approved + paid + payment_verified_at` bookings का है। तीसरे slot पर Online payment method अनिवार्य करता है।
- `20261112220000_cash_platform_fee_due_and_online_settlement.sql` (blob `5d4245451ee104eb2e8a26251cc4ed6359ee9ba6`) `srk_platform_fee_ledger` बनाता है; non-null unique idempotency keys, cash_due/online_fee/settlement/reversal entry types और electrician-level advisory transaction lock जोड़ता है। Cash पर fee due; Online पर current fee और पुराने due को electrician payable से समायोजित करने का प्रयास है। Payout में `previous_platform_fee_settled` field जोड़ा जाता है।
- `20261113120000_limit_cash_fee_settlement_to_labour_share.sql` (blob `34360879d1670bb63515be406f2077fccdd2bdc8`) पुराने Cash due की वसूली को `v_service - v_current_fee` तक सीमित करता है, ताकि customer-supplied materials से पुराने dues न काटे जाएँ। यह Master के materials-exclusion नियम के अनुरूप सुधार है।
- Feature Branch के Electrician UI में Cash Platform Fee due और wallet summary दिखाने के लिए `srk_get_my_platform_fee_summary` call मौजूद है। Customer UI में ग्राहक स्वयं Cash से Online चुन सकता है और `srk_customer_change_payment_method` RPC call करता है।
- Current Feature Branch migration tree में संबंधित अतिरिक्त files: `20261112230000_show_customer_payment_choice_to_assigned_electrician.sql`, `20261113090000_customer_can_explicitly_switch_cash_booking_to_online.sql`; इनका भी full dependency/security review बाकी है।

### महत्वपूर्ण blockers / defects जिन्हें staging tests से पहले सुधारना होगा
1. **तीसरे booking rule का count acceptance reservation नहीं है।** यह केवल पहले से completed+paid+verified bookings गिनता है। दो concurrent accepted-but-not-yet-completed bookings को cycle slots में reserve नहीं करता। इसलिए actual sequence acceptance-time reservation के बजाय completion-time history पर निर्भर हो सकता है। Profile row lock offer acceptance को serialize करता है, लेकिन count में pending assigned bookings शामिल नहीं हैं।
2. **Cash cycle eligibility की परिभाषा अधूरी है।** Migration comments कहती हैं कि cancelled, failed, refunded और unpaid/incomplete bookings slot नहीं खातीं; पर exact Master rule के लिए eligible booking, acceptance reservation, release, cancellation और refund पर slot पुनः उपलब्ध होने का authoritative state/ledger स्पष्ट नहीं है। केवल completed+paid count cancellation/failed/refund history और पुनः booking sequence को deterministic रूप से नहीं संभालता।
3. **Wallet top-up से cycle reset का path प्रमाणित नहीं।** उपलब्ध acceptance migration में wallet top-up या outstanding fee clear होने पर cash eligibility reset करने की कोई जाँच नहीं दिखती। यह Master rule का blocker है।
4. **Cash fee posting अभी quote-era fields पर निर्भर है।** Trigger `completed + quote_status=approved + amount_paid=service_charge+materials_amount` और `commission_rate` इस्तेमाल करता है। Actual-minute timer-approved labour amount, immutable timer approval और 15% fixed Master fee को लागू नहीं करता।
5. **Refund reversal pooled balance पर आधारित है।** Online settlement पुराने Cash dues को pooled amount में घटाता है; refund के समय specific due-to-settlement allocation नहीं है। बाद में settled Cash booking refund को block करके Admin reconciliation माँगना सुरक्षित fail-closed व्यवहार है, पर पूर्ण automatic refund/reversal workflow नहीं।
6. **Cash receipt evidence और trigger provenance अधूरे हैं।** Trigger `auth.uid()` को `created_by` देता है; webhook/service-role context में actor null हो सकता है। Cash payment receipt verification, electrician/customer confirmation, Admin evidence, source actor और immutable receipt proof को स्पष्ट रूप से map करना बाकी है।
7. **Payout reconciliation risk।** Payout row पर `ON CONFLICT (booking_id) DO UPDATE` pending payout को बदल सकता है। Refund, repeated webhook, existing payout और concurrent state changes पर regression tests चाहिए। पहले से paid payout पर refund block है; Admin recovery path अलग चाहिए।
8. **RPC grants/RLS/ledger immutability का पूर्ण प्रमाण अभी नहीं।** Ledger पर client grants revoke और RLS enable दिखते हैं, पर append-only enforcement trigger, SELECT policy, Admin visibility, RPC ACL, trigger execution role और runtime JWT negative tests की पुष्टि आवश्यक है।
9. **Payment method string comparison brittle है।** Acceptance rule exact `Razorpay ऑनलाइन भुगतान` string compare करता है, जबकि अन्य जगह Cash/Online पहचान substring से होती है। Canonical enum/constraint और legacy normalization आवश्यक है।
10. **Customer-initiated Cash→Online switch eligibility path।** UI में customer choice है, लेकिन RPC को server-side booking ownership, unassigned/assigned stage, third-slot enforcement, payment order creation race, audit और idempotency के साथ validate करना होगा। UI permission अकेले पर्याप्त नहीं।

### अगला सुरक्षित काम
- दूसरे duplicate Production migration version `20261111083811` का source/commit/PR ancestry खोज जारी रखें; अभी कोई source प्रमाणित नहीं।
- सभी cash-cycle और wallet migrations को Feature Branch तथा अन्य branches में क्रम/SQL/blob के आधार पर पढ़ें; इन्हें Production implementation न मानें।
- नई timer/actual-minute billing और cash-cycle reservation ledger को एक state machine में design करें: acceptance पर atomic slot reservation; deterministic idempotency; cancellation/offer expiry/rejection/refund पर reservation release; top-up द्वारा fee due clear होने पर documented reset; तीसरे eligible slot पर Online enforcement।
- Cash/Online receipt, 15% labour-only fee, materials exclusion, wallet settlement, payout, refunds और audit को एक ही transactional server path में reconcile करें।
- पहले isolated staging/Test Mode में concurrency, duplicate webhook, retries, failed payment, cancellation, refund, wallet top-up, due settlement, paid payout recovery और cross-user authorization tests चलाएँ। Staging resource/charges के लिए अलग अनुमति आवश्यक है।

**निष्कर्ष:** Feature Branch में Cash Platform Fee ledger और third-booking Online enforcement का प्रारंभिक ढाँचा मौजूद है, लेकिन यह Master Requirements के लिए अभी complete या production-ready नहीं है। मुख्य P0 gap acceptance-time cycle reservation, wallet top-up reset, timer-based labour calculation और पूर्ण refund/ledger reconciliation हैं। Production untouched है।


## 17.33 — Cash Payment migration ancestry और Customer Payment Choice RPC audit (13 Nov 2026)

### Duplicate Production migration version 20261111083811 — ancestry परिणाम
- GitHub repository commit search में exact version `20261111083811`, migration नाम `add_assigned_electrician_cash_payment_status`, और cash-payment संबंधी commit-message terms के लिए कोई matching commit नहीं मिला।
- GitHub REST path-history query में भी exact filename/path का commit result नहीं मिला। यह परिणाम केवल उपलब्ध repository/connector search scope का है; इससे यह सिद्ध नहीं होता कि migration कभी बनी ही नहीं। Production migration history में version मौजूद है, इसलिए उसका applied effect unresolved ही रहेगा।
- इस समय पहले version `20261111082515` का source ही मिला है। दूसरे version को no-op, duplicate body या harmless migration मानना उचित नहीं। अगला source recovery route: Supabase migration metadata के साथ deployment logs/PR refs/commit tree snapshots और live object chronology का correlation; उपलब्ध प्रमाण से बाहर अनुमान नहीं।

### Customer Payment Choice migrations का source review
1. `20261112230000_show_customer_payment_choice_to_assigned_electrician.sql` (blob `76f9ed88b2bef99943f70ddf0ec2dda6cc8169ab`) `srk_get_my_offer_details()` को drop/recreate करता है और electrician को assigned booking का payment_method दिखाता है। लेकिन recreated function में booking status पर कोई active/terminal allow-list नहीं है। यह name/phone/address/coordinates के पुराने response behavior को भी जारी रखता है; इसलिए completed/cancelled/quote_rejected booking पर contact/location response बंद करने का Master privacy नियम इस migration से पूरा नहीं होता। यह Section 17.8–17.13 के completed-contact exposure से जुड़ा P0 blocker है।
2. `20261113090000_customer_can_explicitly_switch_cash_booking_to_online.sql` (blob `3a26f7741751707b8854b38066505a0ae0b611b7`) SECURITY DEFINER RPC customer ownership, `auth.uid()`, unassigned + new/confirmed status, unpaid/pending, no Razorpay order/payment और Cash-origin checks लगाता है; explicit Online choice ही स्वीकार करता है, payment शुरू नहीं करता। यह अच्छा ownership/locking आधार है।
3. इस RPC में explicit customer choice को सही तरह preserve किया गया है, लेकिन RPC स्वयं electrician cycle eligibility की गणना नहीं करता। यह third-booking enforcement को `srk_respond_to_offer` पर छोड़ता है। इस separation का race/state test जरूरी है: Customer switch और electrician offer acceptance एक साथ हों, दो offers parallel accept हों, या order creation switch के बीच शुरू हो।
4. Customer choice RPC में dedicated audit event/actor/source field की पुष्टि इस source से नहीं होती। Booking row update का generic audit trigger पर्याप्त है या नहीं, उसके allow-list/actor payload की अलग जाँच जरूरी है।
5. दोनों migrations केवल Feature Branch sources हैं। Production में लागू होने का कोई प्रमाण नहीं; live Production migration history में इन exact versions की पुष्टि अलग से करनी होगी।

### निष्कर्ष और अगला कदम
- दूसरे duplicate Cash migration version का source अभी unresolved है; कोई SQL replay या migration-history repair नहीं।
- Customer payment-method switch RPC में ownership/state guards हैं, पर third-slot eligibility server path और race/idempotency परीक्षण बाकी हैं।
- Assigned electrician offer-details RPC में terminal booking contact/location leakage बना रहता है; Customer Payment Choice UI जोड़ने के नाम पर इस privacy defect को स्वीकार नहीं किया जा सकता। अगली implementation में payment_method को सुरक्षित field के रूप में expose करें, पर customer phone/address/coordinates केवल assigned active booking तक सीमित करें और completed/cancelled/rejected/unassigned पर null/omit करें।
- कोई Production DB/API/UI/payment/deployment change नहीं किया गया। यह केवल source audit और documentation है।


## 17.34 — Cash Cycle / Wallet Top-up: Live Production Function Inventory और Migration Commit-History Recheck (13 Nov 2026)

### Migration source / history
- Exact Production migration version `20261111083811` के लिए repository path `supabase/migrations/20261111083811_add_assigned_electrician_cash_payment_status.sql` की GitHub commit-path history query खाली लौटी। इससे केवल यह सिद्ध होता है कि queried repository path पर commit history नहीं मिली; किसी अन्य filename, deleted branch, fork, backup या Supabase dashboard SQL editor में source होने की संभावना इससे समाप्त नहीं होती।
- Repository-wide commit-text search में exact version और migration name के लिए कोई commit result नहीं मिला। GitHub code search इस जाँच में Feature Branch या सभी historical branches का भरोसेमंद पूर्ण प्रमाण नहीं दे पाया; इसे “कहीं भी source नहीं” का अंतिम प्रमाण न माना जाए।
- Migration #2 का applied effect अभी unresolved है। Production history record को हटाना, rename करना, no-op मानना या दूसरी बार SQL replay करना निषिद्ध रहेगा जब तक उसका SQL body और live effect प्रमाणित न हो।

### Live Production function inventory (read-only)
- `public.srk_electrician_confirm_cash_payment(uuid)` अभी भी completed + approved legacy quote + Cash method + unpaid/pending + positive `quoted_amount` पर निर्भर है। यह booking row lock करता है, payment_status paid और amount_paid quoted_amount करता है; timer actual-minute amount, cash-cycle slot reservation या wallet Platform Fee settlement नहीं करता।
- `public.srk_get_my_assigned_cash_payment(uuid)` वही legacy quote/quoted_amount eligibility electrician को लौटाता है।
- `public.srk_get_my_wallet_summary()` authenticated call पर customer wallet और approved electrician के लिए electrician wallet create करने का side effect रखता है; इसे pure read-only summary नहीं समझना चाहिए।
- `public.srk_admin_wallet_overview()` Admin guard के साथ wallet counts और posted ledger credits/debits aggregate करता है; यह अपने-आप cash-cycle due, per-electrician booking sequence या fee settlement साबित नहीं करता।
- Live public/private function-definition scan में `cash_cycle`, `platform_fee_due` और `wallet_top` शब्दों वाले function bodies नहीं मिले। अलग नामों या tables/Edge/Netlify logic में कोई implementation हो सकती है; इसलिए यह scoped function-text result है, पूर्ण अनुपस्थिति का प्रमाण नहीं।

### निष्कर्ष / release blockers
- Production में verified cash confirmation अभी legacy quote आधारित है; Master timer-based actual-minute billing से मेल नहीं खाता।
- इस scan से first-two Cash / third Online, fee-due ledger, top-up clear होने पर reset, booking acceptance reservation, cancellation/offer-expiry release, concurrent booking race protection और deterministic idempotency का live implementation प्रमाणित नहीं हुआ।
- अगली जाँच: सभी cash/wallet ledger tables और columns, triggers, policies/grants, RPC callers, frontend references, Netlify handlers तथा हर उपलब्ध branch के cash-cycle migrations को अलग-अलग map करना; फिर transaction/state-machine design को Feature Branch में प्रस्तावित करना।
- Production में कोई SQL/DDL, function, grant, wallet/account/ledger row, migration history या payment setting बदली नहीं गई। कोई deployment या staging resource create नहीं किया गया।


## 17.35 — Cash Cycle Feature Migrations: Acceptance Reservation, Wallet Ledger और Refund Logic का Static Review (13 Nov 2026)

### Feature Branch में मौजूद प्रस्तावित SQL (Production में लागू नहीं)
- `20261112170000_enforce_electrician_third_booking_online_payment.sql` में `srk_respond_to_offer` electrician profile row पर `FOR UPDATE` lock लेता है और prior completed + approved + paid + verified bookings गिनता है। यह एक ही समय पर offer accept करने वाले transactions को serialize करता है।
- लेकिन count केवल completed/paid bookings गिनता है; accepted/assigned मगर अभी incomplete bookings के लिए durable cycle slot reservation नहीं बनती। इसलिए लगातार कई offers स्वीकार होने पर सभी transactions वही prior count देख सकते हैं और तीसरे slot की सीमा bypass हो सकती है। केवल profile lock पर्याप्त नहीं है। अलग per-electrician cycle/slot reservation table या समकक्ष transactional state चाहिए, जिसमें accept पर slot reserve, terminal eligible payment पर consume, और decline/cancel/expiry पर policy के अनुसार release हो।
- मौजूदा migration का नियम हर तीसरी booking को Online कहता है, पर Master का “पहली दो eligible Cash, तीसरी Online, wallet top-up से बकाया Platform Fee साफ होने पर cycle reset” नियम पूर्ण रूप से implement नहीं करता। “eligible booking” की परिभाषा भी approved final state machine से बाँधनी होगी।

### Platform Fee ledger migration की समीक्षा
- `20261112220000_cash_platform_fee_due_and_online_settlement.sql` Feature Branch में `srk_platform_fee_ledger` बनाता है; amount positive, idempotency key NOT NULL + UNIQUE और RLS enabled; PUBLIC/anon/authenticated direct privileges revoke किए गए हैं। यह सही दिशा है, लेकिन trigger/function execute grants, service_role access और ledger append-only protection को अलग verify करना होगा।
- Cash due तथा online fee postings booking-based idempotency keys से duplicate webhook postings रोकने का प्रयास करते हैं। Per-electrician advisory transaction lock cash और online financial postings के बीच serialization देता है।
- उसी migration में पुराने Cash dues की वसूली पहले `v_total - v_current_fee` से की जाती थी, जिसमें materials भी शामिल हो सकते थे।
- `20261113120000_limit_cash_fee_settlement_to_labour_share.sql` इसे सुधारकर पुराने due की अधिकतम वसूली `v_service - v_current_fee` तक सीमित करता है। इससे materials/parts राशि Platform Fee debt settlement का स्रोत नहीं बनती। यह Master के labour-only सिद्धांत के अनुरूप है।
- फिर भी दोनों migrations legacy `service_charge`, `materials_amount`, `commission_rate`, `quote_status='approved'` और `quoted_amount` आधारित completed-payment trigger पर निर्भर हैं। Timer-derived actual-minute labour amount से जुड़ना बाकी है।

### Refund और payout जोखिम
- Feature migration cash fee due, online fee, previous cash due settlement, restore और reversal के लिए अलग ledger entry types और deterministic keys रखती है। Paid payout होने पर refund trigger Admin reconciliation की माँग करता है; यह सुरक्षित रोक है, पर पूर्ण Admin recovery workflow अभी चाहिए।
- Cash booking का fee due यदि बाद की online booking से pooled रूप में settle हो चुका हो तो cash refund को trigger रोक देता है। यह silent ledger corruption रोकता है, लेकिन pooled due की booking-wise allocation नहीं होने के कारण valid refunds भी जरूरत से ज्यादा block हो सकते हैं। हर due lot और settlement allocation को source cash booking से traceable बनाना बेहतर होगा।
- Online refund पर जिस booking में `cash_due_settlement` entry थी, उसी booking के ledger से restore entry बनती है; partial refund, multiple later settlements, repeated/out-of-order webhook और payout already paid स्थितियों के लिए deterministic reconciliation tests जरूरी हैं।
- Payout calculation में electrician payable का formula total (labour + materials) minus current fee minus previous fee है; पुराने due की वसूली labour share तक सीमित है। Materials को Platform Fee base से बाहर रखना अनिवार्य regression assertion बने।

### Customer payment method switch
- `20261113090000_customer_can_explicitly_switch_cash_booking_to_online.sql` customer ownership, unassigned state, unpaid/pending, no payment verification/order/payment ID की जाँच के बाद केवल explicit Cash→Razorpay switch करता है। यह payment तत्काल collect नहीं करता। Feature Branch-only; production status अलग है।

### Live Production trigger coverage (read-only)
- Live `service_bookings` में commission calculation, legacy payable creation, booking audit/status history, cancellation offer cleanup triggers मिले।
- Live `srk_electrician_payouts` पर Admin audit trigger मिला।
- Live `srk_wallet_ledger`, `srk_wallet_accounts` या `srk_platform_fee_ledger` पर इस query में कोई non-internal trigger नहीं मिला; Production में `srk_platform_fee_ledger` table का अस्तित्व इस inventory में प्रमाणित नहीं हुआ। इसलिए Feature Branch ledger को Production feature मानना गलत होगा।
- Live wallet ledger में idempotency_key nullable है (Section 17.23/17.24); wallet ledger के लिए NOT NULL deterministic key और append-only reversal model अभी blocker हैं।

### अगली implementation gate
1. एक स्पष्ट cycle state machine और per-electrician slot reservation design; acceptance, completion, payment verification, cancellation, expiry और refund पर atomic transitions।
2. Top-up flow को वास्तविक approved provider payment से जोड़ना; केवल wallet balance edit या UI flag से cycle reset नहीं।
3. Booking-wise fee due allocation, partial settlement/refund, paid payout recovery और append-only immutable audit।
4. Timer actual-minute labour amount, 15% labour-only fee, materials exclusion और server-side amount reconciliation।
5. Parallel acceptance, repeated webhook, timeout/retry, cancellation race, partial/full refund और duplicate idempotency tests।
6. सभी बदलाव Feature Branch और isolated Test Mode में; Production migration/apply/deploy से पहले अलग अनुमति।

Production Database, wallet/ledger rows, triggers, grants, migration history, payment settings या deployment में कोई बदलाव नहीं किया गया। यह read-only Production catalog inspection और Feature Branch SQL static review है।


## 17.36 — Wallet Foundation और Cash Slot Reservation का विस्तृत Static Review (13 Nov 2026)

### Wallet foundation migration (Feature Branch only)
- `20261109010000_create_secure_wallet_ledger_foundation.sql` में wallet account पर (user_id,wallet_type) unique है; wallet ledger में amount positive, direction credit/debit, status pending/posted/reversed/failed और idempotency_key UNIQUE है, लेकिन idempotency_key nullable है। इसलिए duplicate-safe posting अभी केवल तब मजबूत है जब caller स्वयं non-null key दे; DB constraint हर entry के लिए key अनिवार्य नहीं करता।
- Customer top-ups और electrician payouts स्पष्ट रूप से disabled रखे गए हैं। Wallet Summary response में `topups_enabled=false`, electrician payout `payouts_enabled=false` है। इस कारण Master के “wallet top-up से fee due साफ कर Cycle reset” नियम को अभी वास्तविक provider-backed top-up flow के रूप में चालू नहीं किया जा सकता।
- `srk_get_my_wallet_summary()` नाम read-only लगता है, पर customer wallet और approved electrician wallet insert करता है। यह side effect मौजूदा Production audit में भी देखा गया; इसे अलग idempotent provisioning RPC/trigger या स्पष्ट रूप से documented behavior में बदलने पर विचार हो। Concurrent first calls unique constraint + ON CONFLICT से duplicate account रोकते हैं, पर retry/error and authorization tests आवश्यक हैं।
- Wallet ledger owner SELECT policies हैं; client-side direct writes revoke हैं और service_role को write access दिया गया है। Feature migration में ledger append-only trigger नहीं दिखा। Production wallet ledger में भी audit के दौरान कोई dedicated append-only trigger नहीं मिला। Corrections को पुरानी row update/delete से नहीं, नई reversal entry से करना होगा; इसके लिए DB-level enforcement आवश्यक है।

### Acceptance slot algorithm — identified defect
- Feature Branch migration `20261112170000_enforce_electrician_third_booking_online_payment.sql` acceptance पर electrician profile row lock लेता है, पर slot number completed+paid+verified bookings की COUNT से निकालता है।
- यह “acceptance पर slot reserve” का दावा पूरा नहीं करता: accepted/in-progress लेकिन unpaid/incomplete bookings count में शामिल नहीं हैं। उदाहरण: count 1 है और दो अलग bookings electrician द्वारा क्रमशः स्वीकार हो जाती हैं; दोनों को अगला slot 2 दिखाई दे सकता है। तीसरा Online rule bypass हो सकता है।
- केवल status count को broaden करना पर्याप्त नहीं: cancellations, expiry, reassignment, refunds, partial refunds और parallel acceptance को स्पष्ट transactional state transitions चाहिए।

### प्रस्तावित सुरक्षित design (अभी लागू नहीं)
1. Per-electrician cycle row: `electrician_profile_id` primary/unique, `cycle_number`, `next_slot` (1..3), `fee_due_amount`, `version`, `updated_at`। Row को हर acceptance/payment/top-up/cancellation transaction में `FOR UPDATE` lock करें।
2. अलग booking slot reservation: `booking_id` unique, `electrician_profile_id`, `cycle_number`, `slot_number`, `reservation_status` (reserved/consumed/released), `required_payment_method`, server timestamps, non-null unique idempotency key। एक booking के लिए एक ही सक्रिय reservation।
3. Acceptance transaction में profile/cycle row lock → booking row lock → existing active reservation check → अगला slot reserve → slot 3 पर Online-only enforcement → assignment/offer status update। किसी भी failure पर पूरा transaction rollback। Lock order सभी RPCs में एक जैसा रहे ताकि deadlock न हो।
4. Slot reservation को eligibility के स्पष्ट business definition से जोड़ें। Master approval आवश्यक: slot acceptance पर reserve हो; booking eligible completed+verified paid होने पर consume हो; customer/Admin cancellation या offer expiry पर release हो; refund होने पर prior cycle को कैसे reverse/adjust करना है, अलग audited policy हो। “कभी consume नहीं” बनाम “एक बार cycle में गिनी booking” का निर्णय बिना approval न मानें।
5. Cash due को booking-wise fee lots में रखें। Online booking पर current 15% labour fee पहले; पुराने cash due का settlement केवल उसी booking की labour share से अधिकतम उपलब्ध राशि तक। Materials कभी fee base या पुराने due settlement source न हों। हर settlement lot को source cash booking से link करें।
6. Wallet top-up तभी cycle reset करे जब approved provider webhook signature, exact amount/currency, unique provider reference और idempotency verify हो; top-up posted होने के बाद fee due शून्य/निर्धारित सीमा तक साफ होने की transactionally verified शर्त पूरी हो। केवल client request या wallet UI balance से reset नहीं। Top-up provider approval से पहले feature disabled रहे।
7. Ledger append-only: posted entry update/delete रोकें; reversal/restore अलग signed ledger entries हों। `idempotency_key NOT NULL`, unique deterministic keys, actor/source/booking/provider metadata और immutable audit रखें।
8. Refund/chargeback में source cash due, प्रत्येक settlement allocation, current online fee, payout pending/paid और partial refund amount को अलग-अलग reconcile करें; paid payout पर Admin recovery flow और reasoned audit अनिवार्य हो।

### निष्कर्ष
- Feature Branch में wallet foundation, cash fee ledger और third-booking guard का प्रारंभिक code है, पर यह अभी पूर्ण Cash Cycle/Top-up system नहीं है।
- मुख्य blocker acceptance-time durable reservation है; दूसरा blocker wallet top-up provider flow disabled होना; तीसरा wallet ledger append-only + non-null idempotency enforcement।
- इस चरण में कोई code migration/function change लागू नहीं किया गया; केवल source review और design specification दर्ज की गई है। Production DB, wallet rows, payment settings, deployment और staging resources untouched हैं।


## 17.37 — Production Wallet/Booking/Payout Schema का Column-Level Reconciliation (13 Nov 2026)

### Live Production schema snapshot (SELECT-only catalog)
- `service_bookings` में अभी legacy `quoted_amount`, `service_charge`, `materials_amount`, `quote_status`, `commission_rate`, `commission_amount`, `work_started_at`, `payment_method`, `payment_status`, `amount_paid`, `payment_verified_at` fields मौजूद हैं। इस inventory में server timer start-request/approval/stop-request/approval, actual_minutes, timer-derived labour total, cash-cycle number/slot reservation, platform-fee-due amount या cash-fee settlement allocation columns नहीं मिले।
- `service_bookings.payment_method` NOT NULL है और default `Cash`; इस snapshot में allowed payment-method CHECK constraint नहीं दिखा (पूर्व Section 17.31 में भी ऐसा constraint नहीं मिला)। API/RPC validation को database state transition के साथ align करना होगा।
- `srk_wallet_accounts` में user_id, wallet_type, INR currency, account status और unique (user_id,wallet_type) हैं।
- `srk_wallet_ledger` में positive amount, credit/debit, pending/posted/reversed/failed, reference/provider fields और unique idempotency_key है; लेकिन idempotency_key nullable है। Schema snapshot में append-only/immutable enforcement column नहीं, और prior trigger inventory में इस table पर trigger नहीं मिला।
- `srk_electrician_payouts` में gross_service_amount, materials_amount, platform_commission, electrician_payable, payout status/method/reference/paid_by/paid_at हैं; dedicated booking-level cash fee due allocation या cycle reservation fields नहीं मिले।
- इस query में `srk_platform_fee_ledger` Production table नहीं लौटा। यह पहले से देखे गए Feature Branch migration की Production deployment पुष्टि नहीं करता; बल्कि इस live table inventory में उसका नाम अनुपस्थित है।

### Financial control implications
- Existing wallet balance ledger SUM से बनता है; इसलिए duplicate posting, mutable historical rows, nullable idempotency और correction semantics सीधे financial integrity पर असर डालते हैं। Append-only reversal enforcement और NOT NULL idempotency DB स्तर पर लागू होने चाहिए।
- Payout table में gross/material/platform fee/net payable fields हैं, लेकिन booking-to-cash-cycle settlement lot allocation का कोई field इस inspected schema में नहीं है। Cash due वसूली और refund के लिए separate linked allocation ledger चाहिए; payout total से historical cash dues का अनुमान नहीं लगाना चाहिए।
- Legacy commission field का नाम Master की “Platform Fee” भाषा से मेल नहीं खाता; customer-facing copy में “commission” न दिखे। Migration में historical commission records preserve रहें और new timer-based platform fee को अलग, स्पष्ट accounting field/ledger में रखें।
- Snapshot catalog-only है; किसी wallet/booking/payout customer row या balance को पढ़ा/बदला नहीं गया। RLS, constraints, indexes, grants, trigger definitions के अलग audits Sections 17.23–17.36 में दर्ज हैं।

### Next safe work
- Additive Feature Branch schema proposal: timer event/audit records, per-electrician cycle row, unique booking slot reservation, booking-wise fee-due lots, settlement allocation rows, append-only wallet/platform-fee ledger and deterministic non-null idempotency keys.
- Migration plan must preserve all existing quote/payment/payout/refund rows and be rehearsed against a schema snapshot in isolated Test Mode after migration-history reconciliation. No Production migration until separately authorized.

No Production schema, data, grants, triggers, wallet balances, payment configuration or deployment changed in this audit.


## 17.38 — Cash Fee Ledger Migration का Financial Invariant Review और Pre-Implementation Gate (13 Nov 2026)

Feature Branch की चार SQL migrations को source-level पर दोबारा पढ़ा गया; कोई migration apply नहीं की गई।

### 1. Cash cycle acceptance guard अभी सुरक्षित reservation नहीं है
- `srk_respond_to_offer` हर acceptance पर electrician profile lock लेता है, लेकिन slot count केवल completed + approved quote + paid + verified bookings से बनाता है। Pending accepted bookings reservation में शामिल नहीं होतीं। इसलिए दो active accepted bookings एक ही future slot पर निर्भर हो सकती हैं। यह P0 blocker है।
- यह query payment_method को booking row से पढ़ती है और तीसरे slot पर exact Razorpay label की अपेक्षा करती है। UI/API के अन्य allowed labels या casing/legacy values के साथ mismatch पर valid Online booking reject हो सकती है; normalized enum/check constraint और single canonical payment method value चाहिए।
- Cycle reset का verified wallet top-up path इस migration में नहीं है।

### 2. Cash Platform Fee / Online settlement invariants
- `srk_platform_fee_ledger` Feature Branch migration में idempotency_key NOT NULL + UNIQUE है, जो पुराने wallet ledger से बेहतर है; लेकिन table को immutable कहने वाला comment अपने-आप UPDATE/DELETE रोकता नहीं। इस table पर append-only trigger या write-only RPC boundary अलग से चाहिए।
- Current online fee 15% labour/service amount से निकाली जाती है; materials current fee base से बाहर हैं। बाद के सुधार में previous cash due recovery को `greatest(v_service - v_current_fee, 0)` तक सीमित किया गया है, इसलिए materials से पुराने dues settle नहीं होते। इसे regression invariant रखें।
- Ledger में previous cash dues electrician के pooled balance से SUM होते हैं; cash_due_settlement केवल उस online booking से जुड़ता है जिसने pooled balance settle किया। कौन-सी source cash booking कितनी settle हुई, इसका allocation relation नहीं है। इसी वजह से refund logic source cash booking refund के बाद किसी भी later pooled settlement को देखकर refund रोक देता है। यह data corruption रोकता है, लेकिन वैध refunds को unnecessarily block कर सकता है। Booking-wise settlement allocation table चाहिए।
- Refund पर pending payout को refunded किया जाता है; paid payout होने पर trigger Admin reconciliation exception देता है। यह fail-safe है, पर paid payout reversal/partial recovery का पूरा Admin workflow अलग implement करना होगा।
- `srk_create_electrician_payable` अभी completed + approved quote + verified payment और `service_charge + materials_amount = amount_paid` पर निर्भर है। इसलिए सही labour-only fee formula होने के बावजूद timer-based actual-minute amount अभी लागू नहीं हुआ।

### 3. Customer payment switch
- `srk_customer_change_payment_method` केवल authenticated owner की unassigned new/confirmed, unpaid/pending, बिना Razorpay order/payment वाली Cash booking को explicit Online में बदलता है। यह तत्काल payment collect नहीं करता; यह सही separation है।
- इसे electrician assignment या third-slot decision से atomically integrate करना होगा, ताकि customer method switch और offer acceptance के बीच race न हो। Customer consent बिना silent switch नहीं होना चाहिए।

### 4. Required immutable accounting model before coding
- Per-electrician cycle state + booking slot reservation (unique booking_id, slot number, cycle number, status, canonical payment method, reservation idempotency key)।
- Cash due lots keyed to originating cash booking; online settlement allocation rows linking each source due lot to the settling online booking and exact amount.
- Wallet top-up payment intent/provider reference, verified webhook event ID, amount/currency, posted ledger entry, fee-due application and cycle reset all in one idempotent server-side transaction.
- Append-only wallet and platform-fee ledgers: NOT NULL deterministic idempotency key; UPDATE/DELETE denied to application roles and rejected by trigger; corrections only through reversal/restore entries.
- Refund reconciliation supports partial amounts, multiple settlement allocations, cash due reversal, online fee reversal, pending payout reversal, and separate Admin-authorized recovery after paid payout.
- All fee and recovery calculations must use actual-minute labour amount only; materials are pass-through and excluded from 15% fee and old-fee recovery. Payout must reconcile labour + separately approved materials − current labour fee − allocated prior fee.

### 5. Test gate (must pass before release)
- 2 concurrent offer acceptances for one electrician; third slot reservation; booking cancellation/offer expiry release; reassignment; duplicate accept retry.
- Cash due creation exactly once; repeated payment webhook; two online payments racing; exact fee rounding; materials large while labour small; no negative payout.
- Partial and full refund before/after fee settlement; multiple due lots; paid payout; out-of-order duplicate webhook; Admin reconciliation audit.
- Customer payment method switch vs assignment race; reject unauthenticated/other-customer/paid/order-created switch; ensure no silent method change.
- Wallet top-up invalid signature, wrong amount/currency, duplicate provider event, timeout retry, insufficient amount, full fee clearance and only then cycle reset.

Conclusion: Feature Branch SQL has useful foundations (row locks, per-electrician advisory lock, deterministic fee ledger keys, explicit customer Cash→Online choice, labour-only settlement cap), but does not yet meet the Master Requirements end-to-end. No implementation patch or schema migration was created in this step. Production database, customer/payment records, migration history, provider settings, staging resources and deployment remain unchanged.


## 17.39 — Cash Cycle के वास्तविक UI/API Callers और Payment Flow Integration Audit (13 Nov 2026)

Feature Branch के UI और Netlify/root handlers में Cash/Online और acceptance RPC callers की जाँच की गई। कोई browser session, payment, RPC mutation या live customer record इस्तेमाल नहीं किया गया।

### Electrician UI
- `electrician.html` offer acceptance/decline के लिए सीधे `srk_respond_to_offer` RPC call करता है। इसलिए acceptance-time reservation इसी RPC transaction में atomic होना चाहिए; केवल UI-side slot check सुरक्षित नहीं होगा।
- Offer card `srk_get_my_offer_details()` से payment_method badge, quoted_amount, customer name/phone/address/location और call link render करता है। पुराने audit के अनुसार RPC में completed booking contact भी लौट सकता है; UI में इस card पर completed-state contact removal guard नहीं मिला। Contact privacy fix इस same response contract और UI render दोनों में चाहिए।
- Electrician Earnings screen Platform Fee due के लिए अलग RPC response (`outstanding_due`, `entries`) render करता है और ledger entry labels में cash_due, cash_due_reversal, online_fee, cash_due_settlement, cash_due_restore, online_fee_reversal शामिल हैं। इस UI contract को future booking-wise allocation rows से backwards-compatible या versioned करना होगा।
- Wallet summary UI भी है; लेकिन current wallet foundation top-ups/payouts disabled बताता है। UI दिखना वास्तविक top-up permission या verified payment flow का प्रमाण नहीं।

### Customer UI
- `booking.html` Customer booking list own customer_user_id filter से rows पढ़ती है और payment_method दिखाती है। Unassigned new/confirmed Cash booking पर Customer स्वयं “Online भुगतान चुनें” action चला सकता है।
- यह action `srk_customer_change_payment_method` RPC को call करता है; confirmation स्पष्ट है और RPC तत्काल payment collect नहीं करता। UI reload के बाद method choice refresh होती है।
- Customer payment action completed + approved quote + Razorpay-selected booking पर `quoted_amount` से payment amount भेजता है। यह अभी timer-derived actual-minute amount नहीं है।
- Booking form `create-booking.js` को client-supplied `payment_method` और `quoted_amount` भेजती है। Root handler इन्हें clean/parse करके service_role insert payload में डालता है। Payment method allow-list और authoritative pricing को server-side enforce करना आवश्यक है; केवल UI select values पर भरोसा नहीं।

### Online payment server handlers
- `razorpay-webhook.js` booking को Razorpay order ID से lookup करता है; explicit Online method check करता है; फिर केवल completed + approved quote booking स्वीकारता है और `service_charge + materials_amount) को approved total मानता है। यह legacy quote contract है, timer amount नहीं।
- `verify-payment.js` भी customer session/booking phone ownership, Razorpay signature, Online method, completed status और approved quote checks करता है; payable total quote-era amount fields से निकलता है। दोनों handlers को एक shared server-authoritative timer amount and payment-intent reconciliation contract पर लाना होगा।
- Webhook repeated/out-of-order events, duplicate provider event ID, partial refund, amount/currency mismatch और payout/fee-ledger race के लिए end-to-end provider Test Mode tests अभी बाकी हैं।

### Integration blockers
1. Cash cycle reservation का canonical caller `srk_respond_to_offer` है; migration में persistent reservation table/state absent है।
2. Customer Cash→Online switch unassigned stage में संभव है, लेकिन offer acceptance के समय slot enforcement के साथ transactionally coordinate होना चाहिए।
3. Electrician UI payment badge/fee due display legacy RPC response contract पर निर्भर है; new allocation ledger/API contract साथ में update हो।
4. Booking creation client `quoted_amount` स्वीकारती है; इसे Master timer billing से पहले source of truth नहीं बनाया जा सकता।
5. Razorpay verify/webhook quote-approved state पर निर्भर हैं; नया timer approval और immutable billing timestamp integrate हुए बिना new cycle logic release नहीं होना चाहिए।

No code, UI, SQL, payment provider, wallet, customer data, Production schema or deployment was changed. This is source-level caller mapping only.


## 17.40 — Legacy Work Status से Server-Authoritative Timer तक State-Machine Design Review (13 Nov 2026)

### वर्तमान Feature Branch flow का प्रमाण
- Electrician UI `srk_update_booking_work_status` RPC को `inspection`, `in_progress`, `completed` status भेजता है। Inspection पर quote submit UI खुलता है; customer quote approve/reject करता है; quote_approved होने पर electrician in_progress और फिर completed करता है।
- उपलब्ध Feature Branch file inventory और inspected `electrician.html`, `booking.html`, booking/payment handlers तथा relevant migrations में Master वाला timer request/Customer approval/immutable server timestamp/actual-minute billing flow नहीं मिला। यह inspected source scope का निष्कर्ष है, पूरे repository के हर hidden/generated object का दावा नहीं।
- इसलिए मौजूदा `in_progress` को timer started मानना गलत होगा: यह केवल status transition है। Browser/mobile clock से duration निकालना भी सुरक्षित नहीं।
- Electrician work UI अभी quote में labour amount manually भरता है और `srk_submit_booking_quote` call करता है। Customer payment UI और Razorpay handlers बाद में `quoted_amount`, `service_charge`, `materials_amount`, `quote_status` पढ़ते हैं। Timer implementation को इन callers के साथ coordinated replacement चाहिए।

### प्रस्तावित canonical lifecycle (नई implementation; अभी लागू नहीं)
1. `assigned`: offer accepted, electrician assigned, cash-cycle slot reserved; दोनों पक्षों के contact numbers केवल इस active accepted booking context में उपलब्ध।
2. `start_requested`: assigned electrician server RPC से start request करता है; request ID/idempotency key और server received_at दर्ज। Customer को उसी booking के लिए approval prompt।
3. `in_progress`: Customer approval RPC server transaction में start event को approved करता है और immutable `timer_started_at` server timestamp लिखता है। केवल इसी समय से billable duration शुरू। Duplicate approval उसी event का result लौटाए; दूसरा timer न बने।
4. `completion_requested`: Electrician completion RPC भेजता है; server first receipt time immutable `completion_requested_at` लिखता है। यह timestamp billing endpoint candidate है, लेकिन अभी final नहीं।
5. Customer completion approval: server approval event दर्ज करे और timer stop boundary को पहले server-received completion request timestamp से bind करे; Customer approval timestamp को billing end न बनाए।
6. Customer approval न दे/विवाद करे: Admin review queue; Admin reasoned decision और actor audit के साथ accept/adjust/reject कर सकता है। Admin adjustment में original start/request/stop timestamps overwrite न हों; अलग adjustment event हो।
7. `completed` + payment pending: immutable actual_minutes और labour amount freeze; Cash/Online method customer की पहले से saved choice रहे। Payment verify होने पर ही paid/finalized financial ledger postings हों।
8. `cancelled`/failed/refunded: timer events delete न हों; cancellation/refund अलग event और ledger reversal से दर्ज हों।

### Server-side data model requirements
- Append-only `booking_timer_events`: booking_id, event_type, actor_user_id/role, request_id, idempotency_key NOT NULL UNIQUE, server_received_at, approval status, reason, source, created_at. Client timestamp केवल diagnostic metadata; billing के लिए नहीं।
- Booking पर current lifecycle projection: timer_state, start_event_id, immutable timer_started_at, completion_request_event_id, immutable completion_requested_at, customer_completion_decision, decision_at, actual_minutes, labour_amount_minor/decimal, pricing_rule_version, approved_by/admin_adjustment reference. सभी fields server RPC से ही बदलें।
- एक booking पर अधिकतम एक approved start और एक accepted completion boundary; DB unique/partial indexes और transaction locks से enforce करें। Duplicate RPC retry deterministic response दे।
- Server function authenticated customer ownership और assigned approved+active electrician identity verify करे; Admin override अलग Admin guard और mandatory reason से। Direct client table writes revoke; RLS read access role/ownership अनुसार।
- समय calculation UTC timestamptz से server-side; local display Asia/Kolkata. Duration seconds से actual minutes निकालने की rounding policy Master से तय होनी बाकी है (पूर्ण minute का floor/ceil/round निर्णय अभी invent न करें)।
- Pricing formula: category 8-hour rate × billable actual minutes / 480. Existing rates and 15% labour-only Platform Fee apply; materials अलग pass-through, fee base में शून्य। Currency precision/paise rounding, 1–8 hour limit, overtime, pause/resume policy को लिखित Master decision के बिना hard-code न करें।

### Required caller migration map
- Replace Electrician `workStatus()`, inspection/quote submission UI with start request, completion request and pending-approval states.
- Replace Customer quote approval/rejection UI with start approval and completion approval/dispute UI.
- Replace `create-booking.js` client `quoted_amount` acceptance; booking creation must store only server-validated category/rate snapshot and chosen payment method, not a customer price.
- Replace `create-order.js`, `verify-payment.js`, `razorpay-webhook.js`, cash confirmation and payable triggers so every amount is derived from frozen timer billing record and exact labour/material split.
- Update payout, Platform Fee ledger, refund, cancellation, Admin dashboard, receipt/history, push/realtime, audit and support views to consume timer event IDs and immutable amount snapshot.
- Contact RPCs must expose phones only while booking is accepted/active; after completion/cancellation no phone in RPC response, offer details, history, receipt, cache or notifications.

### Release tests
- Customer approves start; rejects start; duplicate approve; wrong customer; wrong electrician; unassigned/expired offer; disabled electrician; expired session.
- Completion request timestamp first server receipt is retained through delayed customer approval; duplicate/reordered request; Admin review and reasoned adjustment; no client clock tampering effect.
- Two concurrent start requests; multiple tabs; retry after network timeout; start/completion race; booking cancellation race; timer event immutability.
- Category rates, exact minute calculation, fractional paise rounding decision, 1–8 hour boundary, overtime policy, daylight/timezone display, materials exclusion, 15% labour fee and all Cash/Online settlement paths.
- Customer/Electrician contact negative tests immediately after terminal state; verify no PII in history/receipt/cache/realtime/push/logs.

### Decision gate
- Timer model and immutable event design are now documented, not implemented. Before code/migration, confirm unresolved Master policies: minute rounding, overtime, pause/resume, customer approval timeout/dispute, Admin adjustment limits, cancellation while timer active, and whether booking becomes completed at customer approval or after payment. Preserve legacy quote fields/data until all callers and historical records are migrated.
- No migration file was created and no Production database, customer/payment data, provider settings, staging resource, or deployment was changed.


## 17.41 — Live Production Work-Status और Quote RPC की Definition-Level जाँच (13 Nov 2026)

Production Supabase catalog से छह function definitions read-only प्राप्त की गईं। कोई RPC execute नहीं किया गया।

### 1. `srk_update_booking_work_status(uuid,text)`
- SECURITY DEFINER, owner postgres, fixed search_path `pg_catalog, public, auth, pg_temp`.
- केवल `inspection`, `in_progress`, `completed` status स्वीकारता है।
- Electrician profile lookup में `user_id = auth.uid()` है, लेकिन `auth_user_id = auth.uid()` fallback नहीं है। दूसरी identity link पर निर्भर वैध Electrician UI session इस RPC से fail हो सकती है, जबकि अन्य RPC दोनों identity fields मानते हैं। यह identity-consistency defect candidate है; live JWT test के बिना वास्तविक प्रभावित account count अज्ञात है।
- Assignment check और booking row `FOR UPDATE` मौजूद हैं। लेकिन start केवल `quote_approved` पर `work_started_at=now()` लिखता है; completion सीधे status completed कर देता है। Customer timer approval, immutable completion-request timestamp, actual_minutes और Admin dispute path नहीं हैं।

### 2. Quote RPCs
- `srk_submit_booking_quote` authenticated approved+active electrician ढूँढता है और `user_id` या `auth_user_id` दोनों पहचान स्वीकारता है; booking assignment check + row lock करता है; electrician द्वारा service/material amounts और total manually set होते हैं।
- `srk_customer_respond_booking_quote` authenticated booking owner check + row lock करता है; quote approve/reject पर status quote_approved/quote_rejected करता है। यह Master timer start/completion approval से अलग पुराना flow है।
- `srk_get_my_assigned_booking_quote_details` approved+active linked electrician के assigned bookings लौटाता है और status list में completed भी शामिल है; address/location और quote/payment fields लौटते हैं। इस output में phone field नहीं, लेकिन address/location terminal state के बाद भी उपलब्ध हैं; completed contact privacy की व्यापक location/address minimization जाँच आवश्यक है।

### 3. Cash confirmation और payout trigger
- `srk_electrician_confirm_cash_payment` assignment/identity (user_id या auth_user_id), approved+active profile, booking row lock और already-paid replay check रखता है; लेकिन completed + approved quote + Cash + positive quoted_amount की शर्त पर payment paid करता है। Amount `quoted_amount` से आता है, timer billing से नहीं।
- `srk_create_electrician_payable` trigger SECURITY DEFINER और fixed search_path है। Payout तभी बनाता है जब completed+paid+approved quote+verified payment और payment evidence मौजूद हो। It enforces amount_paid = service_charge + materials_amount; fee/commission labour service_charge पर लगती है और electrician payable में materials जोड़ता है। Existing pending payout conflict पर fields update हो सकते हैं; paid payout update नहीं होता। Refund पर केवल pending payout refunded किया जाता है; paid payout अलग Admin reconciliation माँगता है।

### 4. Release/security implications
1. New timer RPCs में electrician identity matching का एक canonical helper अपनाएँ (user_id OR auth_user_id), साथ में approved+active और assigned booking check; पुराने RPC की identity mismatch को regression test करें।
2. Work status को client-provided arbitrary text से बदलने की जगह narrowly scoped RPCs: request_start, customer_approve_start, request_completion, customer_approve_completion, admin_resolve_timer_dispute। हर call ownership, role, assignment, booking state, row lock और non-null idempotency key enforce करे।
3. Legacy quote RPCs/columns को तब तक preserve करें जब तक new timer, payment, cash, payout, refund, Admin, receipts and history callers migrate न हों।
4. Customer/Electrician completed history में phone ही नहीं, live address/location/coordinates भी आवश्यकता से अधिक न लौटें; Admin access अलग audited रहे।
5. SECURITY DEFINER ACLs को per-function audit करें; blanket revoke न करें। Runtime JWT negative/positive tests और RLS/ACL checks staging में जरूरी हैं।

यह definition-level source audit है। No Production function, trigger, ACL, table, row, payment, wallet balance or deployment changed.


## 17.42 — Production Booking Constraints, RPC ACL और Trigger Release-Dependency Audit (13 Nov 2026)

Production catalog से constraints, selected RPC grants और service_bookings triggers की SELECT-only जाँच की गई। कोई function execute या schema change नहीं किया।

### 1. Current database constraints
- Booking status CHECK अभी केवल `new`, `confirmed`, `assigned`, `inspection`, `awaiting_quote_approval`, `quote_approved`, `quote_rejected`, `in_progress`, `completed`, `cancelled` स्वीकारता है। Master के `start_requested`, `completion_requested`, `timer_disputed` जैसे प्रस्तावित states अभी स्वीकार नहीं होंगे; additive event model या carefully migrated state constraint चाहिए।
- Assignment-required CHECK `assigned`, inspection, quote states, `in_progress`, `completed` पर electrician assignment अनिवार्य करता है। नए state names जोड़ने पर इसी constraint को साथ बदलना होगा; अन्यथा state update fail हो सकता है।
- Payment status CHECK: unpaid, pending, paid, refunded, failed. Partial refund, refund_pending, partially_refunded, reversed या disputed जैसे states अभी सीधे स्वीकार नहीं होंगे। इन्हें booking payment status में जोड़ना या अलग payment/refund state tables में रखना design decision है।
- Quote status CHECK: not_submitted, pending, approved, rejected. Legacy quote values को delete/rename न करें; old records preserve हों।
- `amount_paid` nonnegative/range checks हैं; quoted_amount range, service_charge nonnegative, materials_amount nonnegative हैं। इस inspected set में payment_method पर CHECK constraint नहीं मिला; canonical enum/value DB/API/RPC में consistently enforce नहीं होता।
- Location latitude/longitude pair and range checks हैं; phone exactly 10 digits, PIN exactly 6 digits. New booking schema additions को existing checks के साथ compatible रखना होगा।

### 2. Selected RPC ACL snapshot
- `srk_update_booking_work_status`, `srk_submit_booking_quote`, `srk_customer_respond_booking_quote`, `srk_get_my_assigned_booking_quote_details`, `srk_electrician_confirm_cash_payment`, `srk_get_my_assigned_cash_payment`, `srk_respond_to_offer`: anon EXECUTE false; authenticated EXECUTE true; service_role EXECUTE true.
- यह ACL snapshot blanket revoke की अनुमति नहीं देता। Authenticated users को intended RPC access चाहिए; body-level ownership, role, assignment, lifecycle checks असली सुरक्षा हैं। service_role trusted server-only secret boundary में रहे; उसे client/browser में कभी expose न करें।
- Query में `srk_customer_change_payment_method` selected names के result में नहीं आया; इसलिए इस Production snapshot से उसका live existence/ACL प्रमाणित नहीं हुआ। Feature Branch migration/caller का होना Production में applied होने का प्रमाण नहीं।

### 3. service_bookings trigger order/dependency inventory
- BEFORE INSERT `a_guard_booking` runs `guard_new_booking()`.
- AFTER INSERT `broadcast_new_booking` invokes `broadcast_booking_job()`.
- AFTER INSERT/UPDATE/DELETE `srk_audit_service_bookings` invokes Admin audit capture.
- BEFORE INSERT/UPDATE OF status,payment_status,amount_paid,commission_rate `srk_calculate_booking_commission`.
- AFTER UPDATE status cancelled `srk_cancel_booking_job_offers` expires/cancels offers.
- AFTER INSERT/UPDATE status `srk_log_service_booking_status`.
- AFTER INSERT/UPDATE OF payment_status,status,quote_status,service_charge,materials_amount,assigned_electrician_id,payment_verified_at,razorpay_payment_id,amount_paid `trg_srk_create_electrician_payable`.
- New timer/actual-minute fields are not in the legacy payable trigger's watched column list. A future timer payment path must explicitly invoke a new idempotent payout calculation or update trigger dependency; simply adding timer columns won't create payouts. Audit trigger allow-list also needs new timer fields/events.
- Cancellation trigger currently only cancels job offers; it does not implement stage fee, customer debt, electrician wallet debit or SRK cancellation ledger (as previously recorded in Sections 17.23–17.24).

### 4. Migration sequencing requirements
1. Reconcile Production migration history/source first; don't edit live constraints or apply an unverified migration.
2. Add timer event and billing snapshot structures without dropping legacy quote columns/statuses.
3. Introduce new state/transition constraints and assignment checks only after mapping all existing rows and every RPC/UI caller.
4. Build new timer, payment, payout and refund RPCs with tested ACLs before switching UI callers.
5. Add new audit/ledger triggers with deterministic idempotency and reversal behavior; test trigger interaction/order and webhook service_role context.
6. Only after old callers are removed and historical records are preserved, plan deprecation of legacy quote flow.

No Production constraint, grant, trigger, function, table, row, payment, wallet balance, migration history or deployment changed.


## 17.43 — Repository-wide Quote/Work-Status Callers और Admin Direct-Mutation Sweep (13 Nov 2026)

GitHub code search और Feature Branch source excerpts से पुराने Quote/Work-Status contract के अतिरिक्त callers की जाँच की गई। Search index default-branch snapshots/excerpts देता है; जहाँ आवश्यक हो Feature Branch file source से पुष्टि की गई। यह exhaustive runtime call graph नहीं है।

### Confirmed callers / dependencies
- `electrician.html`: `srk_update_booking_work_status` (inspection/in_progress/completed), `srk_submit_booking_quote` (service + materials), `srk_respond_to_offer` (accept/decline), `srk_get_my_offer_details` (offer and booking detail). UI still shows quote amount, quote controls, customer phone/address/location and legacy statuses.
- `index.html`: separate/older Customer quote-response UI calls `srk_customer_respond_booking_quote`; customer booking list reads quoted_amount, service_charge, materials_amount, quote_status, quote_note and displays quote approval/rejection controls. This confirms Customer quote flow has more than one page/caller and cannot be retired by editing only `booking.html`.
- `booking.html`: customer history/payment flow reads quote fields and legacy status; Cash-to-Online selection and Online payment still depend on legacy booking state/amount.
- `create-booking.js`: reads client `quoted_amount` and stores client-provided amount after numeric validation; authentication/phone verification alone does not make client amount authoritative.
- `razorpay-webhook.js`: reads `quoted_amount, service_charge, materials_amount, quote_status, status, payment_status`; computes expected amount from service + materials and cross-checks quote total. Replacing the UI without replacing webhook contract would break/incorrectly reject payments.
- `admin.html`: Admin booking table directly reads booking financial/status fields and exposes editable `quoted_amount`, payment status selector and booking status selector; separate save flow exists. It also directly edits address/district/state/PIN on booking rows. These paths need server-side, reasoned Admin RPCs and immutable before/after audit for timer amount, payment and location changes. Do not assume Admin page visibility alone enforces permissions.
- `admin.html` separately uses controlled payout RPC `srk_admin_mark_electrician_payout_paid`, Admin wallet overview and reporting RPCs; preserve these and migrate them to the new timer/fee ledger contract rather than removing Admin financial controls.

### Critical implications
1. Customer old quote UI is present in `index.html` as well as booking flow; route consolidation and customer-panel replacement must include both entry points.
2. Work status, quote approval, booking creation, Razorpay webhook, cash confirmation, payout trigger and Admin editing are one connected financial lifecycle. Partial UI-only replacement is unsafe.
3. Admin direct amount/status edits are a control-plane risk for the future immutable timer bill. New Admin adjustment RPC must require a reason, validate payment/refund/payout state, preserve original bill, write an adjustment event, and audit actor + before/after + timestamp.
4. Client `quoted_amount` should be ignored/rejected by new booking API; server must derive category price snapshot from approved service category and Master rate table. Do not silently alter old API before all clients are migrated.
5. Razorpay order, verify and webhook handlers must consume one frozen server billing snapshot and verify booking, customer, INR currency, amount, payment method, order/payment IDs, event idempotency and out-of-order state. Materials remain separately itemized and excluded from Platform Fee basis.
6. Legacy quote status and fields remain necessary for historical bookings and existing in-flight records until the new timer lifecycle is live and a reconciliation/backfill strategy is tested.

### Next safe implementation order
- Create an explicit caller matrix for every route/API/RPC/trigger/Admin screen, with old/new contract and rollback behavior.
- Design additive timer event + immutable billing snapshot + adjustment event schema, then review all old migration dependencies.
- Build and test server RPCs and payment handlers first in isolated Feature Branch; keep legacy paths readable for historical rows.
- Migrate Electrician UI, Customer panel, Admin UI, receipts/history and notifications together behind a versioned flow; then run end-to-end Cash and Online tests.
- Retire old quote UI/RPC only after code search, live function dependency scan, browser E2E, payment webhook regression and historical-record verification show no active caller.

No application code, database function, table, ACL, payment provider, booking/customer record or deployment changed. Only this documentation section was added to the Feature Branch.


## 17.44 — Admin Panel Direct-Write और Razorpay Payment Finalization का Control-Boundary Audit (13 Nov 2026)

Feature Branch के मौजूदा `admin.html`, `create-booking.js`, `create-order.js`, `verify-payment.js` और `razorpay-webhook.js` को source-level पर फिर जाँचा गया। कोई API request, payment, RPC या database write execute नहीं किया गया।

### 1. Admin Panel के प्रत्यक्ष mutation paths
- `admin.html` booking list में customer phone, address, district/state/PIN, location coordinates, status, quoted_amount, payment status और payment method पढ़ता है।
- Location edit handler सीधे `service_bookings` पर `address,district,state,pincode` PATCH करता है; यह dedicated reasoned Admin RPC और before/after event के बजाय browser Supabase client से direct table update है।
- Booking save handler पहले booking पढ़ता है, फिर non-paid booking के लिए `status` और `quoted_amount` सीधे table पर update करता है। Paid booking पर amount/payment status बदलने के कुछ UI guards हैं; ये UI-only guards हैं और server-side immutable billing authorization का विकल्प नहीं।
- Manual payment branch controlled `srk_admin_record_manual_payment` RPC का उपयोग करती है; इसे preserve करना है, लेकिन नए timer billing snapshot, exact amount, receipt evidence, idempotency और actor audit से reconcile करना होगा।
- Electrician active toggle भी `electrician_profiles.active` पर direct update है। इसे emergency control और staff permission matrix के साथ server-guarded mutation बनाना होगा।
- Payout paid marking अलग Admin RPC `srk_admin_mark_electrician_payout_paid` से है; यह controlled pattern है, पर नए payout/fee allocation ledger के साथ regression tests चाहिए।

### 2. Online payment finalization के मौजूदा अंतर
- `create-order.js` order बनाने से पहले customer session/booking ownership और Online method जाँचता है; फिर completed + approved quote और `service_charge + materials_amount = quoted_amount` reconciliation पर निर्भर करता है।
- `verify-payment.js` Razorpay signature verify करता है, provider payment fetch करके captured status, INR currency, amount और order ID मिलाता है; इसके बाद service-role PATCH से booking को paid करता है। यह legacy quote total पर आधारित है और payment-intent/billing-snapshot identity अभी नहीं दिखी।
- `razorpay-webhook.js` webhook signature verify करता है और Online/completed/approved-quote/amount checks के बाद service-role PATCH करता है। अलग verify endpoint और webhook एक ही booking को finalize कर सकते हैं; conditional update/re-read replay safety देता है, पर event-ID ledger, shared atomic finalization RPC और concurrent webhook-vs-verify race का पूर्ण प्रमाण इस source scan में नहीं मिला।
- दोनों finalizers payment status और amount_paid लिखते हैं; payout trigger इन्हीं legacy watched columns और quote fields पर निर्भर है। Timer billing snapshot को finalization और payout trigger दोनों में जोड़ना होगा।

### 3. Security boundary और release requirements
1. Admin direct booking amount/status/location और electrician active writes को scoped Admin RPCs में ले जाएँ; हर mutation में Admin/staff permission check, mandatory reason, before/after audit, actor, timestamp और idempotency हो।
2. Paid/partially refunded/payout-created booking के amount/status परिवर्तन केवल explicit adjustment/refund/reconciliation workflows से हों; मूल timer bill immutable रहे।
3. Customer booking API में client `quoted_amount` को authoritative input न मानें; server approved category/rate snapshot से amount निकाले।
4. Order, verify और webhook एक frozen billing snapshot/payment intent को reference करें; booking/customer/order/payment/currency/amount exact match, provider event dedupe और atomic one-time finalization लागू हो।
5. Admin location correction को अलग audited address-correction event बनाएँ; completed booking history में अनावश्यक phone/address/coordinates exposure न हो।
6. Feature Branch में पहले unit/integration tests, फिर Razorpay Test Mode में duplicate webhook, verify+webhook simultaneous delivery, wrong amount/currency/order, stale booking, refund-before/after-payout और Admin unauthorized mutation negative tests चलें।

### निष्कर्ष
Admin Panel में कुछ नियंत्रित RPC paths मौजूद हैं, लेकिन location, booking status/quote amount और electrician active flag के लिए direct browser table writes भी हैं। Online verify और webhook दोनों legacy quote contract के तहत paid status लिखते हैं। इसलिए केवल नया UI लगाने से Admin controls या payment integrity Master Requirements के अनुरूप नहीं होंगे।

No application code, database schema/function/ACL, booking/payment/wallet record, Razorpay setting, staging resource or deployment changed. केवल यह audit section Feature Branch की Master Requirements documentation में जोड़ा गया।


## 17.45 — Admin HTML के सभी Supabase Read/Write Callers की सूची और सुरक्षित बदलाव का नक्शा (13 Nov 2026)

Feature Branch के पूरे `admin.html` source में `from(...)` और `rpc(...)` calls का static inventory बनाया गया। यह केवल browser source call inventory है; live RLS/ACL और runtime Admin JWT behavior का प्रमाण नहीं।

### A. Read-only data paths
| Object / RPC | Admin UI उपयोग |
|---|---|
| `service_bookings` SELECT | अधिकतम 300 booking rows; customer phone/address/location, status, quote/payment fields |
| `electrician_applications` SELECT | अधिकतम 300 applications; `select('*')` |
| `electrician_profiles` SELECT | अधिकतम 500 profiles; `select('*')` |
| `srk_electrician_payouts` SELECT | अधिकतम 300 payouts और joined electrician display name/phone |
| `srk_admin_commission_report` | Commission report |
| `srk_admin_wallet_overview` | Wallet aggregate |
| `is_srk_admin` | Admin session gate |

### B. Mutation paths — RPC-controlled
- `srk_admin_mark_electrician_payout_paid`: payout paid confirmation; preserve, but migrate to timer-derived payable and allocated fee/refund reconciliation.
- `srk_admin_record_manual_payment`: manual payment receipt; preserve with exact frozen bill reconciliation, reference/evidence, idempotency and audit.
- `srk_admin_offer_booking`: matching/offer creation; preserve and coordinate with durable Cash slot reservation.
- `srk_admin_review_application`: application review; extend to category/ID approval policy only through explicit guarded workflow.
- These RPC names/callers were found in UI source. Their current live ACL/body correctness is not inferred from the UI inventory.

### C. Direct browser table writes — migrate behind guarded RPCs
1. `service_bookings.update({address,district,state,pincode})`: direct booking location correction. Required replacement: `srk_admin_correct_booking_location` (proposed name only), mandatory reason, validated address/PIN, before/after audit and Admin/staff permission.
2. `service_bookings.update({status,quoted_amount})`: direct booking status and amount edit for non-paid path. Required replacement: distinct narrow lifecycle decision and billing-adjustment RPCs; no arbitrary status string or overwrite of immutable timer bill. Preserve legacy correction only for explicitly identified historical bookings.
3. `electrician_profiles.update({active})`: direct activation/deactivation. Required replacement: guarded account-control RPC with reason, actor, emergency-control state, staff permission, and audit; prevent deactivation from silently corrupting an in-progress assigned booking.

### D. Additional controls
- Admin page currently gates entry using authenticated session plus `is_srk_admin()`; this is not evidence of MFA, granular staff roles, route hardening or server-side authorization for every direct write.
- `select('*')` on applications/profiles and payout join can fetch more personal/verification fields than each screen needs. Replace with explicit minimum columns and role-scoped views/RPC responses; never place verification documents or unnecessary PII in generic Admin list payloads.
- Booking table UI includes payment-status selector and paid amount display, but manual receipt is routed through a dedicated RPC. Preserve this controlled path and test unauthorized direct PATCH denial with actual JWTs.
- Offer creation, application review and payout confirmation are distinct business actions; do not collapse them into a generic Admin update RPC.
- Emergency pause, block/unblock, staff roles and permissions must be separate auditable control-plane operations.

### E. Verification required before implementation
1. Inspect live policies/grants for UPDATE on `service_bookings` and `electrician_profiles`; confirm direct browser write is Admin-only and staff cannot bypass permission scopes.
2. Read live definitions and ACLs of all five Admin RPCs listed above; test positive Admin and negative Customer/Electrician/staff-without-permission JWTs in isolated test environment.
3. Verify Admin direct PATCH behavior is denied to non-Admin even if UI scripts are manually invoked.
4. Add audit coverage for location correction, status transition, legacy amount correction, active toggle, application review, offer creation, manual receipt, payout paid.
5. Add least-privilege select projections; inspect Admin exports, browser console/errors, cached responses and staff-device/session controls.
6. Do not delete Admin controls or old fields until each action has a tested replacement and historical reconciliation.

No code, live policy/grant, database row, Admin account, payment, wallet, customer data, staging resource or deployment changed. Only this source inventory and proposed migration map were documented.


## 17.46 — पाँच Admin RPC और Admin Report/Wallet RPC की Live Production Definition + ACL जाँच (13 Nov 2026)

Production Supabase catalog से केवल function definitions, owner, SECURITY DEFINER, search_path और EXECUTE ACL पढ़े गए। किसी RPC को call नहीं किया गया; कोई data row, payment या mutation execute नहीं हुआ।

### 1. साझा Security Boundary
- सातों जाँचे गए RPC postgres-owned SECURITY DEFINER हैं और fixed search_path `pg_catalog, public, auth, pg_temp` रखते हैं।
- `is_srk_admin()` स्वयं `auth.uid()` को `srk_admin_users.user_id` से मिलाता है।
- सातों में PUBLIC और anon EXECUTE ACL नहीं है; authenticated तथा service_role EXECUTE है।
- छह operational/report RPC bodies में Admin check `auth.uid() IS NULL OR NOT is_srk_admin()` के रूप में मौजूद है। `is_srk_admin()` स्वयं boolean membership check है।
- यह static body/ACL evidence है; वास्तविक Customer/Electrician/unauthorized staff JWT negative tests अभी नहीं हुए। service_role bypass और trusted server caller अलग security boundary हैं।

### 2. पाँच Admin mutation RPC
1. `srk_admin_mark_electrician_payout_paid(uuid,text,text,text)`: Admin check, method allow-list (upi/bank), reference/note validation, booking-first फिर payout row lock, केवल pending payout, verified paid booking और legacy quote/service/material/commission reconciliation। अच्छा locking pattern है; पर timer billing snapshot, booking-wise fee allocations और paid-payout refund recovery अभी शामिल नहीं।
2. `srk_admin_record_manual_payment(uuid,text,text,text)`: Admin check, method/reference/note validation, booking row lock, completed+approved quote, assigned electrician, non-paid/non-refunded state, Razorpay IDs absent, existing manual entry rejection, quote breakdown equality; फिर manual entry insert और booking paid update एक transaction में। वर्तमान amount अभी legacy `service_charge + materials_amount = quoted_amount` है; timer bill, immutable payment intent और partial refund allocation नहीं।
3. `srk_admin_offer_booking(uuid)`: Admin check, booking row lock, unassigned तथा new/confirmed state; active+approved+linked electrician को PIN-first, otherwise district matching के आधार पर offers। वर्तमान query में category/verified skill eligibility और nearest-distance ranking स्पष्ट नहीं; इसे Master Smart Matching के अनुरूप जाँचना/बनाना होगा। Durable Cash slot reservation इसी acceptance transaction/RPC family से coordinate हो।
4. `srk_admin_review_application(uuid,text)`: Admin check; approved/rejected/suspended allow-list; application row lock; approval से पहले verified Auth phone match; profile create/update approved but inactive। Category approval, document verification evidence, unique digital ID issuance और staff granular permission इस definition में स्पष्ट रूप से पूर्ण नहीं।
5. `srk_admin_wallet_overview()`: Admin check; wallet counts, posted credits/debits, pending entries और verified bank links के aggregate देता है। यह accounting dashboard नहीं: cash-fee due lots, settlement allocation, cancellation debt, refunds/reversals और actual payout liability reconciliation शामिल नहीं।

### 3. Admin Reports और Role Gate
- `srk_admin_commission_report()` Admin guard के बाद paid+completed legacy bookings से amount_paid, commission_amount और electrician earning जोड़ता है। यह timer/actual-minute fee, materials pass-through, cancellation, refund/reversal और paid payout ledger से पूर्ण financial statement नहीं।
- `is_srk_admin()` allow-list membership check है; MFA, staff roles, permission scopes, session/device policy या emergency-control checks इस function में नहीं।
- सभी सात definitions में fixed search_path है; ACL authenticated execution की अनुमति देता है, इसलिए प्रत्येक SECURITY DEFINER body का Admin guard अनिवार्य और अभी मौजूद है (membership helper को छोड़कर)।

### 4. सुरक्षित अगला कदम
1. Feature Branch में narrow Admin RPCs प्रस्तावित करें: location correction, legacy-only booking correction, timer billing adjustment, electrician activation/emergency block, और staff permission-aware application review।
2. हर mutation में mandatory reason, actor, before/after audit, idempotency और row lock रखें; paid/refunded/payout-linked financial rows पर generic edits निषिद्ध हों।
3. Offer matching में category/skill approval और distance/availability eligibility जोड़ें; Cash slot reservation को acceptance के साथ atomic करें।
4. Manual payment और payout RPC को timer snapshot + labour-only 15% platform fee + separate materials + fee/refund allocation से जोड़ें; historical quote path को केवल legacy records के लिए रखें।
5. Isolated test environment में Admin positive और Customer/Electrician/unauthorized staff negative JWT tests, duplicate/retry/concurrency और audit assertions चलाएँ।

No production function, ACL, policy, table, record, payment setting, wallet, staging resource or deployment changed. यह read-only live catalog audit है और इसके निष्कर्ष Master Requirements में दर्ज किए गए।


## 17.47 — Smart Matching और Admin RPC के लिए Live Schema Readiness / Data Model Gap (13 Nov 2026)

Production `information_schema.columns` से केवल column names/types/nullability पढ़े गए। कोई customer/electrician row या PII value नहीं पढ़ी गई और कोई write नहीं हुआ।

### 1. Matching के लिए उपलब्ध वर्तमान fields
- `electrician_profiles`: active, verification_status, skills[], state, district, pincode, location_lat/lng, auth_user_id, user_id.
- `electrician_applications`: skills text, experience_years, verification_status, active, location_lat/lng और service-area fields.
- `service_bookings`: service_type, state/district/pincode, location_lat/lng, assigned_electrician_id, status.
- `job_offers`: booking_id, electrician_id, status, match_level, created_at, responded_at.
- इन tables में इस schema snapshot में अलग approved category/rate tier, verified skill evidence per skill, electrician availability schedule/current busy state, travel radius, distance rank, offer expiry/round, या unique digital electrician ID columns नहीं मिले।

### 2. Smart Matching का gap
- वर्तमान `srk_admin_offer_booking` PIN-first और district fallback करता है; nearest eligible electrician ranking और approved category/rate-tier match की पुष्टि नहीं।
- `skills[]` मौजूद है, पर केवल text-array membership से skill का verified होना सिद्ध नहीं होता। Verified skill/category approval के लिए evidence/status/approver/audit data model चाहिए।
- Customer की `service_type` को approved electrician category और exact service skill से map करना होगा; category downgrade/upgrade automatic नहीं होना चाहिए।
- Location missing/invalid होने पर deterministic PIN/district fallback होना चाहिए; distance calculation के लिए valid coordinates, bounded radius, tie-breaker और privacy-safe location handling परिभाषित हों।
- Offer creation को duplicate-safe, bounded batch, deterministic ranking और acceptance/Cash-slot reservation के साथ transactional बनाना होगा। Existing `job_offers` status timestamps हैं, पर इस column inventory में expiry/round/sequence fields नहीं।

### 3. प्रस्तावित Feature Branch-only Admin RPC contracts (नाम प्रस्तावित; अभी बनाए नहीं गए)
| Proposed RPC | सीमित जिम्मेदारी | आवश्यक सुरक्षा |
|---|---|---|
| `srk_admin_correct_booking_location` | address/district/state/PIN correction | Admin/staff permission, reason, validation, before/after audit |
| `srk_admin_transition_booking` | केवल अनुमत non-financial lifecycle transition | explicit from/to allow-list, row lock, state-machine validation, idempotency |
| `srk_admin_adjust_legacy_booking_amount` | केवल legacy quote bookings का documented correction | timer/frozen-bill bookings निषिद्ध, reason, before/after, finance audit |
| `srk_admin_set_electrician_control_state` | active/block/suspend/emergency control | permission scope, reason, in-progress booking protection, actor audit |
| `srk_admin_review_electrician_application` | application + approved category/verified skills review | OTP-linked identity, document evidence, category allow-list, unique ID, separate activation |
| `srk_admin_dispatch_booking_offers` | eligible candidates rank करके offers create करना | category+verified skills, availability, distance, row lock, dedupe, Cash slot coordination |

ये contract names design proposals हैं, live objects नहीं। इन्हें current Production में create या call नहीं किया गया।

### 4. Migration prerequisite
- Migration history source reconciliation अभी unresolved है (Production 81 entries; cross-branch scan में 43 names के लिए exact-version या same-name source नहीं मिला)। इसलिए अभी कोई timestamped migration या Production schema edit सुरक्षित रूप से तैयार/apply नहीं किया गया।
- पहले source lineage और live dependencies reconcile हों; फिर additive Feature Branch migration में नई category/skill evidence, availability, offer sequence/expiry और Admin audit structures जोड़े जाएँ।
- पुराने profiles/bookings को स्वतः category या verified-skill मानकर backfill न करें; Admin-reviewed mapping आवश्यक है।
- Acceptance, booking slot reservation और offer state एक ही transaction में lock/commit हों; matching result केवल candidate discovery हो, authorization नहीं।

### 5. अगला सुरक्षित implementation क्रम
1. Category/service/skill mapping और verification evidence schema finalize करें।
2. Offer eligibility और distance ranking का deterministic specification लिखें; missing coordinates fallback तय करें।
3. Narrow Admin RPC contracts और permission matrix finalize करें।
4. Migration lineage clear होने पर Feature Branch-only additive SQL और unit tests; फिर isolated Test Mode में concurrency, duplicate offer, wrong category, unverified skill, inactive/suspended electrician, missing location और acceptance race tests।
5. कोई Production migration/deployment तभी जब अलग से स्पष्ट approval मिले।

No production schema, data, RPC, ACL, wallet, booking, payment, staging resource or deployment changed. यह section read-only schema evidence और प्रस्तावित design दर्ज करता है।


## 17.48 — छह प्रस्तावित Admin RPC के Permission, Validation, Audit और State-Transition Contracts (13 Nov 2026)

यह section छह RPC के implementation contracts तय करता है। ये अभी design-only हैं; कोई नया RPC, migration, permission, table या production change नहीं बनाया गया।

### 1. सभी RPC के साझा अनिवार्य नियम
- प्रत्येक RPC `SECURITY DEFINER` हो तो fixed trusted `search_path`, postgres owner, PUBLIC/anon EXECUTE revoke और केवल आवश्यक authenticated/service_role grants हों। SECURITY DEFINER अपने-आप authorization नहीं है।
- User-facing Admin action में `auth.uid()` अनिवार्य हो; caller का Admin/staff role और exact permission scope server-side verify हो। केवल UI hide करना पर्याप्त नहीं।
- Main Admin supreme/non-delegable रहेगा। Staff role केवल explicitly granted View/Add/Edit/Manage permission कर सके; staff स्वयं permission या role grant नहीं कर सकता।
- हर mutation में mandatory non-empty reason, actor ID, source, server timestamp, target ID, before/after snapshot/hash और deterministic non-null idempotency key audit में हो।
- हर multi-row action transaction में row locks और deterministic lock order अपनाए; duplicate request same result दे, conflicting replay reject हो।
- Input allow-list, length/range checks, ownership/relationship checks, current-state precondition और explicit result code अनिवार्य। Client amount, actor ID, role, approval flag या timestamp को authoritative न मानें।
- PII response least-privilege हो; completed/cancelled/rejected booking contact/coordinates सामान्य Customer/Electrician response में न लौटें।
- Financial/timer snapshots immutable हों; correction नई adjustment/reversal event से हो, मूल record overwrite नहीं।

### 2. RPC-specific contracts

#### A. `srk_admin_correct_booking_location` — प्रस्तावित
- Inputs: booking ID, corrected address, state, district, PIN, optional validated coordinates, reason, idempotency key.
- Server: Admin/staff location-edit permission; booking lock; PIN/state/district validation; completed booking पर केवल historical correction event, operational dispatch location नहीं बदलना; accepted/in-progress booking में re-dispatch risk पर अलग Admin confirmation.
- Audit: पुराने/नए address fields, actor, reason, source, timestamp; customer/electrician को केवल आवश्यक notification.
- निषेध: amount, status, assignment, timer या payment field इस RPC से बदलना नहीं।

#### B. `srk_admin_transition_booking` — प्रस्तावित
- Inputs: booking ID, requested target action/state, reason, idempotency key.
- Server: state-machine allow-list और explicit from→to edges; booking lock; assignment/offer/slot consistency; timer state, payment/refund और cancellation decision guard.
- Admin को भी paid/refunded/payout-linked booking को generic status change से बदलने की अनुमति नहीं; dedicated refund/reconciliation/cancellation RPC जरूरी।
- हर transition immutable event और notification outbox entry लिखे; duplicate request idempotent हो।

#### C. `srk_admin_adjust_legacy_booking_amount` — प्रस्तावित
- केवल legacy quote-era booking जिनमें timer bill snapshot मौजूद नहीं।
- Inputs: booking ID, corrected labour amount, separate materials amount, reason, evidence/reference, idempotency key.
- Server: Admin-only finance permission; row lock; non-negative amounts; original quote/payment/provider/refund/payout reconciliation; paid/refunded/payout-linked booking पर generic correction निषिद्ध या dedicated recovery workflow में भेजे।
- Original quoted amount कभी overwrite न हो; append-only adjustment record और revised receivable/payable calculation बने।
- Materials labour base और 15% platform fee calculation से पूरी तरह बाहर रहें।

#### D. `srk_admin_set_electrician_control_state` — प्रस्तावित
- Inputs: electrician profile ID, active/blocked/suspended state, reason, scope/duration if applicable, idempotency key.
- Server: Admin/staff account-control permission; profile lock; identity link validation; open accepted/in-progress booking होने पर automatic assignment removal नहीं; emergency block अलग event और safe customer reassignment/notification workflow.
- Re-enable केवल authorized Admin/staff permission से; self-approval/permission escalation निषिद्ध।
- Audit actor, old/new state, reason, effective time और affected booking IDs रखे।

#### E. `srk_admin_review_electrician_application` — प्रस्तावित
- Inputs: application ID, decision, approved category, verified skill evidence references, reason, idempotency key.
- Server: application lock; allowed decision; Auth phone ownership match; document evidence review status; category allow-list; per-skill verifier/approver and evidence; unique non-reusable electrician digital ID issuance.
- Approval, active status और dispatch eligibility अलग controls हों; approved profile default inactive until activation. Rejection/suspension reason and appeal/review history retained.
- किसी client-provided skill string को verified skill न मानें; category downgrade/upgrade automatic न हो।

#### F. `srk_admin_dispatch_booking_offers` — प्रस्तावित
- Inputs: booking ID, bounded batch size, reason/dispatch mode, idempotency key.
- Server: booking lock; approved category + exact verified skill + active/approved profile + availability + service area + travel radius; nearest eligible first with deterministic tie-break; missing coordinates पर documented PIN/district fallback.
- Candidate discovery और offer creation एक transaction/consistent snapshot में; unique booking/electrician offer; expiry and sequence; only one accepted electrician; duplicate/retry safe.
- Acceptance RPC same transaction family में Cash slot reservation करे; third-slot Online rule को durable reservation से enforce करे।
- No eligible candidate होने पर explicit no_match state; unverified/inactive/wrong-category electrician को offer नहीं।

### 3. Permission matrix (minimum)
| Action | Main Admin | Staff with exact scope | Customer/Electrician |
|---|---|---|---|
| Location correction | Allow + audit | Only location-edit scope | Deny |
| Booking lifecycle transition | Allow + audit | Only booking-manage scope, non-financial edges | Deny |
| Legacy finance adjustment | Allow + finance audit | Explicit finance-adjust scope only, optionally dual approval | Deny |
| Electrician block/activate | Allow + emergency audit | Only account-control scope; emergency block may be Main Admin-only | Deny |
| Application/category/skill approval | Allow + evidence audit | Only verification-review scope; final activation Main Admin-only if policy requires | Deny |
| Offer dispatch | Allow + dispatch audit | Only dispatch-manage scope | Deny |

### 4. Required negative and positive tests
- Customer JWT, Electrician JWT, expired session, suspended Admin, staff missing exact scope, staff attempting self-escalation: deny.
- Main Admin valid request: allow only valid transition and record audit.
- Invalid PIN/category/skill/status, negative amount, blank reason, forged actor/time, duplicate idempotency, mismatched ownership: reject safely.
- Two Admins editing same booking, dispatch duplicates, accept-vs-cancel race, block-vs-accept race: deterministic locking and no double assignment/slot.
- Completed booking contact response contains no phone/address/coordinates for non-Admin; Admin contact route remains separately guarded.
- Financial correction never changes timer snapshot; materials never enter 15% labour-only fee base.
- Audit append-only behavior tested against UPDATE/DELETE attempts and service-role caller provenance.

### 5. Implementation gate
- पहले migration lineage gap और live ACL/RLS evidence clear करें।
- फिर additive Feature Branch migration और RPC implementation; existing RPC callers update करें।
- Unit tests + SQL integration + JWT negative tests + UI E2E + Razorpay Test Mode regression आवश्यक।
- कोई Production apply, paid staging resource या deployment अलग explicit approval के बिना नहीं।

No production code/schema/ACL/data, payment, wallet, customer/electrician record, staging resource or deployment changed. केवल design contract documentation Feature Branch में जोड़ा गया।


## 17.49 — Migration Commit-Ancestry Search और unresolved Cash Payment migration की source recovery (13 Nov 2026)

GitHub repository के commit search और चुने गए commit diffs की जाँच की गई। यह उपलब्ध repository commit-search results तक सीमित है; deleted branches, forks, local clones, GitHub backups या Supabase dashboard के बाहर के स्रोत इसमें शामिल नहीं।

### 1. Duplicate Cash Payment migration का परिणाम
- Production migration version `20261111083811_add_assigned_electrician_cash_payment_status` के लिए exact version/name commit search में कोई result नहीं मिला।
- `add_assigned_electrician_cash_payment_status` phrase search में भी कोई commit result नहीं मिला।
- इसलिए दूसरी migration का source और उसका अलग applied effect अभी unresolved है। केवल live schema/functions से उसका exact historical SQL पुनर्निर्मित नहीं किया जा सकता।
- पहले version `20261111082515` का exact source पहले sweep में मिला था; उससे दूसरे version का effect infer नहीं करना है।
- No-op migration बनाकर history को “ठीक” करना, duplicate version को drop/rename करना या अनुमानित SQL replay करना निषिद्ध है।

### 2. Commit diff में मिले अतिरिक्त lineage evidence
- Commit `8c5a3dfefff85d4faf8c4fdff05cb7467236d96c` customer direct-call contact RPC migration जोड़ता है; active states की allow-list में completed नहीं है। यह उस commit की source history है, Production में exact body apply होने का स्वतंत्र प्रमाण नहीं।
- Commit `04d0c02f03cd7fb27d9b699b109dedc0fa0e0bad` quote workflow का पूरा migration source जोड़ता है; पहले मौजूद one-line “Applied migration” note से source recovery संभव हुई। इससे historical quote dependency chain और commission/service-only behavior का evidence मिलता है।
- Commit `a08a874098a9ee929c76bb94612b6dee4f93bf5e` Razorpay Route transfer reconciliation ledger का server-only schema दिखाता है; RLS enabled, anon/authenticated table privileges revoked, service_role write access. इसे live Production में मौजूद मानना अभी उचित नहीं; अलग live inventory चाहिए।
- Commit `23fcdc2a95fcafd4ec321be02f091d0eed28802c` GPS columns और coordinate pair/range constraints का source दिखाता है; बाद के commit `762262ea9dfb64e0d4c1366d54953ec3402a90c0` में उन constraints को validate करने का evidence है।
- Commit `c8144e4eabc4434603844f48aac335aada90fe1a` customer booking ownership column, index और own-booking SELECT policy का source दिखाता है।
- Commit `7c13153393efbef7ab2150a5068d59e59358c847` private API rate-limit table और service_role-only RPC का source है; संबंधित filename correction commits भी मिले।

### 3. निष्कर्ष और अगला सुरक्षित कदम
- Commit search से कुछ पुराने migrations के source lineage का अतिरिक्त प्रमाण मिला, पर unresolved second Cash migration recover नहीं हुई।
- अब प्रत्येक recovered source के लिए commit ancestry, blob SHA, Production migration version, live object definition और schema effect का अलग evidence map बनाना होगा।
- Route transfer ledger, GPS constraints, booking ownership और rate-limit migration के live Production objects/ACLs को targeted SELECT-only catalog comparison से जाँचना होगा।
- किसी recovered commit को अकेले Production migration का exact applied body न मानें; version/name/content/live effect का चार-तरफा मिलान आवश्यक है।

No migration history, source file, branch, database object, data row, permission, payment setting or deployment changed. केवल commit-search और diff evidence Master Requirements में दर्ज किया गया।


## 17.50 — Recovered Migration Sources बनाम Live Production Schema/ACL का targeted comparison (13 Nov 2026)

Production catalog से केवल schema metadata, constraints, policies, grants और function definition पढ़े गए। कोई table row, payment transfer, rate-limit record या customer/electrician PII नहीं पढ़ा गया।

### 1. Razorpay Route Transfer Ledger — Live Production में मौजूद
- `public.srk_route_transfers` Production में मौजूद है; RLS enabled, FORCE RLS false.
- Live columns recovered commit `a08a8740...` के design से मेल खाते हैं: booking/payment/recipient, linked account, transfer ID, non-null idempotency key, paise amount, INR currency, transfer/settlement states, errors, timestamps.
- Live constraints में positive amount, INR only, recipient type/user consistency, unique idempotency key, unique (payment ID, recipient type), unique transfer ID और booking/user foreign keys हैं।
- Policy `srk_route_transfers_deny_client_api` anon और authenticated को ALL operations पर false करती है। Table grants snapshot में postgres और service_role दिखे; anon/authenticated grants नहीं दिखे।
- Migration source ने service_role के लिए SELECT/INSERT/UPDATE लिखा था, जबकि वर्तमान `information_schema.role_table_grants` snapshot service_role पर DELETE/TRUNCATE सहित broader effective grants दिखाता है। यह अंतर जाँचने योग्य है; कोई privilege change नहीं किया गया।
- यह schema मौजूद होने का प्रमाण है, न कि Razorpay Route live transfers चालू होने, linked account approved होने, या वास्तविक धन भेजे जाने का प्रमाण। Transfer functions/callers, triggers, service-role use और Test Mode/Live Mode permissions अलग जाँचेंगे।

### 2. GPS Coordinate Constraints — तीनों tables पर validated
- `service_bookings`, `electrician_applications`, `electrician_profiles` में latitude/longitude columns मौजूद हैं।
- तीनों में coordinate pair और valid range constraints मौजूद हैं; सभी छह constraints `convalidated=true` हैं।
- इसलिए GPS coordinate pair/range validation live Production में लागू और validated है।
- इससे location permission consent, accuracy, stale location, radius policy या Smart Matching correctness प्रमाणित नहीं होती।

### 3. Customer Booking Ownership — live evidence
- `service_bookings.customer_user_id` मौजूद है और `auth.users(id)` foreign key के साथ `ON DELETE SET NULL` है।
- Live SELECT RLS policy Admin या matching customer_user_id को booking read की अनुमति देती है। यह cross-user direct SELECT restriction का catalog evidence है; real JWT negative tests अभी बाकी हैं।
- Historical guest/null ownership rows को automatically किसी Customer से link नहीं करना चाहिए।

### 4. Public API Rate Limit — private schema में live
- `private.srk_public_api_rate_limits` मौजूद है और RLS enabled है; FORCE RLS false. इस targeted policy query में कोई explicit table policy नहीं मिली।
- `public.srk_check_public_rate_limit(text,text,integer)` postgres-owned SECURITY DEFINER है, fixed search_path `pg_catalog, private, pg_temp`; ACL में केवल postgres और service_role EXECUTE हैं, PUBLIC/anon/authenticated नहीं।
- Function endpoint allow-list (booking/application), 64-char lowercase hex IP hash, limit 1–20, hourly window counter और 7-day cleanup लागू करता है।
- Table grant snapshot में service_role पर broad privileges (DELETE/TRUNCATE सहित) दिखे; function स्वयं cleanup के लिए DELETE करता है। Least-privilege review आवश्यक है, पर अभी कोई grant बदला नहीं।
- इससे rate-limit function/schema का live existence प्रमाणित है; production endpoint callers, IP hash derivation, actual limits और bypass resistance अभी अलग code/runtime test मांगते हैं।

### 5. Migration lineage निष्कर्ष
- Route Transfer, GPS, booking ownership और rate-limit source candidates का live schema effect काफी हद तक corroborate हुआ।
- यह exact migration version/body applied होने का पूर्ण प्रमाण नहीं: migration history version, source blob, commit ancestry और live object effect का अलग-अलग मिलान जारी रहेगा।
- Live GPS constraints validated हैं; Route Transfer ledger मौजूद है; private rate-limit table/function मौजूद हैं। इन features को “अभी Production में नहीं” कहना अब सही नहीं होगा।
- दूसरी Cash Payment status migration `20261111083811` अब भी unresolved है; ऊपर के schema matches उससे संबंधित नहीं हैं।

### 6. अगला सुरक्षित चरण
1. Route Transfer के सभी functions, Netlify callers, webhook triggers, status update path और service_role usage का read-only inventory।
2. Service_role grants के source/default privileges का catalog audit; least-privilege recommendation, बिना बदलाव।
3. Rate-limit endpoint callers और actual per-endpoint limit values का code-to-live mapping।
4. फिर शेष Production migration history के high-risk payment/security sources पर यही four-way comparison।

No Production schema, grant, policy, record, payment/transfer, migration history, deployment or staging resource changed. यह SELECT-only evidence और Feature Branch documentation update है।


## 17.51 — Razorpay Route Transfer Functions, Webhook Callers और Transfer Status Path Audit (13 Nov 2026)

Feature Branch source और Production catalog का read-only audit किया गया। कोई webhook invoke नहीं हुआ, Razorpay API call/transfer नहीं हुआ, और कोई DB record नहीं पढ़ा/बदला गया।

### 1. Feature Branch में Route transfer implementation की स्थिति
- Repository tree में Route transfer ledger की एक migration मिली: `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql`.
- इस migration में server-only `srk_route_transfers` table, unique idempotency key, unique (payment ID, recipient type), transfer/settlement states और RLS शामिल हैं।
- Feature Branch source tree में Route transfer create/fetch/reverse/settlement handler, Netlify function adapter, scheduled reconciliation worker या payout-trigger caller नहीं मिला।
- उपलब्ध payment handlers `create-order.js`, `verify-payment.js`, `razorpay-webhook.js` केवल customer order/payment verification और `service_bookings` payment status update करते हैं; Route transfer ledger में insert/update नहीं करते।
- Netlify webhook adapter केवल root `razorpay-webhook.js` को forward करता है; अलग Route transfer logic नहीं।
- इसलिए Route transfer ledger को live table होने के बावजूद automated transfer workflow implemented/verified नहीं माना जा सकता।

### 2. Live Production catalog में Route transfer RPC/trigger evidence
- Public/private function name scan में Route/transfer-specific create, reconcile, reverse या settlement RPC नहीं मिला।
- `srk_route_transfers` table पर कोई database trigger नहीं मिला; इसलिए DB trigger से transfer lifecycle/audit/immutability लागू होने का evidence नहीं।
- Table में RLS enabled, FORCE RLS false; anon/authenticated के लिए deny-all policy मौजूद है।
- `service_role` के effective table grants में SELECT/INSERT/UPDATE के अलावा DELETE, TRUNCATE, REFERENCES और TRIGGER भी दिखे। Migration source केवल SELECT/INSERT/UPDATE grant करता है। अतिरिक्त privileges का स्रोत इस catalog check से तय नहीं हुआ; role-level/default grants और inherited membership की अलग जाँच जरूरी है।
- अभी कोई GRANT/REVOKE नहीं किया गया। RLS deny policy के बावजूद service_role privileged server path है; broad service_role permissions को least-privilege review के बिना सुरक्षित नहीं मानना चाहिए।

### 3. Existing Razorpay webhook की code-level findings
- Webhook raw request body पर HMAC-SHA256 signature verify करता है और `payment.captured` / `order.paid` events स्वीकारता है।
- Payment ID/order ID format, captured status, INR, amount और booking order match checks हैं।
- लेकिन webhook event ID `x-razorpay-event-id` / payload event identity को durable event ledger में persist/dedupe नहीं करता; concurrent delivery में booking PATCH `payment_status != paid` guard पर निर्भर है।
- Unknown booking, cash booking, amount mismatch और non-payable booking के लिए HTTP 200 with `reconciled:false` लौटता है; इससे provider retry नहीं होगा। Admin webhook exception table/function live होने का प्रमाण है, लेकिन इस root handler में exception record insert नहीं दिखा।
- Handler payment captured होने पर केवल `service_bookings` को paid करता है; electrician/platform split transfer create नहीं करता, Route transfer state update नहीं करता।
- यह legacy quote-approved completed booking और `service_charge + materials_amount = quoted_amount` पर निर्भर है; Master timer-based labour bill, separate materials, 15% labour-only fee से मेल नहीं खाता।
- Verify-payment और webhook दोनों service-role PATCH से paid status finalize करते हैं; shared atomic finalization RPC/event ledger नहीं दिखा। Race handling केवल read-after-empty PATCH result पर आधारित है।

### 4. Production में refund workflow (संबंधित सीमा)
- Admin refund preparation RPC Admin guard, booking row lock, verified Razorpay payment और quote-total reconciliation करता है; payout pending हो तो block करता है; paid payout पर separate Admin reconciliation माँगता है।
- Refund table पर audit trigger INSERT/UPDATE/DELETE रिकॉर्ड करता है, पर Route transfer reversal/partial transfer reversal linkage इस inspected function में नहीं।
- Admin webhook exception list RPC exception/processing_error rows पढ़ता है; इससे exception table उपलब्ध है, पर inspected webhook source द्वारा rows populate होना प्रमाणित नहीं।

### 5. Release blockers / आवश्यक अगला design
1. Payment event inbox: provider event ID unique, raw payload hash, signature verification result, received/processed timestamps, retry/error state; duplicate और out-of-order events atomic तरीके से handle हों।
2. Shared server finalization RPC: payment intent/billing snapshot, booking lock, provider payment ID/order/amount/currency, one-time ledger posting और idempotent result.
3. Route transfer orchestrator: approved linked account, recipient split, labour-only platform fee, materials exclusion, deterministic transfer idempotency key, provider API request/response references.
4. Transfer status webhook/reconciliation: created/pending/processed/failed/reversed/partially_reversed/manual_review transitions; provider event dedupe; periodic reconciliation; no blind duplicate transfer.
5. Refund linkage: booking/payment/transfer recipient mapping, partial/full reversals, payout already paid recovery, cash-vs-online separation.
6. Append-only transfer event/audit trail; ledger rows must not be deletable/truncatable by ordinary application role.
7. Least-privilege service_role review; determine why effective DELETE/TRUNCATE/TRIGGER/REFERENCES grants exceed migration grant statement before any change.
8. Test Mode only: duplicate webhook, out-of-order capture/refund, verify-vs-webhook race, network timeout after provider transfer, partial reversal, duplicate idempotency, unlinked account and amount mismatch.

### 6. निष्कर्ष
- Route transfer ledger schema Production में है, लेकिन इस Feature Branch snapshot में उसे operate करने वाला transfer workflow नहीं मिला।
- Existing Razorpay payment capture webhook is not a Route transfer engine; payment paid status alone does not prove electrician payout/commission split transfer.
- Do not enable Live Route transfer or infer payout completion from `service_bookings.payment_status='paid'`.
- No production function, trigger, grant, table, record, payment, transfer, webhook setting, staging resource or deployment changed.

यह section केवल code/catalog evidence दर्ज करता है; Route transfers अभी implemented या end-to-end tested घोषित नहीं हैं।


## 17.52 — Existing Razorpay Webhook Event Inbox Discovery और सुरक्षित अगला Design (13 Nov 2026)

यह चरण केवल Production catalog metadata और Feature Branch source का read-only निरीक्षण है। कोई webhook payload/transaction row नहीं पढ़ी गई; कोई schema/permission/data परिवर्तन नहीं किया गया।

### 1. महत्वपूर्ण नई खोज: Webhook Event Inbox पहले से मौजूद है
Production में `public.srk_razorpay_webhook_events` table पहले से मौजूद है:
- `event_id` text PRIMARY KEY — provider event ID को unique रखने की क्षमता पहले से है।
- `event_type`, Razorpay order/payment/refund IDs, amount paise, currency, processing status, reconciliation reason और received/processed/updated timestamps मौजूद हैं।
- Status allow-list: received, reconciled, exception, ignored, processing_error.
- Order/time और status/time indexes मौजूद हैं।
- RLS enabled, FORCE RLS false; anon/authenticated के लिए कोई policy नहीं मिली।
- Effective grants में service_role को INSERT/SELECT/UPDATE के साथ DELETE/TRUNCATE/REFERENCES/TRIGGER भी मिले। इन अतिरिक्त grants का source अभी unresolved है।
- Table metadata में payload hash, signature verification result, attempt counter, lease/claim token, next retry time, last error class या immutable event history fields नहीं मिले।
- वास्तविक event rows/payloads नहीं पढ़े; इसलिए table में कोई event है या handler द्वारा इस्तेमाल हो रहा है, ऐसा दावा नहीं।

### 2. Existing webhook source से तुलना
- Feature Branch `razorpay-webhook.js` अभी event ID को durable inbox में insert/upsert नहीं करता।
- Handler केवल captured payment को legacy quote-approved completed booking पर reconcile करता है।
- इसलिए Production में event inbox table मौजूद होना, event deduplication/processing चालू होने का प्रमाण नहीं।
- `srk_admin_list_razorpay_webhook_exceptions(integer)` केवल exception/processing_error records पढ़ता है; inspected webhook handler उनमें event record लिखता हुआ नहीं मिला।

### 3. नया table बनाने के बजाय existing inbox को सुरक्षित रूप से evolve करने का प्रस्ताव
Migration lineage पूरी तरह reconcile होने और Feature Branch schema dependencies की पुष्टि के बाद additive design:
- Existing `event_id` primary key को provider event dedupe key बनाए रखें; duplicate delivery पर दूसरा processing job न बने।
- केवल आवश्यक metadata columns additive रूप से जोड़ें: raw_body_sha256, signature_verified_at/result, attempt_count, claimed_at/lease_token, next_attempt_at, last_error_code, last_error_at; raw secrets/authorization headers store न हों।
- Full raw payload default रूप से store न करें; यदि audit आवश्यकता साबित हो तो PII minimization, retention और access policy अलग तय हो।
- Atomic claim/lease RPC duplicate workers को रोकता हो; expired lease recovery हो; retryable और terminal exceptions अलग हों।
- Event processing और payment finalization अलग atomic boundaries में न हों: shared DB RPC booking row lock, provider payment identity/amount/currency, frozen billing snapshot और one-time ledger entries एक transaction में verify/post करे।
- Out-of-order events को state machine के अनुसार handle करें; पुराने event से paid/refunded/reversed state पीछे न जाए।
- Webhook response: durable event successfully recorded/claimed हो तो 2xx; temporary DB failure पर non-2xx जिससे provider retry करे; terminal mismatch को event inbox में exception के रूप में दर्ज कर 2xx दें और Admin reconciliation queue में दिखाएँ।
- Event inbox access server-only रहे; client direct read/write नहीं। Admin को केवल guarded, minimized exception view।
- Append-only event transition log और controlled retention/archival; normal app role से DELETE/TRUNCATE न हो।

### 4. Route transfer design पर निर्भरता
- Event inbox payment capture/refund/transfer event identity dedupe कर सकता है, पर transfer orchestration अलग durable state machine है।
- Route transfer creation तभी हो जब verified captured payment, frozen timer labour amount, materials excluded, approved electrician linked account, recipient amount reconciliation और per-recipient idempotency key सभी पास हों।
- Transfer API timeout में blind retry नहीं: पहले provider transfer ID/reference से lookup/reconcile; ambiguity पर manual_review।
- Partial/full refund के लिए original transfer mapping, amount already reversed, remaining refundable amount, payout status और append-only reversal entries अनिवार्य।
- Payment capture event को सीधे transfer API call से जोड़ने से पहले settlement timing, provider capability/approval और Test Mode evidence validate करें।

### 5. अगला काम
1. Production migration history में `srk_razorpay_webhook_events` की exact migration version/source blob/ancestry recover करें; current catalog अकेला पर्याप्त नहीं।
2. Admin exception RPC, table RLS/grants और existing webhook handler के सभी callers का complete map करें।
3. Feature Branch में existing inbox-compatible additive migration और server handler architecture design करें; migration timestamp अनुमान से न बनाएं।
4. पहले unit tests और mocked provider tests; उसके बाद approved Test Mode only, no Live transfers.
5. Service_role extra grants का origin/default privileges/inherited membership अलग से trace करें; अभी कोई permission change नहीं।

### 6. निष्कर्ष
नया webhook event table बनाने की जरूरत अभी सिद्ध नहीं है; Production में पहले से event inbox है। सही अगला रास्ता duplicate table नहीं, बल्कि source lineage verify करके existing inbox को सुरक्षित रूप से इस्तेमाल/विस्तारित करना है। Event inbox मौजूद है, लेकिन current inspected webhook handler उसे उपयोग नहीं करता — यह मुख्य integration gap है।


## 17.53 — Production Webhook Inbox के exact columns, RLS, indexes और Admin exception RPC की पुनः पुष्टि (13 Nov 2026)

यह जाँच केवल PostgreSQL catalog metadata और function definition पर आधारित है। कोई event row, customer PII, payment payload या financial record नहीं पढ़ा गया; कोई DB mutation नहीं हुई।

### 1. Inbox table का exact live shape
`public.srk_razorpay_webhook_events` में ये columns हैं:
- `event_id` text NOT NULL (primary key)
- `event_type` text NOT NULL
- `razorpay_order_id`, `razorpay_payment_id`, `razorpay_refund_id` nullable text
- `payment_amount_paise` nullable bigint, `payment_currency` nullable text
- `processing_status` NOT NULL, default `received`
- `reconciliation_reason` nullable text
- `received_at` NOT NULL default now(); `processed_at` nullable; `updated_at` NOT NULL default now().
- Indexes: unique primary key on `event_id`; order ID + received time descending; processing status + received time descending.
- इस catalog snapshot में payload hash, signature result, attempt count, claim lease, retry schedule और last-error fields नहीं हैं।

### 2. RLS और effective table grants
- RLS enabled होने की पूर्व catalog जाँच की पुष्टि के साथ, इस बार `pg_policies` query में इस table के लिए कोई policy row नहीं मिली। अतः client API के लिए policy-based access नहीं खुलता।
- `information_schema.role_table_grants` में postgres और service_role को SELECT/INSERT/UPDATE के अतिरिक्त DELETE, TRUNCATE, REFERENCES और TRIGGER भी मिले।
- anon/authenticated के लिए table grants नहीं मिले।
- अतिरिक्त service_role privileges का स्रोत अभी भी unresolved है; default privileges, role membership/inherited grants और object-level grant history की जाँच बाकी है। कोई GRANT/REVOKE नहीं किया।

### 3. Admin exception RPC की वास्तविक सीमा
- `public.srk_admin_list_razorpay_webhook_exceptions(integer)` live definition प्राप्त हुई।
- SECURITY DEFINER, fixed search_path `pg_catalog, public, auth, pg_temp`; Admin membership guard; limit 1–100.
- केवल `exception` और `processing_error` statuses लौटाता है।
- Returned columns में event ID/type, order/payment IDs, amount/currency, processing status/reason और timestamps हैं; `razorpay_refund_id` लौटाया नहीं जाता।
- यह read-only listing RPC है; इससे event insert, retry, reprocess, lease claim या refund reconciliation capability सिद्ध नहीं होती।

### 4. Implementation निर्णय
- Existing inbox table को ही आधार बनाना है; दूसरा duplicate event table नहीं बनाना।
- Event ID dedupe, payload hash, verified-signature metadata, safe lease/attempt/retry fields और append-only event transition audit का additive proposal रखा जाए।
- Refund event के लिए Admin exception visibility में refund ID भी शामिल हो; लेकिन RPC update से पहले exact migration lineage और dependent clients verify हों।
- No raw payload storage unless retention/PII controls explicitly designed.
- No event rows read/modified; no schema, policy, grants or function changed.

### 5. अगला audit क्रम
1. Inbox table की exact migration source/version/blob और Production migration history से match।
2. सभी repository references/callers और webhook endpoint routing का search; पता करें कोई दूसरा handler event table write तो नहीं करता।
3. Table owner, role membership, default privileges और service_role extra grants का origin trace।
4. Existing event status transitions और Admin exception UI mapping का source audit।
5. उसके बाद ही Feature Branch में additive migration design और tests; Production में कोई migration नहीं।


## 17.54 — Webhook Inbox Migration Lineage और service_role अतिरिक्त Grants के स्रोत की जाँच (13 Nov 2026)

यह जाँच Production migration history, PostgreSQL catalog ACL/default ACL/role membership तथा Feature Branch GitHub source की read-only तुलना पर आधारित है। कोई event/payment row या payload नहीं पढ़ा गया; कोई permission/schema/data परिवर्तन नहीं हुआ।

### 1. Migration lineage का निष्कर्ष
- Production migration history में 81 entries हैं; उपलब्ध सूची में `srk_razorpay_webhook_events` बनाने वाली कोई स्पष्ट migration entry/name नहीं मिला।
- Feature Branch recursive tree में भी इस inbox table की creation/alteration migration नहीं मिली।
- GitHub commit search में exact table identifier `srk_razorpay_webhook_events` से कोई matching commit नहीं मिला।
- इसलिए table का exact migration version, source SQL blob और commit ancestry अभी recover नहीं हुए। Production में table मौजूद होना अपने-आप migration source/history का प्रमाण नहीं है। इसे untracked/manual/omitted source घोषित करना भी अभी जल्दबाजी होगी।
- अगला स्रोत-पुनर्प्राप्ति चरण: उपलब्ध backup/export, historical branch refs और Supabase migration artifacts में exact CREATE TABLE/ALTER TABLE source खोजना; बिना स्रोत के कोई migration repair/replay नहीं।

### 2. Table owner और effective ACL
- Live table owner `postgres` है। Live relation ACL: postgres और service_role दोनों को `arwdDxtm` (SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER) मिला है।
- anon/authenticated इस table की relation ACL में नहीं हैं; पिछली जाँच में कोई RLS policy भी नहीं मिली और RLS enabled है।
- इस table के लिए service_role का व्यापक ACL एक वास्तविक least-privilege concern है; लेकिन इसे केवल इस table पर अलग से दिया गया grant मानना सही नहीं होगा।

### 3. Default privileges से मिला महत्वपूर्ण कारण
- Production `pg_default_acl` में public schema के future tables (`defaclobjtype='r'`) के लिए postgres grantor का default ACL `{postgres=arwdDxtm, anon=arwdDxtm, authenticated=arwdDxtm, service_role=arwdDxtm}` मिला।
- Supabase_admin grantor के public-table default ACL में भी यही broad role set मौजूद है।
- यह बताता है कि public schema में default-created tables को broad grants मिल सकने का platform/database-wide कारण मौजूद है; यह specific inbox table की exact grant provenance या ऐतिहासिक migration SQL साबित नहीं करता।
- Role membership snapshot में authenticator और supabase_realtime_admin service_role के सदस्य हैं; postgres service_role का सदस्य है। service_role को किसी अतिरिक्त high-privilege role की membership इस query में नहीं मिली।
- निष्कर्ष: पहले default ACL के scope/necessity और specific object ACL की उत्पत्ति अलग-अलग trace करनी होगी। Global default ACL को बदलना व्यापक प्रभाव वाला कदम होगा; अभी कोई REVOKE/ALTER DEFAULT PRIVILEGES नहीं।

### 4. Webhook implementation cross-check
- Feature Branch root `razorpay-webhook.js` signature HMAC verify करता है, लेकिन `srk_razorpay_webhook_events` को INSERT/UPDATE/SELECT नहीं करता।
- `netlify/functions/razorpay-webhook.js` केवल root handler का adapter है; दूसरा event persistence handler नहीं।
- `netlify/functions/verify-payment.js` भी root `verify-payment.js` adapter है।
- Root webhook अभी केवल `payment.captured` और `order.paid` process करता है; unknown/non-payable/amount mismatch/cash booking पर durable inbox event record नहीं बनाता। Refund/transfer event lifecycle इस handler में नहीं है।
- Feature Branch tree में event inbox table के लिए migration source भी नहीं मिला। अतः Production inbox और current branch handler के बीच integration gap बना हुआ है।

### 5. अगला सुरक्षित क्रम
1. Historical source/backup/branch artifact से inbox table की creation SQL और ACL history recover करें।
2. Default ACL के owner/grantor scope और platform-managed grants का प्रभाव समझें; global grants को छुए बिना table-specific least-privilege proposal तैयार करें।
3. Existing webhook handler और Admin exception UI/RPC के सभी code references की complete search करें; refund ID field consumers को verify करें।
4. Source lineage मिलने के बाद ही Feature Branch additive migration/handler proposal बनाएं; migration timestamp अनुमान से न बनाएं।
5. Mocked tests: duplicate event ID, signature fail, retryable DB error, out-of-order payment/refund, concurrent claim, terminal mismatch और Admin exception visibility।

### 6. सुरक्षा सीमा
- Production table, grants, default privileges, policies, functions, rows, payments, transfers और webhook settings में कोई बदलाव नहीं हुआ।
- कोई Test Mode या Live provider API call, staging resource creation या deployment नहीं हुआ।


## 17.55 — Admin Webhook Exception UI और Repository Caller Mapping (13 Nov 2026)

Feature Branch के tracked Admin UI और webhook adapter source का read-only audit किया गया। Production UI/API को कोई request या mutation नहीं भेजी गई।

### 1. Admin UI की वास्तविक स्थिति
- Feature Branch में Admin portal का tracked entry file `admin.html` है; उसमें Admin login के बाद `is_srk_admin()`, booking/application/profile data, `srk_admin_commission_report()`, wallet overview और payout/manual-payment RPC calls मिले।
- `admin.html` में `srk_admin_list_razorpay_webhook_exceptions`, `webhook`, `exception`, `processing_error` या refund exception view का कोई matching reference नहीं मिला।
- इसलिए Production में Admin exception-list RPC मौजूद होने के बावजूद Feature Branch Admin portal उसे call/render नहीं करता। यह UI visibility gap है; RPC का अस्तित्व UI workflow होने का प्रमाण नहीं।
- `admin.html` में refund management UI/RPC call भी इस scan में नहीं मिला। Refund exception handling अलग से जोड़ने से पहले current Admin refund RPCs, approval process और UI architecture का complete review आवश्यक है।

### 2. Webhook callers / routing
- Root `razorpay-webhook.js` ही inspected webhook processing implementation है।
- `netlify/functions/razorpay-webhook.js` root handler को import/export करता है; कोई स्वतंत्र processing logic नहीं।
- `netlify/functions/verify-payment.js` root `verify-payment.js` को adapter के रूप में export करता है।
- Root webhook event inbox table का कोई read/write नहीं करता; इसलिए Admin exception RPC के लिए इस handler से durable exception event नहीं बनता।
- GitHub code-search endpoint पर exact table/RPC identifiers की खोज में कोई परिणाम नहीं आया; इसे अकेले repository-wide absence का निर्णायक प्रमाण नहीं मानते। Tracked tree और Admin HTML direct inspection से ऊपर के निष्कर्ष निकाले गए हैं।

### 3. Migration source recovery की वर्तमान सीमा
- Production migration history (81 entries) में inbox table की स्पष्ट creation migration नहीं मिली।
- Feature Branch tracked migration tree में भी creation migration नहीं मिली।
- Exact identifier पर commit search भी खाली रहा।
- Historical branch refs/backup/database export में source recovery अभी बाकी है; वर्तमान evidence से मूल migration timestamp या SQL body बताना संभव नहीं।

### 4. सुरक्षित implementation दिशा (अभी design-only)
- Admin में exception queue केवल guarded Admin RPC से आए; raw event payload, signature header, secret या अनावश्यक PII कभी expose न हो।
- Exception row में event ID/type, refund/payment/order reference, amount/currency, received time, status, retryability और sanitized error reason दिखें।
- Retry/Reprocess को सीधे UI से table UPDATE न बनने दें; dedicated Admin RPC reason, actor, idempotency, state transition validation और audit event के साथ atomic claim/retry schedule करे।
- Terminal mismatch events को automatic retry न करें; reconciliation queue/manual review में रखें।
- Existing refund RPC/UI contracts समझे बिना refund retry या transfer reversal button न जोड़ें।

### 5. अगला चरण
1. Historical branch refs/backup/export से webhook inbox table source recover करने का प्रयास।
2. Existing Admin refund workflow RPCs, their guards, audit triggers and table relationships inspect करना।
3. Main Admin/staff permissions और Admin UI navigation contract से exception queue जोड़ने का design।
4. UI/API mock tests: Admin vs non-Admin, empty queue, refund event, duplicate event, retry lock, terminal mismatch, sanitized errors.

### 6. सुरक्षा सीमा
कोई Production UI, function, table, grant, policy, event, payment, refund, transfer या deployment बदला नहीं गया। कोई Test/Live provider API call या paid staging resource नहीं बनाया गया।


## 17.56 — Admin Refund Workflow, RPC, Ledger, Audit और Historical Handler Audit (13 Nov 2026)

### 1. Production Refund RPC और State Flow (catalog read-only)
Production में निम्न refund functions की live definitions पढ़ी गईं:
- Customer: `srk_customer_create_booking_refund_request`, `srk_customer_list_booking_refund_requests`
- Admin: `srk_admin_list_booking_refund_requests`, `srk_admin_decide_booking_refund_request`, `srk_admin_prepare_booking_refund`, `srk_admin_list_razorpay_refunds`, `srk_admin_prepare_razorpay_refund`, `srk_admin_record_manual_refund`, `srk_admin_finalize_manual_booking_refund`
- Service reconciliation: `srk_service_reconcile_booking_refund`
- Audit trigger function: `srk_capture_razorpay_refund_audit_event`

Observed behavior:
- Customer request RPC `auth.uid()` और booking.customer_user_id ownership check करता है; केवल verified paid booking और positive amount पर request लेता है; reason 20–1000 chars; प्रति booking unique request; rejected request को दोबारा submit किया जा सकता है।
- Admin list/decision/preparation/manual-refund RPCs Admin guard लगाते हैं; decision RPC row lock लेता है और processing/unknown/processed को दोबारा decision से रोकता है।
- Razorpay prepare RPC booking row lock लेता है; verified Razorpay payment, payment ID format और amount-paid reconciliation जाँचता है; quote approved और `quoted_amount = service_charge + materials_amount = amount_paid` अनिवार्य है। Timer/non-quote refund explicitly blocked है।
- Existing refund record मिलने पर वही record लौटाया जाता है; failed refund पर नया attempt रोककर manual reconciliation माँगी जाती है।
- Pending payout को blocked किया जाता है; paid payout पर recovery/reconciliation error आता है।
- Service reconcile RPC केवल service_role स्वीकारता है; provider status pending/processed/failed allow-list; refund row lock; processed terminal replay handling; processed होने पर booking payment_status refunded और संबंधित request processed; failed होने पर request unknown। यह refund retry orchestration स्वयं नहीं करता।
- Manual refund RPC verified paid manual-payment booking, matching manual payment audit entry और duplicate रोकथाम जाँचता है; paid electrician payout पर रोकता है; audit entry बनाकर booking को refunded करता है।

### 2. Live Tables, Constraints, RLS और Audit
तीन live tables catalog में मौजूद हैं:
- `srk_booking_refund_requests`: प्रति booking unique request; status allow-list requested/in_review/approved/rejected/processing/unknown/processed; amount > 0; booking/customer/admin/refund FKs।
- `srk_razorpay_refunds`: प्रति booking unique refund; unique idempotency key और provider refund ID; INR only; payment/refund ID format checks; status requested/processing/unknown/processed/failed।
- `srk_manual_refund_entries`: प्रति booking और प्रति payment-entry unique; positive amount; reference validation; booking/payment/actor FKs।
- तीनों tables RLS enabled, FORCE RLS false; catalog ACL में postgres और service_role के broad table privileges हैं; anon/authenticated table ACL grant नहीं दिखा। Service role grants में DELETE/TRUNCATE सहित व्यापक अधिकार हैं; इन्हें अभी नहीं बदला गया।
- `srk_razorpay_refunds` पर INSERT/UPDATE/DELETE audit trigger `srk_capture_razorpay_refund_audit_event` है; manual refund entries पर `srk_capture_admin_audit_event` trigger है। Razorpay audit function refund_id/amount/status/provider_status के before/after बदलाव, actor और action को Admin audit events में लिखता है।
- Refund request table पर अलग audit trigger इस निरीक्षण में नहीं मिला; request state changes का पूर्ण before/after audit coverage अभी प्रमाणित नहीं।

### 3. Refund UI और Historical Feature Branch का अंतर
- वर्तमान Feature Branch `feature/platform-fee-cash-online-cycle` के `admin.html` में Refund section, refund RPC caller या refund button नहीं मिला; यह वर्तमान Admin UI gap है।
- Historical branch `safe-payment-refund-implementation` में `admin.html` में Razorpay Refund रिकॉर्ड table, `srk_admin_list_razorpay_refunds` caller, Manual Refund और Razorpay Refund actions मिले। उसी branch में `create-refund.js` और Netlify adapter मौजूद हैं। इसे current Feature Branch या Production में deployed/active मानने का प्रमाण नहीं है।
- Historical `create-refund.js` flow Admin token और Admin RPC से refund prepare करता है, फिर server-side Razorpay API call करता है; refund record/payout/booking state पर direct service-role REST PATCH भी करता है। Provider timeout/uncertain response को unknown बताकर same idempotency key से retry की बात करता है। Provider API call वास्तव में execute नहीं किया गया।
- Historical handler के direct table PATCH path और live service reconciliation RPC के बीच single atomic state transition प्रमाणित नहीं; delayed response/webhook race तथा payout restoration/settlement paths को tests से verify करना बाकी है।
- Current Feature Branch root webhook में refund event handling/reconciliation नहीं मिला; historical refund handler alone webhook lifecycle की पुष्टि नहीं करता।

### 4. Master Requirements से महत्वपूर्ण अंतर / Blockers
1. Refund calculation अभी legacy quote total पर आधारित है; timer actual-minute labour, separate materials, labour-only 15% platform fee और partial refund allocation से जुड़ा नहीं।
2. Razorpay refund schema/function में एक refund per booking और full paid amount assumption है; partial/multiple refunds का समर्थित allocation नहीं।
3. Paid electrician payout के बाद refund recovery ledger/workflow नहीं; केवल रोक/exception है।
4. Cash/manual refund में payout recovery और cancellation/fee/wallet reversal accounting का पूर्ण path नहीं।
5. Refund event inbox dedupe, provider refund webhook reconciliation, out-of-order handling और periodic status fetch/reconciliation का current Feature Branch integration नहीं मिला।
6. Failed/unknown refund के लिए audited retry/reprocess RPC/UI नहीं; failed state पर नया prepare रोकता है, unknown को retryable कहने से पहले provider-side status verification चाहिए।
7. Refund request state का append-only audit/actor reason coverage, staff-scoped permissions, maker-checker approval और immutable event history अभी प्रमाणित नहीं।
8. Admin UI में current refund visibility/action path absent है; historical UI को बिना वर्तमान Master Requirements से मिलान किए वापस नहीं लाना।

### 5. आगे का सुरक्षित काम
- Historical branch के migration/source/commit ancestry को live definitions से मिलाना; historical code को सीधे restore न करना।
- Refund architecture को timer bill snapshot, full/partial refund allocation, separate materials, platform fee, payout recovery, cash/online ledgers और provider webhook inbox के साथ redesign करना।
- Dedicated server-side provider adapter, shared atomic reconciliation RPC, unique provider event/refund IDs, deterministic idempotency, retry lease/claim, immutable audit और safe Admin queue का contract बनाना।
- Admin/customer UI केवल अनुमोदित RPC contract पर बनाना; refund reason, actor, amount breakdown और terminal/unknown state स्पष्ट दिखाना।
- Test Mode में duplicate/out-of-order refund webhook, provider timeout, same-idempotency retry, partial/full refund, failed refund, paid payout recovery, concurrent Admin action और non-Admin JWT denial tests आवश्यक।

### 6. सुरक्षा सीमा
यह निरीक्षण केवल Production catalog/function definitions/constraints/ACL/triggers और GitHub source का read-only audit था। कोई वास्तविक refund/payment/provider API call, refund record read, customer PII row read, Production table/function/grant/policy change, migration, staging resource या deployment नहीं किया गया।


## 17.57 — Timer Billing + Razorpay Refund + Route Reversal का सुरक्षित एकीकृत डिज़ाइन और Test Matrix (13 Nov 2026)

यह section design/test contract है; implementation या production behavior का दावा नहीं है।

### 1. एकमात्र वित्तीय स्रोत: Frozen Booking Bill
Timer completion/customer approval के बाद server-side immutable bill snapshot बने:
- booking_id, customer_id, electrician_id, category/rate tier;
- approved start/end server timestamps और actual billable minutes;
- labour amount, separately approved materials amount, tax/other permitted line items (यदि लागू हों), gross payable;
- 15% Platform Fee केवल labour amount पर; materials पर कभी नहीं;
- payment method, payment intent/order/payment IDs, currency और captured amount;
- bill version/hash, created_at, approval/audit event references।
Snapshot बनने के बाद client quote/amount को payment या refund calculation में authority न मिले। Correction केवल reasoned Admin adjustment event से; original snapshot overwrite नहीं।

### 2. Refund Allocation Ledger (प्रस्तावित)
हर refund को अलग immutable allocation entries में बाँटना होगा:
- original bill line और original captured payment से link;
- refunded labour paise, refunded materials paise और अन्य eligible line-item paise अलग;
- प्रत्येक line पर पहले से refunded total और शेष refundable balance;
- provider refund ID / idempotency key / currency / status / timestamps;
- actor, reason, request source, before-after state और audit event।
सभी गणनाएँ integer paise में; INR के अलावा currency reject; amount शून्य/negative, over-refund, duplicate provider ID और original payment से अधिक cumulative refund reject।
Partial refund के लिए allocation rule (Admin द्वारा line-wise चयन या स्वीकृत deterministic proportional rule) को Product/Finance approval के बाद ही freeze करना है; बिना स्वीकृत नियम स्वतः labour/material विभाजन न करें।

### 3. Platform Fee और Route Reversal Invariants
- Platform Fee का मूल आधार केवल snapshot का labour हिस्सा है; materials पर 15% fee नहीं।
- Refund में labour allocation और materials allocation अलग रखें। Route transfer reversal केवल उस labour/platform-fee और electrician-settlement हिस्से तक सीमित हो जो वास्तव में transfer हुआ हो और refund allocation से संबंधित हो।
- Materials pass-through को Platform Fee या electrician commission की गणना में शामिल न करें।
- Transfer अभी pending/failed हो तो उसे completed reversal न मानें; provider-verified status आवश्यक।
- Transfer पहले से processed हो तो full/partial reversal की provider confirmation और immutable ledger entry दोनों आवश्यक।
- Electrician payout पहले से bank-paid हो तो केवल booking को refunded mark करना पर्याप्त नहीं; recovery/receivable, future earning offset, dispute और approval का अलग policy निर्णय चाहिए। कोई स्वतः wallet debit या negative balance policy approval के बिना नहीं।
- Route reversal और customer refund अलग provider operations हैं; एक सफल होने से दूसरा सफल मानना निषिद्ध। दोनों के लिए स्वतंत्र idempotency key, event status और reconciliation चाहिए।

### 4. Unified Refund State Machine (प्रस्तावित)
`requested → in_review → approved → preparing → provider_pending → processed`
वैकल्पिक terminal/exception states: `rejected`, `failed`, `unknown`, `manual_review`, `partially_processed`।
- Customer request केवल request बनाती है; provider refund शुरू नहीं करती।
- Admin approval amount और line allocation को reason सहित freeze करती है।
- Server worker/RPC atomic claim/lease के साथ provider operation चलाता है; browser से secret या direct table mutation नहीं।
- Network timeout को `unknown` रखें; उसी immutable idempotency key से provider status fetch/reconcile किए बिना नया refund request न भेजें।
- Webhook signature verify, durable event inbox insert, unique provider event ID, payload hash, duplicate/out-of-order handling; event processor event को atomically claim करे।
- Provider webhook और synchronous API response दोनों shared reconciliation service/RPC में converge करें; terminal `processed/failed` state को stale response overwrite न करे।
- Customer payment refund, Route transfer reversal, electrician payout recovery और platform fee accounting अलग linked sub-ledgers हों; सबकी completion independently verified हो।

### 5. Atomicity, Audit और Permission Rules
- Booking, bill snapshot, refund request, refund allocation, payment record और transfer allocation पर deterministic lock order तय हो; deadlock/retry handling test हो।
- Unique constraints: provider event ID, refund idempotency key, provider refund ID (जब उपलब्ध), allocation source+operation key, transfer reversal idempotency key।
- Append-only events; correction/reversal नया compensating event हो, historical ledger row delete/update नहीं।
- Admin RPC में Main Admin/staff exact permission scope, reason, actor, source, server timestamp, before/after, idempotency और row lock अनिवार्य।
- Customer केवल अपनी booking/request देखे; Electrician केवल अनुमोदित सीमित status देखे; किसी पक्ष को दूसरे का phone/address/bank/provider secret न मिले।
- Service role केवल server runtime; client table writes बंद; table-level broad DELETE/TRUNCATE grants का least-privilege review implementation से पहले।
- Staff maker-checker/dual approval की सीमा और emergency override policy अलग तय करनी है; अभी approved नहीं मानी जाए।

### 6. अनिवार्य Test Matrix (Test Mode / Mock; अभी निष्पादित नहीं)
1. Full Online refund, labour-only; full Online refund with labour+materials.
2. Partial labour refund; partial materials refund; mixed partial refund; repeated partial refunds; cumulative over-refund rejection.
3. Materials amount पर 15% fee न लगना; fee केवल labour allocation पर।
4. Route transfer pending, processed, failed, reversed और partially reversed; प्रत्येक status पर refund coordination।
5. Customer refund processed लेकिन Route reversal pending; Route reversal processed लेकिन customer refund unknown; reconciliation resumes without duplicate provider operation.
6. Electrician payout pending, blocked, processed और already bank-paid; paid payout recovery policy के बिना auto debit न हो।
7. Cash booking refund; manual refund reference duplicate; cash customer/electrician/platform fee ledger reversal अलग-अलग।
8. Provider API timeout before response, timeout after provider accepted, 4xx validation, 5xx, malformed response; same idempotency key/status fetch.
9. Duplicate webhook, duplicate event ID with altered payload hash, out-of-order pending after processed, invalid signature, unknown refund ID, amount/currency/payment mismatch.
10. Concurrent Admin approve, concurrent worker claim, webhook-vs-API response race, duplicate customer request, booking cancellation/refund race.
11. Customer A vs Customer B, Electrician, unauthorised staff and Admin JWT permission tests; PII masking/visibility checks.
12. Audit completeness, append-only enforcement, integer paise rounding, retry lease expiry, provider reconciliation after downtime.
13. Timer boundary tests: customer approves start, completion request server timestamp, late approval, duplicate start/stop, dispute, frozen bill hash unchanged.
14. Legacy quote booking compatibility: historical paid/refunded/cash records preserved; no automatic migration/backfill; legacy refund route isolated from new timer bill route.

### 7. Implementation क्रम और Release Gates
A. Product/Finance decisions freeze: partial allocation default, cancellation/refund eligibility, fee reversal timing, paid payout recovery, cash refund payer/receiver, tax treatment, staff approval threshold.
B. Source/lineage recovery: refund tables/functions/webhook inbox/Route ledger migrations and ACL provenance; exact SQL blob + migration history + live catalog match.
C. Additive schema/RPC design on approved isolated development environment only; production project पर migration नहीं।
D. Unit + SQL invariant + concurrency tests; mocked Razorpay adapter tests; JWT role matrix.
E. Razorpay Test Mode end-to-end: duplicate/out-of-order webhook, timeout, full/partial refund, transfer reversal, payout exception; no Live funds.
F. Admin/customer/electrician UI integration and receipts/ledger/report reconciliation; accessibility and Hindi copy.
G. Security review, migration lineage reconciliation, rollback plan, explicit user approval; then only one consolidated production deployment after user authorizes it.

### 8. वर्तमान स्थिति और निषेध
- ऊपर का design केवल प्रस्तावित contract है; कोई migration, table, RPC, UI, provider call या test execution इस section से नहीं हुआ।
- अभी कोई isolated Supabase development branch नहीं बनाया गया; paid/hourly resource का खर्च user approval के बिना नहीं।
- Product/Finance policy decisions pending होने तक partial refund, fee reversal, paid payout recovery और cash refund को auto-process नहीं करना।
- Production schema, RLS, grants, functions, rows, payments, refunds, transfers, webhooks या deployment में कोई बदलाव नहीं।


## 17.58 — Current Feature Branch Timer → Bill → Payment → Fee → Refund Dependency Map (13 Nov 2026)

यह GitHub Feature Branch का source audit है; यह Production deployment या live behavior का प्रमाण नहीं है।

### 1. Timer lifecycle: वर्तमान code में नहीं मिला
- Recursive tracked tree में timer-specific migration/file या timer start/stop/approval/bill-snapshot implementation नहीं मिला।
- `electrician.html` अभी `assigned → inspection → quote → quote_approved → in_progress → completed` flow दिखाता है।
- Electrician स्वयं `workStatus(id,'in_progress')` और `workStatus(id,'completed')` करता है; Customer द्वारा start approval/stop approval और immutable server-time boundary का UI/RPC path इस file में नहीं मिला।
- Quote submit `srk_submit_booking_quote` से `service_charge`, `materials_amount`, `quote_note` भेजता है; पुराने inspection/quote lifecycle पर निर्भर है।
- `booking.html` Customer payment UI में completed + quote approved + quoted_amount पर निर्भर है; timer snapshot/actual minutes नहीं पढ़ता।
- इसलिए Section 17.57 का frozen bill अभी design-only है; कोई timer invoice source मौजूद होने का प्रमाण नहीं।

### 2. Booking create और amount trust boundary
- `create-booking.js` client payload से `payment_method` और optional `quoted_amount` पढ़कर booking insert करता है; यह केवल प्रारंभिक request data है, final price authority नहीं होना चाहिए।
- `booking.html` submit के समय `quoted_amount` client से भेजता है।
- भविष्य में booking create पर final price स्वीकार न हो; bill केवल approved category/rate + server timer + approved material lines से बने। Client-sent total को payment amount न मानें।

### 3. Online payment chain: सभी तीन हिस्से legacy quote पर
- `create-order.js` booking में `quoted_amount`, `service_charge + materials_amount`, `status='completed'`, `quote_status='approved'` validate करता है; Razorpay order amount quote total से बनाता/reuses करता है।
- `verify-payment.js` signature, provider captured status, order ID, INR और amount verify करता है; फिर `service_bookings.payment_status='paid'` direct service-role PATCH करता है। Amount source legacy approved quote है।
- `razorpay-webhook.js` `payment.captured/order.paid` events पर वही quote/status/amount validation करता है और booking paid PATCH करता है। Durable event inbox write और shared atomic finalization RPC current handler में नहीं।
- Customer UI भी quoted_amount से online pay button amount दिखाती है।
- इन तीनों payment paths को एक shared atomic finalization function और frozen bill snapshot पर migrate करना होगा; अलग-अलग legacy validation/updates को साथ-साथ न छोड़ें।

### 4. Platform Fee / Cash settlement chain: quote-era fields पर आधारित
- Feature Branch migration `20261112220000_cash_platform_fee_due_and_online_settlement.sql` `service_bookings.payment_status='paid'` + `status='completed'` पर payout/fee trigger चलाती है।
- `20261113120000_limit_cash_fee_settlement_to_labour_share.sql` उसी trigger का संशोधित source है; current fee `service_charge × commission_rate` के रूप में निकाला जाता है, materials को अलग रखता है; पुराने Cash dues को अगले Online booking के labour share से सीमित करके settle करता है।
- Cash booking पर electrician को direct customer cash मिलता है और SRK ledger में labour-only Platform Fee due बनता है। Online booking पर electrician payable/payout record बनता है और पुराने cash fee dues को online receipt से settle किया जा सकता है।
- Refund trigger path paid payout पर रोकता है; Cash due पहले ही बाद की booking में settle हो चुका हो तो Cash refund को Admin reconciliation तक block करता है; Online refund पुराने settled cash due को restore करता है।
- यह logic अभी `service_charge`, `materials_amount`, `commission_rate`, legacy payout rows और `payment_status='refunded'` transition पर निर्भर है; timer bill allocations/partial refund/provider Route reversal को consume नहीं करता।
- Migration file में `srk_platform_fee_ledger` Feature Branch schema है; इसकी Production presence इस audit में पुनः verify नहीं की गई। इसे live मानकर code/deploy नहीं करना।

### 5. Refund और payout integration की सीमा
- पहले दर्ज Section 17.56 के अनुसार live refund RPC quote-total equality पर आधारित हैं; current Feature Branch Admin refund UI अनुपस्थित है।
- Cash fee trigger में refund होने पर ledger compensation की कुछ स्थितियाँ हैं, पर already-settled cash dues तथा paid payout cases जानबूझकर block होते हैं और Admin reconciliation माँगते हैं।
- Razorpay refund provider call, refund webhook event inbox, Route transfer/reversal ledger, paid payout recovery और timer line-item allocation का end-to-end bridge नहीं मिला।
- इसलिए `payment_status='refunded'` को अकेले पूरे financial refund का प्रमाण नहीं मानना चाहिए; customer refund, Platform Fee reversal, electrician earning/payout recovery और Route reversal अलग-अलग reconcile हों।

### 6. End-to-end dependency order (implementation contract)
1. Timer event store + Customer start/stop approval + dispute boundary.
2. Immutable bill snapshot: labour minutes/rate, separate material items, total, fee basis and hash.
3. Payment intent/order bound to snapshot ID/hash and immutable paise amount.
4. One atomic payment finalizer used by verify endpoint and webhook; durable event inbox and dedupe.
5. Fee/payout/cash-cycle ledger posting from snapshot, not quote fields; booking slot reservation and concurrency lock.
6. Refund allocation ledger tied to original snapshot/payment; partial/full cumulative cap.
7. Provider refund and Route transfer/reversal orchestration as separate idempotent operations.
8. Payout recovery and cash-fee restore/reversal compensating entries.
9. Admin/customer/electrician UI, receipt, earnings, finance reports and audit migrated together.
10. Legacy quote path read-only compatibility for historical records; no blanket backfill or destructive column/function drop.

### 7. High-risk integration test cases (source-driven)
- Timer stop request vs Customer approval delay: bill uses documented server boundary, not browser clock.
- Materials-only amount change does not change 15% fee; labour change recalculates only before bill freeze.
- Verify endpoint and webhook simultaneously receive same captured payment: one payment ledger/payout/fee posting only.
- Webhook duplicate/out-of-order and unknown booking: durable event/exception queue, no silent HTTP-200 loss.
- Razorpay order reuse after bill snapshot version/hash change: old order rejected, new authorized order only.
- Cash cycle slot reservation race across two electricians/booking accepts; third slot policy enforced atomically.
- Cash fee due settled from later online labour share, then original cash booking refund: compensation/restore reconciles once.
- Online booking refund after cash dues settlement: restore exactly the previously settled due, no materials deduction.
- Full/partial refund with pending vs paid payout; paid payout must route to approved recovery workflow.
- Route transfer success while customer refund fails, and inverse; independent status and retry.
- Legacy paid/refunded/quote records remain unchanged and visible in historical reporting.

### 8. निष्कर्ष
- Verified in Feature Branch: legacy quote-based work flow, quote-based order/verify/webhook, labour-only cash fee settlement logic, limited refund compensations and payout blockers.
- Not present/verified in Feature Branch: customer-approved timer lifecycle, immutable timer bill snapshot, unified atomic payment finalizer, refund allocation ledger, Route transfer orchestrator/reversal, complete paid-payout recovery.
- No tests were executed in this read-only source review. No code/migration/UI was changed in this section; only this requirements audit record is being added.


## 17.59 — Admin, Customer, Electrician Earnings, Wallet and Receipt/Report Dependency Audit (13 Nov 2026)

यह Feature Branch के tracked source और migration definitions का read-only audit है। UI/source में किसी सुविधा का न मिलना Production में उसका न होना सिद्ध नहीं करता; live status अलग verify करना होगा।

### 1. Admin Panel — legacy amount/status और payout/report dependencies
- `admin.html` booking list में `quoted_amount`, `payment_status`, `amount_paid`, Razorpay IDs और booking status पढ़ता है।
- Admin booking edit path status तथा `quoted_amount` सीधे table update करता है; paid amount edit रोकता है और Razorpay-linked payment status direct बदलने से रोकता है। यह फिर भी legacy amount/status editing path है; timer frozen bill के लिए dedicated reasoned adjustment/event RPC नहीं।
- Manual payment के लिए `srk_admin_record_manual_payment` RPC caller मौजूद है; लेकिन UI पहले booking को Completed कराकर manual payment दर्ज करने का पुराना क्रम अपनाता है।
- Admin payout list `srk_electrician_payouts` पढ़ती है; Paid marking dedicated RPC `srk_admin_mark_electrician_payout_paid` से है और वास्तविक UTR/reference माँगती है।
- Admin wallet overview `srk_admin_wallet_overview()` और payout panel दिखते हैं; इस UI में Refund management और Webhook Exception queue caller/section नहीं मिला (Section 17.55–17.56)।
- Admin commission report RPC का स्रोत paid+completed booking `amount_paid` और `commission_amount` जोड़ता है; timer minutes, bill snapshot, fee allocations, cash fee due, refund/Route reversal और paid-payout recovery का consolidated statement नहीं।

### 2. Customer Booking — quote total, payment status, amount paid
- `booking.html` customer booking history में `quoted_amount`, `service_charge`, `quote_status`, `amount_paid` और `payment_status` दिखाता/पढ़ता है।
- Online pay action केवल completed + approved quote booking के लिए है और client-side amount `quoted_amount` से आता है।
- Paid UI केवल `amount_paid` और booking reference दिखाता है; इस inspected file में itemized immutable bill/receipt, labour minutes, rate tier, material line items, Platform Fee, refund allocations, Razorpay refund ID, Route reversal state या downloadable receipt flow नहीं मिला।
- Customer स्वयं Cash से Online बदलने का RPC path है; यह payment method preference update है, bill snapshot/payment capture नहीं।

### 3. Electrician Earnings, Fee Due and Wallet
- `electrician.html` earnings `srk_get_my_earnings()` से पढ़ता है और `amount_received`, `commission_amount`, `electrician_earning` आधारित totals दिखाता है; ये legacy report fields हैं।
- Payout history `srk_electrician_payouts` से `electrician_payable`, payout status, method, reference और paid_at पढ़ती है।
- Platform Fee due summary `srk_get_my_platform_fee_summary()` से अलग दिखता है; cash due, reversal और online settlement entries के labels मौजूद हैं।
- Wallet summary `srk_get_my_wallet_summary()` और bank-link list पढ़ी जाती है; UI text और wallet foundation migration के अनुसार bank payouts disabled हैं जब तक Route linked-account onboarding/live approval पूरा न हो। Wallet read पर account row create होने का side effect migration में मौजूद है; इसे accounting ledger posting न समझें।
- Wallet foundation migration कहती है कि customer top-up/electrician payouts provider flow approval तक enabled नहीं; wallet ledger अलग है, जबकि payout table और Platform Fee ledger के बीच पूर्ण unified journal/reconciliation का प्रमाण नहीं।
- Earnings display में पुराने `commission_amount` को “Platform Fee” label से दिखाया गया है; timer snapshot से गणना का path अभी नहीं।

### 4. Receipt / invoice / report coverage
- Inspected Customer और Electrician pages में formal immutable bill/receipt generator या receipt download/share component नहीं मिला।
- Admin commission report और wallet overview मौजूद हैं, लेकिन वे timer billing + labour/material split + fee + refunds + Route reversals + payouts का एक unified financial statement नहीं।
- इस audit में अलग receipt/invoice source file tracked tree में नहीं मिली। यह tracked Feature Branch source तक सीमित निष्कर्ष है; external provider receipts/other branches इससे बाहर हैं।

### 5. Required migration map
| क्षेत्र | वर्तमान dependency | Timer Billing में आवश्यक बदलाव |
|---|---|---|
| Admin booking editor | `status`, `quoted_amount` direct update | narrow reasoned RPC; frozen bill immutable; append-only adjustment |
| Admin manual payment | completed quote + manual payment RPC | bill snapshot ID/hash + exact paise + cash/online evidence |
| Admin payout | legacy payout amount/status | bill allocation + fee settlement + refund/recovery reconciliation |
| Admin commission report | `amount_paid`, `commission_amount` | labour-only fee lots, material pass-through, refund/reversal and payout statement |
| Customer history | quote fields and amount_paid | immutable itemized bill, actual minutes, rate, materials, payment/refund status |
| Customer receipt | basic paid amount/reference only | server-generated receipt with unique ID, snapshot hash, payment/refund/fee details |
| Electrician earnings | amount_received/commission_amount/electrician_earning | frozen bill and actual fee ledger allocations |
| Electrician wallet | separate wallet summary/ledger + payout table | approved accounting model; no silent wallet debt/negative balance |
| Platform Fee due | separate cash fee ledger | snapshot-based due and compensating entries, partial refund aware |
| Refund/Route | separate/incomplete paths | linked allocation and independent provider status reconciliation |

### 6. Priority blockers before implementation sign-off
1. One canonical bill snapshot must feed Customer receipt, Electrician earnings, Admin reports, payment order, fee ledger, payout and refund.
2. Admin cannot edit frozen amount/status through generic table update; controlled adjustment must preserve original and reason/actor/audit.
3. Customer receipt and Electrician earning statements must distinguish labour, materials, Platform Fee, previous cash-fee settlement, net payable and refunds.
4. Reconcile wallet ledger, payout table, platform fee ledger and Route transfer ledger; define which is accounting source of truth and avoid double counting.
5. Define receipt number, version/hash, tax/GST treatment if applicable, refund credit/debit notes and historical quote receipt compatibility before coding.
6. Keep bank payout disabled until approved provider onboarding and live permissions; Test Mode does not prove live settlement.
7. No destructive quote-column/function cleanup until every historical reader, report and refund path has a compatibility plan.

### 7. निष्कर्ष
- Feature Branch में Admin payout/manual-payment, Customer booking/payment history, Electrician earnings, Platform Fee due summary और wallet overview के हिस्से मौजूद हैं।
- ये अभी quote-era booking amount और अलग-अलग ledger/report structures पर आधारित हैं; complete Timer Bill/Receipt/Refund/Route statement नहीं।
- इस section में कोई UI, RPC, SQL migration, schema, data, provider setting या deployment नहीं बदला; केवल audit documentation जोड़ी जा रही है।


## 17.60 — Feature Branch Security, Access-Control and Final Legacy-Cleanup Readiness Audit (13 Nov 2026)

यह source-level review है; Production security certification या penetration test नहीं। कोई live JWT, PII, payment, provider या database mutation test नहीं किया गया।

### 1. Public booking/application endpoints
- `create-booking.js` और `apply-electrician.js` POST-only हैं; 16 KB body cap, input validation, Netlify client-IP header, SHA-256 IP hash और server-side rate-limit RPC इस्तेमाल करते हैं।
- Feature Branch limits: booking 5/hour/IP hash, electrician application 3/hour/IP hash; rate-limit backend unavailable होने पर fail-closed 503.
- Customer booking endpoint Supabase Auth user token verify करता है, confirmed phone और submitted 10-digit phone match करता है।
- Public direct INSERT policies हटाने और anon/authenticated INSERT revoke करने का migration source मौजूद; writes server-side service_role endpoint से।
- सीमाएँ: IP-based throttling shared NAT/mobile network users को प्रभावित कर सकती है; IP hash में server-side secret/HMAC नहीं, इसलिए hash को anonymization या strong anti-abuse identity न मानें। Rate-limit test, trusted Netlify header behavior और proxy spoofing boundary production-like environment में verify होनी चाहिए।
- Booking endpoint अभी client-sent `payment_method` और `quoted_amount` insert करता है। इसे authoritative price/payment decision न बनने दें; timer bill/payment intent server-generated होना चाहिए।

### 2. Authenticated RPC and contact privacy
- Customer call-contact migration में customer ownership `customer_user_id = auth.uid()`, assigned electrician और active booking states filter हैं; completed/cancelled states excluded.
- Feature Branch का private implementation + public SECURITY INVOKER wrapper pattern मौजूद है; private function SECURITY DEFINER और `search_path=public,pg_temp` पर है। Fixed trusted path और object qualification review आवश्यक है।
- Earlier migration version public SECURITY DEFINER contact function थी; later migration replaces it with private implementation. Migration ordering/Production applied state exact source lineage के बिना assume न करें।
- Section 17.45 में Production-side other contact RPCs/offer details में completed-state leakage concern दर्ज है। Branch में सभी customer/electrician/admin contact functions को single privacy policy से reconcile करना बाकी है।
- Master phone policy: before acceptance numbers hidden; after assignment visible; after completion/cancellation no mutual phone exposure. हर RPC, table/API, receipt/history and UI must enforce same state boundary. Negative JWT tests (wrong customer, wrong electrician, unassigned, completed, cancelled, anon) required.

### 3. SECURITY DEFINER / grants / service-role boundary
- Feature Branch migration files contain SECURITY DEFINER functions for rate limiting, work status/quotes, wallet overview, cash fee settlement, offer acceptance and related flows. Fixed search_path is present in some, but not all historical functions have identical path configuration.
- Service-role writes in Netlify functions bypass RLS by design; every endpoint must independently authenticate actor, validate ownership/role, validate allowed fields and amounts, and avoid logging secrets/PII.
- Existing wallet and Route/fee ledgers have RLS enabled and client write access revoked in migration sources; service_role receives broad write privileges. Ledger immutability is not fully guaranteed by RLS alone; DELETE/TRUNCATE grants, table owner, triggers and role inheritance/default privileges must be checked separately.
- Production audit Sections 17.50–17.54 found broader effective service_role ACL/default privileges and webhook inbox source lineage unresolved. No global default ACL or service_role grants should be changed without a scoped dependency/rollback plan.

### 4. High-risk business-state and race conditions
- Offer acceptance migration serializes same-electrician acceptances with profile row lock and booking lock; it calculates third-booking rule from completed, quote-approved, paid, payment-verified records. It is still quote-era and does not implement the new timer billing snapshot.
- Cash fee migration uses per-electrician advisory transaction lock and idempotency keys; however pooled cash dues can later be settled by a different online booking, making original cash booking refund require Admin reconciliation. Paid payout refunds are also blocked for manual reconciliation.
- Webhook and verify-payment still update booking paid state via separate service-role PATCH paths; no common atomic finalizer was found. Duplicate/out-of-order event inbox processing is not connected in current handler.
- No concurrency/JWT/provider fault-injection tests were run in this source audit.

### 5. Legacy code and data cleanup — safe deletion criteria
किसी पुराने component को सिर्फ इसलिए delete नहीं करना है कि वह Master Requirements में नहीं है। पहले ये gates पूरे हों:
1. All callers and dynamic references (HTML, JS, RPC, trigger, webhook, scheduled job, Admin tool) identified.
2. Historical booking, quote, payment, payout, refund and audit data retention/receipt/report compatibility documented.
3. New timer bill, payment, fee, cash, wallet, refund and Route path implemented and verified in isolated approved test environment.
4. RLS/ACL/SECURITY DEFINER and role-negative tests pass.
5. Duplicate webhook, concurrent acceptance/payment, refund timeout, paid payout and cash-fee restore/reversal tests pass.
6. Read-only compatibility period and rollback/restore plan signed off.
7. Only then remove unreachable UI/callers/RPCs/triggers/columns in ordered, reversible migrations; never delete historical financial records or blindly drop shared columns/functions.

### 6. Release gates still open
- Source/migration lineage reconciliation: unresolved second Cash migration history item and webhook inbox origin (Sections 17.49, 17.54).
- Timer lifecycle and frozen bill: not implemented.
- Unified payment finalizer/event inbox integration: not implemented.
- Route create/status/reversal orchestration: not implemented.
- Refund allocation/partial refund/paid payout recovery: not implemented.
- Receipt/invoice and unified financial reports: not implemented.
- Contact privacy full RPC matrix and Admin/staff scopes/MFA: not fully verified.
- JWT role tests, RLS/ACL tests, concurrency and provider Test Mode integration: not executed.
- No approved isolated Supabase development environment has been provisioned; do not create a potentially billable branch without explicit approval.

### 7. निष्कर्ष
Feature Branch में उपयोगी security controls हैं: authenticated customer booking, confirmed phone match, rate limits, public INSERT restrictions, contact ownership filters, selected fixed-search-path functions, client write revocation on sensitive ledgers, and idempotency keys. फिर भी ये controls full security sign-off नहीं हैं। मुख्य blockers timer/payment/refund/Route lifecycle, full contact privacy matrix, broad service_role/default ACL, webhook lineage, financial audit/immutability, and unexecuted tests हैं।
इस section में केवल Master Requirements documentation बदली गई; कोई source code, SQL migration, Production object/data, grant, provider setting, staging resource या deployment नहीं बदला।


## 17.61 — सामग्री (सामान) पूरी तरह Customer की जिम्मेदारी; Electrician का कोई संबंध नहीं (13 Nov 2026)

यह उपयोगकर्ता का स्पष्ट और नवीनतम निर्णय है। यह Master Requirements में पहले लिखे उन सभी विकल्पों/वाक्यों को supersede करता है जिनमें इलेक्ट्रिशियन द्वारा सामान लाने, सामान सप्लाई करने, सामान का बिल देने, सामग्री की कीमत जोड़ने या ग्राहक द्वारा इलेक्ट्रिशियन से सामान खरीदने की संभावना बताई गई थी।

### अनिवार्य नियम
1. सारा सामान/पार्ट्स ग्राहक खुद खरीदेगा और खुद लेकर आएगा।
2. सामान खरीदने, चुनने, लाने, उपलब्ध कराने, बदलने, उसकी कीमत तय करने या उसका बिल देने से इलेक्ट्रिशियन का कोई संबंध नहीं होगा।
3. Electrician App में सामान/Materials का कोई विकल्प, बटन, फ़ील्ड, सूची, quotation, amount input या supply workflow नहीं होना चाहिए।
4. Customer Booking/App में भी SRK के माध्यम से सामान खरीदने या इलेक्ट्रिशियन से सामान मँगाने का कोई विकल्प नहीं होगा। ग्राहक अपने स्तर पर सामान की व्यवस्था करेगा।
5. SRK booking, timer bill, invoice/receipt, payment, payout, electrician earnings, Platform Fee, wallet, refund और financial reports में सामान की कीमत शामिल नहीं होगी।
6. इलेक्ट्रिशियन की कमाई और Platform Fee केवल स्वीकृत labour/service charge और लागू timer billing के आधार पर होंगे। 15% Platform Fee का आधार labour amount ही रहेगा।
7. यदि काम के दौरान सामान की जरूरत पड़े और ग्राहक के पास न हो, तो इलेक्ट्रिशियन ग्राहक को जरूरत बता सकता है; ग्राहक स्वयं सामान लाएगा/व्यवस्था करेगा। इलेक्ट्रिशियन की ओर से खरीद, advance, reimbursement, markup या सामान के पैसे का लेन-देन SRK workflow में नहीं होगा।
8. पुराने Quote-era `materials_amount`, `service_charge + materials_amount` और material-inclusive payout/refund calculations केवल ऐतिहासिक रिकॉर्ड/compatibility के लिए सुरक्षित रहेंगे। इन्हें नए billing, payment या fee calculation में उपयोग नहीं करना है। पुराने डेटा को मिटाना या चुपचाप शून्य करना मना है; versioned migration और historical reporting mapping आवश्यक है।

### पुराने विरोधी नियमों का निस्तारण
- “इलेक्ट्रिशियन सामान दे सकता है और अलग itemized bill देगा” वाला नियम रद्द।
- “ग्राहक सामान खुद खरीद सकता है या इलेक्ट्रिशियन से खरीद सकता है” वाला विकल्प रद्द।
- नया नियम: सामान हमेशा ग्राहक की जिम्मेदारी; इलेक्ट्रिशियन और SRK सामान की खरीद/बिक्री/राशि से अलग रहेंगे।
- इस नीति के कारण Timer Bill/Receipt में केवल labour/service billing और लागू Platform Fee दिखेगी; materials line/amount नहीं होगा।

### Implementation और deletion gate
Feature Branch के UI, JS, SQL/RPC, triggers, reports, refund/payout logic में materials-related live dependencies की सूची बनाकर केवल नए labour-only flow में migration के बाद हटाएँ। Historical quote/payment/refund rows और audit records को सुरक्षित रखें। जब तक dependency mapping और regression tests पूरे न हों, Production columns/functions न हटाएँ।
इस सेक्शन में Master Requirements documentation ही बदली गई है; source code, database, Production, payment provider या deployment में कोई बदलाव नहीं किया गया।


## 17.62 — Customer-only Materials Policy: Current Feature Branch UI and Payment Dependency Audit (13 Nov 2026)

Section 17.61 के बाद संबंधित Feature Branch files का प्रत्यक्ष निरीक्षण:

### Customer UI — `booking.html`
- Booking instructions में लिखा है कि इलेक्ट्रिशियन केवल मेहनताना बताएगा और जरूरी सामान ग्राहक स्वयं खरीदेगा/उपलब्ध कराएगा।
- Customer booking payload में `quoted_amount` अभी भी भेजा जाता है; इसे नए Timer Bill का authoritative amount नहीं माना जा सकता।
- Customer history/payment display अभी quote-era fields और completed + approved quote पर निर्भर है।
- इस निरीक्षण में Customer को इलेक्ट्रिशियन से सामान खरीदने/मँगाने का UI option नहीं मिला; फिर भी नए UI में material amount/line item/payment का कोई स्थान नहीं होना चाहिए।

### Electrician UI — `electrician.html`
- वर्तमान quote card केवल “सर्विस / मेहनताना शुल्क” input दिखाता है; अलग materials amount input नहीं दिखा।
- Submit caller `srk_submit_booking_quote` को `p_materials_amount: 0` भेजता है।
- Confirmation text ग्राहक द्वारा सामान स्वयं उपलब्ध कराने की बात कहता है।
- इसलिए UI पर अभी अलग सामान मूल्य input नहीं दिखा, लेकिन quote workflow अभी मौजूद है। नए Timer Billing लागू होने पर इस legacy quote card/RPC caller को हटाना है; Electrician UI में materials/supply/invoice/amount controls कभी नहीं जोड़ने हैं।

### Admin and server-side legacy dependencies
- `admin.html` अभी `quoted_amount` पढ़ता है और direct booking update में amount/status लिखता है।
- `create-order.js`, `verify-payment.js`, `razorpay-webhook.js` अभी `service_charge + materials_amount = quoted_amount` legacy reconciliation करते हैं।
- ये server payment dependencies हटाए बिना केवल materials column/UI हटाना payment verification और historical compatibility तोड़ सकता है।
- पुराने payout/refund/fee functions और records में `materials_amount`/material-inclusive totals के संदर्भ हैं; उन्हें केवल historical versioned compatibility तक सीमित करना है, नए bill/fee/refund calculation में नहीं।

### निष्कर्ष और अगला implementation क्रम
1. नया Timer Bill schema केवल labour/service amount रखे; materials field/line item न हो।
2. Customer/Electrician/Admin UI, API, receipt/report में materials amount, supply option, materials quote या reimbursement flow न हो।
3. Payment order, verification और webhook को frozen labour-only bill snapshot से जोड़ें; client `quoted_amount` और legacy materials total authority न हों।
4. Payout, Platform Fee, cash due, wallet, refund और Route calculations को labour-only bill से migrate करें।
5. पुरानी quote/material values को read-only historical records में सुरक्षित रखें; पुराने RPC/columns केवल तब retire हों जब सभी callers migrate और tests pass हों।
6. Required tests: customer payload में materials field भेजे जाने पर ignore/reject; electrician materials field/RPC attempt denied; payment amount exactly labour bill; fee = 15% labour only; receipt/report no materials line; old paid quote record remains readable.

इस section में केवल read-only source audit और Master Requirements documentation update किया गया। कोई code, migration, Production object/data, payment या deployment नहीं बदला।


## 17.63 — Timer समाप्त होने पर Server-calculated Bill और Customer Cash/Online विकल्प (13 Nov 2026)

यह उपयोगकर्ता का स्पष्ट निर्णय है: Timer समाप्त होने पर इलेक्ट्रिशियन कोई रकम दर्ज नहीं करेगा। सिस्टम वास्तविक समय और निर्धारित rate के आधार पर server पर अपने-आप final labour amount निकालेगा। इसके बाद ग्राहक को सीधे Cash या Online Payment का विकल्प दिखेगा।

### अनिवार्य व्यवहार
1. इलेक्ट्रिशियन Timer शुरू/काम पूरा करने के आवश्यक action कर सकता है, लेकिन Timer समाप्त होने पर उसे कोई amount, मेहनताना, quote, bill total या payment amount भरने/बदलने की जरूरत नहीं होगी।
2. Timer की start/stop timestamps server-authoritative होंगी। Client/mobile clock या electrician द्वारा typed duration/amount को bill calculation का आधार नहीं बनाना है।
3. Server booking की approved category/rate tier और वास्तविक billable minutes के आधार पर labour amount स्वतः calculate करेगा। निर्धारित 8-hour rate को 480 से भाग देकर प्रति मिनट दर निकलेगी; वास्तविक मिनटों के अनुपात में राशि बनेगी, बिना अगले घंटे/मिनट तक round-up किए। लागू currency rounding नियम के अनुसार अंतिम रकम बनेगी।
4. Customer की आवश्यक completion approval/dispute प्रक्रिया पूरी होने पर server frozen labour-only bill snapshot बनाएगा। Snapshot में booking, rate, actual minutes, labour amount, calculation/version और audit timestamps सुरक्षित होंगे। Snapshot बनने के बाद client-side amount बदलकर payment नहीं कराया जा सकेगा।
5. Bill बनने के तुरंत बाद Customer App में उसी server-generated final amount के साथ दो payment विकल्प दिखेंगे: **Cash** और **Online Payment**। ग्राहक इनमें से एक चुनेगा।
6. Cash चुनने पर मौजूदा cash-payment confirmation/verification workflow चलेगा। Online चुनने पर Razorpay order और verification/webhook उसी frozen bill snapshot की exact रकम से बंधे होंगे।
7. Electrician App में amount भरने, Cash/Online चुनने, payment order बनाने, ग्राहक से payment mode तय कराने या bill total बदलने का कोई input/permission नहीं होगा। Electrician को केवल आवश्यक payment status दिखाई जा सकती है।
8. Platform Fee 15% केवल server-calculated labour amount पर लागू होगी। सामान/materials की कोई रकम या line item bill, Cash/Online payment, receipt, payout या fee calculation में नहीं आएगी।
9. Payment mode चुनने और payment status बदलने के बीच idempotency, duplicate request, concurrency, provider timeout और webhook reconciliation लागू होंगे। Client द्वारा भेजी गई रकम/payment mode को authoritative न मानें।
10. पुराने quote-era records सुरक्षित रहेंगे; यह नया timer bill/payment flow उनसे अलग versioned होगा। पुराने रिकॉर्डों को नए नियम के अनुसार rewrite या zero नहीं करना है।

### Acceptance tests
- Timer समाप्त होने पर Electrician को amount input नहीं दिखता और कोई amount submit API आवश्यक नहीं होती।
- Server timestamps और approved rate से independent expected amount निकलता है; client द्वारा भेजी गई बदली हुई रकम अस्वीकार/अनदेखी होती है।
- Customer को उसी exact frozen amount के साथ Cash और Online दोनों विकल्प मिलते हैं।
- Cash और Online दोनों paths सही booking/bill से जुड़ते हैं; duplicate clicks/webhooks से duplicate charge/ledger entry नहीं बनती।
- Electrician API/UI से amount या payment mode बदलने का प्रयास असफल होता है।
- Bill/receipt/fee में केवल labour amount और लागू 15% Platform Fee होती है; materials का कोई field/line नहीं।
- Historical quote-era paid records पढ़े जा सकते हैं और अपरिवर्तित रहते हैं।

यह section Master Requirements में निर्णय दर्ज करता है; इसे implementation समझा न जाए। इस update में source code, SQL migration, Production database/provider settings या deployment नहीं बदले गए।

## 17.64 — Timer Bill / Payment Choice Implementation से पहले Feature Branch Caller Audit (13 Nov 2026)

Section 17.63 के अनुसार implementation शुरू करने से पहले tracked source में वर्तमान caller/dependency का प्रारंभिक प्रत्यक्ष निरीक्षण किया गया। यह अभी पूर्ण migration-lineage या runtime test नहीं है।

### प्रत्यक्ष रूप से मिले blockers
1. electrician.html में अभी legacy quote flow मौजूद है: srk_submit_booking_quote को service amount, materials amount और note भेजे जाते हैं। नया timer flow लागू होने पर इस quote entry/caller को हटाना होगा; Electrician से कोई रकम नहीं भरवानी।
2. Electrician offer/work UI में quote_approved state के आधार पर काम शुरू करने का button है। यह timer start के लिए Customer approval + server timestamp वाले नए lifecycle से बदलेगा।
3. booking.html में Customer अभी booking बनाते समय Cash/Online चुनता है; payment choice pre-work है। नए नियम में final server bill बनने के बाद Customer को Cash/Online चुनना होगा। पुराने customer history में quote fields भी पढ़े जाते हैं।
4. create-booking.js client payload से payment_method और quoted_amount स्वीकार करके booking में लिखता है। नए flow में booking creation के समय amount/payment choice को अंतिम भुगतान निर्णय नहीं मानना; client amount को financial authority से हटाना होगा।
5. create-order.js अभी quoted_amount, service_charge + materials_amount, quote approval और पहले से चुने Online method पर निर्भर है। यह नया timer bill नहीं पढ़ता और इसे frozen labour-only bill snapshot से order बनाना होगा।
6. verify-payment.js और razorpay-webhook.js भी quote-era service_charge + materials_amount = quoted_amount जांचते हैं और paid state अलग-अलग PATCH करते हैं। इन्हें एक साझा, idempotent server finalizer और frozen bill snapshot पर migrate करना होगा।
7. admin.html booking list/edit में quoted_amount और direct status/amount update अभी मौजूद हैं। नए timer bill में Admin amount editing केवल narrowly scoped, audited adjustment workflow से ही हो सकती है; सामान्य direct edit नहीं।
8. प्रारंभिक migration scan में 20261109002000_expose_assigned_booking_map_pin.sql offer result में quoted_amount expose करता है और 20261109003000_secure_commission_reporting.sql में booking update grant quoted_amount शामिल है। इन्हें caller/security dependency map में शामिल करना है; तुरंत हटाना नहीं।
9. Root-level payment handlers के साथ netlify/functions/ wrappers भी हैं। बदलाव में canonical handler और deployment wrapper दोनों का parity test जरूरी है।

### अगला सुरक्षित implementation क्रम
- पहले पूरे Feature Branch tree और सभी migrations/RPC/triggers/views/policies में timer, quote, amount, materials, payment method, commission, cash settlement और refund dependencies की पूर्ण inventory बनाना।
- फिर server-authoritative timer event lifecycle और immutable/versioned labour-only bill snapshot का schema/RPC contract तय करना।
- उसके बाद Customer approval boundary, bill calculation, Cash/Online choice, Razorpay order, unified finalizer, fee/payout/refund/receipt/report callers को क्रमशः जोड़ना।
- Existing quote-era rows/functions को read-only historical compatibility में रखना; migration + caller switch + tests + rollback proof से पहले drop/rename/rewrite नहीं करना।
- हर चरण में Customer/Electrician/Admin role negative tests, duplicate/concurrency tests, provider timeout/webhook tests और historical-record regression tests करना।

### इस audit की सीमा
इस pass में मुख्य Customer/Electrician/Admin UI तथा root payment handlers का source निरीक्षण किया गया और migration inventory की शुरुआत की गई। पूर्ण migration/RPC/trigger lineage, SQL role tests, timer implementation, payment provider tests और end-to-end execution अभी बाकी हैं। कोई code/SQL/Production change या deployment नहीं किया गया।

## 17.65 — Feature Branch SQL Migration / RPC Financial Dependency Audit (13 Nov 2026)

Feature Branch की सभी 21 tracked Supabase migration files की inventory और timer/payment से सीधे जुड़ी quote, fee, payout, offer, payment-choice migrations का source inspection किया गया। यह source audit है; Production database में migration application या runtime behavior का प्रमाण नहीं।

### A. Legacy quote और materials dependencies
1. 20261109_electrician_inspection_quotes_and_service_only_commission.sql legacy quote RPC srk_submit_booking_quote बनाता है; यह service_charge, materials_amount, quoted_amount और quote approval/status lifecycle लिखता है। साथ में work-status transition quote_approved पर निर्भर है।
2. 20261112193000_labour_only_quotes_customer_supplies_materials.sql non-zero materials amount अस्वीकार करता है और नए quote में materials_amount=0 लिखता है, लेकिन पुराने quote RPC और electrician-entered service amount को बनाए रखता है। यह अभी Timer Billing नहीं है।
3. 20261112230000_show_customer_payment_choice_to_assigned_electrician.sql assigned electrician के offer RPC में quoted_amount, service_charge, materials_amount और payment_method return करता है। नए flow में electrician को customer का payment choice या bill amount दिखाने की जरूरत नहीं है; इस RPC response को redesign करना होगा।

### B. Fee / payout में महत्वपूर्ण incompatibility
4. 20261112220000_cash_platform_fee_due_and_online_settlement.sql और 20261113120000_limit_cash_fee_settlement_to_labour_share.sql के trigger में अभी भी service_charge + materials_amount को total payment माना गया है और amount_paid उसी combined total से मिलाया जाता है।
5. नवीनतम 20261113120000 migration prior cash fee recovery को v_service - current fee तक सीमित करती है, जो सही दिशा है; लेकिन payout row में materials_amount अभी भी लिखा जाता है और electrician_payable अभी भी v_total (service + materials) से calculate होता है। इसलिए केवल fee recovery labour-only होने से पूरा payout labour-only नहीं बनता।
6. srk_admin_record_manual_payment अभी भी approved quote breakdown service_charge + materials_amount और quoted_amount से total बनाता है। नया Cash/manual confirmation frozen labour-only bill snapshot से जुड़ना चाहिए।
7. srk_admin_mark_electrician_payout_paid अभी भी booking paid amount, service_charge + materials_amount, payout materials_amount और quote approval का मिलान करता है। इसे नए bill snapshot और labour-only payout formula पर migrate करना आवश्यक है।
8. पुरानी commission/report function तथा payout table में materials fields ऐतिहासिक compatibility के लिए रह सकती हैं, पर नई bill/payout rows में materials रकम शून्य/अनुपस्थित और गणना से बाहर होनी चाहिए। पुराने historical rows rewrite नहीं होंगे।

### C. Payment choice timing में विरोध
9. 20261112170000_enforce_electrician_third_booking_online_payment.sql हर तीसरी completed/approved/verified-paid booking की अगली eligibility के लिए acceptance समय पर customer payment_method को Razorpay Online होना आवश्यक करता है।
10. 20261113090000_customer_can_explicitly_switch_cash_booking_to_online.sql केवल unassigned, unpaid, new/confirmed booking में Cash से Online switch की अनुमति देता है।
11. ये दोनों pre-work/pre-assignment payment choice मॉडल हैं; Section 17.63 के नए नियम में final bill बनने के बाद Customer Cash या Online चुनेगा। Third-booking enforcement को नए timing में redesign करना होगा; मौजूदा नियम को सीधे हटाने से booking acceptance race/eligibility logic टूट सकता है।

### D. Timer और payment architecture अभी अनुपस्थित
12. 21 migrations में कोई canonical timer event store, server-side start/stop/approval RPC, bill snapshot table/version/hash, bill adjustment ledger या timer lifecycle migration नहीं मिली।
13. Existing quote status और work_started_at legacy timestamps timer billing का पर्याप्त विकल्प नहीं हैं। इन्हें actual minute billing authority न मानें।
14. Payment order/verification/webhook और refund/payout RPCs अभी quote-era data पर निर्भर हैं। नए bill snapshot पर migration और unified payment finalizer के बिना legacy columns हटाना unsafe है।

### E. Implementation gates
- नया timer lifecycle और immutable labour-only bill schema/RPC पहले बनें; start/stop server timestamps, Customer approval boundary और exact minute calculation enforce हों।
- Cash/Online choice final bill के बाद Customer-only authenticated action हो; Electrician API/UI से amount और payment mode read/write न हो।
- Fee, payout, manual payment, Razorpay order, verification, webhook, refund, Route और Admin payout confirmation सभी एक ही frozen bill snapshot से राशि लें।
- New financial rows में material amount कोई गणना न बदले; legacy materials columns/records केवल historical read compatibility के लिए रहें।
- Third-booking policy को bill-time choice के साथ transactionally enforce करने का अलग design और concurrency tests हों।
- Historical quote records, existing payout records, cash fee dues और refund histories के before/after reconciliation report तथा rollback plan बने।
- SQL migration order/Production lineage verify किए बिना migration replay, drop, rename, truncate या Production write न करें।

इस audit में केवल Feature Branch migration source पढ़ा और Master Requirements update किया गया। कोई source code, SQL migration, database object/data, payment provider setting, real payment/payout/refund या deployment नहीं बदला।
## 17.66 — Timer → Payment Handler / UI / RPC Caller End-to-End Source Audit (13 Nov 2026)

Feature Branch के 10 मुख्य caller/UI/payment files का source-level inspection किया गया: create-booking.js, create-order.js, verify-payment.js, razorpay-webhook.js, Netlify adapters, electrician.html, booking.html और admin.html। यह code-path audit है; runtime, browser E2E, Razorpay Test Mode या SQL role test नहीं।

### A. Customer booking
- create-booking.js अभी request body से payment_method और quoted_amount पढ़ता है; quoted_amount validation के बाद service_bookings में insert होता है। नई व्यवस्था में booking के समय कोई final amount या payment choice authoritative नहीं होगा। Client amount/payment fields को ignore/reject करना और bill बनने के बाद Customer-only choice RPC देना होगा।
- booking.html में booking form अभी Cash/Online dropdown दिखाता है; customer history में legacy quote amount/quote status और early Cash-to-Online switch है। इन्हें final frozen bill बनने के बाद Cash/Online chooser, bill details और receipt से बदलना होगा।

### B. Electrician workflow
- electrician.html में quote amount input/RPC srk_submit_booking_quote अभी मौजूद है; quote-approved पर electrician स्वयं in_progress और completed status बदलता है। यह user के timer rule के विरुद्ध है।
- Existing offer details में customer का payment_method और quote/material amount भी लौटता है। नए electrician interface में केवल assigned job और timer actions हों; amount/payment method controls या materials option न हों।
- Replace with server RPC lifecycle: electrician requests start → customer approves → server records start timestamp; electrician requests completion → server records stop boundary → customer approves/disputes. Client clock/status PATCH authoritative नहीं होगा।

### C. Razorpay order / verification / webhook
- create-order.js booking को completed + quote_approved और preselected Razorpay method पर gate करता है; service_charge + materials_amount को quoted_amount से मिलाकर Razorpay order amount बनाता है। यह legacy quote calculation है।
- Existing order reuse check भी Razorpay order amount को quoted_amount से compare करता है। New order amount must equal frozen bill snapshot gross labour amount in integer paise; idempotent payment intent/order row must bind booking + bill version/hash + customer + INR amount.
- verify-payment.js HMAC signature और provider payment lookup करता है, फिर service_bookings पर direct PATCH से payment_status=paid/amount_paid/payment ID लिखता है। इसे shared server-only atomic finalizer से बदलना होगा; verify endpoint और webhook अलग-अलग payment state finalizers न रखें।
- razorpay-webhook.js raw-body signature validation मौजूद है और payment event को completed+approved quote तथा quote total से reconcile करता है; फिर direct booking PATCH करता है। Handler अभी durable event inbox/deduplication/lease processing या common finalizer use नहीं करता।
- Netlify function wrappers मौजूद हैं; wrapper/root handler parity, method/body/header preservation और webhook raw-body signature handling को integration tests में verify करना होगा।

### D. Admin
- admin.html booking table में quoted_amount पढ़ता है और direct service_bookings update से status/quoted_amount लिखता है। Manual payment flow में पहले booking Completed अलग से save करने को कहता है, फिर payment record करता है।
- New Admin controls में amount/status direct table edits नहीं होंगे। किसी approved adjustment के लिए reason, actor, before/after, bill version, idempotency और narrow audited RPC चाहिए; Admin भी original frozen bill overwrite नहीं करेगा।

### E. Blocking implementation order
1. Migration/RPC/trigger/view/policy lineage का पूर्ण dependency graph और live Production migration history से मिलान; missing migration source का समाधान।
2. Timer event + customer approval RPC और immutable bill snapshot schema; rate table server controlled, no client amount input.
3. Customer bill screen/receipt और bill-time Cash/Online selection; electrician quote/material/payment UI हटाना.
4. Shared payment intent/order + payment finalizer + durable webhook inbox; create-order, verify, webhook और Netlify adapters एक ही bill version/paise amount use करें.
5. Fee/payout/cash due/manual payment/refund/Route/report/Admin RPC को उसी labour-only bill से migrate करें; third-booking eligibility को post-bill choice के साथ सुरक्षित transactionally redesign करें.
6. Role negative tests, duplicate/concurrency, out-of-order webhook, provider timeout/unknown, amount mismatch, replay, historical quote regression, UI/E2E और rollback verification.

इस audit में source पढ़ा गया और कोई code, SQL, Production database, payment provider, real payment या deployment नहीं बदला।
## 17.67 — Server-authoritative Timer और Immutable Labour Bill का Database Design (13 Nov 2026)

यह design Feature Branch source तथा Production schema/function inventory देखकर तैयार किया गया है। यह design specification है, लागू migration नहीं। Production में read-only schema inspection में service_bookings पर legacy work_started_at मौजूद है, पर canonical timer session/event/bill snapshot table नहीं मिली।

### 1. मौजूदा Production schema से मिली सीमाएँ
- service_bookings में status, assigned_electrician_id, customer_user_id, work_started_at, quote_status, quoted_amount, service_charge, materials_amount, payment_method, payment_status और Razorpay IDs हैं। ये पुराने quote/payment workflow के columns हैं।
- Production में srk_electrician_payouts में gross_service_amount और materials_amount दोनों मौजूद हैं। इन्हें historical compatibility के लिए रखना होगा; नए payout formula में materials का योगदान शून्य होगा।
- srk_razorpay_webhook_events table Production में मौजूद है और event_id primary key है; इसे duplicate बनाने के बजाय उसकी पूरी definition, policies, indexes और consumers recover करके नए payment finalizer से integrate करना होगा।
- Production RPC inventory में srk_submit_booking_quote, srk_customer_respond_booking_quote, srk_update_booking_work_status, srk_get_my_assigned_booking_quote_details, srk_get_my_offer_details, srk_admin_record_manual_payment और srk_create_electrician_payable सहित quote-era callers मौजूद हैं। इनका exact definition/trigger/dependency lineage migration plan से पहले recover करना अनिवार्य है।

### 2. प्रस्तावित logical data model (नए नाम; existing Production में अभी नहीं)
A. `srk_booking_timer_sessions` — प्रति booking एक canonical work session (unique booking_id); booking_id, customer_user_id, electrician_profile_id, approved rate_card_id/version, timer_state, start_requested_at, started_at, completion_requested_at, stopped_at, customer_approved_at, dispute state, created_at/updated_at. Server timestamps ही authority होंगे।
B. `srk_booking_timer_events` — append-only event ledger; unique event/idempotency key, booking/session IDs, event_type, actor_user_id/role, server_recorded_at, request correlation ID, optional safe metadata. Event types: start_requested, start_approved, timer_started, completion_requested, timer_stopped, completion_approved, disputed, admin_resolved, cancelled. कोई client timestamp bill calculation में इस्तेमाल नहीं होगा।
C. `srk_labour_rate_cards` — server-managed versioned rate catalog; category/rate tier, 8-hour reference minutes=480, reference price paise, effective_from/to, active flag, version, Admin audit. Existing agreed reference rates: Assistant ₹899, Skilled ₹1,199, Expert ₹1,599, Premium Specialist ₹1,999; village/city same. Rate snapshot timer start पर pin होगा ताकि बाद में rate edit होने से running booking न बदले।
D. `srk_labour_bill_snapshots` — प्रति bill version immutable snapshot; unique booking_id + version; session_id, customer/electrician IDs, rate card/version, started_at/stopped_at, billable_minutes, reference_rate_paise, calculation numerator/denominator, labour_amount_paise, currency INR, rounding_policy_version, bill_hash, status, generated_at, customer_approved_at, created_by/system actor. कोई materials field/line item नहीं।
E. `srk_labour_bill_adjustments` — केवल exceptional Admin-reviewed correction; append-only adjustment amount in paise, reason, actor, reviewer if required, source bill version, idempotency key, timestamp. Original snapshot overwrite नहीं होगा; नया version/adjustment reference बनेगा। Adjustment permissions/limits और maker-checker अभी तय नहीं।

### 3. Proposed state transitions
- assigned → start_requested (Electrician request only) → awaiting_customer_start_approval → running (Customer approval पर server now() timestamp)।
- running → completion_requested (Electrician request) → stopped_pending_customer_approval (server stop boundary) → completed_bill_pending (Customer approval)।
- Customer dispute होने पर disputed_admin_review; Admin resolution reason/audit के बाद ही final bill snapshot बने।
- Final bill snapshot बनने के बाद payment_due; Customer उसी frozen amount पर Cash या Online चुने। Payment flow से पहले bill version/hash immutable रहे।
- Duplicate/replayed requests idempotent response दें; wrong actor, wrong booking, unassigned electrician, cancelled/terminal booking, invalid transition deny हों।
- Customer approval न मिलने का timeout, electrician/customer offline, emergency stop और dispute SLA अभी तय नहीं; इन्हें auto-approve नहीं मानना है।

### 4. Labour amount calculation contract
- `billable_minutes = server_stopped_at - server_started_at` से निकले वास्तविक पूरे elapsed minutes; client clock निषिद्ध।
- `raw_amount = approved_8h_rate × billable_minutes / 480`; केवल labour/service amount। कोई सामान/parts जोड़ नहीं।
- Currency calculation integer paise में होनी चाहिए। 480 से भाग देने पर fractional paise संभव हैं; अंतिम paise rounding mode अभी Product decision के लिए खुला है। तब तक exact rounding mode invent न करें।
- Existing agreed rate amounts ऊपर दिए गए हैं। Category mapping, rate tier pinning और 8 घंटे से अधिक अवधि का formula/maximum अभी स्पष्ट रूप से freeze होना बाकी है।
- Pause/resume, idle-time exclusion, multiple sessions, timer correction और timer boundary semantics अभी अनिर्णीत हैं। स्पष्ट नियम: एक session चालू रहने पर समय लगातार गिना जाएगा; दो दिन तक भी auto-stop नहीं होगा। इनका निर्णय हुए बिना production billing migration नहीं।

### 5. Customer approval और payment binding
- Start approval Customer के authenticated account/verified identity से हो; assigned electrician स्वयं अपनी start request approve नहीं कर सकता।
- Completion approval Customer के authenticated account से हो; dispute पर bill/payment रोकें और Admin review करें।
- Final snapshot बनते समय server एक बार labour amount, bill version/hash और INR paise amount freeze करे।
- `srk_customer_choose_bill_payment` जैसा narrow RPC केवल bill owner को final bill पर Cash/Online चुनने दे; Electrician payment choice न देखे/बदले।
- Razorpay order, verification, webhook, Cash confirmation, fee ledger, payout, refund और receipt सभी exact bill_snapshot_id + version + hash + amount_paise से bind हों। Client-supplied quoted_amount/payment_method financial authority नहीं होंगे।
- 15% Platform Fee केवल labour amount पर; Electrician payable = labour amount minus current Platform Fee minus legitimately settled prior cash fee dues. Cash collection customer और electrician के बीच; SRK केवल fee due ledger रखे।

### 6. Security / consistency requirements
- Browser सीधे timer/session/event/bill/payment ledger tables में INSERT/UPDATE/DELETE नहीं करेगा। सभी state transitions narrowly scoped RPC/server endpoints से।
- SECURITY DEFINER केवल आवश्यक होने पर; private/non-exposed schema, fixed search_path, auth.uid()/role + booking ownership/assignment checks, explicit revoke/grant, RLS defense-in-depth और function ACL audit।
- Lock order booking → timer session → bill/payment intent → electrician fee ledger एक documented order में; idempotency unique constraints, transaction locks और race tests।
- Timer events और bill snapshots append-only; corrections compensating events/versioned adjustments से। Historical quote rows untouched।
- PII/contact data event metadata में अनावश्यक रूप से copy नहीं करना। Admin access audited और least-privilege।

### 7. अगली implementation से पहले जरूरी decisions / blockers
1. Paise rounding rule (nearest paise half-up, half-even या अन्य) की स्पष्ट मंजूरी।
2. 8 घंटे से आगे का नियम तय: वही approved 8-hour rate ÷ 480 प्रति मिनट, पूरी वास्तविक अवधि पर लगातार लागू; कोई cap/daily reset/overtime multiplier नहीं।
3. Pause/resume होगा या timer uninterrupted elapsed time होगा?
4. Customer start/completion approval के लिए timeout और no-response policy; auto-approval निषिद्ध जब तक स्पष्ट मंजूरी न हो।
5. Dispute resolution और Admin adjustment limits / maker-checker।
6. Timer को किस verified category/rate tier से bind करना है; वर्तमान schema में approved category/rate tier का canonical verified evidence मौजूद होने का प्रमाण नहीं।
7. Production webhook inbox की full schema/consumer lineage और all quote/payment trigger definitions recover करना।

इस pass में Production से केवल read-only schema/function inventory queries चलाई गईं। कोई DDL/DML, migration, policy, function, trigger, data, provider configuration या deployment नहीं बदला।
### 17.67A — User clarification: 8 घंटे से अधिक Timer और निरंतर Billing (13 Nov 2026)
- User ने स्पष्ट किया: Timer शुरू होने के बाद Timer बंद होने तक पूरी अवधि के अनुसार ही रकम निकलेगी। 8 घंटे, 15 घंटे, 24 घंटे, लगातार 2 दिन या उससे अधिक—कोई समय सीमा नहीं।
- 8-hour category rate केवल reference rate है। पूरे elapsed billable minutes पर समान per-minute rate = approved 8-hour rate / 480 लागू होगा।
- Timer के चलते रहने पर daily reset, 8-hour cap, auto-stop या overtime multiplier नहीं होगा। Server start timestamp और server stop timestamp से total duration निकलेगा। Timer बंद होने पर ही अंतिम रकम calculate/freeze होगी।
- उदाहरण (सिर्फ गणना समझाने के लिए): 48 घंटे = 2,880 मिनट; labour amount = 8-hour rate × 2,880 / 480 = 6 × 8-hour rate।
- User ने यह भी स्पष्ट किया कि रकम Timer बंद होने पर system/server अपने आप निकालेगा; Electrician कोई amount enter नहीं करेगा।
- अभी भी अलग निर्णय शेष: fractional paise की rounding policy; Pause/Resume/idle-time exclusion; Customer approval/dispute timeout. इन पर कोई अनुमान नहीं लगाया जाएगा।
## 17.68 — Production Timer/Quote/Payment Trigger और Webhook Dependency Audit

यह Section 17.67 के बाद Production read-only catalog inspection पर आधारित है। कोई database object/data नहीं बदला।

### A. `service_bookings` पर live triggers
- `a_guard_booking` BEFORE INSERT → `guard_new_booking()`; नई booking validation/creation path का dependency। इसकी पूरी function body और callers को future booking payload changes से पहले review करना होगा।
- `broadcast_new_booking` AFTER INSERT → `broadcast_booking_job()`; job offer/broadcast lifecycle को preserve करना होगा।
- `srk_audit_service_bookings` AFTER INSERT/UPDATE/DELETE → `srk_capture_admin_audit_event()`; new timer/bill events को audit trail से जोड़ने का scope तय करना होगा।
- `srk_calculate_booking_commission` BEFORE INSERT OR UPDATE OF status/payment_status/amount_paid/commission_rate → commission recalculation trigger। New immutable bill से legacy amount fields update होने पर गलत commission overwrite न हो, इसके लिए redesign आवश्यक।
- `srk_cancel_booking_job_offers` AFTER status becomes cancelled → offer cleanup; new timer cancellation state के साथ compatibility test जरूरी।
- `srk_log_service_booking_status` AFTER INSERT/UPDATE OF status → status history; timer state अलग event ledger में होगा, दोनों histories की consistency और duplicate event behavior तय करना होगा।
- `trg_srk_create_electrician_payable` AFTER INSERT OR UPDATE OF payment_status/status/quote_status/service_charge/materials_amount/assigned_electrician_id/payment_verified_at/razorpay_payment_id/amount_paid → `srk_create_electrician_payable()`। यह quote approval और service+materials total पर निर्भर है; नया bill इसे trigger करके legacy payout गलत न बनाए।
- `srk_electrician_payouts` पर `srk_audit_electrician_payouts` AFTER INSERT/UPDATE/DELETE audit trigger है।

### B. Confirmed live legacy dependencies (function bodies inspected)
- `srk_submit_booking_quote` electrician से service_charge और materials_amount लेता है, quoted_amount बनाता है और status `awaiting_quote_approval` करता है। New electrician UI से quote entry हटेगी; function को legacy history compatibility के लिए सुरक्षित रखकर new bookings के लिए block/retire करने की versioned strategy चाहिए।
- `srk_customer_respond_booking_quote` Customer quote approve/reject करता है और booking status को quote_approved/quote_rejected करता है। इसे timer start approval के रूप में reuse नहीं करना चाहिए; अलग narrowly scoped RPC चाहिए।
- `srk_update_booking_work_status` electrician को inspection → quote_approved से in_progress (work_started_at=now) → completed करने देता है। यह Customer timer approval/stop approval नहीं है; नया timer lifecycle इसे replace करेगा, लेकिन पुराने bookings के लिए compatibility path चाहिए।
- `srk_get_my_offer_details` electrician offer result में quoted_amount, service_charge, materials_amount, quote_status और quote_note expose करता है। New offer RPC contract में कोई amount/material/payment controls/fields नहीं होने चाहिए। Customer phone visibility lifecycle भी status predicates से जुड़ा है; इसे अलग security audit में verify करना होगा।
- `srk_get_my_offer_price_details` customer_suggested_amount, service_charge, materials_amount, quote_status, quote_note देता है। New electrician API से इसे हटाना/deny करना होगा; callers पहले खोजे जाएँ।
- `srk_electrician_confirm_cash_payment` केवल completed + quote approved + preselected cash + quoted_amount के आधार पर booking को paid करता है। New cash confirmation को immutable bill snapshot/payment choice से bind करना होगा।
- `srk_admin_record_manual_payment` completed + approved quote अनिवार्य करता है और total = service_charge + materials_amount = quoted_amount validate करता है। New Admin manual payment को frozen labour-only bill amount पर narrow audited action होना चाहिए।
- `srk_create_electrician_payable` paid + completed + quote approved पर service+materials total verify करता है; payout row में materials_amount और payable = service + materials − commission लिखता है। New payout formula labour-only bill पर आधारित होगा; legacy rows को mutate नहीं करना।
- `srk_admin_mark_electrician_payout_paid` booking-first lock order रखता है और pending payout को paid mark करता है; नए payout records को bill snapshot ID/version से जोड़ने की जरूरत है।

### C. Live constraints/indexes/policies से migration cautions
- `service_bookings.status` CHECK अभी legacy states (`inspection`, `awaiting_quote_approval`, `quote_approved`, `quote_rejected`, `in_progress`, `completed`) पर आधारित है। New timer/payment states add करने से पहले transition compatibility और constraint rollout plan जरूरी है।
- `service_bookings` में `quote_status` CHECK केवल `not_submitted/pending/approved/rejected` है; पुराने function body `approved/rejected` लिखती है। इसे silently बदलना नहीं।
- `service_bookings` में materials_amount nonnegative CHECK और assignment status CHECK हैं। इन्हें तुरंत drop/zero न करें; historical data और dependent functions पहले map हों।
- `srk_electrician_payouts` में booking_id unique है; एक booking पर एक ही payout row संभव। Versioned adjustments/refund recovery के लिए उसी row को overwrite करने के बजाय append-only ledger design चाहिए।
- `srk_razorpay_webhook_events` में event_id primary key, status CHECK (`received/reconciled/exception/ignored/processing_error`) तथा order/status indexes मौजूद हैं। इसे दोबारा create न करें। उपलब्ध columns में payload hash, signature verification result, retry count, lease owner/expiry और payment snapshot reference स्पष्ट रूप से नहीं मिले। Existing consumer/insert path अभी इस pass में prove नहीं हुआ।
- `service_bookings` SELECT policy Admin या booking customer को देती है; Admin UPDATE policy है। Electrician offer access RPC SECURITY DEFINER से है। New timer/bill tables को direct broad table access न दें; RPC ownership checks और RLS अलग-अलग audit हों।
- `srk_electrician_payouts` SELECT policy Admin या matching electrician profile user_id को देती है। Webhook table के लिए इस inspection में कोई pg_policies row नहीं लौटी; इसका मतलब client access सुरक्षित है ऐसा मानने से पहले table ACL और schema exposure भी जाँचना होगा।

### D. आगे की सुरक्षित कार्यवाही
1. Production में सभी trigger function definitions (`guard_new_booking`, commission trigger, status log, offer broadcast, audit, cancellation) और complete webhook writer/reader caller lineage recover करें।
2. Feature Branch migration files और Production function bodies का object-by-object drift matrix बनाएँ; Production में कोई apply/alter/drop नहीं।
3. New timer/bill tables के लिए isolated development branch/environment की मंजूरी और cost स्पष्ट होने तक schema apply न करें।
4. Timer RPCs और immutable bill snapshot के साथ old trigger side effects disable/route करने की reversible migration design करें; old paid/completed/quote bookings का regression test करें।
5. Shared payment finalizer और durable webhook inbox consumer के बाद ही payout/cash/manual/refund/Route migration करें।
6. Constraint/trigger/policy/RPC changes पर authenticated Customer, assigned Electrician, unassigned Electrician, Admin और service-role negative/positive tests अनिवार्य।

Audit सीमा: यह catalog/function inspection है, production penetration test नहीं। इस pass में केवल read-only SQL queries चलीं; कोई DDL/DML, migration, payment, webhook replay, provider action या deployment नहीं हुआ।

## 17.69 — Payment Finalizer और Razorpay Webhook Writer/Reader Source Audit (13 Nov 2026)

यह pass Feature Branch के payment handlers और Production के live trigger/webhook schema/function catalog के read-only inspection पर आधारित है। कोई code runtime, database या provider state नहीं बदली।

### A. Feature Branch source findings
- `razorpay-webhook.js` raw request body पर HMAC-SHA256 signature को timing-safe compare करता है और केवल `payment.captured` / `order.paid` captured INR payment events आगे लेता है। लेकिन verified event को `srk_razorpay_webhook_events` inbox में insert/upsert नहीं करता; durable event deduplication, lease/retry और reconciliation history इस handler में नहीं है।
- Webhook booking lookup quote-era `quoted_amount`, `service_charge + materials_amount`, `quote_status='approved'`, completed status और preselected Razorpay method पर निर्भर है। यह नए customer-only-materials और timer-bill नियम के अनुकूल नहीं है।
- Webhook service-role REST से सीधे `service_bookings` PATCH करके `payment_status='paid'`, `amount_paid`, payment ID और client-side current timestamp लिखता है। Shared atomic finalizer/RPC नहीं है; payout/commission triggers इसी update पर चल सकते हैं।
- Amount/order mismatch, booking missing, cash booking और non-payable state पर webhook HTTP 200 के साथ unreconciled result देता है। Provider retry पर निर्भर रहने के बजाय durable exception inbox + Admin reconciliation आवश्यक है। केवल update-not-applied जैसी कुछ स्थितियों में HTTP 500 retry signal है।
- `verify-payment.js` checkout signature verify करता है, Razorpay payment resource से captured status/order/currency/amount जाँचता है, फिर अलग से सीधे booking PATCH करता है। यह भी shared finalizer और durable inbox का उपयोग नहीं करता। Webhook और verify endpoint की concurrent calls में अलग-अलग paths हैं; DB-level unique payment intent/finalization contract आवश्यक है।
- `create-order.js` customer session/booking ownership जाँचता है और order creation के लिए per-booking lock लेता है; लेकिन payable eligibility, amount और reusable-order check अभी quote approval तथा `service_charge + materials_amount` पर आधारित हैं। इसे frozen bill snapshot ID/version/hash और integer paise amount से बदलना होगा।
- Netlify webhook adapter केवल root handler import करता है; parity का अर्थ वही legacy handler है, कोई अलग reconciliation logic नहीं।

### B. Production trigger bodies की recovered dependencies
- `guard_new_booking()` insert पर status/payment state/assignment/commission defaults force करता है। नई booking payload/financial columns बदलने से पहले इसकी behavior compatibility test जरूरी है।
- `broadcast_booking_job()` approved active electricians को पहले exact PIN, फिर district match पर offers देता है; नई smart matching/category eligibility लागू करने से पहले existing offer creation behavior सुरक्षित रखें।
- `srk_calculate_booking_commission()` paid + completed booking पर `service_charge × commission_rate` से commission बनाता है। इसे immutable labour bill snapshot से जोड़ना होगा, वरना legacy field update नया bill overwrite/गलत commission बना सकता है।
- `srk_create_electrician_payable()` paid + completed + quote approved + verified payment पर service और materials दोनों जोड़कर payment match करता है; payout row में `materials_amount` रखता है और electrician payable = service + materials − service-based commission बनाता है। यह binding customer-only-materials policy का सीधा blocker है। इसे new bill path से route/replace करने से पहले सभी legacy callers और historical payout rows सुरक्षित रखने होंगे।
- Audit/status-history/cancel-offer triggers भी booking update पर चलते हैं; finalizer migration में उनकी event duplication और audit coverage जाँचना होगा।

### C. Existing webhook inbox schema/access
- Production `srk_razorpay_webhook_events` columns: `event_id` (NOT NULL), `event_type` (NOT NULL), `razorpay_order_id`, `razorpay_payment_id`, `payment_amount_paise`, `payment_currency`, `processing_status` (NOT NULL), `reconciliation_reason`, `received_at` (NOT NULL), `processed_at`, `updated_at` (NOT NULL), `razorpay_refund_id`.
- Table grants inspection में `service_role` को table privileges और `postgres` को owner-level privileges मिले; `anon`/ `authenticated` के direct table grants नहीं दिखे। पहले के policy inspection में इस table पर कोई policy row नहीं मिली थी। Schema exposure/role inheritance की पूरी पुष्टि अलग ACL audit से ही होगी।
- उपलब्ध schema में raw payload/payload hash, signature verification outcome, retry count, lease owner/expiry, last error और bill snapshot/payment-intent reference के columns नहीं दिखे। Existing table को duplicate create न करें; versioned extension/mapping plan बनाएं।
- Production में `srk_admin_list_razorpay_webhook_exceptions(integer)` नाम का Admin-guarded SECURITY DEFINER read RPC मिला। यह केवल `exception` और `processing_error` statuses पढ़ता है; event ingestion/consumer/claim/retry/reconcile writer lineage इस pass में prove नहीं हुई।

### D. निष्कर्ष और अगला सुरक्षित क्रम
1. Current checkout verification और webhook दोनों direct booking PATCH करते हैं; इन्हें एक shared idempotent server-side finalizer/RPC में converge करना अनिवार्य है।
2. पहले bill snapshot/payment intent का canonical schema और finalizer contract design करें; फिर existing webhook inbox को duplicate किए बिना durable event claim/process/exception lifecycle जोड़ें।
3. Razorpay order creation, client verification, webhook, cash confirmation, manual payment, fee, payout और refund सभी exact bill snapshot ID/version/hash/amount_paise पर bind हों।
4. New payout/commission trigger केवल labour amount और 15% labour-only Platform Fee पर चले। Legacy quote/material fields केवल ऐतिहासिक compatibility के लिए रहें; पुराने paid records/payouts mutate या delete न हों।
5. Test Mode में duplicate/out-of-order events, verify-vs-webhook race, two payment IDs for one bill, wrong amount/currency/order, provider timeout, DB failure, retry, exception recovery और old quote-era regression tests जरूरी हैं।
6. Production migration/deployment से पहले isolated dev environment, complete object/caller lineage, rollback और सभी role-based negative tests आवश्यक हैं। कोई Production DDL/DML या provider action इस audit से अधिकृत नहीं है।

Audit सीमा: source/catalog inspection; live payment test, webhook replay, penetration test या production certification नहीं। इस pass में कोई database, application source, provider setting या deployment change नहीं किया गया।


## 17.70 — Razorpay Webhook Inbox, Payment Verification और Atomic Finalization Deep Audit (13 Nov 2026)

यह pass Section 17.69 के बाद सीमित read-only follow-up है। Feature Branch के root handlers और Netlify adapters के exact source versions तथा Production webhook table के live columns, grants और संबंधित database function catalog देखे गए। कोई source, database या provider state नहीं बदली।

### A. Exact Feature Branch source lineage
- `razorpay-webhook.js` blob SHA: `f45df3a4c64288028e60ba44857c83df40cf645a`
- `verify-payment.js` blob SHA: `99518ccae34ba022c000cb9933ad80aeb359cfb6`
- `create-order.js` blob SHA: `8d33e098f0595e7a8bed74df737be79414695025`
- `netlify/functions/razorpay-webhook.js` blob SHA: `426a4ddd46d6127ddc600dd3aff499f063c52d5b`
- `netlify/functions/verify-payment.js` blob SHA: `92215fac69910e886914f10cf48141592a349258`

### B. Event ingestion और deduplication gaps
1. Root webhook handler `x-razorpay-signature` से raw body HMAC-SHA256 verify करता है और timing-safe comparison करता है। यह सही सुरक्षा नियंत्रण है; raw body और signature validation को भविष्य के adapter में सुरक्षित रखना अनिवार्य है।
2. Handler Razorpay event ID/header को durable inbox में persist नहीं करता, `srk_razorpay_webhook_events` में INSERT/UPDATE नहीं करता और event status/lease/retry lifecycle चलाता हुआ नहीं दिखता।
3. `payment.captured` और `order.paid` दोनों एक ही captured payment को represent कर सकते हैं। Current code event-level dedupe न होने के कारण दोनों deliveries process करने की कोशिश कर सकता है। Booking PATCH में `payment_status=neq.paid` एक सीमित race guard है, पूर्ण event/payment idempotency contract नहीं।
4. Unknown booking, wrong amount, cash booking और not-payable booking पर handler HTTP 200 लौटाकर unreconciled छोड़ देता है। ऐसी घटनाएँ durable exception queue में लिखी जानी चाहिए; provider retry को एकमात्र recovery mechanism न मानें।
5. Webhook handler refund/Route transfer lifecycle process नहीं करता। इस audit में कोई separate Production database webhook writer/consumer function नाम नहीं मिला; इससे यह साबित नहीं होता कि कोई बाहरी/अलग service मौजूद नहीं है। उसकी deployment lineage/configuration अलग से recover करनी होगी।

### C. Verification और order creation race
- `verify-payment.js` checkout signature verify करने के बाद Razorpay Payment API से captured state, order ID, INR currency और amount जाँचता है। Customer JWT, phone confirmation और booking ownership भी जाँचे जाते हैं। लेकिन successful verification पर यह भी सीधे service-role PATCH करता है; webhook से अलग finalization path बना रहता है।
- Webhook और verify endpoint एक ही payment पर लगभग साथ चलें तो दोनों अलग-अलग booking read/validate/PATCH कर सकते हैं। Current conditional PATCH duplicate paid-state overwrite को सीमित करता है, लेकिन atomic payment intent, unique captured payment binding, bill snapshot lock और एक shared ledger finalization guarantee नहीं देता।
- `create-order.js` per-booking payment-order lock लेता है और lock के बाद booking दोबारा पढ़ता है; यह उपयोगी concurrency protection है। फिर भी order amount `service_charge + materials_amount` / `quoted_amount` से आता है और reusable order उसी quote total से match होता है। नया order केवल frozen labour bill snapshot के integer paise, bill version/hash और उसी payment intent से बने।
- Netlify adapters root handlers import करते हैं; इसलिए root handler की सभी legacy सीमाएँ Netlify endpoint पर भी लागू हैं। Raw body/base64/header forwarding का deploy-runtime integration test अभी आवश्यक है।

### D. Production webhook table — live catalog confirmation
Production `public.srk_razorpay_webhook_events` में 12 columns मिले:
`event_id`, `event_type`, `razorpay_order_id`, `razorpay_payment_id`, `payment_amount_paise`, `payment_currency`, `processing_status`, `reconciliation_reason`, `received_at`, `processed_at`, `updated_at`, `razorpay_refund_id`.
- `event_id` और `event_type` NOT NULL हैं; status default `received` है। इस table को दोबारा create नहीं करना है।
- इन columns में raw payload/payload hash, signature result, retry counter, lease owner/expiry, last error और bill snapshot/payment-intent binding नहीं मिले।
- Live table grants में `service_role` को SELECT/INSERT/UPDATE/DELETE सहित table privileges मिले; `postgres` owner-level privileges रखता है। `anon` और `authenticated` के direct grants query में नहीं मिले। RLS/policy और schema exposure को grants से अलग मानकर scoped ACL review जारी रखें।
- इस table पर trigger catalog query में कोई non-internal trigger नहीं मिला।
- Production public function catalog में webhook नाम से केवल `srk_admin_list_razorpay_webhook_exceptions(integer)` मिला। यह Admin-guarded SECURITY DEFINER read RPC है और `exception` तथा `processing_error` rows सूचीबद्ध करता है। इस audit से कोई DB-side inbox writer, claim/lease RPC या event consumer सिद्ध नहीं हुआ।
- निष्कर्ष: table मौजूद है, पर inspected Feature Branch handler उसका उपयोग नहीं करता; live Production event writer/consumer lineage अभी unresolved है। Existing event rows को पढ़े/मिलाए बिना schema migration या duplicate inbox निर्माण न करें।

### E. Shared finalizer के लिए अनिवार्य contract
1. Webhook और customer verification दोनों एक ही trusted server-side finalizer invoke करें; कोई handler सीधे `service_bookings.payment_status/amount_paid` PATCH न करे।
2. Finalizer exact booking + customer + immutable labour bill snapshot ID/version/hash + expected integer paise + INR + Razorpay order/payment IDs validate करे।
3. Unique constraints/idempotency keys event ID, payment ID और bill/payment intent पर duplicate तथा conflicting captured payments रोकें। `payment.captured` और `order.paid` दोनों event types एक ही payment को दो बार finalize न कर सकें।
4. Transaction में booking/payment intent lock, payment ledger insert, bill snapshot reference, booking paid state, 15% labour-only fee और labour-only electrician payable एक atomic unit हों। किसी एक चरण की failure पर पूरा DB transaction rollback हो।
5. Provider API network call database transaction के बाहर रहे; webhook inbox पहले durable receipt बने, फिर worker/consumer claim lease लेकर process करे। Provider timeout/DB outage पर event pending/retryable रहे; permanent mismatch Admin exception बने।
6. Raw body को सीमित retention और secret/PII redaction policy के साथ store करें या cryptographic payload hash + verified signature metadata रखें। Signature secret कभी DB/log/UI में न जाए।
7. Cash/manual payment भी उसी bill snapshot और shared accounting finalization contract में आए, लेकिन cash verification semantics अलग और auditable रहें। Refund और Route reversal अलग linked ledgers तथा independent idempotency keys के साथ चलें।
8. Admin exception UI केवल सुरक्षित list नहीं; आगे चलकर reason, retry eligibility, controlled reprocess, immutable audit और maker-checker approval भी चाहिए। वर्तमान Admin list RPC केवल read surface है।

### F. अगला सुरक्षित क्रम
1. Production webhook inbox के existing rows, indexes, constraints, RLS, grants, schema exposure और historical statuses की read-only inventory पूरी करें; event writer source/deployment lineage खोजें।
2. Timer bill snapshot/payment intent और shared finalizer का versioned contract बनाएं; पहले isolated development environment में लागू/परीक्षित करें।
3. Webhook receipt/claim/lease/consumer, client verification, order creation और shared finalizer को Test Mode में जोड़कर duplicate/out-of-order/race/fault/retry/exception recovery tests चलाएँ।
4. Fee/payout triggers को labour-only snapshot आधारित करें; पुराने quote/material paid bookings और payouts को historical compatibility mapping से सुरक्षित रखें।
5. Customer, assigned/unassigned Electrician, Admin और service-role positive/negative authorization tests, webhook raw-body adapter tests और rollback rehearsal के बाद ही production change प्रस्तावित करें।

Audit सीमा: source + live catalog read-only inspection। कोई DDL/DML, event replay, Razorpay API/provider action, refund/transfer, application source edit, deployment या live payment test नहीं किया गया।


### G. Production webhook inbox inventory — अतिरिक्त live verification
- RLS enabled है; `FORCE ROW LEVEL SECURITY` enabled नहीं है। कोई table policy row नहीं मिली।
- Effective privilege checks में `anon` और `authenticated` को direct SELECT नहीं मिला; `service_role` को SELECT/INSERT/UPDATE मिला। Schema USAGE दोनों public roles को है, लेकिन table privilege न होने के कारण direct table read नहीं मिला।
- तीन indexes मिले: `event_id` primary-key unique index, `(razorpay_order_id, received_at DESC)`, और `(processing_status, received_at DESC)`।
- Constraints में केवल `PRIMARY KEY(event_id)` और processing status allow-list check मिला: `received`, `reconciled`, `exception`, `ignored`, `processing_error`।
- Live status aggregation खाली object लौटा; निरीक्षण के समय table में कोई webhook event row नहीं थी। इसका अर्थ यह नहीं कि Razorpay account में कोई event नहीं आया; केवल इस Production table में वर्तमान में कोई row नहीं मिली।
- कोई table trigger नहीं मिला। इस कारण existing table के साथ durable writer/consumer अभी भी स्थापित/सिद्ध नहीं है।


## 17.71 — Repository Branches, Netlify Routing और Webhook Deployment Lineage Audit (13 Nov 2026)

इस pass में repository की उपलब्ध branches, Feature Branch/Main के payment-related file trees, पुराने refund implementation branch, Netlify function adapter और route configuration का read-only inspection किया गया। कोई deployment/provider dashboard या secret value access नहीं किया गया।

### A. उपलब्ध repository branches और lineage
- उपलब्ध branches में `main`, `feature/platform-fee-cash-online-cycle`, `safe-payment-refund-implementation`, अन्य feature/fix branches और `gh-pages` शामिल हैं।
- `main` और current Feature Branch के payment-related file trees में root `razorpay-webhook.js`, `verify-payment.js`, Netlify adapters और `netlify.toml` मिले। किसी अलग inbox worker/consumer या webhook event ingestion service का स्पष्ट source path नहीं मिला।
- `safe-payment-refund-implementation` branch में अलग `create-refund.js` और उसका Netlify adapter है, लेकिन उसका webhook handler भी quote-era booking lookup और direct booking PATCH पर आधारित है; वह durable event inbox writer/consumer का प्रमाण नहीं है। इसे Production में deployed या सुरक्षित मानकर promote न करें।
- Branch presence अकेले deployment proof नहीं है। किस commit/branch को Netlify Production में deploy किया गया था, यह Netlify deployment metadata/dashboard से अलग सत्यापित करना होगा; इस audit में ऐसा access/verification नहीं हुआ।

### B. Netlify routing evidence
- `netlify.toml` में `/api/razorpay-webhook` को `/.netlify/functions/razorpay-webhook` पर rewrite किया गया है।
- `netlify/functions/razorpay-webhook.js` केवल `../../razorpay-webhook.js` का handler import/export करता है। कोई queue/worker invocation या DB inbox call adapter में नहीं है।
- `/api/verify-payment` भी corresponding Netlify adapter से root `verify-payment.js` को चलाता है।
- यह repository configuration source-level routing दिखाती है; deployed route, function invocation logs, environment variables और Razorpay Dashboard में configured webhook URL/secret की वास्तविक स्थिति अभी independently verified नहीं है।

### C. Current conclusion
1. उपलब्ध source branches में durable webhook event writer/consumer का implementation नहीं मिला।
2. Production में inbox table और Admin exception-list RPC मौजूद हैं, पर उनके साथ जुड़ा writer/consumer source/deployment lineage अभी unresolved है।
3. इसलिए existing inbox को live payment handling के लिए कार्यरत मानना गलत होगा; पहले deployment logs, configured webhook endpoint, Supabase function/job/cron/queue inventory और historical external worker ownership recover करना जरूरी है।
4. कोई नया worker, cron, queue, migration या webhook URL अभी create/change न करें। पहले exact Production deployment और provider configuration evidence लें, फिर isolated dev में implementation प्रस्तावित करें।

Audit सीमा: repository source/branch/config inspection only। Netlify dashboard/deployment logs, Razorpay Dashboard webhook configuration, Supabase Edge Functions/cron/queues external deployment, secrets और live webhook delivery इस pass में inspect नहीं हुए। कोई code, database, provider configuration या deployment change नहीं हुआ।


## 17.72 — Netlify/Razorpay Live Dashboard Access Boundary और CI/CD Routing Audit (13 Nov 2026)

### A. Repository/CI configuration से सत्यापित तथ्य
- `main` और `feature/platform-fee-cash-online-cycle` दोनों में `netlify.toml` का SHA समान है: `a6a91b088ca71f6e67622a0c37bb755bf4025f77`।
- Netlify build config publish directory `.`, functions directory `netlify/functions`, Node.js `20`, esbuild bundler है।
- `/api/razorpay-webhook` और `/api/verify-payment` के redirects संबंधित Netlify Functions पर हैं। यह केवल repository config है, live Netlify deploy state का प्रमाण नहीं।
- Inspected GitHub workflow `.github/workflows/supabase-schema-ci.yml` SHA `8cdd128fb69227fee82b5084f8b78634f13ffcb2` केवल manual `workflow_dispatch` पर चलता है और Feature Branch के लिए local isolated Supabase schema migration test बनाता है। इसमें Netlify deploy या Razorpay webhook registration step नहीं है।
- Workflow Production schema-only export के लिए dedicated low-privilege GitHub secret मांगता है, row data export रोकता है, फिर migrations local Supabase stack में चलाता है। यह CI workflow खुद Production migration apply नहीं करता।

### B. Live dashboard verification की सीमा
- इस session में Netlify account/site/deployment/logs/environment variables और Razorpay Dashboard webhook endpoint/events/secrets पढ़ने वाला connected action उपलब्ध नहीं मिला।
- इसलिए वर्तमान live Netlify Production commit, deploy status, function logs, configured webhook URL, active/inactive webhook secret, delivery attempts और recent provider events सत्यापित नहीं किए जा सके।
- कोई अनुमान नहीं लगाया गया; repository config को live deployment status नहीं माना गया।
- Vercel integration उपलब्ध होना Netlify account access का विकल्प नहीं है; Vercel deployment को Netlify Production का प्रमाण नहीं माना जाएगा।

### C. सुरक्षित अगला कदम
1. Netlify site की latest Production deployment metadata और deployed commit SHA पढ़ें; कोई deploy/rollback trigger न करें।
2. उसी deployed commit के root webhook handler और Netlify adapter hashes compare करें।
3. Function invocation/error logs से raw-body/header handling और HTTP response behavior जाँचें; logs में secret/token/PII expose न करें।
4. Razorpay Dashboard में webhook URL, subscribed event names, delivery status और secret rotation metadata को बिना secret value देखे verify करें।
5. Netlify environment variables में केवल variable names/presence/last-updated metadata जाँचें; secret values कभी print/export न करें।
6. जब तक live config lineage प्रमाणित न हो, webhook URL/secret, Production deploy, database writer/consumer या payment handler न बदलें।

Audit सीमा: GitHub source/config inspection only। Netlify और Razorpay live dashboards/logs से कोई authenticated access नहीं हुआ। कोई deployment, webhook registration, secret change, payment, refund, transfer या Production database modification नहीं किया गया।


## 17.73 — Supabase Production Edge Functions, pg_net और Scheduled Worker Lineage Audit (13 Nov 2026)

### A. Production project snapshot
- Project `gnqhoaqatmoiwwhgzkgm`, region `ap-south-1`, status `ACTIVE_HEALTHY`, PostgreSQL 17.11।
- यह audit केवल read-only metadata, catalog और function source inspection पर आधारित है।

### B. Active Edge Functions
1. `send-sms-2factor`: ACTIVE, version 8, `verify_jwt=false`। Source POST-only है, `SEND_SMS_HOOK_SECRET` के साथ Standard Webhooks signature verify करता है, Supabase-generated OTP को 2Factor template `SRK_ELECTRONIC_OTP` से deliver करता है। Provider key/secret values inspect या expose नहीं किए गए।
2. `push-job-offer`: ACTIVE, version 4, `verify_jwt=false`। GET public VAPID public key देता है; POST `x-srk-push-secret` validate करता है, payload को `public.job_offers` INSERT/UPDATE webhook shape तक सीमित करता है, approved active electrician की subscriptions पर Web Push भेजता है और expired subscriptions साफ करता है। Source में Supabase service key और VAPID private key server-side env से लिए जाते हैं; values नहीं पढ़े गए।

### C. Push notification trigger lineage
- Production में `public.job_offers` पर `trg_srk_push_job_offer` AFTER INSERT OR UPDATE trigger मिला।
- Trigger function `private.srk_notify_job_offer_push()` SECURITY DEFINER है और `search_path=pg_catalog` सेट करता है।
- Function Vault से `PUSH_WEBHOOK_SECRET` लेता है और `net.http_post` के माध्यम से उसी project के `push-job-offer` Edge Function को JSON payload भेजता है।
- यह Push notification pipeline है, Razorpay payment webhook inbox/worker नहीं। इसे payment event consumer न समझें।

### D. Cron/Queue inventory
- Installed extension में `pg_net` मिला; `net.http_request_queue`, `net.http_response`, `net._http_response` मौजूद हैं। ये pg_net HTTP request/response infrastructure हैं, application-level durable payment event inbox/worker का प्रमाण नहीं।
- Catalog में `cron` schema / `cron.job` relation नहीं मिला; इस Production database snapshot में pg_cron scheduled job inventory उपलब्ध नहीं दिखी।
- `pgmq` या `queues` schema नहीं मिला।
- `public/private` function name search में Razorpay exception-list Admin RPC के अतिरिक्त webhook/payment worker/claim consumer नाम का function नहीं मिला।
- Existing `public.srk_razorpay_webhook_events` inbox table है, लेकिन इस audit में कोई writer/claim/consumer lineage नहीं मिला। Section 17.70–17.71 की findings कायम हैं।

### E. निष्कर्ष और सीमा
- Supabase project में active Edge Functions हैं, लेकिन इनमें से कोई भी Razorpay webhook event inbox consumer या payment finalizer worker नहीं है।
- pg_net push trigger का उपयोग करता है; यह general queue worker, scheduled retry system या Razorpay processor नहीं है।
- Database catalog inspection से इस project के बाहर चल रहे external worker, GitHub Actions scheduled workflows, Netlify scheduled functions या third-party automation का अस्तित्व न होना सिद्ध नहीं होता। External systems अभी unverified हैं।
- No code, database, Edge Function, Vault secret, webhook, schedule, queue, payment, refund, transfer, deployment or provider configuration was changed.
- अगला कदम: external worker/automation ownership evidence और Netlify/Razorpay live dashboard read-only verification प्राप्त करना; तब तक payment inbox या worker नया न बनाएं।

Security note: Edge Function source contains secret variable names only; secret values were not queried, printed, exported or changed.


## 17.74 — Vercel Production/Preview, GitHub Pages और Deployment Branch Lineage Audit (13 Nov 2026)

### A. Vercel project और Production deployment — live metadata verified
- Vercel team `srk-electranic`, project `srk-electranic-`; connected Git repository `shahrukhkhan12136-bot/Srk-electranic-`।
- Project ID `prj_AZLN9fhI89k22qY7ZiI8PzsDBYdj`; team ID `team_9faMRH6X4ckmKDWZqPrIn8Sa`।
- Project metadata में `live=false` दिखा, जबकि Production target का latest deployment state `READY` है। इन दोनों fields का अर्थ समान नहीं मानना; dashboard से custom domain/traffic routing की पुष्टि अलग से आवश्यक है।
- Latest Production deployment ID `dpl_BaUb7Kpt2LZ1TgNv9TE4J7Pq4bkq`, state `READY`, branch `main`, commit `7f62b622e33e49b0196d0d93febf73049579c281`।
- Production aliases: `srk-electranic.vercel.app`, `srk-electranic-srk-electranic.vercel.app`, `srk-electranic-git-main-srk-electranic.vercel.app`।
- Latest Production deployment का commit Feature Branch के नवीनतम audit documentation commits से अलग है। Feature Branch commits के Vercel deployments `READY` हैं, लेकिन उनका `target=null` है; वे Preview deployments हैं, Production promotion नहीं।
- Vercel project metadata में SSO protection `all_except_custom_domains` enabled है; password protection disabled है। Actual custom-domain exposure/access behavior का browser-level test इस audit में नहीं किया गया।
- Vercel environment variable metadata query में कोई project env rows नहीं मिलीं और hidden Production env count 0 था। Values decrypt/read नहीं की गईं। यह Vercel env configuration का परिणाम है; Netlify env variables के बारे में कुछ नहीं बताता।

### B. GitHub Pages alternate deployment path
- Feature Branch और `main` दोनों में `.github/workflows/publish-pages.yml` मौजूद है; SHA `cb45002c2b6bbbf2b0a325477a9e252de5729b0e`।
- Workflow `gh-pages` branch पर हर push और manual `workflow_dispatch` पर GitHub Pages deploy job चलाने के लिए configured है।
- Workflow branch से repository root की सभी files GitHub Pages artifact में upload करता है।
- `gh-pages` branch मौजूद है; वर्तमान branch commit `e61e8652be064d055b7537a485d3db38ae2a9dd6`।
- Branch tree में customer/admin/electrician HTML, `create-order.js`, `razorpay-webhook.js`, `verify-payment.js`, Netlify adapters, `netlify.toml`, `vercel.json`, `srk-config.js` और Supabase migrations की copies मौजूद हैं।
- इससे GitHub Pages workflow/branch alternate publishing path के रूप में configured होना सिद्ध होता है; GitHub Pages का वर्तमान published URL, latest successful workflow run या live traffic इस audit में verify नहीं हुआ।
- GitHub Pages static hosting पर server-side Netlify Function adapters स्वयं execute नहीं होंगे। इसलिए इस branch को payment-capable production backend नहीं मानना चाहिए; stale/duplicate frontend या config exposure का अलग review आवश्यक है।

### C. CI/CD lineage और deployment risk
- Feature Branch के current `.github/workflows/` में दो workflows हैं: `publish-pages.yml` और `supabase-schema-ci.yml`। कोई GitHub Actions scheduled cron या payment/webhook worker workflow नहीं मिला।
- `supabase-schema-ci.yml` केवल manual `workflow_dispatch` है और isolated local migration test करता है; Production migrations apply नहीं करता।
- Vercel Feature Branch auto-builds Preview target पर दिखे; कोई automatic Production promotion प्रमाणित नहीं।
- GitHub Pages push-triggered deployment अलग alternate publishing route है। इसे Netlify Production target के बराबर नहीं मानें।
- Netlify अभी भी repository README का घोषित primary target है; Netlify live deployment metadata/logs तथा Razorpay Dashboard webhook configuration इस session में उपलब्ध नहीं हुए।

### D. सुरक्षित अगला कदम
1. Vercel dashboard में `live=false` status, production domain aliases, SSO/custom domain exposure और project env setup को owner के साथ reconcile करें।
2. GitHub Actions में `publish-pages.yml` के run history और Pages settings/published URL verify करें।
3. `gh-pages` पर `srk-config.js` और अन्य copied config files की public exposure review करें; किसी file को बिना secret/content/dependency review हटाएँ नहीं।
4. Netlify Production deployed commit और Razorpay webhook endpoint/secret configuration का read-only verification अभी भी आवश्यक है।
5. Master Requirements से बाहर alternate hosting paths को retire करने का निर्णय केवल dependency, domain DNS, traffic, webhook callback और rollback evidence मिलने के बाद लें।

Audit सीमा: Vercel project/deployment metadata और non-decrypted env metadata read-only; GitHub branch/workflow source read-only। कोई Vercel/Netlify/GitHub Pages deployment, alias, DNS, env var, workflow, webhook, database, payment या provider configuration बदला नहीं गया।


## 17.75 — GitHub Pages Live Deployment Evidence और Supabase Schema CI Failure Root Cause (13 Nov 2026)

### A. GitHub Pages deployment अब प्रमाणित
- GitHub Actions workflow `.github/workflows/publish-pages.yml` SHA `cb45002c2b6bbbf2b0a325477a9e252de5729b0e` की run history में दो successful manual deployments मिले: run IDs `42915375937` और `42913902399`; दोनों 10 Nov 2026 को `main` branch से `workflow_dispatch` द्वारा चलाए गए।
- Run `42915375937`, job `130176332993`: Checkout published branch, Configure Pages, Upload static site और Deploy to GitHub Pages सभी सफल।
- Deploy log ने प्रकाशित URL `https://shahrukhkhan12136-bot.github.io/Srk-electranic/` लौटाया और Pages deployment success report किया।
- Deploy artifact ID `13808428749`; artifact size 69,638 bytes। Workflow ने `gh-pages` branch checkout करके repository root को static artifact बनाया।
- इसलिए GitHub Pages केवल configured workflow नहीं है; कम-से-कम 10 Nov 2026 को सफल publish हुआ था। वर्तमान HTTP reachability/traffic इस tool session में independently verify नहीं हो सका।
- Workflow trigger `gh-pages` push और manual dispatch है; उपलब्ध दो runs दोनों manual `main` dispatch हैं। इसका अर्थ यह नहीं कि हर push पर deployment सफल हुआ।

### B. GitHub Pages पर प्रकाशित configuration की समीक्षा
- `gh-pages/srk-config.js` SHA `0b2efc073bc0c70dacac11fa7a90daa11f47aeda` inspect किया।
- File में Supabase project URL और browser-facing `SUPABASE_ANON_KEY` है; file स्वयं इसे browser-safe publishable key बताती है। कोई `service_role`/secret key इस file में नहीं मिली।
- Anon/publishable key का public होना अपने-आप में secret leak नहीं है; वास्तविक सुरक्षा Supabase RLS, grants और exposed RPC policies पर निर्भर है। इस audit में key value को report या copy नहीं किया गया।
- Pages artifact में HTML, config, Netlify adapters, Razorpay root handlers और migration files की copies शामिल थीं। Static GitHub Pages hosting इन Netlify serverless adapters को execute नहीं करती। अतः Pages copy को working payment backend या active Razorpay webhook processor न मानें।
- Public Pages copy की पूर्ण secret scan, browser network test, form submission/payment test और current traffic verification अभी शेष हैं।

### C. Supabase isolated schema CI — नवीनतम failure का root cause
- Feature Branch `.github/workflows/supabase-schema-ci.yml` SHA `eddf175d30f8b3bec3a1fa527e1c64563082737c`।
- Latest run `43282223334` (12 Nov 2026 18:40 UTC), manual `workflow_dispatch`, completed with `failure`।
- Job `131406225631` में secret-presence check, pinned Supabase CLI install, clean temporary project creation और restricted export-role privilege check सफल हुए।
- Export-role check ने confirm किया कि account superuser/BYPASSRLS नहीं था और public/private tables का SELECT/modify access नहीं रखता।
- अगला `pg_dump --schema-only --no-owner --no-acl --schema=public --schema=private` step `public.services` पर `LOCK TABLE ... IN ACCESS SHARE MODE` के दौरान `permission denied for table services` से fail हुआ।
- इसलिए schema export बना ही नहीं; local stack restore, पाँच pending Feature migrations, lint और smoke tests सभी skip हुए। इसे migration failure या Production schema failure कहना गलत होगा; CI अभी source schema सुरक्षित ढंग से export नहीं कर पाया।
- Recent preceding runs `43281436323`, `43279241291`, `43277167040` और `43249594748` भी इसी workflow में failure हुए। Run `43282223334` का detailed log ऊपर का exact blocker दिखाता है।
- Root-cause interpretation: workflow का “no table-row SELECT privilege” security guard सफल है, लेकिन चुना हुआ `pg_dump` तरीका schema-only dump से पहले table locks मांगता है। Restricted role को बिना table data पढ़ने की अनुमति दिए आवश्यक metadata/lock operation उपलब्ध कराने का सुरक्षित तरीका अभी तय नहीं हुआ।
- PostgreSQL version 17.11 Production होने के कारण संभावित dedicated `MAINTAIN`/catalog-only approach को version-specific least-privilege review और isolated test के बिना लागू न करें। `SELECT` grant देना या privileged `postgres/service_role/BYPASSRLS` credential से dump लेना स्वीकार्य workaround नहीं है।
- CI workflow में पाँच pending migration paths भी दर्ज हैं: third-booking online payment, labour-only/customer-supplied materials, cash platform-fee due/online settlement, electrician payment-choice visibility और customer cash-to-online switch। ये इस failed run में execute नहीं हुए; इनका Production में लागू होना इस evidence से सिद्ध नहीं होता।

### D. सुरक्षित सुधार योजना — अभी कोई बदलाव नहीं
1. Schema export strategy को Production पर privilege grant किए बिना isolated environment में validate करें; पहले catalog-only export या narrowly scoped `MAINTAIN`-based pg_dump compatibility जाँचें।
2. Restricted export role की कोई privilege change आवश्यक हो तो अलग approval और explicit rollback plan के बिना न करें।
3. CI को सफल करने के बाद ही पाँचों pending migrations का clean isolated apply, lint, smoke और rollback review करें।
4. GitHub Pages की public copy पर पूर्ण secret/config scan और browser-side functionality audit करें; static host पर backend-dependent actions को स्पष्ट रूप से disabled/redirected रखना आवश्यक है।
5. GitHub Pages, Vercel Preview/Production और Netlify को अलग deployment targets मानकर domain/DNS/webhook ownership verify किए बिना कोई alternate path बंद न करें।

Audit सीमा: GitHub Actions run metadata/job logs, workflow source, `gh-pages` branch config और published artifact metadata read-only inspect किए। कोई workflow rerun, secret read, permission grant, migration execution, Pages/Vercel/Netlify deployment या Production change नहीं किया।


## 17.76 — GitHub Pages Public Artifact Static Secret-Pattern Scan और CI Export Permission Compatibility (13 Nov 2026)

### A. gh-pages artifact inventory और static scan
- Audited published `gh-pages` commit `e61e8652be064d055b7537a485d3db38ae2a9dd6`; recursive tree में 58 entries मिले, कोई truncated tree नहीं।
- Inventory में customer/admin/electrician HTML, browser config, payment handlers, Netlify adapters, push-test pages, package manifest, setup/schema SQL और 12 से अधिक migration/config/documentation files शामिल हैं।
- निम्न 20 source/config files में static pattern scan किया: `COMPLETE_DATABASE_SETUP.sql`, `ADMIN_EMAIL_LOGIN_SETUP.sql`, `PORTAL_SCHEMA.sql`, `PORTAL_SECURITY_UPDATE.sql`, `SUPABASE_SCHEMA.sql`, `supabase-connection-test.html`, `admin.html`, `index.html`, `customer-login.html`, `electrician.html`, `create-order.js`, `razorpay-webhook.js`, `verify-payment.js`, `apply-electrician.js`, `create-booking.js`, `push-test/index.html`, `push-test/offer.html`, `push-test/sw.js`, `package.json`, `README.md`।
- Scan में literal AWS access-key pattern, hard-coded JWT-shaped token, Razorpay secret-shaped key, private-key PEM block, credential-bearing PostgreSQL URL या long secret/password/token assignment नहीं मिला।
- Payment/backend handler files में `service_role` शब्द/reference मिले; inspected matches credential literals नहीं, server-side environment/authorization references हैं। वास्तविक environment secret values न पढ़े गए, न log किए गए।
- `gh-pages/srk-config.js` में केवल browser-facing Supabase URL और Anon/publishable key का configuration है; service_role secret नहीं। Anon key public design का हिस्सा है; RLS/ACL और exposed RPC policy ही data सुरक्षा तय करते हैं।
- यह static pattern scan है, पूर्ण DLP/secret-scanning certification नहीं। Encoded/obfuscated credentials, historical commits, binary artifacts, third-party dependencies, live runtime responses और external logs इस scan के दायरे में नहीं थे।
- प्रकाशित root artifact में setup SQL, migrations, internal deployment documentation, server handler source और push-test pages भी हैं। भले उनमें कोई literal credential pattern न मिला हो, production public website के लिए यह अनावश्यक source/schema disclosure और stale endpoint exposure बढ़ाता है। अगली सुरक्षित release में root-wide copy के बजाय explicit public-file allowlist अपनाने का प्रस्ताव है; अभी कोई file हटाई या publish workflow बदला नहीं गया।
- GitHub Pages static hosting Netlify adapters/functions को execute नहीं करती। इसलिए वहाँ मौजूद Razorpay webhook/create-order/verify-payment source को operational backend न समझें।

### B. Supabase CI export failure — permission mismatch स्पष्ट
- Latest CI run `43282223334`, job `131406225631` के logs से पता चला कि workflow पहले restricted role check पास करता है, जो role को table-row SELECT और write privileges से वंचित रखता है।
- इसके तुरंत बाद `pg_dump --schema-only` सभी public/private tables पर ACCESS SHARE lock माँगता है और `public.services` पर `permission denied` से रुकता है।
- इसलिए वर्तमान workflow के दो design goals में compatibility gap है: “table data read न कर सकने वाला role” और “pg_dump को tables पर lock लेने देना”। Failure को केवल credential गलत होने का निष्कर्ष न मानें; restricted role check सफल था।
- CI workflow में `pg_dump` का installed client version 18.6 था जबकि Production PostgreSQL 17.11 है। यह अकेले failure का प्रमाणित कारण नहीं; exact logged blocker table lock permission है। Client/server major-version compatibility को भी supported-version policy के अनुसार align/verify करना शेष है।
- इस audit में कोई grant/revoke, role change, secret update या workflow edit नहीं किया गया। `SELECT` देना, privileged postgres/service_role credential का उपयोग करना या सुरक्षा guard हटाना स्वीकार्य quick fix नहीं है।
- अगला विकल्प: production credentials को छुए बिना isolated fixture में export strategies जाँचें; यदि pg_dump को ACCESS SHARE permission चाहिए तो dedicated read-only schema-export role की privilege boundary को PostgreSQL 17 के आधिकारिक privilege model के साथ review करें। जब तक row access न होने और schema metadata extraction दोनों की guarantee सिद्ध न हो, workflow को Production export के लिए enable/modify न करें।

Audit सीमा: केवल GitHub read-only tree/blob/workflow source और पहले से उपलब्ध run logs inspect किए। कोई source file, branch, Pages artifact, workflow, Supabase role, secret, database object, deployment या provider setting बदली नहीं गई।


## 17.77 — Vercel Current Production Target, Feature Preview and Domain/Alias Reconciliation (13 Nov 2026)

### A. Project metadata और current deployment
- Vercel project `srk-electranic-`, project ID `prj_AZLN9fhI89k22qY7ZiI8PzsDBYdj`, team `team_9faMRH6X4ckmKDWZqPrIn8Sa` को live connected account से read-only पुनः जाँचा।
- Project metadata में `live=false`; latest deployment `dpl_4D5ovJfzTLfVGZcjMrb74obGYQmg` state `READY`, target `null`, branch `fix/admin-activation-rpc-and-readme-20261113`, commit `f7568de4137596052037d3e1431439f3d1d18a0e`।
- इस latest deployment को Vercel Production कहना सही नहीं: API target स्पष्ट रूप से null है। Project-level `live=false` का अर्थ इस audit से निश्चित नहीं किया गया; इसे deployment state या DNS/traffic status का पर्याय न मानें।
- Latest 30 deployment records में अनेक `READY` Preview/target-null builds मिले, जिनमें Feature Branch `feature/platform-fee-cash-online-cycle` का नवीनतम उपलब्ध commit `cece990af868c71e3b8260e4f6d5ffa44c4991f2` Preview target null है।
- अलग `target=production` filter में चार Production deployments लौटे। नवीनतम वही पुराना main deployment `dpl_BaUb7Kpt2LZ1TgNv9TE4J7Pq4bkq`, commit `7f62b622e33e49b0196d0d93febf73049579c281`, branch `main`, state `READY` है। इससे पुष्टि होती है कि Feature Branch documentation commits Production पर promote नहीं हुए।
- Production alias `srk-electranic.vercel.app`, `srk-electranic-srk-electranic.vercel.app`, और `srk-electranic-git-main-srk-electranic.vercel.app` पुराने main Production deployment से जुड़े हैं।
- Feature Branch के लिए `srk-electranic-git-feature-platform-fee-c-8eb82a-srk-electranic.vercel.app` alias Preview deployment `dpl_5XS99XTRZ5mKwB9LRaun8BFijWtg` से जुड़ा है; यह Production alias नहीं है।

### B. Domain और protection स्थिति
- Project domain list में केवल verified built-in `srk-electranic.vercel.app` project domain मिला; कोई custom domain इस Vercel project पर सूचीबद्ध नहीं था।
- Project SSO protection `all_except_custom_domains` enabled है; password protection disabled है। चूँकि वर्तमान सूची में custom domain नहीं है, SSO protection के इस setting को देखते हुए किसी अलग custom-domain access behavior का दावा नहीं किया जा सकता।
- No DNS, domain, alias, SSO, protection, deployment, environment variable या project metadata change किया गया।

### C. Hosting decision gate
- वर्तमान evidence: Vercel Production अभी भी पुराना `main` commit serve करने के लिए assigned है; Feature Branch builds Preview-only हैं; GitHub Pages की एक सफल static deployment भी मौजूद है; Netlify को README में primary target कहा गया है पर live deployment अभी स्वतंत्र रूप से verify नहीं हुआ।
- इसलिए किसी hosting target को बंद करना, alias हटाना, project pause करना, Production promote/rollback करना या DNS बदलना अभी असुरक्षित होगा। पहले Netlify live commit/functions, Razorpay webhook endpoint, custom-domain DNS owner, वास्तविक traffic और rollback path का संयुक्त reconciliation आवश्यक है।
- अगला safe step: Netlify dashboard/connected integration access उपलब्ध होने पर Production deploy commit, function inventory/logs और env-var names/presence (secret values नहीं) verify करें; Razorpay Dashboard में webhook URL, subscribed event names और delivery status केवल read-only inspect करें।

Audit सीमा: Vercel project, deployment list, production-filtered deployment list, feature-branch deployment list, project domain list और aliases केवल read-only देखे। कोई deployment, promotion, alias, DNS, environment variable, protection या billing setting नहीं बदली।


## 17.78 — Netlify Production और Razorpay Dashboard Verification Access Boundary (13 Nov 2026)

### A. Connected access और discovery result
- उपलब्ध connected account actions और plugin directory को Netlify तथा Razorpay के लिए खोजा; इस session में कोई Netlify site/deployment/function/log/environment read integration और कोई Razorpay merchant dashboard/webhook/delivery read integration उपलब्ध या connected नहीं मिला।
- Netlify और Razorpay के नाम से plugin discovery में कोई matching plugin result नहीं मिला। Vercel integration उपलब्ध है, लेकिन उससे Netlify या Razorpay account data प्रमाणित नहीं होता।
- Public web search से SRK ELECTRONIC के Netlify Production deployment या Razorpay merchant webhook configuration का authoritative evidence नहीं मिला। समान नाम वाली unrelated websites को इस project का deployment नहीं माना गया।
- इसलिए Netlify Production का live commit, deployment state, functions, function logs, environment-variable names/presence, custom domain mapping और Razorpay webhook URL/events/delivery attempts/secret presence अभी **unverified** हैं। Repo `netlify.toml` या source handler code इन live dashboard facts का विकल्प नहीं है।

### B. Safe verification checklist — read-only only
1. Netlify account owner/dashboard में सही site ID और site URL identify करें; latest Production deploy commit SHA, deploy state/time, publish directory, functions directory और deploy log inspect करें।
2. Netlify Functions list और recent logs inspect करें; `/api/razorpay-webhook` तथा `/api/verify-payment` के live route resolution और runtime errors verify करें।
3. Netlify environment settings में केवल required variable names और presence/target context (Production/Deploy Preview) देखें; कोई secret value reveal/copy/export न करें।
4. Razorpay Dashboard में Webhooks screen पर configured endpoint URL, subscribed event names, enabled status, recent delivery status/HTTP response/retry history inspect करें। Secret value न खोलें, न rotate करें।
5. Razorpay endpoint को live Netlify function URL और current Production deployment source से correlate करें; event deliveries का समय Netlify function logs और Supabase inbox records से मिलाएँ।
6. कोई endpoint edit, secret rotation, webhook resend, payment/refund/transfer, deploy, rollback या environment change इस read-only audit में शामिल नहीं है; इसके लिए अलग स्पष्ट approval आवश्यक होगा।

### C. Current deployment decision
- Vercel का latest confirmed Production deployment पुराना `main` commit है; Feature Branch केवल Preview है।
- GitHub Pages पर सफल static publication है, पर वहाँ Netlify Functions execute नहीं होतीं।
- Netlify को repository README में primary target कहा गया है, लेकिन live Netlify deployment का प्रमाण अभी उपलब्ध नहीं।
- जब तक Netlify Production + Razorpay webhook + DNS/custom-domain + rollback lineage का एक-दूसरे से मेल खाता प्रमाण न मिले, किसी भी hosting path को बंद/बदलना या Production promotion करना निषिद्ध रहेगा।

Audit सीमा: केवल उपलब्ध connected tool/plugin discovery और public web search से access availability जाँची। कोई Netlify/Razorpay login, configuration, secret, webhook, payment, deployment, DNS या Production resource बदला नहीं गया। यह access limitation है, service outage या misconfiguration का निष्कर्ष नहीं।


## 17.79 — PostgreSQL 17 Schema Export CI Permission Failure: Exact Root Cause and Least-Privilege Candidate (13 Nov 2026)

### A. Exact failed CI evidence
- Inspected GitHub Actions run `43282223334`, job `131406225631`, including step summaries and decoded logs.
- `Verify export credential cannot read rows or alter schema` passed. Thus the configured connection passed the workflow's existing no-SELECT/no-write/no-schema-CREATE guard.
- Failure occurred in `Export schema only from production (no table data)`, at `pg_dump --schema-only --no-owner --no-acl --schema=public --schema=private`.
- PostgreSQL returned: `permission denied for table services` while executing `LOCK TABLE ... IN ACCESS SHARE MODE`. The exact lock list included public and private relations.
- Later local stack startup, schema restore, five Feature migrations, lint and smoke checks were all skipped. No migration test passed in this run.
- Runner installed `pg_dump 18.6` while Production server is PostgreSQL 17.11. This version difference is recorded, but the observed failure is explicitly a permission denial on ACCESS SHARE lock, not a client/server version error.

### B. PostgreSQL 17 privilege rule confirmed from official documentation
- PostgreSQL 17 `LOCK TABLE` documentation states ACCESS SHARE may be acquired with SELECT; MAINTAIN, UPDATE, DELETE or TRUNCATE also permit any lock mode.
- PostgreSQL 17 privilege documentation defines MAINTAIN as allowing VACUUM, ANALYZE, CLUSTER, REFRESH MATERIALIZED VIEW, REINDEX and LOCK TABLE.
- PostgreSQL 17 `pg_dump` documentation confirms `--schema-only` omits data, but does not mean pg_dump skips table locks.
- Official references: https://www.postgresql.org/docs/17/sql-lock.html ; https://www.postgresql.org/docs/17/ddl-priv.html ; https://www.postgresql.org/docs/17/app-pgdump.html

### C. Least-privilege candidate — not yet applied
- Candidate to test in an isolated disposable PostgreSQL 17 environment: grant only `MAINTAIN` on each required relation to the dedicated schema-export role, without granting SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, schema CREATE, ownership, superuser, BYPASSRLS, service_role or role/database administration.
- `MAINTAIN` is not risk-free: it permits maintenance operations and any table lock mode, so it must be narrowly scoped, documented, reviewed and not granted to a general application role. It does not itself grant SELECT/table-row reading.
- Before any Production grant, first prove in a disposable PG17 test that the exact `pg_dump --schema-only` command succeeds with MAINTAIN-only permissions, that no table data is emitted, and that the workflow's credential guard explicitly validates the intended privilege boundary.
- Update the guard to fail if the export role has unexpected relation privileges, and separately allow/verify MAINTAIN only on the explicit relation allowlist. Do not silently let MAINTAIN pass as an unexamined privilege.
- Inspect whether views/materialized views/foreign tables and objects outside public/private need additional handling; do not broaden grants automatically. Keep PostgreSQL client major aligned with Production 17 for deterministic reproducibility, although this is not the proven cause of the present failure.
- Alternative architecture is a reviewed catalog-based schema snapshot pipeline, but it requires object-coverage proof for tables, constraints, indexes, functions, triggers, policies, grants, types, extensions and dependencies before replacing pg_dump.

### D. No changes and next gate
- No Production GRANT/REVOKE, role, schema, table, workflow, secret, database, deployment or provider changes were made.
- Do not grant SELECT to make pg_dump pass; do not use postgres, service_role, superuser or BYPASSRLS credentials; do not weaken/remove the existing guard.
- Next safe step: construct and run a disposable PostgreSQL 17 permission proof with a synthetic schema and dummy rows, validate MAINTAIN-only behavior and row-read denial, then document results. Only after that should a separate approval be requested for any narrowly scoped Production privilege change.


## 17.80 — Disposable PostgreSQL 17 MAINTAIN-Only Proof: Execution Environment Blocker (13 Nov 2026)

### A. Environment capability check
- अगला सुरक्षित कदम Section 17.79 के अनुसार isolated PostgreSQL 17 instance पर synthetic table + dummy rows के साथ MAINTAIN-only privilege proof चलाना था।
- उपलब्ध local execution environment में `docker`, `podman`, `psql`, `pg_dump` और `initdb` में से कोई executable उपलब्ध नहीं मिला; Python `psycopg` driver भी उपलब्ध नहीं था। इसलिए यहाँ PostgreSQL server/client शुरू करके वास्तविक GRANT/LOCK/pg_dump behavior execute करना संभव नहीं हुआ।
- उपलब्ध Supabase Production project इस test के लिए उपयोग नहीं किया गया। Supabase paid branch/temporary compute भी create नहीं किया गया, क्योंकि इससे लागत लग सकती है और user ने disposable paid staging को अलग approval के बिना निषिद्ध रखा है। Existing Production-export CI workflow भी trigger/rerun नहीं किया गया; वह Production connection secret पर निर्भर है और synthetic disposable database नहीं है।
- इस environment check से केवल local test-runtime अनुपलब्ध होना सिद्ध होता है; यह MAINTAIN privilege के व्यवहार की test result नहीं है। कोई pass/fail assertion नहीं किया गया।

### B. Exact proof still required in a disposable PostgreSQL 17 instance
1. PostgreSQL server और `pg_dump` दोनों major version 17 pin करें; एक synthetic database/schema में dummy rows वाली test table बनाएँ और अलग owner तथा dedicated non-owner export role रखें।
2. Export role को केवल connection/schema USAGE और test relation पर MAINTAIN दें; SELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER, schema CREATE, ownership, role membership, superuser और BYPASSRLS न दें।
3. उसी role से `BEGIN; LOCK TABLE ... IN ACCESS SHARE MODE; ROLLBACK;` चलाकर lock success जाँचें।
4. उसी role से `SELECT` करने पर permission denied अपेक्षित है; test को query result/row count leak नहीं करना चाहिए।
5. उसी role से exact CI-style `pg_dump --schema-only --no-owner --no-acl --schema=public --schema=private` चलाएँ। Verify करें कि schema objects मौजूद हैं, table dummy row value/row INSERT/COPY data output में नहीं है, और restore disposable target पर सफल है।
6. अलग negative controls में MAINTAIN हटाकर ACCESS SHARE lock/pg_dump failure, तथा कोई unexpected DML/schema privilege मिलने पर guard failure verify करें। Test relation allowlist से बाहर किसी relation पर MAINTAIN नहीं होना चाहिए।
7. Views, materialized views, partitions/inheritance, foreign tables, sequences, extensions, functions और dependency closure को अलग-अलग enumerate करें; केवल successful synthetic table test के आधार पर Production object allowlist/grant तय न करें।
8. Test SQL, exact commands, PostgreSQL server/client versions, role ACL matrix, dump scan, restore result और negative-control logs सुरक्षित रखें; secret/real data शामिल न करें।

### C. Decision
- MAINTAIN-only proposal अभी **unproven / not approved for Production** है।
- Disposable PG17 runtime उपलब्ध होने पर ऊपर का test चलाना अगला काम है। उसके सफल होने के बाद भी Production पर narrowly scoped grant से पहले explicit separate approval, full relation inventory, ACL review, rollback/revoke plan और post-change verification आवश्यक हैं।
- SELECT grant, broad MAINTAIN grant, service_role/postgres/superuser use, guard weakening, Production schema/role/ACL changes और workflow secret/config changes निषिद्ध रहेंगे।

Audit सीमा: केवल local runtime executable/driver availability जाँची और PostgreSQL 17 official privilege rules को test-plan में बदला। कोई database, role, privilege, migration, workflow, secret, deployment या provider setting नहीं बदली।


## 17.81 — Schema CI Export-Role Guard and Supabase CLI v3 Command Audit (13 Nov 2026)

### A. Workflow source facts
- Feature Branch workflow `.github/workflows/supabase-schema-ci.yml` SHA `eddf175d30f8b3bec3a1fa527e1c64563082737c` को read-only inspect किया। यह केवल `workflow_dispatch` पर चलता है और `github.ref` को Feature Branch तक सीमित करता है।
- Workflow Supabase CLI `3.0.0` pin करता है; export credential केवल GitHub Secret `SUPABASE_DB_URL` से environment में आता है। Secret value पढ़ी या प्रदर्शित नहीं की गई।
- Workflow `supabase db query --remote="$SUPABASE_DB_URL" --read-only` से credential guard चलाता है; फिर अलग system `pg_dump` से `--schema-only` dump बनाता है; उसके बाद local Supabase stack, restore, पाँच feature migrations, lint और smoke test चलाने का इरादा है।
- `supabase/config.toml` इस Feature Branch path पर नहीं मिला (GitHub API 404); workflow फिर भी temporary directory में `supabase init` करता है। `package.json` में केवल Razorpay runtime dependency है; इससे CI PostgreSQL client version pin नहीं होता।

### B. Credential guard coverage gap
- वर्तमान guard superuser/BYPASSRLS/CREATEROLE/CREATEDB/replication attributes, public/private table SELECT, column SELECT, INSERT/UPDATE/DELETE/TRUNCATE/TRIGGER और schema CREATE को reject करता है।
- Guard वर्तमान में `MAINTAIN` privilege की presence, relation-level MAINTAIN allowlist, unexpected relation privileges, object ownership, role membership/inherited privileges और exact required object scope को explicitly validate नहीं करता। इसलिए केवल `safe_schema_export_role=true` वर्तमान query से यह सिद्ध नहीं करता कि candidate MAINTAIN-only permission boundary ठीक उसी allowlist तक सीमित है।
- Section 17.79 का proposed MAINTAIN-only grant यदि भविष्य में लागू किया जाए, तो मौजूदा guard उसे संभवतः अनजाने में pass कर देगा; यह अपने आप में उस grant का validation नहीं होगा। Guard को fail-closed ACL matrix बनानी होगी: प्रत्येक relation पर allowed privileges स्पष्ट रूप से सूचीबद्ध हों; MAINTAIN केवल approved relation allowlist पर; अन्य relation पर MAINTAIN या कोई अनपेक्षित privilege मिले तो failure। Ownership/role membership/inheritance से मिले effective privileges भी जाँचे जाएँ।
- `has_table_privilege`/`has_any_column_privilege` effective privilege checks हैं; फिर भी allowlist का प्रमाण देने के लिए catalog ACL/owner/role-membership inspection अलग से आवश्यक है। `PUBLIC`/inherited grants और default privileges को भी privilege provenance के साथ enumerate करना होगा।

### C. CLI v3 behavior and version reproducibility
- Supabase CLI v3.0.0 documentation/changelog (4 Nov 2026) के अनुसार database commands local target default करते हैं; hosted database URL के लिए `--remote=<postgres-url>` supported है। `db query --read-only` read-only hosted query path है और it rejects statements that do not begin with approved read-only forms. Existing guard starts with SELECT, so its command form is consistent with the documented v3 target model.
- Workflow's `apt-get install postgresql-client` is not pinned to PostgreSQL 17, so observed runner installed pg_dump 18.6 while Production server is 17.11. Pinning Supabase CLI alone does not pin this separately installed PostgreSQL client. This is reproducibility/version drift, not proof that version mismatch caused the ACCESS SHARE permission error.
- For a deterministic future CI run, install an explicit PostgreSQL 17 client package/repository and assert `pg_dump --version` major is 17 before connecting. Keep target confirmation explicit and ensure no command can fall back to a hosted target unintentionally.

### D. No change / next test gate
- No workflow/source file, GitHub Secret, role, ACL, database, Production resource or deployment was changed; no workflow was dispatched or rerun.
- Next safe test remains disposable PostgreSQL 17 synthetic database proof (Section 17.80), then unit-test the guard against: no MAINTAIN; allowlisted MAINTAIN only; out-of-allowlist MAINTAIN; SELECT via direct/inherited/PUBLIC grants; owner role; role membership; schema CREATE; and DML grants. Test both positive and negative cases before any separate Production approval.
- Official references: Supabase CLI v3 changelog https://supabase.com/changelog/supabase-cli-v3 ; CLI db query reference https://supabase.com/docs/reference/cli/supabase-db-query ; PostgreSQL 17 privileges https://www.postgresql.org/docs/17/ddl-priv.html ; PostgreSQL 17 LOCK TABLE https://www.postgresql.org/docs/17/sql-lock.html .

Audit सीमा: केवल Feature Branch workflow, package metadata और official CLI documentation का read-only review किया। कोई workflow, code, secret, role, privilege, database, deployment या provider setting नहीं बदली।


## 17.82 — Five Pending Feature Migrations: Business-Rule and Security Blocker Review (13 Nov 2026)

### A. Third-booking online reservation logic — sequence race / reservation gap
- Migration `20261112170000_enforce_electrician_third_booking_online_payment.sql` serializes acceptance per electrician by locking the profile row, but computes the next slot using only already completed, approved, verified-paid bookings.
- Binding requirement says the booking slot is reserved at acceptance. Two or more accepted but not-yet-completed bookings are therefore not counted in the next sequence number. Repeated acceptances before earlier jobs complete can assign multiple jobs to the same apparent sequence slot; the third-booking rule is not reliably reserved in acceptance order.
- A dedicated atomic per-electrician sequence/reservation ledger or counter is needed, with reservation on acceptance and explicit release/reconciliation on decline/cancel/failure/refund according to approved rules. Do not infer the reservation lifecycle or modify this migration until those state transitions are specified and tested.
- The current count checks completed+approved+paid and `payment_verified_at`, but the `payment_status='paid'` predicate makes the additional `NOT IN ('refunded','failed')` redundant. No real concurrency test was run.

### B. Labour-only / customer-supplied materials — legacy financial paths remain
- Migration `20261112193000_labour_only_quotes_customer_supplies_materials.sql` rejects non-zero materials in the quote RPC and stores zero for newly submitted quotes; this aligns that one entry point with the current customer-supplies rule.
- However migration `20261112220000_cash_platform_fee_due_and_online_settlement.sql` still calculates `v_total = service_charge + materials_amount`, validates `amount_paid` against that total, uses `service_charge + materials_amount` for old cash-due settlement capacity, writes `materials_amount` to payouts, includes it in electrician payable, and uses it in payout validation/reporting. This directly conflicts with the latest binding rule that materials are outside SRK booking/payment/payout/fee/refund accounting. It also contains `v_materials` in the new financial trigger.
- The same migration calculates the fee using `new.commission_rate` without enforcing the binding fixed 15% rate. Existing row values must be audited/versioned; do not silently rewrite historical payouts or legacy quote rows. A versioned labour-only snapshot/finalizer must replace these financial calculations after dependency compatibility review.
- `srk_admin_record_manual_payment` also uses service plus materials and can record UPI/bank transfer as a manual payment. This legacy path must be reconciled with the immutable bill snapshot and verified Razorpay/cash payment contracts before enabling the migration.

### C. Electrician offer-details RPC — prohibited materials and contact lifecycle exposure
- Migration `20261112230000_show_customer_payment_choice_to_assigned_electrician.sql` adds `payment_method` to the offer-details return, but also returns `materials_amount` and customer phone/address/location whenever `assigned_electrician_id = p.id`.
- It does not require booking status to remain active; therefore the same assigned electrician can continue receiving customer contact/location and materials fields after completion or cancellation unless another independent access layer blocks it. That conflicts with the binding rule to hide both parties' phone numbers after completion/cancellation and with the no-materials option/data exposure rule.
- The RPC filters profile ownership only through `p.user_id = auth.uid()` while other project RPCs also accept `auth_user_id`; verify canonical identity mapping and profile uniqueness before relying on this endpoint. Function is SECURITY DEFINER, so its explicit row/column predicates are the access boundary and require adversarial tests.
- Do not remove the required payment_method visibility after assignment; instead redesign the return contract to expose only necessary fields, no materials fields, and contact data only while the booking is in an allowed active state. Verify customer/electrician mutual contact hiding on completed/cancelled records across all APIs, history and receipts.

### D. Customer Cash-to-Online switch — partial safeguards only
- Migration `20261113090000_customer_can_explicitly_switch_cash_booking_to_online.sql` correctly limits the RPC to the authenticated customer's own unassigned, unpaid Cash booking and does not create a payment order or collect money.
- It checks status, assignment, payment state and existing Razorpay identifiers under a booking row lock. However, full integration still requires acceptance-cycle reservation, frozen bill snapshot, exact order/payment binding, idempotency, webhook/verify common finalizer and customer UI refresh/error handling tests; this migration alone does not establish the complete online payment lifecycle.

### E. Overall decision / no changes
- All five files were read-only inspected on Feature Branch. No SQL was executed against Production, no migration was applied, and no source file was changed.
- The five migrations are not ready for Production. Highest-priority blockers: acceptance-time booking-slot reservation, complete removal of materials from new financial paths while preserving historical records, fixed 15% labour-only fee basis, contact/material field minimization in SECURITY DEFINER RPC, and end-to-end payment finalizer integration.
- Before any implementation, design a versioned reservation ledger and immutable labour bill snapshot; map old quote/payout records; review all dependent triggers/RPCs/UI; then run disposable PostgreSQL 17 tests including concurrency, idempotency, rollback, RLS/ACL, post-completion contact denial and cash/online/refund reconciliation. Production remains unchanged.

Audit सीमा: केवल पाँच Feature Branch migration files का source review किया। कोई migration, SQL, database, role, secret, payment, deployment या provider setting नहीं बदली।


## 17.83 — Master Checklist का क्रमबद्ध Page-by-Page Execution और Evidence-Based Progress Protocol (13 Nov 2026)

### A. अनिवार्य कार्य-संकल्प
- Master Checklist को पहले item से अंतिम item तक निर्धारित क्रम में चलाया जाएगा। किसी item/page को केवल पढ़कर या चर्चा करके पूरा नहीं माना जाएगा।
- हर item पर यह क्रम अनिवार्य होगा: (1) मौजूदा requirement और dependencies पढ़ना, (2) वर्तमान implementation/state की जाँच, (3) requirement से gap पहचानना, (4) आवश्यक बदलाव का सुरक्षित design, (5) स्वीकृत सीमा में implementation, (6) संबंधित tests चलाना, (7) test evidence और परिणाम दर्ज करना, (8) code/config/schema/documentation जहाँ लागू हो वहाँ save/commit करना, (9) saved state दोबारा fetch करके verify करना, (10) तभी अगले item पर बढ़ना।
- एक item के सभी आवश्यक tests पास न हों तो उसे Complete नहीं माना जाएगा। उसे Blocked / In Progress / Failed में स्पष्ट कारण और अगला कदम सहित रखा जाएगा।
- कोई item बिना जाँच के skip नहीं होगा। यदि dependency, user decision, provider access, staging, खर्च या explicit approval की कमी हो तो item को Blocked दर्ज करके उस dependency का प्रभाव स्पष्ट किया जाएगा। केवल स्वतंत्र और सुरक्षित items पर ही क्रम बनाए रखते हुए आगे काम हो सकता है; blocked item को छिपाकर complete नहीं दिखाया जाएगा।
- किसी एक page/section के सभी items का evidence review होने के बाद ही उस page/section को बंद करके अगली section पर बढ़ा जाएगा। बाद में regression या नई dependency मिलने पर पुराने item को फिर खोलकर retest किया जाएगा।

### B. प्रत्येक item का अनिवार्य status और evidence record
हर checklist item के लिए कम-से-कम ये fields track होंगे:
1. Checklist ID और exact requirement.
2. Status: Not Started / In Progress / Blocked / Implemented—Testing Pending / Test Failed / Verified Complete.
3. जाँचे गए source files, database objects, UI/API/RPC/provider paths.
4. किया गया बदलाव और उसका scope; कोई बदलाव नहीं हुआ तो कारण.
5. Test case, test environment, date, result (Pass/Fail/Not Run) और उपलब्ध evidence/reference.
6. बचा हुआ जोखिम, dependency, approval या unresolved decision.
7. Save/commit reference और saved content को दोबारा fetch करके verification.
8. अगला item/अगला सुरक्षित कदम.

### C. वास्तविक प्रतिशत की गणना
- कुल denominator Master Checklist के वर्तमान version में मौजूद सभी unique, actionable checkbox items होंगे। नई checklist entry जुड़ने या duplicate/retired item को औपचारिक रूप से reconcile करने पर denominator बदलेगा और version/date दर्ज होगी।
- केवल Verified Complete status वाले items numerator में गिने जाएँगे। केवल code मौजूद होना, migration file लिखी होना, UI दिखाई देना, audit करना, documentation करना या test plan बनना अपने आप completion नहीं है।
- Completion % = (Verified Complete items ÷ कुल actionable checklist items) × 100.
- Remaining % = 100 − Completion %; साथ में शेष items की संख्या भी दिखाई जाएगी।
- In Progress, Blocked, Implemented—Testing Pending, Test Failed और Not Started items complete numerator में नहीं आएँगे।
- यदि किसी item पर user approval, live provider access या Production release gate बाकी है, तो वह final release के लिए Verified Complete नहीं होगा; यदि उसके केवल pre-production substeps पूरे हैं तो उन्हें अलग evidence सहित दर्ज किया जाएगा।
- हर progress report में numerator, denominator, percentage, verified complete count, in-progress count, blocked count, failed count, not-started count और last verified date बताया जाएगा। अनुमानित प्रतिशत को वास्तविक प्रतिशत के रूप में प्रस्तुत नहीं किया जाएगा।

### D. सुरक्षा और release boundaries
- यह protocol पहले से तय SRK ELECTRONIC Master Requirements, no-destructive-change/data-preservation rules और explicit approval gates को नहीं बदलता।
- Production DDL/migrations, live code deployment, payment/refund/transfer, provider API action, paid staging, secrets/config changes या Production deployment के लिए आवश्यक अलग explicit approval अनिवार्य रहेगा।
- Production deployment तब तक नहीं होगा जब तक सभी आवश्यक checklist items evidence सहित verify न हों, known blockers/risks का निर्णय न हो और user एक consolidated deployment को स्पष्ट अनुमति न दे।
- Test evidence में वास्तविक customer PII, OTP, secret values या payment credentials दर्ज/प्रदर्शित नहीं किए जाएँगे।

### E. वर्तमान baseline
- 13 Nov 2026 को Master Checklist sections 14–16 में 96 checkbox items गिने गए; इनमें 0 items अभी checkbox में [x] के रूप में marked हैं।
- यह केवल document checkbox baseline है; इसे वास्तविक implementation completion 0% नहीं माना जाएगा। पहले item-by-item audit से वास्तविक verified numerator स्थापित किया जाएगा।
- इस protocol को लागू करने के बाद अगला काम Master Checklist के पहले actionable item से शुरू होगा; पुराने audits केवल संबंधित item के evidence के रूप में उपयोग होंगे, और जहाँ evidence अधूरा/पुराना हो वहाँ पुनःजाँच और retest होगा।

Audit सीमा: इस section में केवल कार्य-प्रक्रिया, status model और progress calculation नियम दर्ज किए गए हैं। कोई application code, database, migration, secret, provider setting या deployment नहीं बदला गया।


## 17.84 — Master Checklist Item 14.1.1: Customer OTP Login — Initial Source Audit (13 Nov 2026)

**Checklist item (exact requirement):** “OTP login: expiry, resend cooldown/limits, wrong-attempt limits, abuse/rate limiting, secure session और logout।”

### A. क्रम और scope
- यह Master Checklist का पहला actionable checkbox है: Section 14.1, line 279 in the fetched Feature Branch document.
- इस item के भीतर OTP expiry, resend cooldown/limits, wrong-attempt limits, abuse/rate limiting, secure session और logout सभी को verify करना है। केवल OTP भेजने/सत्यापित करने का UI मौजूद होना पर्याप्त नहीं है।
- Audit Feature Branch source और उपलब्ध Supabase project metadata तक सीमित रहा। Live customer OTP भेजकर/verify करके परीक्षण नहीं किया गया।

### B. मौजूदा implementation का निरीक्षण
- `customer-login.html` (blob SHA `984d3f3f75383a6a21417eab14502fc3d73cfe6b`) में Supabase `signInWithOtp({phone})` और `verifyOtp({phone, token, type:'sms'})` मौजूद हैं। OTP input 4–8 digits स्वीकार करता है।
- Standalone login page में 60-second resend cooldown केवल browser JavaScript variable/timer (`resendAt`) से लागू है। Page reload, दूसरा device/browser या direct Auth API request इस client-side timer को bypass कर सकता है। Server-side per-phone/IP resend enforcement का प्रमाण इस page में नहीं मिला।
- Standalone login page में explicit logout/session-revocation UI/action नहीं मिला। Login success पर booking page पर redirect होता है।
- `booking.html` (blob SHA `c5568eb56251e9aa6c9a4397ddccb289ebaeb754`) में भी 60-second client-side resend cooldown है; `verifyOtp` और `getSession` इस्तेमाल होते हैं; इस page पर `auth.signOut()` logout action मौजूद है।
- Booking page का अलग customer phone input editable है। OTP-authenticated session phone और booking form phone के बीच server-side equality enforcement का प्रमाण इस source review में स्थापित नहीं हुआ। यह verified-mobile requirement से जुड़ा adjacent blocker है; इसे इसी login item के acceptance tests में शामिल किया जाएगा, पर बिना dependency review के booking flow नहीं बदला गया।
- दोनों pages `createClient` को बिना explicit auth options के initialize करते हैं। Source में custom session lifetime, inactivity timeout, token revocation policy या session lifecycle configuration नहीं दिखी। Supabase client defaults अकेले project-wide secure-session policy का प्रमाण नहीं हैं।
- Wrong OTP message generic है, लेकिन source में per-user/per-IP wrong-attempt counter, lockout/backoff या abuse telemetry नहीं है। Provider-side protection हो सकती है, पर उपलब्ध source/config evidence से उसका actual setting/limit verify नहीं हुआ।
- Existing migration `20261108120608_add_public_api_rate_limiting.sql` का rate limiter केवल `booking` और `application` endpoints स्वीकार करता है; यह OTP send/verify abuse controls का प्रमाण नहीं है। अगली migration `20261108120658_enable_rls_public_api_rate_limits.sql` केवल उस table पर RLS enable करती है।
- Supabase project metadata से project ACTIVE_HEALTHY और PostgreSQL 17.11 verify हुआ। उपलब्ध connected Supabase actions में Auth OTP expiry/rate-limit settings पढ़ने का endpoint नहीं मिला; provider dashboard settings, SMS delivery configuration और Auth logs का सत्यापन अभी बाकी है।

### C. Gap / status
**Status: In Progress — implementation और end-to-end testing बाकी।**
1. Resend cooldown अभी client-only है; server/provider enforced per-phone and per-IP limits का प्रमाण नहीं।
2. Wrong-attempt limit, progressive backoff/lockout और abuse monitoring verify नहीं हुए।
3. OTP expiry अवधि और provider-side OTP verification attempt limits verify नहीं हुए।
4. Standalone login page में explicit logout/session-revocation action नहीं।
5. Session persistence/refresh/expiry/revocation policy और cross-device logout behavior verify नहीं।
6. Booking form का editable phone authenticated verified phone से enforceably bound है या नहीं, यह verify नहीं।
7. Browser/device reload, concurrent requests, OTP replay, expired OTP, repeated wrong OTP, resend abuse, logout और protected-resource access के tests नहीं चले।

### D. सुरक्षित अगला implementation/test क्रम
- पहले Supabase Auth dashboard में OTP expiry, SMS provider limits, send/verify rate limits और session settings की read-only पुष्टि; कोई setting बदले बिना values/policy का sanitized evidence दर्ज करना।
- फिर OTP send/verify के लिए provider-enforced limits और server-side abuse controls का design; मौजूदा booking/application limiter को OTP protection मानकर reuse न करना।
- Standalone login में authenticated-session state और explicit sign-out जोड़ने का scoped Feature Branch change design करना; booking page तथा standalone page के session behavior को एकसमान करना।
- Booking submission पर verified session phone को server-side authoritative बनाना; editable form phone को trust न करना। Existing customer/legacy booking compatibility और data impact पहले map करना।
- Unit/integration tests में expiry, cooldown bypass attempts, wrong-attempt threshold, IP/phone abuse, OTP replay, session refresh/expiry, logout/revocation, direct protected API access, phone mismatch और duplicate/concurrent requests शामिल करना।
- Provider credentials/OTP या वास्तविक customer data को test evidence में न रखें। Production Auth settings, secrets या live SMS/provider configuration बिना अलग explicit approval न बदलें।

### E. Test evidence और change boundary
- Source review: Pass (static inspection only); runtime/functional/security tests: Not Run.
- Supabase Auth dashboard settings and logs: Not accessible through available connected actions; verification Blocked.
- No source file, migration, database object, Auth setting, secret, SMS provider, customer account/session, payment or deployment was changed.
- इस item को Verified Complete नहीं माना गया है। अगला कदम provider configuration read-only verification और फिर Feature Branch implementation/test plan है।

Audit सीमा: पहले checklist item का source-level inspection किया गया; कोई code या Production change नहीं किया गया।


## 17.85 — Master Checklist Item 14.1.1: Supabase Auth Logs Read-Only Follow-up (13 Nov 2026)

### जाँच का दायरा
- Production Supabase project `gnqhoaqatmoiwwhgzkgm` पर केवल unified log stream के read-only aggregate queries चलाए।
- पहले उपलब्ध log sources की सूची देखी: `auth_logs`, `auth_audit_logs` सहित Auth और अन्य service log sources उपलब्ध हैं।
- फिर Auth sources पर aggregate counts निकाले; raw event messages, phone numbers, OTP, email, tokens या user identifiers नहीं निकाले/दर्ज किए।

### Sanitized परिणाम
- Query के default recent 24-hour window में `auth_logs`: 27 events, जिनमें event message में “otp” शब्द का उल्लेख 9 बार; “rate/limit” उल्लेख 0; “invalid/expired/failed” शब्द-आधारित उल्लेख 0।
- `auth_audit_logs`: 18 events; ऊपर के शब्द-आधारित counters 0।
- Hourly aggregate में 12 Nov 2026 UTC के तीन घंटे दिखे: 09:00 पर 14 Auth events (3 OTP mentions), 10:00 पर 10 (6 OTP mentions), 14:00 पर 3 (0 OTP mentions)।
- ये केवल log text के aggregate keyword counts हैं। इनसे सफल OTP delivery, verification, expiry duration, गलत OTP attempt count, per-phone/IP limit, lockout या abuse absence साबित नहीं होता। Keyword न दिखना feature/control के न होने का निर्णायक प्रमाण नहीं है।

### Blockers यथावत
- Connected Supabase actions में Auth configuration/dashboard settings पढ़ने का action उपलब्ध नहीं मिला; OTP expiry, send/verify rate-limit settings, SMS provider configuration और Auth-specific limits अभी verify नहीं।
- कोई raw Auth event detail या personal identifier inspect/export नहीं किया।
- कोई Auth setting, provider setting, secret, database object, user/session, source code या deployment नहीं बदला।
- Checklist item 14.1.1 अभी **In Progress** है; runtime tests और configuration evidence बाकी हैं।

### अगला क्रम
1. Supabase Dashboard के Authentication settings में OTP expiry और SMS/Auth rate limits की read-only पुष्टि आवश्यक है।
2. Dashboard access उपलब्ध होने के बाद sanitized setting names/values और verification date दर्ज करें; secrets या OTP values नहीं।
3. फिर Feature Branch में missing server/provider enforcement, session/logout और verified-phone binding का scoped implementation plan तथा automated tests तैयार करें।


## 17.86 — Master Checklist Item 14.1.1: Standalone Customer Login Session Status and Logout UI Change (13 Nov 2026)

### Implementation
- Feature Branch file `customer-login.html` में existing customer OTP flow को रखते हुए session status panel जोड़ा।
- Page load पर `auth.getSession()` से वर्तमान session state पढ़ी जाती है; logged-in होने पर verified phone (यदि उपलब्ध) दिखता है और send/verify buttons disable होते हैं।
- `auth.onAuthStateChange()` listener से session state UI sync होती है।
- “सुरक्षित लॉगआउट” button `auth.signOut()` चलाता है; success पर OTP input और phone input साफ होते हैं और session panel refresh होता है।
- Logout failure पर generic error message दिखता है; raw provider error या credentials user को प्रदर्शित नहीं किए जाते।
- यह UI/session SDK integration change है; इससे server-side OTP limits, OTP expiry, Auth provider policy या सभी devices पर revocation का स्वतंत्र runtime प्रमाण नहीं मिलता।

### Save and verification
- File commit: `0b220d27c0ceea8216da97395694949e73d5c63d`
- Updated blob SHA: `a0e261ee7eda3d3378074425bb83fe2837032149`
- GitHub से file दोबारा fetch करके panel, session sync, signOut call, auth state listener और closing HTML tag verify किए।
- Embedded JavaScript को V8 `new Function` syntax compilation से जाँचा: 1 script, syntax PASS.
- Static checks: session panel 1, logout button 1, signOut call 1, auth state listener present.

### अभी बाकी परीक्षण
- Real browser/device पर existing session, page reload, successful logout, logout error, दूसरे tab में session change और protected booking API access tests नहीं चले।
- Supabase Auth server/provider expiry, resend/verify rate limits, wrong-attempt throttling और abuse protection अभी unverified हैं।
- Booking page और standalone page के cross-page session behavior तथा verified session phone बनाम booking phone binding का E2E test बाकी है।
- इसलिए checklist item 14.1.1 **In Progress** रहेगा; Verified Complete नहीं।

### Change boundary
- केवल Feature Branch `customer-login.html` बदला गया।
- Production database/Auth settings, secrets, SMS provider, customer records/sessions, payments और deployment में कोई बदलाव नहीं।


## 17.87 — Master Checklist Item 14.1.1: Feature Branch Auth Configuration and Customer OTP Entry-Point Recheck (13 Nov 2026)

### अतिरिक्त source inspection
- Feature Branch `index.html` fetch SHA `b2c2573b7338bab74ee191db054e697617f29e11`: 2,386 bytes; इसमें direct `signInWithOtp` नहीं मिला। इसलिए इस landing file को standalone customer OTP sender का प्रमाण नहीं माना।
- Feature Branch `electrician.html` fetch SHA `794dc8cac838461eafc67c1479e61bf4b0566337`: electrician का अलग OTP flow मौजूद है; यह customer checklist item 14.1.1 का substitute नहीं और electrician authentication का अलग checklist scope है।
- Feature Branch path `supabase/config.toml` fetch पर 404/NOT_FOUND मिला। इस path पर repository Auth config उपलब्ध होने का प्रमाण नहीं। इससे यह निष्कर्ष नहीं निकलता कि Supabase Production में configuration नहीं है।
- GitHub code-search में `otp_exp`, `sms_otp_exp`, `max_frequency`, `refresh_token_reuse_interval`, `otp_length`, `auth.rate_limit` के लिए कोई result नहीं मिला; code search default branch scope में है, इसलिए इसे Feature Branch या Production settings का निर्णायक प्रमाण नहीं माना गया।
- Feature Branch `customer-login.html` तथा `booking.html` में पहले से दर्ज direct Supabase OTP send/verify flows और browser-only 60-second resend timer ही वर्तमान customer evidence हैं।

### निष्कर्ष और बाधाएँ
- Repository में Supabase Auth dashboard के वास्तविक OTP expiry, SMS send frequency, verify attempt/rate limit, CAPTCHA और session policy का सत्यापित export/config नहीं मिला।
- Connected Supabase actions में Auth dashboard settings read action उपलब्ध नहीं; Production settings को अनुमान से या database internals से नहीं बदला जाएगा।
- OTP provider-level controls और वास्तविक device tests के बिना wrong-attempt throttling, expiry और abuse protection को PASS नहीं कहा जा सकता।
- अगला सुरक्षित कदम: Supabase Dashboard में Auth > Providers > Phone तथा Auth > Rate Limits / Security settings की read-only जाँच; values को बिना secret/PII के दर्ज करना। फिर उन्हीं verified values के आधार पर Feature Branch implementation और test plan बनाना।
- Item 14.1.1 अभी भी **In Progress** है।

### Change boundary
- यह केवल read-only source inspection और दस्तावेजीकरण है।
- Application code, database, Auth settings, secrets, SMS provider, user/session, payment और deployment में कोई बदलाव नहीं।


## 17.86 — Customer OTP Login: Missing-Config Runtime Guard और Source Config Search (13 नवम्बर 2026)
- Checklist item: **14.1.1** — OTP expiry, resend cooldown/limits, wrong-attempt limits, abuse/rate limiting, secure session और logout।
- Feature Branch source review में `customer-login.html` के Auth state listener को Supabase client उपलब्ध न होने पर सीधे `sb.auth.onAuthStateChange` call करते पाया गया; इससे missing configuration की स्थिति में page script runtime error दे सकता था।
- न्यूनतम Feature Branch सुधार: listener को `if(sb)` guard के अंदर रखा। OTP flow, Auth provider settings, session policy या server-side enforcement नहीं बदले।
- Commit: `4542e3dcf715a58107e352f81a533c21f1780bfa`; file blob SHA: `db3bdd7c51ddb5cfc2ddd409cd87e209851658e2`.
- Save verification: GitHub से file दोबारा fetch की; returned blob SHA commit के blob SHA से match हुआ और guard/logout code मौजूद मिला।
- Static validation: embedded JavaScript को V8 `new Function` से parse किया — PASS; null-config listener guard — PASS; logout call presence — PASS।
- Repository code search में `otp_expiry`, `sms_otp_expiry`, `max_frequency`, `refresh_token_reuse_interval`, `jwt_exp`, `otp_length` तथा Supabase Auth config terms के लिए कोई matching result नहीं मिला। यह search default branch index पर था; इससे Feature Branch या Supabase Production dashboard settings की अनुपस्थिति सिद्ध नहीं होती।
- Supabase Auth dashboard की OTP expiry, SMS send limits, verification attempt limits, session expiry/refresh और abuse controls अभी भी प्रत्यक्ष रूप से सत्यापित नहीं हैं। वास्तविक browser/device, SMS delivery, expired/replayed/wrong OTP, concurrent resend और logout/session revocation tests बाकी हैं।
- **Status: In Progress.** इस सुधार से item 14.1.1 Verified Complete नहीं होता।
- कोई Production database/Auth setting, provider secret, SMS transaction, customer account/session या deployment नहीं बदला।


## 17.87 — Booking Page OTP Flow और Server-Side Verified Phone Binding Audit (13 नवम्बर 2026)
- Checklist item: **14.1.1** — OTP expiry, resend cooldown/limits, wrong-attempt limits, abuse/rate limiting, secure session और logout।
- Feature Branch `booking.html` का OTP flow और `create-booking.js` का server endpoint inspect किया।
- `booking.html` में Supabase `signInWithOtp({ phone })`, `verifyOtp({ phone, token, type: 'sms' })`, `getSession()`, `auth.signOut()` और 60-second browser-side resend cooldown मौजूद हैं।
- महत्त्वपूर्ण सत्यापन: booking form का phone field UI में editable है, लेकिन `create-booking.js` Bearer access token को Supabase `/auth/v1/user` से verify करता है; `user.phone_confirmed_at` आवश्यक रखता है; authenticated user के verified phone को submitted booking phone से normalize करके match करता है; mismatch पर HTTP 403 देता है; booking में verified Auth user ID को `customer_user_id` के रूप में लिखता है। इसलिए इस inspected create-booking endpoint पर केवल मनचाहा दूसरा phone डालकर booking बनना source-level पर रोका गया है।
- Static validation: `booking.html` embedded JavaScript parse — PASS; OTP send/verify, session lookup, logout call और client cooldown presence — PASS; server-side Bearer verification, confirmed-phone check, normalized phone equality और user-ID binding — PASS।
- सीमा: यह source-level inspection है; deployed endpoint parity, live Auth response, actual booking rejection for mismatched phone और browser/device E2E अभी execute नहीं हुए। Client-side 60-second cooldown reload/दूसरे device पर लागू नहीं रहता; Auth provider के server-side OTP limits/expiry अभी अलग से dashboard में verify करने हैं।
- Logout handler में `signOut()` failure handling का स्पष्ट user-facing catch नहीं दिखा; इसे सुधार/functional test के लिए खुला रखा गया है। इस audit में कोई code change नहीं किया।
- **Status: In Progress.** Verified-phone binding का source-level control मिला, लेकिन item 14.1.1 के सभी sub-requirements और runtime tests पूरे नहीं हुए।
- कोई Production database/Auth setting, provider secret, SMS transaction, customer account/session या deployment नहीं बदला।


## 17.88 — Production SMS OTP Edge Function और Aggregate Logs Read-Only Audit (13 नवम्बर 2026)
- Checklist item: **14.1.1** — OTP expiry, resend cooldown/limits, wrong-attempt limits, abuse/rate limiting, secure session और logout।
- Supabase Production project `gnqhoaqatmoiwwhgzkgm` की Edge Function सूची read-only प्राप्त की। `send-sms-2factor` ACTIVE v8, `verify_jwt=false`; deployed source read-only inspect किया।
- Function Supabase Auth के signed webhook payload को `SEND_SMS_HOOK_SECRET` से verify करती है; phone/OTP format validate करती है; 2Factor `SRK_ELECTRONIC_OTP` template से SMS delivery request करती है; provider request timeout 4.2 seconds है; provider failures पर sanitized error logging है।
- Source में इस function के भीतर per-phone/per-IP OTP send quota, wrong-verification attempt counter, lockout/backoff या OTP expiry policy लागू नहीं दिखी। यह केवल इस custom delivery handler का निष्कर्ष है; Supabase Auth की अपनी provider-side limits/expiry अलग हो सकती हैं और dashboard access अभी उपलब्ध नहीं।
- Last-24-hour unified log aggregate (केवल counts/keyword counters; raw messages, phone, OTP, tokens या user IDs नहीं पढ़े):
  - `auth_logs`: 27 events; 9 OTP keyword mentions; 0 rate/limit keyword mentions; 3 error/fail/invalid keyword mentions।
  - `auth_audit_logs`: 18 events; इन चुने हुए keyword counters में 0।
  - `edge_logs`: 449 events; 5 OTP keyword mentions; 177 rate/limit keyword mentions।
  - `function_edge_logs`: 6 events; चुने हुए OTP/rate/error keyword counters 0।
- Keyword counts वास्तविक rate-limit enforcement, OTP delivery/verification success, expiry, wrong-attempt limits या abuse absence का प्रमाण नहीं हैं; edge logs में rate/limit mentions अन्य endpoints से भी हो सकते हैं।
- No Auth settings, function source, secret, database object, user/session, SMS request, or deployment changed. Function inspection and logs query read-only रहे।
- **Status: In Progress.** Dashboard configuration, end-to-end OTP expiry/replay/wrong-code/resend tests, per-phone/IP limits and logout/session lifecycle verification अभी बाकी हैं।


## 17.89 — Customer Booking Logout Error Handling Fix और Static Verification (13 नवम्बर 2026)
- Checklist item: **14.1.1** — OTP expiry, resend cooldown/limits, wrong-attempt limits, abuse/rate limiting, secure session और logout।
- Feature Branch `booking.html` में पहले `customerLogout()` सीधे `auth.signOut()` await करता था; rejection पर कोई catch/finally नहीं था। इससे उपयोगकर्ता को स्पष्ट error message नहीं मिलता और logout button busy/disabled state में फँसने का जोखिम था।
- Feature Branch में handler सुधारा: missing client/button और duplicate click guard; प्रक्रिया के दौरान button disable; signOut error को check; सफल logout के बाद session UI sync; failure पर स्पष्ट Hindi error message; finally में button enable restore।
- Updated `booking.html` blob SHA: `5edcade782121c8984f888a04368bcc266391a79`; commit: `841d372813fd69246a3cf27c0c96202608519d59`.
- Re-fetched file SHA commit output के content SHA से match हुआ।
- पूरे inline JavaScript block का V8 syntax parse PASS; logout duplicate-click guard PASS; signOut error check PASS; finally button restore PASS।
- `srk-config.js` में केवल browser-safe Supabase URL और publishable/anon key configuration है; कोई explicit `persistSession`, `autoRefreshToken`, `detectSessionInUrl` या custom storage/session lifetime setting नहीं मिली। Supabase client defaults लागू हो सकते हैं; actual project Auth policy अभी dashboard से सत्यापित नहीं।
- यह static/source-level fix है; browser/device पर real signOut, offline/network failure, token invalidation, दूसरे device पर session behavior और protected API access का runtime test अभी बाकी है।
- No Production deployment, Auth setting, secret, database object, account/session या SMS transaction changed.
- **Status: In Progress** — logout handler source fix और static parse verified; runtime/logout lifecycle और OTP expiry/abuse controls pending।


## 17.90 — Supabase Auth Configuration Access Boundary और Session Defaults Audit (13 नवम्बर 2026)
- Checklist item: **14.1.1** — OTP expiry, resend cooldown/limits, wrong-attempt limits, abuse/rate limiting, secure session और logout।
- Supabase project metadata read-only: project `gnqhoaqatmoiwwhgzkgm`, region `ap-south-1`, status `ACTIVE_HEALTHY`, PostgreSQL `17.11.0.018`।
- उपलब्ध connected Supabase actions की खोज में Auth OTP expiry, SMS rate limits, verification attempt limits, session lifetime, refresh-token reuse, या Auth provider settings पढ़ने का कोई dedicated configuration getter उपलब्ध नहीं मिला। इसलिए dashboard Auth settings को यहाँ से पढ़ना/सत्यापित करना संभव नहीं हुआ।
- Feature Branch `booking.html` और `customer-login.html` दोनों में `createClient(SUPABASE_URL, SUPABASE_ANON_KEY)` बिना explicit `persistSession`, `autoRefreshToken`, `detectSessionInUrl`, custom storage या session lifetime options के initialize होता है। `srk-config.js` केवल browser-safe URL/publishable anon key config रखता है; कोई service-role/secret key value expose या retrieve नहीं की गई।
- Explicit client options न होने का अर्थ Supabase JS defaults का उपयोग होना है; यह Production project की JWT expiry, refresh-token policy, OTP expiry या server-side session policy का प्रमाण नहीं है।
- कोई SQL Auth internals/PII query, Auth setting mutation, secret read, user/session operation, SMS request, source change या deployment नहीं किया।
- **Blocker:** Auth Dashboard read-only access आवश्यक है ताकि OTP expiry, SMS send limits, verification attempt limits और session policy के actual values प्रमाणित किए जा सकें। उसके बाद browser/device E2E tests (expired/replayed/wrong OTP, resend cooldown bypass attempts, logout success/failure, refresh and cross-device session) चाहिए।
- **Status: In Progress.** Auth settings access तथा runtime tests pending; checklist item 14.1.1 अभी Verified Complete नहीं है।


## 17.91 — Standalone Customer Login Logout Guard और OTP UI Flow Static Audit (13 नवम्बर 2026)
- Checklist item: **14.1.1**।
- Feature Branch `customer-login.html` में पहले से OTP send/verify, session lookup, auth-state listener, 60-second in-memory resend cooldown और logout handler मौजूद मिले। Logout section session होने पर ही visible होता है।
- Logout handler में missing Supabase client की स्थिति के लिए explicit guard नहीं था। इसे `!sb || busy || !logout` guard से सुरक्षित किया; duplicate clicks रोकने और button restore behavior को बरकरार रखा।
- Updated file blob SHA: `a06726bcbd3e04a833b634aeb40b77ff13f47e64`; commit: `3c0854b6ab500eb6be84af28d2c2e4a0b91744a7`.
- Re-fetch SHA commit content SHA से match हुआ; सभी inline JavaScript blocks का V8 syntax parse PASS; missing-client/duplicate-action logout guard PASS।
- दोनों OTP pages में resend cooldown केवल browser memory/timer पर आधारित है; reload/दूसरे device से bypass संभव है। यह server-side enforcement नहीं है।
- Standalone login सफल OTP verification के बाद `/booking.html#customer-login` पर redirect करता है; उसी browser origin के Supabase client storage से session साझा होने की अपेक्षा है, लेकिन cross-page/cross-device runtime verification बाकी है।
- No Production deploy, Auth setting, secret, database object, user/session, SMS request changed.
- **Status: In Progress.** Runtime browser/mobile tests, OTP expiry/verification limits, server-side abuse controls और Auth Dashboard configuration evidence pending।


## 17.92 — दोनों Customer OTP UI Flows का Cooldown/Validation Audit और E2E Test-Harness खोज (13 नवम्बर 2026)
- Checklist item: **14.1.1**।
- Feature Branch `customer-login.html` और `booking.html` का OTP send/verify source दोबारा inspect किया।
- दोनों pages में OTP send से पहले E.164 phone validation, client-side busy/duplicate-click guard, 60-second in-memory resend cooldown और 4–8 digit OTP input validation मौजूद है।
- Booking page send handler timer को clear/recreate करता है; standalone login page 60-second interval पूरा होने पर timer clear करता है। दोनों cooldown page reload/दूसरे device पर persist नहीं होते; इसलिए ये केवल UX guard हैं, authoritative abuse protection नहीं।
- दोनों pages generic OTP verification error दिखाते हैं; client source में wrong-attempt counter, lockout, progressive backoff या abuse telemetry नहीं मिली। Provider-side enforcement अभी भी unverified है।
- GitHub repository search में OTP-specific Playwright/browser test, customer login E2E suite या dedicated OTP test harness नहीं मिला। यह repository search का परिणाम है; किसी external CI secret-backed test environment की अनुपलब्धता का पूर्ण प्रमाण नहीं।
- No live OTP भेजा, no real phone/customer session इस्तेमाल किया, no test account बनाया, no Auth config/secret/database/source changed in this audit.
- **Test boundary:** Real OTP expiry, invalid/replayed token, repeated wrong attempts, resend abuse, browser reload, multi-device session, logout and protected endpoint behavior को सुरक्षित तरीके से सत्यापित करने के लिए approved test phone/account और controlled test environment चाहिए। बिना इसके real SMS/customer account पर परीक्षण नहीं किया जाएगा।
- **Status: In Progress.** Source-level validation confirmed; server-side policy and runtime E2E evidence pending।


## 17.93 — Supabase Auth के आधिकारिक OTP Rate-Limit, Expiry और Session व्यवहार का दस्तावेज़-आधारित मिलान (13 नवम्बर 2026)
- Checklist item: **14.1.1**।
- Supabase के वर्तमान आधिकारिक दस्तावेज़ों (Rate Limits, Phone Sign-in, User Sessions, Signing Out) को पढ़कर Feature Branch के दोनों customer OTP pages से मिलान किया।
- आधिकारिक docs में Auth सुरक्षा के अलग-अलग server-side controls वर्णित हैं: project-level SMS send quota (दस्तावेज़ में default 30 SMS/hour), एक ही user के लिए OTP resend window (default 60 seconds), Auth verification endpoint पर IP-based limit (दस्तावेज़ में default 30 requests/5 minutes), तथा sign-in/sign-up endpoint पर IP-based limit। Limit exceed होने पर 429 response आता है। ये Supabase Auth के built-in controls हैं; हमारे Production project पर इनके वर्तमान configured values अभी read-only तरीके से प्राप्त/verify नहीं हुए।
- Phone OTP की documented default validity 1 hour है; OTP validity configurable है। वास्तविक project setting और provider delivery/verification behavior अभी अज्ञात हैं। UI का 60-second resend timer OTP expiry timer नहीं है।
- Supabase docs CAPTCHA protection को SMS abuse/cost नियंत्रण के लिए recommend करते हैं; दोनों customer OTP pages में CAPTCHA integration source audit में नहीं मिली। Project-level CAPTCHA enablement dashboard/config access न होने से unverified है।
- Session docs के अनुसार default session sign-out/अन्य termination तक indefinite रह सकता है; default JWT expiry सामान्यतः 1 hour है और refresh tokens session को आगे जारी रखते हैं। Time-box/inactivity/single-session limits Auth settings पर निर्भर हैं और कुछ controls plan-dependent हैं। Project values अभी verify नहीं।
- Supabase JS `signOut()` का default scope `global` है। दोनों customer pages बिना scope के `signOut()` call करते हैं; इसलिए documented SDK behavior के अनुसार logout सभी active user sessions/devices को revoke करने का अनुरोध करता है, केवल current device को नहीं। Revoked access JWT अपने expiry तक valid रह सकता है; sensitive server operations में session revocation को अलग से enforce करना आवश्यक हो सकता है।
- Design implication: वर्तमान global logout को silently local-only न बदलें; multi-device logout की user expectation और server-side sensitive-operation policy को E2E tests से confirm करें।
- Supabase Management API का Auth config GET documented है, लेकिन connected account में Auth dashboard/Management API config read capability उपलब्ध नहीं मिली। कोई access token, secret, OTP या customer PII नहीं पढ़ा गया।
- No Auth config mutation, CAPTCHA/provider setting change, source code change, migration, database mutation, SMS send, customer session action or deployment.
- **Status: In Progress.** Built-in Auth protections documented but Production values, CAPTCHA, OTP expiry and session policies remain unverified; runtime tests still pending.


## 17.94 — Hosted Phone OTP दस्तावेज़ों की पुनः पुष्टि, पूर्व Expiry दावे का सुधार और Auth Config Read Access Blocker (13 नवम्बर 2026)
- Checklist item: **14.1.1**।
- इस audit में Supabase के वर्तमान Phone Sign-in, Rate Limits, CAPTCHA और Management API दस्तावेज़ों को Supabase Docs search से दोबारा देखा।
- **पिछले Section 17.93 का सुधार:** उसमें 1-hour OTP expiry को सामान्य Auth/Production guidance से phone OTP पर लागू मान लिया गया था। Hosted Phone Sign-in docs OTP validity को configurable `auth.rate_limits.otp.validity` बताती हैं और उसी page पर SMS PIN को 60 seconds में verify करने का निर्देश है; self-hosted phone guide अलग से 60-second default बताती है। इसलिए hosted Production project की वास्तविक phone OTP expiry को 1 hour कहना प्रमाणित नहीं है। इसे **Unknown / Dashboard config verification required** माना जाएगा। UI का 60-second resend cooldown, server-side OTP resend period और OTP validity तीन अलग बातें हैं।
- Current Auth Rate Limits docs: hosted project में SMS send quota का documented default 30 SMS/hour (project-wide); same-user OTP resend period default 60 seconds; IP-based sign-in/sign-up requests default 30 per 5 minutes; verification endpoint default 30 requests per 5 minutes; over-limit पर HTTP 429। ये documented defaults हैं, हमारे project के actual overrides का प्रमाण नहीं।
- Phone Sign-in docs में 6-digit SMS PIN example है; app source 4–8 digits स्वीकार करता है। Provider/project configuration और actual issued OTP length verify किए बिना इसे failure नहीं कहेंगे; test/compatibility item के रूप में रखेंगे।
- CAPTCHA docs में hCaptcha और Cloudflare Turnstile supported हैं और Auth sign-in/OTP request में CAPTCHA token pass करना आवश्यक होता है; दोनों customer OTP pages में CAPTCHA integration नहीं मिली। Project-level CAPTCHA enablement status unknown है। बिना provider/site key/secret और dashboard approval के इसे चालू नहीं किया।
- Supabase Management API में `GET /v1/projects/{ref}/config/auth` Auth config पढ़ने का documented endpoint है; `GET /v2/projects/{ref}/config` effective service configuration देता है और Alpha stage में है। उपलब्ध connected Supabase tools में इनमें से कोई Management API GET/config action नहीं है; कोई user Management API access token उपलब्ध/authorized नहीं है। इसलिए read-only settings retrieval blocker बना हुआ है।
- Read-only project metadata पुनः पुष्टि: project `gnqhoaqatmoiwwhgzkgm`, region `ap-south-1`, status `ACTIVE_HEALTHY`, PostgreSQL 17.11.0.018।
- No Auth setting change, CAPTCHA setup, provider/secret change, SMS request, customer account/session operation, database/source mutation or deployment.
- **Status: In Progress.** Current hosted Auth settings and phone OTP validity are unverified; runtime negative/abuse/session tests pending.


## 17.95 — Hosted Phone Sign-in के विरुद्ध दोनों OTP पेजों का CAPTCHA Token और OTP Length Source Audit (13 नवम्बर 2026)
- Checklist item: **14.1.1**।
- Supabase के hosted Phone Sign-in docs में OTP request के बाद 6-digit PIN का उदाहरण दिया गया है और उसे 60 seconds के भीतर verify करने का निर्देश है; उसी docs page पर OTP validity और resend period को configurable project settings बताया गया है। इसलिए project की वास्तविक validity को dashboard config के बिना निश्चित नहीं माना जाएगा।
- Feature Branch `booking.html`: `signInWithOtp({ phone })` और `verifyOtp({ phone, token, type: 'sms' })`; OTP input 4–8 digit validation पहले static audit में पुष्टि हुई। Auth request में `options.captchaToken` या कोई CAPTCHA token नहीं भेजा जाता।
- Feature Branch `customer-login.html`: वही phone OTP send/verify calls; Auth request में `options.captchaToken` या CAPTCHA token नहीं भेजा जाता।
- दोनों pages में hCaptcha/Turnstile UI/widget integration source search में नहीं मिली। यह source-level absence है; Supabase Dashboard में CAPTCHA enabled/disabled होने की पुष्टि नहीं। यदि project CAPTCHA enforce करता है, तो वर्तमान requests challenge token के बिना reject हो सकते हैं; actual runtime behavior अभी test नहीं किया।
- Hosted CAPTCHA integration जोड़ने से पहले Admin को hCaptcha/Cloudflare site key और server-side secret, allowed domains, test/staging approval तथा Supabase Auth CAPTCHA configuration उपलब्ध करानी होगी। Secret browser code में कभी नहीं रखा जाएगा। No keys/secrets requested or read.
- OTP length compatibility भी pending: Supabase Phone Sign-in example 6 digits दिखाता है, app input 4–8 स्वीकारता है; 6-digit value उस range में आती है, लेकिन actual provider-issued length और end-to-end behavior test account पर verify करना बाकी है।
- No source code, Auth setting, CAPTCHA provider, secret, database, customer account/session, SMS request or deployment changed.
- **Status: In Progress.** Source audit complete for this sub-area; Dashboard CAPTCHA state, project OTP values and approved test-phone runtime validation remain pending.


## 17.96 — Supabase Auth Rate-Limit Documentation Cross-check और Safe Test Strategy (13 नवम्बर 2026)

- Checklist item: **14.1.1** — Customer OTP expiry, resend limits, wrong-attempt limits, abuse/rate limiting, secure session और logout।
- Supabase के वर्तमान Rate Limits दस्तावेज़ (Updated 26 Oct 2026) को दोबारा cross-check किया:
  - SMS messages sent by Supabase Auth: documented default **30 SMS/hour per project**; customizable.
  - Same-user OTP resend: documented default **60 seconds** before another request is allowed; customizable.
  - Sign-up/sign-in request bucket: documented default **30 requests per 5 minutes per IP**, burst capacity up to 30; customizable.
  - OTP/token verification endpoint: documented default **30 requests per 5 minutes per IP**, burst capacity up to 30; customizable.
  - Exceeded limits return HTTP **429 Too Many Requests**.
- ये अलग-अलग buckets/scopes हैं। Client page का 60-second timer केवल UI-level control है; Supabase Auth server-side rate-limit buckets अलग से लागू होते हैं। इनमें से कोई भी documented default हमारे Production project की actual configured value का प्रमाण नहीं है।
- Phone Sign-in docs OTP validity configurable बताती हैं; Hosted project की वास्तविक auth.rate_limits.otp.validity और issued OTP length अभी Dashboard/Management API से read-only verify नहीं हुई। Documentation snippets में 6-digit PIN example है; current app 4–8 digits स्वीकारता है, इसलिए controlled test account पर compatibility verify करना बाकी है।
- CAPTCHA अभी भी recommended protection है। दोनों customer OTP pages में CAPTCHA widget/token नहीं मिला; Dashboard में CAPTCHA enforcement status unknown है। CAPTCHA को बिना approved provider, site key, secret और test/staging validation के enable या source में wire नहीं किया।
- Safe next test strategy: Supabase Auth में dedicated test phone number + fixed test OTP configure कर के SMS delivery/cost को avoid किया जा सकता है (Supabase Phone Sign-in docs में test phone numbers का supported workflow है)। यह केवल Admin-approved test account/config में किया जाना चाहिए; real customer number या live OTP पर abuse/expiry tests नहीं चलेंगे।
- Connected Supabase integration में Auth config GET/Management API read action अब भी उपलब्ध नहीं मिला; कोई Management API access token उपलब्ध/authorized नहीं। Dashboard access के बिना Production values अनुमानित नहीं की जाएँगी।
- No source code, Auth setting, CAPTCHA provider, secret, database, customer account/session, SMS request, payment या deployment changed.
- **Status: In Progress.** Documentation cross-check complete; Production Auth values, CAPTCHA state, controlled OTP negative/rate-limit tests और session lifecycle E2E अभी pending हैं।


## 17.97 — Feature Branch OTP Browser-Test Infrastructure और Test Command Read-only Audit (13 नवम्बर 2026)

- Checklist item: **14.1.1**।
- Feature Branch पर `package.json` fetch SHA `e04b0cd92ab40ad9f8cf98aca242cfeb67476b78` inspect किया। इसमें केवल package metadata और `razorpay` dependency है; कोई `scripts` section, test command, Playwright, Vitest या browser automation dependency घोषित नहीं है।
- उसी Feature Branch पर `playwright.config.js`, `playwright.config.ts`, `vitest.config.js` paths fetch किए; तीनों NOT_FOUND लौटे। `netlify.toml` में Node 20 और Netlify Functions routing मौजूद है; इससे OTP browser test runner या test command स्थापित होने का प्रमाण नहीं मिलता।
- `customer-login.html` तथा `booking.html` दोबारा fetch किए; वर्तमान blob SHA क्रमशः `a06726bcbd3e04a833b634aeb40b77ff13f47e64` और `5edcade782121c8984f888a04368bcc266391a79` हैं। दोनों में OTP send/verify flows मौजूद; CAPTCHA token integration नहीं मिली।
- यह targeted path audit है, पूरे repository tree या सभी CI workflows की exhaustive inventory नहीं। इसलिए निष्कर्ष केवल इतना है कि inspected manifest/config paths में runnable browser test harness घोषित नहीं है; अन्य directory या external CI में test setup होने की संभावना को पूर्णतः नकारा नहीं गया।
- सुरक्षित अगला engineering step: Feature Branch में isolated OTP test harness प्रस्तावित करना, जिसमें mocked Supabase Auth responses से UI validation, cooldown, duplicate-click, invalid-code errors, session UI और logout failure handling जाँचे जाएँ। वास्तविक OTP expiry, server-side limits, CAPTCHA enforcement तथा cross-device session behavior के लिए अलग approved Supabase test project/test phone और E2E credentials चाहिए; इन्हें mock tests से PASS घोषित नहीं किया जाएगा।
- इस audit में package manifest, dependencies, source code, CI workflow, Auth setting, secret, database, SMS provider, user/session या deployment में कोई बदलाव नहीं किया।
- **Status: In Progress.** Test infrastructure gap का targeted evidence दर्ज; harness implementation, automated tests, Auth dashboard values और controlled runtime tests pending।


## 17.98 — Customer OTP के लिए Node Built-in Source Regression Test Harness जोड़ा (13 नवम्बर 2026)

- Checklist item: **14.1.1**।
- Feature Branch में `tests/otp-source.test.cjs` जोड़ा। यह Node.js built-in `node:test`, `assert` और `vm` पर निर्भर है; कोई नया third-party package install नहीं किया।
- Test coverage: दोनों customer OTP pages में `signInWithOtp` और SMS `verifyOtp` calls; client cooldown/duplicate-action guards; 4–8 digit input source marker; सभी inline JavaScript blocks का syntax compilation; standalone login logout missing-client/duplicate-action/finally guard; booking logout error handling/finally presence।
- `package.json` में `test:otp` script जोड़ा: `node --test tests/otp-source.test.cjs`। Package file refetch SHA `5321cb08db24a525cf0c1394d76f7ba17ff19803` था।
- Test file save/refetch के दौरान source assertions को दोबारा inspect और regex escaping correction की; final test file blob SHA `29d92ed5a8504c8c7100bc0f41eaa0269ea12bd6` (इसके बाद final assertion simplification के लिए latest blob SHA नीचे commit में)।
- Save commits: package script `f7d030da1f0c76582334b2cb1a194aa0031e72e5`; test file initial `ac88bc2049b453b19811e0fdfcce0008004e3e46`; test assertion corrections `7bc5848bd35b3dc6a2b7637909462d7a4a5748f7` और `625844811ac33d3e78122d659ca9aa02a1d55f52`। Final test file को GitHub से re-fetch कर latest SHA verify किया गया।
- **Execution boundary:** इस session में repository checkout/local Node runtime या configured CI runner उपलब्ध नहीं था; इसलिए `npm run test:otp` execute नहीं हुआ। Test files save/refetch verified हैं, लेकिन कोई test PASS घोषित नहीं किया जा रहा। CI execution या authorized local checkout पर run आवश्यक है।
- ये source regression checks हैं, वास्तविक DOM interaction/browser E2E tests नहीं। ये Supabase Auth expiry, server-side rate limits, wrong-attempt lockout, CAPTCHA enforcement, SMS delivery या cross-device session behavior प्रमाणित नहीं करते।
- No third-party dependency install, package lock change, application OTP flow change, Auth config, secret, database, customer session, SMS request, payment or deployment changed.
- **Status: In Progress.** Harness committed; execution, test fixes if any, browser/device E2E and Production Auth config verification pending.


## 17.99 — OTP Source Test के लिए Branch-scoped GitHub Actions Workflow (13 नवम्बर 2026)

- Checklist item: **14.1.1**; क्रमबद्ध execution जारी।
- `.github/workflows/otp-source-tests.yml` जोड़ा। यह केवल `feature/platform-fee-cash-online-cycle` branch पर push और manual `workflow_dispatch` पर चलता है; Node.js 20 setup करके `npm run test:otp` चलाता है। Permissions केवल `contents: read`; कोई deployment step, secret, production environment या provider call नहीं।
- Workflow commit: `c55abd82d53f95ddf723436d4935944413ecb1f8`; file refetch SHA `e8bc8b737db2633e816337ec3c848c9a53b95e31`; workflow content re-fetch verified।
- `package.json` refetch में `test:otp = node --test tests/otp-source.test.cjs` verified। Current test file refetch SHA `55066f3983d8aa1b6238a3810669ece28edfd4d5`; source assertions और inline-script parser content inspect किया।
- Commit combined status में Vercel Preview check `success` दिखा; यह **OTP test result नहीं** है। Commit-specific workflow-run lookup ने कोई run return नहीं किया और connected GitHub Actions tools में all-branch push run listing उपलब्ध नहीं। इसलिए GitHub Actions job का actual execution/result अभी प्रमाणित नहीं है; tests को PASS नहीं माना गया।
- Test harness source-level checks हैं; browser interaction, Supabase Auth expiry/rate limits, wrong-attempt lockout, CAPTCHA, SMS delivery या session revocation का प्रमाण नहीं।
- No Production deployment, Supabase/Auth setting, DB migration, secret, SMS/provider request, payment, customer account/session or production configuration changed. Workflow is scoped to Feature Branch and does not deploy.
- **Status: In Progress.** Workflow saved/refetched; CI test execution/result and real browser/Auth verification pending.


## 17.100 — OTP CI Execution Status Recheck और Vercel Preview Rate-limit Blocker (13 नवम्बर 2026)

- Checklist item: **14.1.1**।
- GitHub combined commit status पुनः जाँचा:
  - Workflow commit `c55abd82d53f95ddf723436d4935944413ecb1f8`: Vercel `success` (यह Preview build है; OTP test नहीं)।
  - Documentation commit `33c288284c81bfc37eaa613e7cadceefd1b28ef0`: Vercel `failure`, target URL पर `upgradeToPro=build-rate-limit` संकेत। यह Vercel Preview/build-rate-limit समस्या है, OTP source test failure नहीं।
  - Test assertion commit `625844811ac33d3e78122d659ca9aa02a1d55f52`: Vercel `failure`, वही build-rate-limit संकेत।
- GitHub Actions commit-run lookup में इस Feature Branch push workflow का run record नहीं मिला; उपलब्ध GitHub connector में all push runs/check-runs enumerate या workflow dispatch करने का action नहीं है। Public Actions page fetch भी सफल नहीं हुआ। इसलिए test command के actual output का कोई प्रमाण नहीं।
- Vercel `failure` को OTP test failure नहीं माना जाएगा; Vercel `success` को OTP test pass नहीं माना जाएगा।
- कोई नया retry, workflow dispatch, deployment, paid plan upgrade या Production action नहीं किया।
- अगला आवश्यक verification: GitHub Actions UI में `Customer OTP source regression tests` workflow का run खोलकर `Run OTP source regression tests` step का output देखना, या authorized Node 20 checkout में `npm run test:otp` चलाकर पूरा output सुरक्षित रखना। यदि failure हो तो पहले failing assertion/source inspect और fix; फिर rerun।
- **Status: In Progress.** No tests marked PASS; no checklist item closed.


## 17.101 — Customer OTP Source Regression Checks का Direct Re-run (13 नवम्बर 2026)

- Checklist item: **14.1.1**।
- Feature Branch से वर्तमान `customer-login.html` और `booking.html` पुनः fetch किए; blob SHA क्रमशः `a06726bcbd3e04a833b634aeb40b77ff13f47e64` और `5edcade782121c8984f888a04368bcc266391a79`।
- दोनों फाइलों पर workflow test harness के अनुरूप 10 direct source checks चलाए:
  1. दोनों पेजों में OTP send और SMS verify source markers — PASS (2 checks)।
  2. दोनों में client cooldown और busy/duplicate-action markers — PASS (2)।
  3. दोनों में bounded numeric OTP input markers — PASS (2)।
  4. दोनों पेजों के सभी inline JavaScript blocks V8 `new Function` parse — PASS (2)।
  5. Standalone login logout guard/signOut/finally — PASS (1)।
  6. Booking logout signOut error handling/finally — PASS (1)।
- कुल **10/10 direct source checks PASS**। ये Feature Branch के fetched source पर किए गए स्वतंत्र static checks हैं; इन्होंने GitHub Actions runner पर `npm run test:otp` चलने का प्रमाण नहीं दिया, और OTP delivery, expiry, Auth server-side rate limits, CAPTCHA, wrong-attempt lockout, browser/device session या वास्तविक logout revocation का runtime प्रमाण नहीं हैं।
- GitHub Actions run record अभी भी connector से उपलब्ध नहीं; Vercel Preview status OTP CI result नहीं है।
- कोई application source, package, workflow, Auth/DB setting, secret, SMS/provider request, customer session, payment या deployment नहीं बदला।
- **Status: In Progress.** Static source checks 10/10 PASS; CI command result और आवश्यक runtime/security verification लंबित।


## 17.102 — Customer OTP Source Regression Tests: GitHub Actions Run सफल (13 नवम्बर 2026)

- Checklist item: **14.1.1**।
- उपयोगकर्ता ने GitHub Actions के नवीनतम otp-source-tests run का परिणाम साझा किया: **succeeded**, लगभग 10 seconds में पूरा।
- Run summary में **1 warning और 1 notice** दिखे। साझा किए गए output में इनके annotation details नहीं थे; इसलिए warning/notice को अनदेखा या harmless घोषित नहीं किया गया। अगला निरीक्षण: Annotations खोलकर दोनों के वास्तविक संदेश और संबंधित step/line जाँचना।
- यह पहली बार है जब GitHub Actions workflow का वास्तविक successful run उपयोगकर्ता द्वारा UI से पुष्ट हुआ। अतः Section 17.99–17.101 में दर्ज CI execution/result pending blocker अब केवल test-run execution के लिए बंद माना जाएगा; workflow source regression job सफल है।
- सफल CI run केवल tests/otp-source.test.cjs के source-level assertions और inline JavaScript syntax checks को प्रमाणित करता है। यह वास्तविक browser UX, OTP SMS delivery/expiry, Supabase Auth के configured server-side rate limits, wrong-attempt lockout, CAPTCHA enforcement, वास्तविक session lifecycle/cross-device logout या production endpoint behavior प्रमाणित नहीं करता।
- **Checklist item 14.1.1 अभी In Progress रहेगा**, Verified Complete नहीं: Auth dashboard settings/expiry/limits/CAPTCHA/session policy का प्रत्यक्ष प्रमाण और स्वीकृत test environment में आवश्यक runtime/E2E परीक्षण शेष हैं।
- इस update में कोई application source, test workflow, package, Supabase Auth/DB setting, secret, SMS/provider request, customer account/session, payment या deployment नहीं बदला।


## 17.103 — Customer OTP Source Regression Tests: पाँच GitHub Actions Runs की UI पुष्टि (13 नवम्बर 2026)

- Checklist item: **14.1.1**। उपयोगकर्ता ने GitHub Actions के `Customer OTP source regression tests` workflow की Runs सूची साझा की; उसमें कुल **5 workflow runs** दिखे और पाँचों का status **completed successfully** था।
- Run सूची का रिकॉर्ड:
  - **Run #5** — commit `959b083`, message `docs: record successful OTP source regression workflow run`, branch `feature/platform-fee-cash-online-cycle`, लगभग 10 seconds।
  - **Run #4** — commit `e9c62e1`, message `docs: record direct OTP source regression checks`, लगभग 14 seconds।
  - **Run #3** — commit `9c52d18`, message `docs: record OTP CI execution status and preview blocker`, लगभग 11 seconds।
  - **Run #2** — commit `33c2882`, message `docs: record OTP source test CI workflow`, लगभग 11 seconds।
  - **Run #1** — commit `c55abd8`, message `ci: run customer OTP source regression tests`; साझा सूची में duration स्पष्ट नहीं था।
- इस UI evidence से workflow के पाँचों दर्ज runs सफल होने की पुष्टि होती है। ये पाँच अलग-अलग workflow executions हैं; इन्हें पाँच अलग test suites या पाँच अलग application features की verification नहीं माना जाएगा।
- पहले साझा latest run summary में **1 warning और 1 notice** भी दिखे थे। वर्तमान Runs सूची केवल success status और duration दिखाती है; warning/notice के वास्तविक annotation संदेश यहाँ उपलब्ध नहीं हैं। इसलिए उनका निरीक्षण अभी बाकी है।
- CI सफलता केवल मौजूदा `tests/otp-source.test.cjs` source regression suite के सफल workflow execution को दर्शाती है। यह वास्तविक OTP SMS delivery/expiry, Supabase Auth Production settings, server-side abuse limits, CAPTCHA, wrong-attempt lockout, browser/device session lifecycle या live logout revocation का प्रमाण नहीं है।
- **14.1.1 का status: In Progress** रहेगा; पाँच सफल CI runs के बावजूद Auth configuration और स्वीकृत runtime/E2E verification बाकी हैं।
- इस evidence update में कोई application source, workflow, package, Supabase Auth/DB setting, secret, SMS/provider request, customer account/session, payment या deployment नहीं बदला।


## 17.104 — Customer OTP Source Regression Tests: छठे GitHub Actions Run की UI पुष्टि (13 नवम्बर 2026)

- Checklist item: **14.1.1**। उपयोगकर्ता ने workflow Runs सूची का नया snapshot साझा किया, जिसमें `Customer OTP source regression tests` के **6 workflow runs** दिखे; सभी छह का status **completed successfully** है।
- नया **Run #6**: commit `02bc05b`, message `docs: record five successful customer OTP workflow runs`, branch `feature/platform-fee-cash-online-cycle`, लगभग **15 seconds**।
- पहले के Runs #1–#5 भी उसी सूची में successful दिखे; उनके विवरण Section 17.103 में दर्ज हैं।
- यह छठा सफल workflow execution है; इसे अलग test suite या OTP के छह अलग security/runtime scenarios की पुष्टि नहीं माना जाएगा।
- Run #5 के summary में पहले दिखे **1 warning और 1 notice** के वास्तविक annotation messages अभी भी उपलब्ध नहीं हैं। इस नए Runs-list snapshot में annotation details नहीं हैं; उन्हें देखकर ही कारण/गंभीरता तय होगी।
- CI success केवल workflow के configured source regression suite के सफल execution को दर्शाती है; वास्तविक SMS delivery/OTP expiry, Production Auth configuration, server-side abuse limits, CAPTCHA, wrong-attempt lockout, browser/device session lifecycle या live logout revocation का प्रमाण नहीं है।
- **14.1.1 status: In Progress**। Auth configuration और स्वीकृत runtime/E2E verification लंबित हैं।
- इस रिकॉर्ड update में application source, workflow, package, Supabase Auth/DB setting, secret, SMS/provider request, customer account/session, payment या deployment नहीं बदला।


## 17.105 — Customer OTP CI Annotations का समाधान: Node 24 Actions और स्थिर Ubuntu Runner (13 Nov 2026)

- उपयोगकर्ता ने Run #5 (commit `959b083`) के वास्तविक annotations साझा किए:
  1. Warning: `actions/checkout@v4` और `actions/setup-node@v4` Node.js 20 runtime घोषित करते हैं; GitHub runner उन्हें Node.js 24 पर force कर रहा है। यह उस run में test failure नहीं था, लेकिन पुराने action majors का deprecation warning है।
  2. Notice: `ubuntu-latest` label का Ubuntu 26 पर migration 19 Oct 2026 से शुरू होना था। यह environment drift का notice है, test failure नहीं।
- Feature Branch workflow `.github/workflows/otp-source-tests.yml` को सुरक्षित CI-only बदलाव के साथ अपडेट किया:
  - `actions/checkout@v4` → `@v5` (Node 24 runtime)
  - `actions/setup-node@v4` → `@v5` (Node 24 runtime)
  - test runtime `node-version: 20` → `24`
  - moving `ubuntu-latest` → pinned `ubuntu-24.04`, ताकि Ubuntu image migration अपने-आप इस workflow को न बदले।
- आधिकारिक action release notes के अनुसार checkout v5 और setup-node v5 Node 24 runtime पर हैं और runner v2.327.1+ चाहते हैं; GitHub-hosted runner पर workflow execution अगला प्रमाण होगा।
- Workflow commit: `926ce5cdc08798d24dee89c13735b64157e29102`.
- Updated workflow blob SHA: `d407198b9c27f731850e7766f634c8cd6bb226ef`; GitHub से दोबारा fetch करके समान SHA सत्यापित किया गया।
- इस workflow commit पर नया CI run trigger हुआ है; उसका परिणाम अभी इस रिकॉर्ड के समय सत्यापित नहीं है। अगला कदम नए run का success और annotations जाँचना है।
- यह बदलाव केवल Feature Branch CI workflow में है। कोई application runtime source, Supabase/Auth setting, database/migration, secret, SMS/provider, payment, customer session या Production deployment नहीं बदला।
- Checklist item 14.1.1 अभी In Progress; CI warning remediation commit saved and refetch-verified, but new run result and real OTP/Auth E2E checks pending.


## 17.106 — OTP CI Runtime Warning Remediation के बाद GitHub Actions Run सफल (13 Nov 2026)

- उपयोगकर्ता द्वारा साझा GitHub Actions स्क्रीन के अनुसार workflow `Customer OTP source regression tests`, run `#9`, commit `3240147`, branch `feature/platform-fee-cash-online-cycle`, push-triggered, Status `Success`, कुल अवधि 12 सेकंड।
- यह Run #9 उसी documentation commit `3240147` पर चला जिसमें Section 17.105 दर्ज हुआ; इससे workflow remediation commit `926ce5c` और उसके बाद documentation commit पर workflow का सफल execution प्रमाणित है।
- Workflow config में Node.js 24, `actions/checkout@v5`, `actions/setup-node@v5`, और pinned `ubuntu-24.04` पहले से save/refetch-verified हैं।
- उपलब्ध स्क्रीन में केवल overall Success और duration दिखते हैं; नया Run #9 का Annotations panel नहीं दिखता। इसलिए पुरानी Node 20 warning और Ubuntu migration notice के हटने की पुष्टि अलग से नहीं की गई है।
- Source regression CI run सफल है; इससे वास्तविक SMS OTP delivery/expiry, Supabase Auth project limits, CAPTCHA enforcement, wrong-attempt lockout, browser/device session behavior या production logout revocation प्रमाणित नहीं होते।
- कोई नया application source, Auth setting, database/migration, secret, SMS/provider, payment या Production deployment बदलाव इस run के रिकॉर्ड के साथ नहीं किया गया।
- Checklist item 14.1.1 अभी In Progress; CI runtime remediation execution success verified from user-provided run summary, annotations and real OTP/Auth E2E checks pending.


## 17.107 — Customer App के पाँच मुख्य मेनू (Checklist 14.1.2) का प्रारंभिक Source Audit (13 Nov 2026)

- क्रमबद्ध Master Checklist के अगले item **14.1.2 — Home, My Bookings, Payments, Help & Support, My Profile** का निरीक्षण शुरू किया गया।
- Feature Branch source ref: `feature/platform-fee-cash-online-cycle`।
- `index.html` SHA: `b2c2573b7338bab74ee191db054e697617f29e11`। इसमें SRK branding/tagline और चार promotional service cards हैं; कोई customer navigation, login action या पाँच-मेनू customer panel नहीं है।
- `booking.html` SHA: `5edcade782121c8984f888a04368bcc266391a79`। इसमें embedded OTP login, एक “मेरी बुकिंग” section, booking form और payment UI है; पाँच मुख्य menu navigation/sections नहीं हैं। “Help & Support” और “My Profile” के customer menu/functional sections नहीं मिले।
- `customer-login.html` SHA: `a06726bcbd3e04a833b634aeb40b77ff13f47e64`। यह standalone OTP login/session/logout screen है; पाँच-मेनू customer app नहीं।
- Feature Branch root directory inspection में अलग customer dashboard/app shell file नहीं मिली। उपलब्ध customer-facing entry files इस audit में `index.html`, `customer-login.html`, और `booking.html` हैं।
- **Gap:** पाँच-मेनू customer app अभी इस source snapshot में implement नहीं है। Existing booking/payment UI को बिना architecture review के menu में wrap करना पर्याप्त नहीं होगा; पहले प्रत्येक menu का data source, authenticated access, ownership/RLS, empty/loading/error/offline states, navigation और mobile accessibility map करना होगा। Existing booking/payment logic को तोड़ने वाला जल्दबाज़ी का UI rewrite नहीं किया जाएगा।
- **Next safe steps:** customer-facing page/API/RPC inventory; प्रत्येक menu के लिए existing backend/data coverage map; फिर minimal-risk app-shell implementation plan और menu-by-menu source tests। कोई live customer data या account/session access नहीं किया गया।
- इस audit में कोई application source, database/migration, Auth setting, secret, provider, SMS, payment या deployment नहीं बदला।
- **Status: In Progress** — source audit ने पाँच-मेनू panel gap की पुष्टि की; implementation और menu-specific tests बाकी हैं। वास्तविक end-to-end tests उपयोगकर्ता के निर्देशानुसार सभी Master Checklist कार्यों के बाद एक batch में होंगे।


## 17.108 — उपयोगकर्ता निर्देश: Source/Implementation Verification और अंतिम वास्तविक परीक्षण की अलग-अलग स्थिति (13 Nov 2026)

- उपयोगकर्ता ने निर्देश दिया कि OTP item को उपलब्ध Source/CI evidence के आधार पर Verified दिखाया जाए और उसके सामने स्पष्ट लिखा जाए कि **वास्तविक परीक्षण बाकी** है। इसी प्रकार Master Checklist के सभी **96 मूल actionable items** पर अंतिम वास्तविक परीक्षण की स्थिति अलग से **बाकी** रखी जाएगी।
- अब से हर मूल checklist item के लिए दो स्वतंत्र स्थिति-रेखाएँ रखी जाएँगी:
  1. **Implementation / Source / Static / CI Verification:** item की वास्तविक code/config/schema/documentation स्थिति और उपलब्ध automated evidence के अनुसार item-by-item जाँची जाएगी। केवल जितना प्रमाणित है उतना ही Verified दर्ज होगा; implementation अधूरा हो तो उसे Verified नहीं कहा जाएगा।
  2. **Final Real-World Test:** सभी 96 items की implementation/source verification प्रक्रिया पूरी होने के बाद उपयोगकर्ता के निर्देशानुसार एक consolidated batch में वास्तविक browser/device, provider, SMS/OTP, payment, role/security और end-to-end tests किए जाएँगे। तब तक हर item के सामने **वास्तविक परीक्षण: बाकी** रहेगा।
- **OTP item 14.1.1:** Source/CI review को उपलब्ध सीमित evidence के लिए Verified दिखाया गया है: OTP send/verify source markers, दोनों pages के client cooldown/duplicate-action markers, OTP input source checks, inline JavaScript syntax checks, logout guard/error handling और user-shared GitHub Actions Run #9 Success। यह full OTP feature या Production security configuration का प्रमाण नहीं है।
- OTP के लिए अंतिम वास्तविक परीक्षण अभी बाकी है। Supabase Production OTP expiry, वास्तविक resend/wrong-attempt limits, CAPTCHA enforcement, abuse/lockout behavior, session expiry/revocation, cross-device behavior और SMS delivery अभी प्रत्यक्ष रूप से सत्यापित नहीं। जहाँ implementation/configuration gap मिलेगा, उसे source verification में भी स्पष्ट रूप से Open/Blocked रखा जाएगा; केवल वास्तविक परीक्षण को टालने के कारण किसी अधूरे implementation को Verified नहीं कहा जाएगा।
- **14.1.2 और शेष 95 items:** हर item को क्रम से inspect → gap analysis → implementation → source/static/automated tests → save/commit → re-fetch verification के बाद ही Source/Implementation Verified किया जाएगा। कोई item बिना evidence के bulk में Verified नहीं होगा।
- Progress reporting में अब अलग-अलग आँकड़े दिए जाएँगे: (a) Source/Implementation Verified / 96, (b) In Progress / Blocked / Not Started, और (c) Final Real-World Tests Pending / 96। इस तरह Source verification को वास्तविक E2E completion समझने की गलती नहीं होगी।
- इस स्थिति-विभाजन से मूल 96 actionable checklist items की गणना नहीं बदलेगी; किसी item को duplicate करके denominator नहीं बढ़ाया जाएगा।
- इस documentation update से कोई application source, database/migration, Auth setting, secret, provider, SMS, payment, customer account/session या deployment नहीं बदला।


## 17.109 — Customer पाँच-मेनू App: Backend/Data/RLS Coverage Audit (Checklist 14.1.2, 13 Nov 2026)

- क्रम के अनुसार 14.1.2 का दूसरा चरण पूरा: Feature Branch source inventory के साथ Supabase Production schema metadata और RLS policy metadata का केवल read-only निरीक्षण किया गया। कोई customer row, phone, address, payment record या account/session data नहीं पढ़ा गया।
- Branch head निरीक्षण के समय: `83687959bdfdfaff1f968fba03d81e1d5afea99f`; recursive Git tree में 76 entries मिलीं। Customer-specific dashboard/menu shell, customer profile page, Help/Support chat page या customer payments-history page नहीं मिला। Customer entry source अब भी `index.html`, `booking.html`, `customer-login.html` है।
- Production public/private table inventory में `service_bookings`, `srk_booking_complaints`, `srk_booking_complaint_events`, `srk_booking_refund_requests`, payment/refund tables, wallet tables और electrician/admin tables मौजूद हैं। Customer profile नाम की अलग public table नहीं मिली। Auth user identity/phone को profile feature समझकर सीधे expose नहीं किया जाएगा।
- **Home:** `index.html` में branding और promotional service cards मौजूद हैं। Authenticated customer home, personalized booking summary, status cards या customer navigation नहीं।
- **My Bookings:** `service_bookings.customer_user_id` मौजूद है। Production में RLS enabled है और authenticated SELECT policy `is_srk_admin() OR auth.uid() = customer_user_id` तक सीमित है। यह own-booking read का आधार देता है; अभी customer menu, सुरक्षित booking detail/history UX, pagination, loading/empty/error state और सभी lifecycle states की UI नहीं है। Guest bookings जिनका `customer_user_id` NULL है, verified customer account की history में स्वतः नहीं जुड़तीं; account-linking/migration rule अलग से तय करना होगा।
- **Payments:** `service_bookings` में payment method/status, Razorpay order/payment IDs, amount_paid और verified timestamp fields हैं; customer-authenticated create-order/verify-payment source मौजूद है। लेकिन payments history/receipt menu नहीं। Source inspection में `create-order.js` और `verify-payment.js` अभी `service_charge + materials_amount` से कुल राशि निकालते हैं और legacy quotation match enforce करते हैं। यह user-approved labour-only billing rule के साथ conflict है; 14.1.2 के Payment screen को इस legacy total पर बनाना सुरक्षित नहीं। Webhook/finalizer race और durable inbox के पुराने audit gaps भी unresolved हैं। पहले payment-cycle checklist items ठीक और source-verified होने चाहिए।
- **Help & Support:** Production में complaint और complaint-event tables मौजूद हैं, पर इन दोनों tables पर RLS enabled होने के बावजूद कोई policy नहीं मिली। Customer-facing support chat/messages/attachments/replies का schema/source इस inventory में नहीं मिला। Refund request table भी मौजूद है लेकिन इस audit में उस पर कोई RLS policy नहीं मिली। इन tables को browser से सीधे query/insert/update करना सुरक्षित नहीं; authenticated ownership-scoped server/RPC design, staff/admin access, attachment storage policies और event/audit rules के बिना Support UI सक्रिय नहीं की जाएगी।
- **My Profile:** Customer profile table/page/API नहीं मिला। `auth.users` को browser से पढ़ने का shortcut नहीं लिया जाएगा। सुरक्षित profile contract तय करना होगा—कौन-से fields editable/read-only होंगे, phone change पर OTP re-verification, address preference बनाम booking-specific address, और account deletion/data retention की नीति।
- **Wallet caution:** `srk_wallet_accounts` और `srk_wallet_ledger` पर owner-read RLS policies हैं, लेकिन wallet owner model user_id आधारित है और मौजूदा project context में यह electrician earnings/wallet है; इसे customer payment history या customer wallet मानकर reuse नहीं किया जाएगा।
- **Safe architecture decision:** पाँच-मेनू app shell को customer OTP session से gate किया जाएगा; customer booking queries केवल `customer_user_id = auth.uid()` RLS scope में रहेंगी। Payments केवल immutable verified labour-bill/payment records से feed होंगी; Support के लिए ownership-scoped server/RPC endpoints और सुरक्षित attachment rules पहले; Profile के लिए explicit customer-profile contract पहले। प्रत्येक section में accessible mobile navigation, loading/empty/error/offline/retry states, logout/session-expiry handling और no-store/private caching लागू करना होगा। Existing booking creation/payment code को menu work के नाम पर copy या rewrite नहीं किया जाएगा।
- **Evidence and limits:** Production table/column inventory और `pg_policies` metadata read-only SELECT से देखे गए। No customer data read. No SQL DDL, RLS policy, RPC, Auth config, source app, payment, provider, SMS, secret or deployment changed. Static source files inspected: `index.html`, `booking.html`, `customer-login.html`, `create-booking.js`, `create-order.js`, `verify-payment.js`, `razorpay-webhook.js`, customer booking/RLS migrations and complaint/contact migrations.
- **Status: In Progress / Blocked on safe backend contracts** — पाँच-menu implementation अभी शुरू नहीं की गई क्योंकि Support/Refund tables पर customer RLS policies अनुपस्थित हैं, Customer Profile contract नहीं है, और Payment source में labour-only billing conflict है। इन dependencies को संबंधित checklist items में क्रम से resolve/verify किए बिना menu feature को functional बताना गलत होगा। अगला कदम 14.1.2 के scope में menu-by-menu data contract और UI shell का non-destructive implementation plan तैयार करना है; implementation तभी जब निर्भर सुरक्षा/payment items के क्रम और अनुमोदित design के अनुरूप हो।
- **अंतिम वास्तविक परीक्षण: बाकी** — 14.1.2 सहित सभी मूल 96 items के लिए उपयोगकर्ता द्वारा तय consolidated real-world test batch तक pending।


## 17.110 — Customer Five-Menu Data Contract और Safe Build Sequence (14.1.2, 13 Nov 2026)

यह section 17.109 के read-only audit पर आधारित design record है। यह implementation या test-pass का दावा नहीं है।

### साझा App Shell Contract
- Entry: OTP-verified Supabase Auth session; session restore के बाद ही private customer data load हो। Session missing/expired/revoked हो तो private screens साफ़ करके login पर लौटें; केवल UI hide करना authorization नहीं माना जाएगा।
- Navigation labels स्थिर: **Home / My Bookings / Payments / Help & Support / My Profile**। Mobile पर accessible bottom navigation, desktop पर समान स्पष्ट navigation; current route/selected state screen-reader accessible हो।
- हर screen के लिए loading, first-use empty, filtered-empty, recoverable error/retry, offline/stale-data और session-expired states अलग हों। Private API responses पर `Cache-Control: no-store`; service worker/localStorage में phone, address, booking/payment/support/profile private payload persist नहीं।
- सभी requests bearer session के साथ server पर verify हों। Client द्वारा भेजा गया customer ID/phone ownership का प्रमाण नहीं; ownership केवल verified `auth.uid()` और server-side predicates/RLS से।
- Hindi-first copy, responsive layout, keyboard/focus visibility, touch target, contrast, semantic headings/forms, reduced-motion और low-bandwidth loading लागू हों।

### Menu 1 — Home
- उद्देश्य: customer का संक्षिप्त परिचय, नया booking CTA, active booking status/next action और recent booking/payment summary।
- Data contract: केवल verified current customer की aggregate summary; backend user identity token से निकाले, client-supplied ID न ले। Summary में address/phone का अनावश्यक पुनर्प्रदर्शन न हो।
- Dependency: booking lifecycle/status machine और timer/payment state definitions स्थिर होने तक status labels को अनुमान से map न करें।
- Tests: no-session denial, दूसरे customer की booking से summary leak न हो, empty/new account, multiple active/terminal bookings, delayed/stale response, offline/retry।

### Menu 2 — My Bookings
- Read path: `service_bookings` पर authenticated own-row SELECT; मौजूदा Production RLS predicate `auth.uid() = customer_user_id` लागू रहे। Admin bypass को customer client path में कभी न जोड़ें।
- सूची/विवरण: booking reference, created date, service/category, safe status timeline, approved estimate/final labour bill के अलग labels, payment state और allowed next action। Phone/address/location केवल current lifecycle और पहले से approved privacy rules के अनुरूप; completion/cancellation के बाद दूसरे पक्ष का phone UI/API/receipt/history में नहीं।
- Guest legacy rows: `customer_user_id IS NULL` rows को phone match के आधार पर auto-claim नहीं करना। Verified OTP proof, collision/duplicate-number review, immutable audit और explicit account-linking flow के लिए अलग security design चाहिए।
- Tests: own/other user RLS negative tests, guest orphan handling, pagination/order stability, status transition coverage, contact visibility before/after acceptance and close, no-store/cache and logout cleanup।

### Menu 3 — Payments
- Source of truth: केवल server-verified payment events और immutable/versioned labour-only bill snapshots; client-calculated amount, legacy quote total, `materials_amount`, electrician wallet या unverified manual entry को customer payment history न मानें।
- UI: labour amount, 15% Platform Fee केवल जहाँ customer bill contract में लागू हो उसका सही disclosure, payment method, pending/captured/failed/refunded/disputed states, receipt/reference और refund status अलग-अलग। कोई material line item नहीं।
- Hard dependency: current `create-order.js`/`verify-payment.js` में legacy `service_charge + materials_amount` logic और webhook/finalizer race के कारण अभी customer Payments menu implement/activate नहीं करना। पहले labour-only immutable bill, common atomic finalizer, durable webhook inbox/reconciliation और historical compatibility अलग checklist sequence में ठीक व source-tested हों।
- Tests: amount tamper, wrong customer/order, duplicate/out-of-order webhook, capture vs verify race, retry/idempotency, partial/full refund, cash-vs-online no-switch, historical legacy row display without recalculation।

### Menu 4 — Help & Support
- Browser direct table access: अभी निषिद्ध। `srk_booking_complaints`, `srk_booking_complaint_events` और refund-request table पर RLS enabled है लेकिन current audit में policies नहीं मिलीं।
- API contract (future): authenticated create/list/detail/reply endpoints; server token से customer ID; ticket हमेशा उसी customer की booking से bind; category/description validation, rate limit, idempotency, safe status transitions, append-only actor/timestamp events; Admin/staff role और assignment checks server-side।
- Attachments: private Storage bucket, strict MIME/size limits, malware/content scanning strategy, random object keys, per-ticket ownership authorization, short-lived signed access; public bucket नहीं। Admin reply/thread और customer-visible/internal note का स्पष्ट separation।
- Refund request Support ticket से अलग financial action रहे; customer केवल request submit/status देखे, refund initiate/approve/amount modify न कर सके।
- Tests: cross-customer ticket/attachment denial, forged booking ID, unauthorized staff, duplicate submit/reply, upload abuse, private attachment URL expiry, audit completeness।

### Menu 5 — My Profile
- Minimal profile contract अलग तय/बनाना होगा; अभी कोई customer profile table/page/API प्रमाणित नहीं। प्रस्तावित fields: `user_id` (Auth UID, unique), `display_name`, optional `email`, optional `preferred_language`, timestamps। Phone Auth से read-only verified identity; phone change केवल अलग OTP re-verification flow।
- Saved addresses अलग customer-owned child records हों; booking के समय address/location immutable booking snapshot रहे ताकि पुरानी booking बदल न जाए। Profile address बदलने से historical booking address overwrite न हो।
- Profile screen में केवल अनुमत fields; account deletion/export/data-retention/legal retention flow अलग policy/approval के बाद। कोई Auth admin credential या `auth.users` direct browser access नहीं।
- Tests: own profile CRUD only, other UID denial, phone not editable, re-verification, duplicate/invalid address, historical booking snapshot unchanged, session revoke/logout cleanup।

### Build gates और क्रम
1. पहले dependency checklist items में customer ownership, state-machine, labour-only billing/payment finalizer, Support/RLS/Storage/staff access और account/profile data-retention decisions source-verified हों।
2. फिर additive migration/API contracts को Feature Branch में implement करें; Production पर DDL/RLS/function/config apply नहीं।
3. Isolated disposable/staging DB उपलब्ध और migration lineage reconciled होने पर migration + RLS/JWT negative tests चलें। Paid resource बिना लागत बताए/अनुमति लिए नहीं।
4. इसके बाद पाँच-menu shell और प्रत्येक screen अलग-अलग जोड़ें; existing booking form/payment flow को duplicate न करें।
5. हर source change पर unit/static tests, security negative tests, accessibility checks, build/CI, saved commit और refetch/hash verification अनिवार्य।
6. सभी 96 items के लिए अंतिम वास्तविक device/provider/SMS/payment/E2E test batch उपयोगकर्ता के निर्देशानुसार अंत में ही होगा; अभी **96/96 वास्तविक परीक्षण बाकी**।

### इस चरण का निष्कर्ष
- Data contracts और safe build gates लिखित रूप में दर्ज; यह design/source documentation है, functional menu implementation नहीं।
- कोई app source, Production schema/RLS, RPC, Auth config, customer data, payment/provider, secret या deployment नहीं बदला।
- 14.1.2 **In Progress / Dependency-Blocked** रहेगा; इसे Verified नहीं किया गया। अगला क्रम checklist में आगे के items का निरीक्षण है; dependency items के क्रम पर पहुँचने पर उन्हें resolve/test किए बिना customer menu को सक्रिय नहीं करेंगे।
- अंतिम वास्तविक परीक्षण: **बाकी**।


## 17.111 — Customer Booking Form और Create-Booking API Audit (Checklist 14.1.3, 13 Nov 2026)

- क्रम के अनुसार अगला मूल actionable item **14.1.3 — Booking form: verified mobile (editable नहीं), नाम, address, map pin, PIN/district/state, work description, category और 1–8 घंटे** का source और schema audit किया गया। यह read-only निरीक्षण है।
- Feature Branch source refs:
  - `booking.html` SHA `5edcade782121c8984f888a04368bcc266391a79`
  - `create-booking.js` SHA `8e7106eb75bb1b9ee7373ab15210eb2a05e14749`
  - `netlify/functions/create-booking.js` SHA `72b3618b0cf1ffcd0537992cec224d846886ffdc` (root handler adapter)
  - `20261108121115_add_customer_account_booking_access.sql` SHA `9877bb969b380d306567322eb110d81eaaa4c115`
  - `20261108233500_restrict_public_form_inserts.sql` SHA `a840a00a17866caa5dc841d6eb596c035198ce43`
- **मौजूदा UI में मौजूद:** नाम, फोन, राज्य dropdown, जिला, 6-digit PIN, पता, optional GPS lat/lng + Google Maps preview/link, service type dropdown, locality, preferred date/time, work details और Cash/Online payment selection। Form submit पर button अस्थायी रूप से disable होता है और API request भेजी जाती है।
- **Verified mobile gap:** Form का `#phone` editable text input है। Submit handler OTP session access token भेजता है और server-side `verifyCustomerSession()` Auth user का `phone_confirmed_at` तथा normalized phone match जाँचता है; इसलिए गलत/दूसरा phone server पर reject होता है। फिर भी user requirement के अनुसार UI में verified Auth phone read-only/disabled होना चाहिए और session phone से populate होना चाहिए। अभी UI यह guarantee नहीं देती; client-side editable field को backend check का विकल्प नहीं मानेंगे।
- **Category gap:** UI में generic service names हैं (घर की वायरिंग, इलेक्ट्रिकल रिपेयर, लाइट/फैन फिटिंग, होम रिपेयरिंग, अन्य), लेकिन approved electrician skill/category selection और server-side allowed category mapping इस form/API में नहीं दिखे। Service type और electrician tier (Assistant ₹899, Skilled ₹1,199, Expert ₹1,599, Premium Specialist ₹1,999 प्रति 8-hour reference) अलग concepts हैं; इनके बीच mapping बिना approval/source evidence के अनुमान से नहीं बनाई जाएगी।
- **1–8 घंटे gap:** Form में duration field नहीं है; API भी duration स्वीकार/validate/persist नहीं करती। इसे भविष्य में customer का expected work-duration input मानकर अलग store/label करना होगा—यह server-authoritative continuous timer की cap, auto-stop या final bill duration नहीं होगा। Actual bill बाद में वास्तविक server start/stop minutes से बनेगा; 8-hour amount reference-rate है।
- **Address/map:** State/district/PIN/address required हैं; GPS coordinates optional हैं और API lat/lng pair/range validation करती है। अभी PIN से authoritative district/state match verification इस API में नहीं है; free-text district mismatch संभव है। GPS permission denied होने पर address route उपलब्ध है, लेकिन customer को manual map-pin selection/confirmation का स्पष्ट flow नहीं मिला। Existing GPS button current device location लेता है, map pin drag/drop नहीं।
- **Work details:** Optional textarea है; server अधिकतम 2,000 chars तक clean करता है। Required/minimum useful detail और unsafe HTML/content rendering policy को अलग validate/test करना होगा।
- **Backend protections observed:** POST only; request size cap 16 KiB; server-side rate-limit RPC (limit 5 per hashed client IP); bearer token को Supabase Auth `/auth/v1/user` से verify; confirmed phone must match; server derives `customer_user_id`; location coordinate bounds checked; public/anon/authenticated direct INSERT revoked and service_role-only insert migration present; `Cache-Control: no-store`. Rate-limit IP header absent or RPC failure returns fail-closed 503. Booking insert uses service role and database trigger creates offers; API only reads offer result.
- **Important unresolved risks:** rate-limit scope is IP-based, not per verified customer/device; duplicate-submit UI guard is only transient button disable and no explicit idempotency key is visible; service type is free-form allowlist not server-enforced; state/district/PIN authoritative validation absent; preferred date/time business-window/past-time rules not checked; date/time timezone policy not explicit; locality is merged into `work_details` rather than separately stored; payment method is accepted as arbitrary cleaned string with default Cash and no explicit allowlist in this handler; client-supplied `quoted_amount` is parsed and stored though UI currently sends null. Do not expand scope to payment redesign here; preserve the separate labour-only/payment audit dependencies.
- **Schema metadata (read-only Production SELECT):** `service_bookings` has customer_name, phone, state, district, pincode, address, service_type, preferred_date/time, work_details, payment_method, quoted_amount, customer_user_id and optional coordinates. No dedicated expected-duration, service-category/tier, normalized locality or authoritative PIN directory table was found in the queried table inventory. The `services` table exposes id, service_name, description, is_active only. No rows/customer data were queried.
- **Safe implementation plan:** (1) use authenticated session phone as the only phone source and show read-only; server verification remains authoritative; (2) define separate service taxonomy and approved electrician category/skill mapping; (3) add expected-duration field 1–8 with explicit “अनुमानित समय, अंतिम बिल वास्तविक मिनट से” disclosure and never feed it as timer cap; (4) implement authoritative PIN/state/district lookup and mismatch warning/review without overwriting typed address; (5) add explicit map-pin confirmation/optional GPS fallback; (6) server allowlists and validates all enumerated fields, date/time policy, work details, payment method and idempotency; (7) additive schema/API change only after migration-lineage and isolated-test gates, with historical rows preserved.
- **Status: In Progress / Blocked on approved category taxonomy, duration semantics and authoritative PIN source** — gaps confirmed; no source/schema change made in this audit. The existing API does enforce Auth phone match but UI is not read-only, so 14.1.3 is not Verified.
- **Tests/evidence:** Static source inspection and read-only schema metadata SELECT only. No automated test was run in this pass; no live booking submitted; no customer rows read; no migration, RLS, RPC, Auth setting, secret, provider, payment, SMS or deployment changed.
- **अंतिम वास्तविक परीक्षण: बाकी** — इस item सहित मूल 96 items के consolidated real-world test batch तक pending।


## 17.112 — Welcome Screen Hero Photo और Homepage Banner (13 Nov 2026)

- User ने स्पष्ट रूप से अतिरिक्त visual requirement दी: Welcome screen पर एक शानदार electrician photograph हो; फोटो/hero के ऊपर electrician की service specialties लिखी हों; उसके नीचे ठीक **“Welcome to SRK ELECTRONIC”** लिखा हो। इसके बाद homepage पर अलग से एक आकर्षक, professional banner भी हो।
- यह original 96 actionable checklist items के denominator को नहीं बढ़ाता; इसे existing customer entry/homepage visual-design scope के supplementary acceptance criteria के रूप में track किया जाएगा।
- **Welcome screen composition:** full-width/high-quality electrician-at-work hero photograph; electrician सुरक्षित तरीके से electrical installation/inspection करता दिखे, clean professional uniform/PPE और tidy residential/commercial setting; image पर readable dark/contrast overlay; ऊपर/ऊपरी हिस्से में वास्तविक सेवाओं के अनुरूप specialties — **“Wiring • Electrical Repair • Light & Fan Fitting”** (Hindi-first equivalent: **“वायरिंग • इलेक्ट्रिकल रिपेयर • लाइट और पंखे की फिटिंग”**); नीचे स्पष्ट brand welcome line **“Welcome to SRK ELECTRONIC”**। Text वास्तविक HTML overlay में होगा, image pixels में baked-in नहीं, ताकि spelling, accessibility, responsive sizing और localization ठीक रहें।
- **Homepage banner:** Welcome screen से अलग wide responsive banner; premium electrician/service visual, brand-consistent navy/blue/gold palette, readable headline and concise service proposition, clear booking CTA; mobile crop/focal point और desktop layout दोनों के लिए अलग responsive behavior; image compression, lazy loading जहाँ उचित हो, descriptive alt text, contrast/accessibility और fallback background अनिवार्य।
- कोई अप्रमाणित “certified”, “government approved”, “No.1” या अन्य गुणवत्ता/लाइसेंस दावा नहीं जोड़ा जाएगा। फोटो में unsafe electrical handling, खुला live wire contact या बिना सुरक्षा उपकरण काम दिखाना स्वीकार्य नहीं।
- **वर्तमान स्थिति:** Feature Branch `index.html` SHA `b2c2573b7338bab74ee191db054e697617f29e11` एक centered logo/tagline और service promo cards दिखाता है; अलग electrician hero photo, specified Welcome line और dedicated homepage banner मौजूद नहीं हैं। `customer-login.html` भी plain OTP card है। यह requirement अभी design/documentation scope में है; UI या assets बदले नहीं गए।
- **Acceptance tests (बाद के visual implementation चरण में):** first-load welcome composition; headline placement/wording; image focal point; homepage banner अलग और स्पष्ट; narrow mobile/tablet/desktop responsive crops; Hindi/English text legibility; keyboard/assistive alt text; image load failure fallback; image performance; booking CTA route; no layout shift/overflow.
- **सुरक्षित अगला चरण:** दोनों image assets को अलग-अलग responsive compositions के रूप में तैयार करना, text HTML में रखना, Feature Branch में optimized assets जोड़ना और entry/home page में integrate करना। Existing login/booking/auth behavior को न बदलें। Source verification के बाद भी consolidated real-world visual/device test pending रहेगा।
- **स्थिति: Requirement Captured / Implementation Pending.** No source/assets/database/Auth/payment/provider/SMS/secret/deployment changes in this update.
- **अंतिम वास्तविक परीक्षण: बाकी** — मूल 96 items के consolidated real-world test batch तक pending।

### 17.113 — Founder Welcome Screen Design Approval and Photo Clarity Gate (2026-11-13)
- User approved the proposed premium navy-blue/gold welcome-screen composition and requested it be used on the SRK ELECTRONIC welcome screen.
- The founder image must be the user's previously saved original reference photo (single-person garden portrait, black button-up shirt and black trousers), not an AI-generated lookalike or a substituted electrician stock photo.
- Photo acceptance gate: face and eyes clearly in focus; natural facial detail retained; no blur, pixelation, excessive smoothing, face distortion, artificial replacement, or text overlay on the face; preserve a high-resolution source and use optimized responsive derivatives without visibly degrading clarity.
- Keep the agreed hierarchy: top headline “भरोसे की पहचान, बेहतरीन सेवा का वादा!”, supporting Hindi brand statement, founder photo as the dominant central visual, then “Welcome to SRK ELECTRONIC”, “आपकी सुरक्षा, हमारी जिम्मेदारी।” and “आपकी जरूरत, हमारी सर्विस — भरोसे के साथ।”.
- The welcome screen design approval does not approve unrelated homepage-banner copy/assets or production deployment. Homepage banner remains a separate component under Section 17.112.
- Implementation status remains Pending until the actual saved photo asset is integrated into the Feature Branch welcome screen and source/static/mobile visual checks pass. The earlier generated mockup is a design reference only and must not replace the user's original photo.
- Final real-world device/browser visual verification remains pending under the 96-item dual-track policy. No Production deployment is authorized.

- अतिरिक्त फोटो-फ्रेमिंग स्वीकृति (2026-11-13): वेलकम स्क्रीन पर फाउंडर फोटो सिर से कमर तक (waist-up), सीधी/सामने की मुद्रा में लगानी है; पैरों या पूरा शरीर दिखाने की जरूरत नहीं। चेहरा और कंधे पूरे रहें, सिर के ऊपर पर्याप्त breathing space हो, कमर के आसपास स्वाभाविक crop हो। मोबाइल/डेस्कटॉप पर responsive crop में चेहरा न कटे और फोटो स्पष्ट रहे। उपयोगकर्ता ने अभी दिखाए गए waist-up crop को वेलकम स्क्रीन के लिए चुना है। इसे approved visual reference मानें; वेबसाइट integration और source verification अभी बाकी हैं।

## 17.114 — Booking Form में OTP-सत्यापित मोबाइल को Read-only करना (Checklist 14.1.3, 13 Nov 2026)

- 14.1.3 के source audit में मिली स्पष्ट UI कमी का सीमित Feature Branch सुधार किया गया: पहले booking form का मोबाइल input editable था, जबकि backend पहले से Auth session के confirmed phone से submitted phone match करता था।
- booking.html में field label अब “OTP से सत्यापित मोबाइल नंबर” है; input readonly है, manual editing हटाई गई है, और helper text बताता है कि booking में OTP login वाला ही नंबर इस्तेमाल होगा।
- syncCustomerSession() अब authenticated session के session.user.phone से digits निकालकर booking phone field भरता है; भारतीय +91 वाले 12-digit नंबर को UI में 10-digit local display में दिखाता है। Session न होने पर field साफ़ और read-only रहती है। Submit payload इसी field का value भेजता है; server-side Auth verification authoritative बना रहता है।
- Feature Branch source commit: fb3a910b2f951b4a5687d128f9a1d0a0a55a10b0; booking.html blob SHA: 411c226d5835299c6a15142dcfa1c6639739e050. Update के बाद file refetch किया गया और blob SHA match सत्यापित हुआ।
- Scope सीमा: यह केवल UI phone-editability gap का source change है। OTP session restore, non-India phone formatting, logged-out submit behavior, accessibility, mobile browser behavior और full API integration की automated/runtime/device testing अभी नहीं हुई। Category taxonomy, 1–8 hour expected-duration semantics और authoritative PIN lookup अभी blocked हैं; इसलिए 14.1.3 पूर्ण Verified नहीं है।
- No Production source/schema/RLS/RPC/Auth config, customer data, payment/provider, SMS, secrets or deployment changed. No real OTP or live booking test was performed.
- स्थिति: Partial Source Fix Saved / Verification Pending — केवल read-back and SHA verification passed; static/runtime test suite और remaining sub-requirements बाकी हैं।
- अंतिम वास्तविक परीक्षण: बाकी — मूल 96 items के consolidated real-world test batch तक pending।

## 17.115 — Master Checklist Item 14.1.4: PIN / District Validation — Source and Data-Dependency Audit (13 Nov 2026)

- क्रम के अनुसार 14.1.3 के बाद अगला मूल actionable item 14.1.4 PIN/district validation का audit किया गया। Feature Branch recursive tree में 66 files देखीं; PIN/postal/district नाम वाली कोई authoritative directory, CSV/JSON/GeoJSON dataset या lookup service implementation नहीं मिली। केवल map-pin/location-support migrations मिलीं; वे GPS coordinates/map display support हैं, PIN-to-state/district authority नहीं।
- पहले के read-only Production schema inventory audit में भी कोई authoritative PIN directory table/service नहीं मिला था। मौजूदा booking form PIN, district और state अलग-अलग लेता है; server-side verified PIN→district/state match का प्रमाण उपलब्ध नहीं। इसलिए typed district/state को authoritative मानना या गलत mismatch को स्वतः overwrite करना सुरक्षित नहीं।
- Safe acceptance design: approved authoritative PIN source and update/licensing policy तय हो; lookup returns canonical state/district and source/version; customer-entered address/locality remains unchanged; mismatch gets clear warning and controlled review path; lookup timeout/offline must fail safely without falsely marking PIN verified; server revalidates on submit and records source/version. Existing historical booking addresses must not be rewritten.
- **स्थिति: Blocked / Dependency Not Available** — approved authoritative PIN dataset/provider and operational fallback policy required. No guessed PIN mappings, no free-text district auto-correction, and no third-party API dependency added.
- No source code, database schema/RLS/RPC, customer records, Auth, secrets, SMS, payment/provider or deployment changed. This was a source/tree and prior schema-evidence audit only; no live PIN lookup test.
- 14.1.3 OTP-phone UI change remains a partial source fix only; full static/runtime/mobile/API tests, category taxonomy, expected-duration persistence and remaining acceptance checks are still pending. No item was marked fully Verified from this audit.
- Final real-world tests remain **96/96 Pending** under Section 17.108. Production deployment remains unauthorized.

## 17.116 — Master Checklist Item 14.1.5: Category, Rate, Duration और Estimate Clarity Audit (13 Nov 2026)

- क्रम के अनुसार 14.1.4 के बाद अगला मूल actionable item 14.1.5 — Category, rate, duration और estimate का स्पष्ट विवरण; estimate और final actual-minute bill अलग — inspect किया गया।
- Feature Branch feature/platform-fee-cash-online-cycle पर booking.html (वर्तमान blob SHA 411c226d5835299c6a15142dcfa1c6639739e050), electrician.html (blob SHA 794dc8cac838461eafc67c1479e61bf4b0566337), create-booking.js (8e7106eb75bb1b9ee7373ab15210eb2a05e14749) और netlify/functions/create-booking.js (72b3618b0cf1ffcd0537992cec224d846886ffdc) inspect किए गए।
- Customer booking UI gap: booking.html में केवल generic service choices हैं—घर की वायरिंग, इलेक्ट्रिकल रिपेयर, लाइट/फैन फिटिंग, होम रिपेयरिंग और अन्य। Customer-selected electrician category (Electrical Assistant / Skilled Electrician / Expert Electrician / Premium Electrical Specialist) का selector नहीं है। 1–8 घंटे expected-duration field भी नहीं है। Booking form में category rate, selected-duration estimate, estimate calculation/disclosure या final actual-minute bill से स्पष्ट तुलना नहीं दिखाई जाती।
- Electrician portal conflict: electrician.html अभी assigned booking पर inspection/quote workflow दिखाता है; inspection/quote_rejected status पर electrician को “सर्विस / मेहनताना शुल्क (₹)” input और “ग्राहक को कोटेशन भेजें” action मिलता है। submitQuote() srk_submit_booking_quote RPC को p_service_charge, p_materials_amount और note भेजता है। यह नई approved requirement से सीधा conflict है: electrician final labour amount quote/set नहीं करेगा; final bill server-authoritative timer, approved category rate और actual billable minutes से निकलेगा। इस पुराने quote path को हटाना/बदलना payment, booking status, refund और historical compatibility audit के बिना सुरक्षित नहीं।
- Backend contract gap: create-booking.js request में quoted_amount स्वीकार करके positive finite numeric value के रूप में validate करता है और booking insert में persist करता है; यह code अपने-आप selected category, rate-card version, expected duration, estimate basis या immutable final-bill snapshot स्थापित नहीं करता। Netlify wrapper file में category/rate/duration-specific matching logic के नाम वाले markers नहीं मिले। Existing database inventory from Section 17.111/17.114 में service_bookings पर dedicated expected-duration, approved-category/rate-card reference या normalized estimate snapshot fields नहीं मिले; services table केवल id, service_name, description, is_active expose करती है।
- Approved commercial inputs (requirements evidence): Section 2 में customer-facing 8-hour rates दर्ज हैं: Electrical Assistant ₹899, Skilled Electrician ₹1,199, Expert Electrician ₹1,599, Premium Electrical Specialist ₹1,999. Section 2A में electrician net payable 8-hour reference amounts ₹764.15, ₹1,019.15, ₹1,359.15, ₹1,699.15 दर्ज हैं। Same village/city rates; actual-minute proportional calculation; no hour-round-up; integer paise arithmetic. लेकिन electrician की approved category को verified skills/documents/practical assessment से जोड़ने वाला canonical source/schema/API इस audit में प्रमाणित नहीं हुआ।
- निर्णय/गैप: Rate values उपलब्ध हैं, पर estimate semantics अभी निर्णायक नहीं—1–8 घंटे के चयन पर दिखने वाली रकम estimate है, booking cap है या कोई advance, यह स्पष्ट owner decision बाकी है। चुनी अवधि से अधिक काम होने पर customer approval/notification UX, paise rounding convention, pause/resume/idle-time policy और category/rate-card effective-date/version rules भी final नहीं। इनको अनुमान से implement करना गलत बिल या गलत category matching पैदा कर सकता है।
- Safe design gate: (1) customer category selector केवल approved four-tier taxonomy पर; (2) customer चुनी अवधि 1–8 घंटे को स्पष्ट “अनुमानित अवधि” label; (3) pre-booking estimate = approved category 8-hour rate × selected estimated minutes ÷ 480, केवल तभी जब owner estimate-vs-cap policy final करे; (4) estimate और final bill अलग UI objects/labels; (5) final amount केवल server timer events + approved category/rate-card version + actual billable minutes से; (6) integer paise calculation/rounding rule owner approval के बाद; (7) electrician requested category और Admin-approved category अलग; (8) पुराना quote workflow हटाने से पहले status/RPC/payment/refund/history migration impact map; (9) server-side category allowlist, eligibility, rate lookup, idempotency और immutable bill snapshot; (10) historical quote/booking records को rewrite या delete नहीं करना।
- Status: In Progress / Blocked on estimate policy, rounding and verified category assignment contract. इस audit में कोई application source, RPC, migration, schema, RLS, customer/electrician data, Auth, secret, SMS/provider, payment या deployment नहीं बदला। Existing electrician quote flow को conflict के रूप में दर्ज किया; उसे चालू रखते हुए नए model को complete बताना स्वीकार्य नहीं।
- Evidence limits: इस pass में source inspection/read-only prior schema inventory का उपयोग हुआ; कोई automated unit/integration test नहीं चलाया गया, कोई live booking/quote/timer/payment नहीं किया गया। 14.1.3 के phone readonly fix का SHA/read-back प्रमाण अलग Section 17.114 में है; उससे 14.1.5 पूरा नहीं होता।
- अंतिम वास्तविक परीक्षण: बाकी — मूल 96 actionable items के लिए consolidated real-world test batch तक 96/96 pending। Production deployment अभी अधिकृत नहीं है。

## 17.117 — Master Checklist Item 14.1.6: Submit Confirmation, Terms/Fee Disclosure और Duplicate-Submit Protection Audit (13 Nov 2026)

- क्रम के अनुसार 14.1.5 के बाद 14.1.6 inspect किया गया। Feature Branch booking.html SHA 411c226d5835299c6a15142dcfa1c6639739e050 और create-booking.js SHA 8e7106eb75bb1b9ee7373ab15210eb2a05e14749 के submit path की line-level जाँच की गई।
- **Confirmation UX gap:** Form submit handler सीधे POST /api/create-booking करता है; submit से पहले customer को नाम, address, selected service, date/time, payment method और लागू terms/fees का consolidated review/confirmation step नहीं दिखता। Success पर booking ID alert में आता है; यह pre-submit confirmation का विकल्प नहीं है।
- **Terms/fee disclosure gap:** Form copy कहती है कि electrician पहले काम देखेगा और मेहनताना बताएगा, लेकिन यह पुराने quote-first flow से जुड़ा है और वर्तमान approved timer/category-rate model से conflict करता है। Customer consent के लिए cancellation stage fees (₹0 before departure, ₹49 en route, ₹99 arrived), payment/Platform Fee policy, estimate-vs-final-bill distinction, customer-supplied materials-only rule और actual-minute billing को स्पष्ट, versioned terms के रूप में submit से पहले स्वीकार कराने का implementation इस pass में नहीं मिला। ग्राहक से materials स्वयं लाने की सूचना मौजूद है, पर पूर्ण terms/fee disclosure और recorded consent नहीं।
- **Duplicate-submit protection:** UI submit button request शुरू होते ही disabled होता है और finally में re-enable होता है—यह सामान्य UI double-click को सीमित करता है। लेकिन explicit in-flight guard/state token, client-generated idempotency key, server-side idempotency persistence/unique constraint या retry-safe replay response source में प्रमाणित नहीं हुआ। create-booking.js में IP-hash rate limit 5 requests है; यह duplicate idempotency नहीं है और वैध retry/दो अलग bookings में अंतर नहीं करती। इसलिए अलग request/retry से duplicate booking बनने का जोखिम पूरी तरह बंद नहीं माना जा सकता।
- **Backend validation scope:** create-booking.js required fields, 10-digit phone/Auth match, PIN format, date/time syntax, GPS coordinate pair/bounds और quoted_amount numeric range validate करता है; पर इस item के लिए consent version/accepted timestamp, terms acceptance, booking idempotency key और server-side duplicate replay contract दिखाई नहीं देता। Payment method के लिए cleaned string/default है; strict allowlist enforcement इस source segment में नहीं दिखी।
- **Safe implementation gate:** (1) customer review screen पर booking summary और selected payment method; (2) approved final pricing model के अनुसार estimate/actual-minute bill explanation; (3) cancellation fees और materials/customer responsibility सहित versioned Hindi terms; (4) explicit unticked consent checkbox और server-recorded terms_version/accepted_at/customer_user_id; (5) client-generated idempotency key bound to authenticated user + canonical request hash; (6) server-side unique/idempotent create operation returning same booking on safe retry; (7) duplicate payload mismatch returns conflict; (8) strict payment-method allowlist; (9) accessible loading/disabled/error/retry state; (10) no success claim until server returns persisted booking ID. Terms text and fee applicability must be consistent with approved policy and related cancellation/payment checklist items before activation.
- **Status: In Progress / Blocked on approved current booking/pricing flow and consent/idempotency contract.** Existing UI button-disable is a partial interaction safeguard only; it does not prove robust server idempotency. No source, schema, migration, RPC, RLS, customer data, Auth, secrets, SMS, payment/provider or deployment changed in this audit.
- **Evidence limits:** Static source inspection only; no automated unit/integration test, browser double-click/retry simulation, live booking, consent capture or payment was performed. The booking API's rate-limit guard is not counted as idempotency verification.
- **अंतिम वास्तविक परीक्षण: बाकी** — मूल 96 actionable items के consolidated real-world test batch तक 96/96 pending। Production deployment अभी अधिकृत नहीं है。


## 17.116 — 14.1.7 Booking Timeline Source Audit (2026-11-13)

### Scope and evidence
- Feature Branch `feature/platform-fee-cash-online-cycle` पर `booking.html` (blob SHA `411c226d5835299c6a15142dcfa1c6639739e050`) और `index.html` (blob SHA `b2c2573b7338bab74ee191db054e697617f29e11`) जाँचे। Customer booking list में status को raw `row.status` text के रूप में दिखाया जाता है; कोई ordered visual timeline/stepper, per-stage timestamp या booking event history render नहीं होती।
- `supabase/migrations/20261109_electrician_inspection_quotes_and_service_only_commission.sql` (SHA `014699d3190e45aacde4022ac7e7fa9ca4fec006`) में status constraint के states `new, confirmed, assigned, inspection, awaiting_quote_approval, quote_approved, quote_rejected, in_progress, completed, cancelled` हैं। उसी migration में electrician-side transitions inspection → quote approval → in_progress → completed हैं।
- Customer contact lookup migration `20261109103038_customer_electrician_direct_call_contacts.sql` (SHA `512eabab313721c7bc28d2034f950a0e748c4221`) direct-call contact केवल assigned/inspection/awaiting_quote_approval/quote_approved/in_progress states में लौटाती है; यह timeline/history API नहीं है।
- Payment status, quote status और booking status अलग-अलग fields हैं; इन्हें एक ही linear status में मिलाने से गलत timeline बन सकती है। Current source में यात्रा/en-route, arrived, customer start approval, completion review/dispute, payment-due और closed के लिए प्रमाणित unified event stream/timestamps नहीं मिले।
- Repository code search में `srk_booking_events` या `status_history` नाम का event/history source नहीं मिला; यह code-search finding है, पूरे repository के हर सम्भव नाम के न होने का पूर्ण प्रमाण नहीं।

### Gaps / required design
1. Customer-facing timeline को केवल server-authoritative state/event data से बनाना; client-side अनुमानित timestamps नहीं।
2. मौजूदा status values को approved lifecycle में map करने से पहले legacy/quote-era states और current timer-based lifecycle का versioned transition map बनाना।
3. हर transition के लिए immutable event ID, booking ID, event type, actor role/ID, server timestamp, idempotency key और safe display metadata; privileged/private fields अलग रखना।
4. Pending/offers/accepted/en route/arrived/start approval/in progress/completion review/payment/closed stages तभी दिखें जब संबंधित backend event/state वास्तव में मौजूद हो। Rejected/expired/cancelled/disputed paths के स्पष्ट terminal/branch states हों।
5. यात्रा/ETA/location events को timeline से अलग privacy-guarded stream मानना; tracking stop conditions और customer/electrician visibility rules लागू हों।
6. Customer ownership, electrician assignment, Admin access, RLS/RPC authorization, event immutability, duplicate/concurrent transition handling तथा event ordering के automated tests अनिवार्य।
7. Existing historical bookings के लिए synthetic timestamps/events न गढ़ें; पुरानी स्थिति को “इतिहास उपलब्ध नहीं” के रूप में स्पष्ट दिखाएँ।

### Status and restrictions
- **14.1.7: In Progress / Dependency-Blocked — Source Audit दर्ज; implementation अभी नहीं।** Unified authoritative event contract, legacy-to-current state mapping और secure read API के बिना UI timeline बनाना भ्रामक होगा।
- Source/implementation verification इस item के लिए अभी **Verified नहीं**। इस audit से कोई production schema, RLS, RPC, customer data, Auth, provider, payment, secret या deployment नहीं बदला।
- Final Real-World Test: इस item के लिए **बाकी**; user के dual-track निर्देश के अनुसार कुल 96/96 वास्तविक परीक्षण अंतिम consolidated batch तक Pending रहेंगे।


### 14.1.7 Feature Branch implementation update (13-11-2026)
- नई migration `20261114070000_customer_safe_idempotent_booking_timeline.sql` में append-only work-event table के लिए `actor_role` और unique transaction-scoped `idempotency_key` जोड़े गए। Event trigger अब customer/electrician/Admin/system actor role निर्धारित करता है और duplicate same-transaction event insert को unique key से रोकता है।
- पुराने event rows के लिए actor role `unknown` रखा गया; कोई synthetic booking history या अनुमानित timestamp नहीं बनाया गया।
- Customer-safe SECURITY DEFINER RPC `srk_customer_get_my_booking_work_timeline()` जोड़ा गया। यह केवल `auth.uid()` के customer-owned bookings के event rows लौटाता है; actor IDs और private `details` expose नहीं करता। PUBLIC/anon execute revoke और authenticated grant लागू हैं।
- `booking.html` अब पुराने `srk_get_customer_booking_timeline()` के बजाय नए RPC से वास्तविक event type, server `occurred_at` और सीमित actor-role label दिखाता है। Event text escaped है; unknown event के लिए केवल generic recorded-change label है। जिन historical bookings में event नहीं है, वहाँ “इतिहास उपलब्ध नहीं” दिखता है; timeline stages गढ़े नहीं जाते।
- `tests/work-timeline.test.cjs` में 7 source regression checks जोड़े; npm script और source CI workflow में शामिल। नवीनतम source CI Run 43432175734 PASS है।
- **सीमाएँ:** legacy status-to-event mapping अभी पूर्ण नहीं; event idempotency key transaction-scoped है (external client request key नहीं); customer timeline API/UI source-level है, electrician timeline API अभी नहीं; वास्तविक RLS/RPC/trigger, event ordering under concurrent writes और pgTAP runtime अभी execute नहीं हुए। इसलिए इस item को Verified/Complete नहीं माना जाएगा।
- Isolated Supabase workflow में नई migration शामिल है, पर workflow अभी dispatch नहीं किया गया। Production migration, Main merge, deployment, payment/payout या customer data परिवर्तन नहीं किए गए। Final consolidated mobile/Desktop QA अभी बाकी है।

### Status and restrictions — updated
- **14.1.7: In Progress — Feature Branch source implementation added; database/runtime verification Pending.** Unified event table, customer-safe read RPC, actor role, transaction-scoped idempotency key और customer timeline UI जोड़े गए हैं। Legacy transition mapping, electrician-facing timeline, runtime authorization/concurrency verification और pgTAP execution शेष हैं।
- Source regression verification: **PASS** (Run 43432175734); database/pgTAP verification: **Pending**; final real-world test: **बाकी**।


## 17.117 — 14.1.8 Accepted Booking Phone Visibility Source Audit (2026-11-13)

### Scope and evidence
- `booking.html` (Feature Branch blob SHA `411c226d5835299c6a15142dcfa1c6639739e050`) customer booking list में `srk_get_customer_call_contacts()` के परिणाम को booking ID से जोड़ती है। Contact मिलने पर phone/call link दिखता है; completed booking पर UI स्पष्ट रूप से नंबर छिपाती है।
- `supabase/migrations/20261109103038_customer_electrician_direct_call_contacts.sql` (SHA `512eabab313721c7bc28d2034f950a0e748c4221`) शुरुआती SECURITY DEFINER public function बनाती है और केवल authenticated customer के अपने assigned booking के लिए contact लौटाती है।
- बाद की migration `supabase/migrations/20261109103143_move_customer_call_contact_lookup_to_private.sql` (SHA `863567c8a7f2557bc0d484f8ceb2b272d144d47d`) implementation को private schema में ले जाती है; public wrapper SECURITY INVOKER है; PUBLIC/anon execute revoke और authenticated-only execute grant दर्ज हैं।
- Private implementation केवल `assigned, inspection, awaiting_quote_approval, quote_approved, in_progress` status में contact देती है। `completed` और `cancelled` status सूची में नहीं हैं। इसलिए backend response स्तर पर भी इन terminal states में नंबर नहीं लौटना चाहिए।
- Customer को pre-assignment/offer अवस्था में इस lookup से नंबर नहीं मिलता; ownership `customer_user_id = auth.uid()` से सीमित है। यह source-level evidence है, runtime/RLS/config test नहीं।

### Gaps / required checks
1. Requirement में “काम पूरा होने के बाद” के साथ cancellation, reassignment, electrician suspension और dispute/closed states पर भी contact hide/allow rules को स्पष्ट lifecycle contract में दर्ज करना। Current allowlist fail-closed है, लेकिन future states जोड़ने पर review अनिवार्य।
2. Customer booking list के अलावा future receipt, notification, support/history APIs में phone fields leak न हों; इन surfaces का end-to-end data-flow audit बाकी है।
3. Electrician-side reverse contact visibility, Admin visibility, assignment acceptance race, realtime/cache refresh तथा terminal-state transition के तुरंत बाद stale client contact removal का अलग परीक्षण बाकी।
4. वास्तविक दो-account test: pre-accept hidden; assigned/accepted पर दोनों पक्षों के लिए approved full-number access; completed/cancelled पर customer UI/API/receipt/history से अनुपलब्ध। यह user के वर्तमान phone-visibility rule के अनुरूप verify हो।

### Status and restrictions
- **14.1.8: Partial Source Evidence / Implementation Verification Pending.** Customer-side private lookup में authenticated ownership और active-status allowlist मौजूद है; पर पूरे requirement की दोनों-पक्षीय visibility, सभी surfaces और runtime behavior सिद्ध नहीं।
- इस audit में कोई code/schema/RLS/Auth/customer data/provider/payment/secret/deployment परिवर्तन नहीं किया।
- Final Real-World Test: **बाकी**; कुल वास्तविक परीक्षण 96/96 Pending रहेंगे।


## 17.118 — 14.1.9 यात्रा के दौरान Live Location / ETA Source Audit (2026-11-13)

### Scope and evidence
- Feature Branch `booking.html` (SHA `411c226d5835299c6a15142dcfa1c6639739e050`) में GPS केवल customer booking address के लिए `navigator.geolocation.getCurrentPosition` से एक बार लिया जाता है। यह electrician की यात्रा के दौरान tracking नहीं है।
- `create-booking.js` (पूर्व audit में दर्ज SHA `72b3618b0cf1ffcd0537992cec224d846886ffdc`) booking पर optional `location_lat/location_lng` pair validate/store करता है। Migration `20261109001000_add_google_maps_location_support.sql` booking और electrician application में map coordinates columns जोड़ती है; ये स्थिर location pins हैं।
- `electrician.html` (SHA `794dc8cac838461eafc67c1479e61bf4b0566337`) assigned booking के लिए Google Maps directions link बनाती है, लेकिन continuous location updates, en-route/arrived controls या ETA calculation नहीं दिखाती।
- `netlify.toml` में geolocation Permissions-Policy `geolocation=(self)` है। Customer GPS capture में unsupported/permission/error case का message है; यह electrician tracking permission lifecycle या stale-location handling का प्रमाण नहीं।
- Repository code search में live tracking/ETA/realtime location update source नहीं मिला; यह code-search evidence है, नाम/implementation के सभी सम्भव रूपों का पूर्ण absence proof नहीं।

### Gaps / safe implementation requirements
1. अलग privacy-guarded electrician-location stream/table और authenticated server endpoint/RPC; booking assignment, active work state और actor ownership हर update पर validate हो।
2. स्पष्ट consent/permission UI, permission-denied fallback, accuracy, captured_at/server_received_at, stale threshold, throttling/rate limits और offline/retry states।
3. Customer को केवल अपनी currently assigned active booking की सीमित location/ETA; अन्य ग्राहक/partner/Admin role के data isolation tests।
4. ETA को अनुमान के रूप में label करना; unavailable/stale स्थिति में “ETA उपलब्ध नहीं” दिखाना, नकली live marker नहीं।
5. यात्रा शुरू होने, arrival, cancellation, reassignment और completion पर tracking start/stop/revoke; terminal booking के बाद location stream से कोई नया read/write नहीं।
6. Location retention/deletion policy, access audit, abuse controls, battery/network impact और low-bandwidth/device/browser tests।
7. Existing booking GPS pin को live electrician location न समझें; historical location को वर्तमान position के रूप में कभी न दिखाएँ।

### Status and restrictions
- **14.1.9: In Progress / Dependency-Blocked — Source Audit दर्ज; live tracking/ETA implementation नहीं मिली।** Privacy, retention और authorized update/read contract तय किए बिना tracking चालू नहीं की जाएगी।
- Source/implementation verification: **Verified नहीं**। कोई code, DB/RLS/RPC, customer location data, Auth, provider, secret या deployment परिवर्तन नहीं किया।
- Final Real-World Test: **बाकी**; कुल 96/96 वास्तविक परीक्षण अंतिम consolidated batch तक Pending।


## 18. मालिक के नवीनतम पुष्टि किए हुए बिलिंग निर्णय — 13 नवम्बर 2026
यह अनुभाग पहले के किसी भी विरोधी सामग्री/बिलिंग कथन पर प्राथमिकता रखता है।

1. **बुकिंग राशि केवल अनुमान (Estimate) है।** ग्राहक को बुकिंग से पहले चुनी category, अनुमानित अवधि और अनुमानित रकम स्पष्ट बताई जाएगी। इसे cap, advance या fixed final price नहीं कहा जाएगा।
2. **अंतिम मेहनताना वास्तविक समय पर आधारित होगा।** Server-recorded billable minutes और स्वीकृत category के 8-hour rate से गणना होगी: category_8h_rate × actual_billable_minutes ÷ 480; monetary rounding integer paise में होगी और लागू rounding convention अलग से सत्यापित/निर्धारित होगी।
3. **बुक की अवधि से अधिक काम होने पर वास्तविक कुल billable minutes के अनुसार शुल्क अपने-आप लगेगा।** अतिरिक्त समय के लिए अलग customer approval आवश्यक नहीं है। Timer केवल server-authoritative और सुरक्षित work-start/completion events से चलेगा; idle/pause और disputed-time handling को अलग से सुरक्षित रूप से लागू करना होगा।
4. **ऐप में सामग्री का कोई रोल नहीं है।** Customer App, Electrician App/Portal, Admin के customer-facing bill/receipt, quotation/estimate, payment history और संबंधित app UI/API/RPC payload में सामग्री का नाम, सामग्री line item, सामग्री शुल्क या सामग्री-संबंधित billing field नहीं दिखेगा। सामग्री को ऐप के बिलिंग flow में शामिल नहीं करना है।
5. App bill/receipt में केवल electrician labour/मेहनताना दिखेगा। यदि पुराने payment record से labour amount स्वतंत्र रूप से सत्यापित नहीं हो सकता, तो कोई अनुमानित labour split न दिखाएँ; केवल सत्यापित भुगतान राशि को स्पष्ट रूप से payment receipt के रूप में दिखाएँ, final labour invoice बताकर नहीं।
6. पुराने database columns, migrations, provider/payment/refund integrations और historical records को बिना dependency audit delete/alter न करें। Legacy material fields को customer/electrician-facing app output से हटाने के लिए safe staged changes और regression tests आवश्यक हैं।
7. Platform Fee या अन्य शुल्क को labour amount में छिपाकर न जोड़ें और न ही इस निर्णय से कोई नया customer charge अनुमानित करें; उसकी स्वीकृत policy और ledger treatment अलग रहेंगे।
8. यह business-rule confirmation है; इससे अपने-आप migration apply, production setting change या deployment की अनुमति नहीं मिलती।


## 19. वास्तविक समय बिलिंग — अगला implementation audit (13 नवम्बर 2026)
### 19.1 पुष्टि किए हुए निर्णय
- Booking-time amount केवल Estimate है; इसे cap, advance या fixed final price नहीं कहा जाएगा।
- Booking अवधि से आगे काम होने पर भी server-recorded वास्तविक elapsed time के आधार पर शुल्क अपने-आप लगेगा; अतिरिक्त समय के लिए अलग approval नहीं चाहिए।
- Timer start होने के बाद server start timestamp से server stop timestamp तक uninterrupted elapsed time गिना जाएगा। कोई daily reset, 8-hour cap, auto-stop या overtime multiplier नहीं होगा; 24 घंटे/कई दिनों तक चलने पर भी यही per-minute rate लागू होगा।
- Electrician कोई final amount manually enter नहीं करेगा; server final labour amount calculate/freeze करेगा।
- App billing में सामग्री का कोई role नहीं: customer/electrician/admin app billing surfaces, estimate, final bill, payment history, receipt और app API/RPC outputs में material name/line/charge/field नहीं दिखेगा।
- Published 8-hour rates: Electrical Assistant ₹899; Skilled Electrician ₹1,199; Expert Electrician ₹1,599; Premium Electrical Specialist ₹1,999. Village/city rate same. Per-minute basis = 8-hour rate / 480.

### 19.2 वर्तमान live backend की जाँच
- `service_bookings` में `work_start_approval_status`, `work_start_requested_at`, `work_timer_running`, `work_timer_seconds`, `work_started_at`, `completion_requested_at`, `completion_approval_status` और `customer_completed_at` fields पहले से मौजूद हैं।
- Live RPCs में electrician work-start request, customer start approval, electrician completion request, customer completion approval/dispute, Admin dispute resolution और electrician work-control lookup मौजूद हैं।
- मौजूदा start-request RPC अभी `quote_approved` + `quote_status='approved'` पर निर्भर है; यह legacy electrician-entered quote workflow से जुड़ा है। इसलिए इसे सीधे नए Estimate-only model के लिए उपयोग करना सुरक्षित नहीं।
- मौजूदा completion request `work_timer_seconds + server elapsed seconds` से timer duration बनाती है और completion approval/dispute पर timer रोकती है। यह timer source है, लेकिन final labour invoice/bill snapshot नहीं।
- कोई canonical category/rate-tier field/table live public schema inventory में नहीं मिला। `electrician_profiles.skills` text array अकेले Admin-approved commercial rate tier का प्रमाण नहीं है; इसे billing authority न मानें।
- Current customer booking creation stores client-provided `quoted_amount`; this must be replaced with server-derived estimate from selected approved category + selected expected duration. Client-provided price must never be trusted.

### 19.3 अभी भी implementation रोकने वाले आवश्यक निर्णय/साक्ष्य
1. **Fractional paise rounding — मालिक की मंजूरी 13-11-2026:** `rate_paise × actual_minutes / 480` को निकटतम पूर्ण पैसे (integer paise) तक round करें; fractional हिस्सा ठीक आधा पैसा या उससे अधिक हो तो अगले पैसे तक round up करें (round half up)। इस निर्णय से rounding blocker हल हो गया है।
2. **Canonical category assignment:** चार rate tiers मौजूद हैं, लेकिन customer-selected requested category और Admin-approved electrician category को सुरक्षित रूप से store/verify करने वाला canonical schema अभी नहीं मिला। `skills` text array को बिना Admin-verification mapping के उपयोग न करें।
3. **Legacy quote/payment dependency:** quote-era RPCs, payment order, webhook, cash confirmation, manual payment, commission/payable triggers और refunds `service_charge + materials_amount + quoted_amount + quote_status` पर निर्भर हैं। इन सभी consumers को versioned labour-bill snapshot से migrate किए बिना legacy columns/functions हटाना या zero करना खतरनाक है।
4. **Immutable final bill:** final bill में booking, approved rate-card/version, server start/stop timestamps, actual elapsed whole minutes, exact calculation numerator/denominator, integer amount paise, calculation version, bill hash, approval/audit timestamps और immutable version चाहिए। Dispute पर payment/finalization रोकना होगा।
5. **Payment binding:** Cash, Razorpay order/verify/webhook, Admin manual payment, Platform Fee, electrician payable/payout और refunds सभी exact frozen bill snapshot ID/version/hash/amount पर bind होने चाहिए; current payment handlers अभी quote-era total पर आधारित हैं।

### 19.4 अगला सुरक्षित implementation क्रम
1. पहले rate-card + requested/approved category schema और Admin approval workflow को design/test करें; customer category और electrician eligibility server-side validate हों।
2. फिर estimate-only booking payload बनाएं: selected category, expected duration 1–8 hours, server-computed estimate; client `quoted_amount` हटे।
3. Existing timer को uninterrupted server-authoritative start/stop model में adapt करें; old quote approval prerequisite हटाने के लिए अलग versioned RPCs बनाएं, legacy bookings का path सुरक्षित रखें।
4. Rounding decision के बाद immutable labour-only final bill snapshot और idempotent payment intent/finalizer बनाएं।
5. Cash/Online, webhook, Platform Fee, payout/refund और Admin reconciliation को snapshot से migrate करें; सभी legacy regression और authorization tests के बाद ही किसी environment में apply की अनुमति माँगें।

### 19.5 सुरक्षा सीमा
यह source + read-only live schema/function inventory है। कोई live DDL/DML, migration apply, payment/provider action, production setting change या deployment नहीं किया गया। Material billing fields को app output से हटाने का staged work शुरू है; legacy database columns और historical accounting dependencies जानबूझकर अभी सुरक्षित रखे गए हैं।

### 19.6 मालिक की rounding पुष्टि और प्रारंभिक गणना मॉड्यूल (13-11-2026)
- मालिक ने पुष्टि की: rate8hPaise × actual_billable_minutes ÷ 480 को निकटतम integer paise तक round करना है; fractional हिस्सा ठीक 0.5 paisa या अधिक हो तो ऊपर round करें (round half up)।
- Feature Branch में lib/labour-billing.js जोड़ा गया: versioned customer gross labour rate-card constants (₹899/₹1,199/₹1,599/₹1,999 प्रति 8 घंटे), exact BigInt numerator/denominator arithmetic, half-up rounding, 1–8 घंटे estimate helper और 8 घंटे से अधिक actual minutes पर कोई cap नहीं।
- tests/labour-billing.test.cjs में rate card, estimate, 77-minute calculation, below/exactly/above-half rounding, zero, multi-day duration, invalid inputs और safe-integer overflow cases जोड़े गए। npm run test:labour command जोड़ा गया।
- यह केवल pure calculation foundation है। अभी इसे booking API, approved electrician-category lookup, timer, immutable final-bill snapshot या payment provider से connect नहीं किया गया है। Customer-selected category / Admin-approved electrician category की canonical schema और server-side authorization अभी blocker हैं; अतः इस helper को अकेले production billing authority न मानें।
- No database migration applied, no production changes, no deployment, no live payment action.

### 19.7 Rate-tier authorization और legacy trigger का read-only पुनः audit (13-11-2026)
- Live `electrician_applications` में requested category का अलग canonical field नहीं है; `skills` केवल text है। `electrician_profiles` में भी approved commercial category/rate-tier field नहीं है; केवल skills array और verification/active flags हैं।
- Live RLS में electrician_applications SELECT/UPDATE Admin-only है; electrician_profiles INSERT/UPDATE/DELETE Admin-only है और read policy linked electrician/Auth user या Admin तक सीमित है। यह सुरक्षित आधार है, पर category assignment का authoritative evidence नहीं।
- `electrician_applications` पर `guard_electrician_application()` BEFORE INSERT और Admin audit trigger मौजूद हैं; `electrician_profiles` पर Admin audit trigger मौजूद है। `service_bookings` पर booking guard, new-booking broadcast, commission calculation, work-approval transition guard, status audit और electrician payable triggers मौजूद हैं।
- इसलिए नई category/rate-tier schema को केवल column जोड़कर नहीं छोड़ना है: application requested tier, Admin-approved tier, approver identity/time, versioned rate-card reference और booking-time immutable category/rate snapshot को सुरक्षित constraints/RPC/RLS तथा audit के साथ लागू करना होगा। Existing commission/payable triggers के function bodies और payment consumers की dependency review के बिना उन्हें बदलना/बायपास करना मना है।
- 11/11 pure calculator unit tests सफल हुए (Node test runner, isolated verification run में branch के समान source/test content के साथ)। यह unit-level arithmetic evidence है; GitHub CI, deployed runtime, Supabase RPC, booking/payment integration या browser QA का प्रमाण नहीं है।
- No live schema changes, migrations applied, production settings changed, deployment or live payment action.

### 19.8 Electrician requested category और Admin-approved rate tier का source draft (13-11-2026)
- Feature Branch में migration draft `20261114000000_electrician_requested_and_approved_rate_tiers.sql` जोड़ा गया। यह आवेदन का `requested_category` अलग रखता है और प्रोफाइल में Admin-approved `approved_rate_tier`, rate-card version, approver UUID तथा approval timestamp अलग रखता है।
- चार मान्य tiers केवल `electrical_assistant`, `skilled_electrician`, `expert_electrician`, `premium_electrical_specialist` हैं। Skills text/array से rate tier infer नहीं होगा।
- Admin-only guarded RPC `srk_admin_set_electrician_rate_tier` हर बदलाव को audit table में दर्ज करता है। नया activation guard rate-tier approval के बिना electrician profile को active करने से रोकता है। पुराने profiles के tier null छोड़े गए हैं; कोई legacy tier अनुमान से backfill नहीं होगा।
- pgTAP source test `supabase/tests/database/electrician_rate_tier_authorization.test.sql` जोड़ा गया। अभी database migration apply नहीं हुई और pgTAP test run नहीं हुआ।
- Current approved feature-branch `index.html` में electrician application form मौजूद नहीं है, जबकि repository search में पुराना form केवल stale indexed result में मिला। इसलिए applicant-facing requested-category selector को अभी किसी अनुमानित page में नहीं जोड़ा गया; actual current form/page locate करके उसी में integration करना आवश्यक है।
- Admin UI में भी अभी rate-tier selector नहीं जोड़ा गया; पहले migration review/test और Admin panel के current approval flow का source integration आवश्यक है।
- कोई production DDL/DML, migration apply, live activation, deployment या payment action नहीं हुआ।

### 19.9 Timer और payment RPC का अगला read-only audit (13-11-2026)
- Live `srk_electrician_request_work_start()` अभी `status='quote_approved'` और `quote_status='approved'` अनिवार्य करता है; estimate-only booking architecture के लिए यह legacy prerequisite हटाना होगा, लेकिन पुराने bookings का compatibility path सुरक्षित रखना होगा।
- Live `srk_electrician_request_work_completion()` में `LEAST(604800, accumulated_seconds + server_elapsed_seconds)` है। यह 7-दिन का hard cap है और मालिक के no-cap / multi-day timer नियम से टकराता है। आगामी migration में cap हटाना आवश्यक है।
- Completion request server time से elapsed seconds जमा करता है और timer रोकता है; Customer reject पर accumulated seconds सुरक्षित रखकर नया `work_started_at` और running timer सेट होता है। Dispute पर timer रोकता है। नई bill snapshot प्रक्रिया केवल Admin/customer-approved completion और dispute-free state पर बनेगी।
- Live customer start approval RPC start timestamp server `now()` पर सेट करता है; timer start server-authoritative है। `work_timer_seconds` integer है, इसलिए accumulated seconds को multi-day duration में रखने के लिए 32-bit सीमा की गणना/constraint review जरूरी है।
- Live cash confirmation और Admin manual payment अभी `quote_status='approved'`, `quoted_amount` या `service_charge + materials_amount` पर निर्भर हैं। ये legacy dependencies हैं; immutable labour-only bill snapshot से replace किए बिना इन RPCs को estimate-only model में switch करना सुरक्षित नहीं।
- **Billable whole-minute policy — मालिक की पुष्टि 13-11-2026 (विकल्प 1):** server-recorded elapsed seconds को billable minutes में बदलते समय कोई भी positive partial minute अगले पूरे minute तक गिना जाएगा (ceiling)। उदाहरण: 10 मिनट 20 सेकंड = 11 billable minutes; ठीक 10 मिनट = 10 minutes; शून्य seconds = 0। यह elapsed-time conversion है और monetary amount की half-up paisa rounding से अलग चरण है।
- No live changes, migrations applied, payment actions or deployment.


### 19.10 Billable minute conversion — मालिक की पुष्टि और unit tests (13-11-2026)
- मालिक ने विकल्प 1 चुना: किसी भी positive partial minute को अगले पूरे billable minute तक round up (ceiling) किया जाएगा। इसलिए 10 मिनट 20 सेकंड का bill 11 मिनट पर बनेगा; केवल पूरे 60-second blocks गिनने वाला floor नियम लागू नहीं होगा।
- Feature Branch के `lib/labour-billing.js` में `calculateBillableMinutesFromElapsedSeconds(elapsedSeconds)` helper जोड़ा गया। यह non-negative safe integer seconds validate करता है और ceiling conversion करता है। इसे monetary half-up rounding से अलग रखा गया है।
- Unit tests में 0, 1, 599, 600, 620 और 86,401 seconds के cases तथा invalid inputs शामिल किए गए। ये pure helper tests हैं; server timer RPC, final bill snapshot, payment binding या live runtime integration का प्रमाण नहीं हैं।
- Combined final labour formula: पहले server elapsed seconds → billable whole minutes (ceiling); फिर approved 8-hour rate × billable minutes ÷ 480 → nearest integer paisa, exact half paisa rounds up.
- कोई live migration apply, production change, payment action या deployment नहीं हुआ।


### 19.11 Timer transition और payment-ledger dependency audit — read-only (13-11-2026)
- Live `service_bookings.work_timer_seconds` का type अभी `integer/int4` है; यह non-null default 0 है। यह लगभग 68 वर्षों की signed 32-bit seconds सीमा देता है। सामान्य multi-day काम में सीमा पर्याप्त है, फिर भी भविष्य की correctness के लिए `bigint` conversion और सभी RPC return signatures/clients की compatibility जांच migration में करनी होगी। `work_started_at` और `completion_requested_at` timestamptz हैं; `work_timer_running` boolean है।
- `srk_electrician_request_work_completion()` elapsed seconds को `LEAST(604800,...)` से 7 दिनों पर cap करता है; यह cap हटना चाहिए। Elapsed duration को server timestamps से ही निकाला जाएगा; client clock trusted नहीं होगा। Negative elapsed clamp और safe integer/bigint bounds स्पष्ट रहेंगे।
- `srk_electrician_request_work_start()` अभी `status='quote_approved'` तथा `quote_status='approved'` मांगता है। Estimate-only flow में इसे हटाना होगा, पर legacy booking के लिए compatibility path रखना होगा। Customer approval RPC का transition guard अभी `awaiting_work_start_approval → in_progress` पर approval authorization मांगता है; इस security guard को bypass नहीं करना है।
- `srk_customer_respond_work_start()` approved start पर server `now()` सेट करता है और timer शुरू करता है। Customer rejection पर status वापस `quote_approved` जाता है; नए estimate-only flow में rejection का सुरक्षित target/status तय कर के transition history तथा old quote compatibility साथ बदलनी होगी।
- `srk_customer_respond_work_completion()` approved completion पर status completed करता है; rejected completion पर timer फिर शुरू करता है और accumulated seconds रखता है; disputed completion timer रोकता है। Final bill snapshot सिर्फ approved completion पर बनेगा, rejected/disputed अवस्था में नहीं। Snapshot insert/idempotency को उसी booking row lock/transaction में बांधना आवश्यक है।
- Legacy finance coupling केवल cash confirmation तक सीमित नहीं है: `srk_electrician_confirm_cash_payment()`, `srk_get_my_assigned_cash_payment()`, `srk_admin_record_manual_payment()`, `srk_create_electrician_payable()`, `srk_admin_mark_electrician_payout_paid()`, Razorpay refund preparation और `srk_admin_finance_dashboard()` अभी `quote_status`, `quoted_amount`, `service_charge`, `materials_amount` या commission/payout breakdown का उपयोग करते हैं। इन्हें labour-only immutable bill snapshot और separately approved commission policy पर migrate किए बिना quote columns को हटाना/ignore करना सुरक्षित नहीं है।
- मौजूदा payable trigger `srk_create_electrician_payable()` payout में `materials_amount` भी जोड़ता है और quote approved होने पर निर्भर है। यह मालिक के app billing rule (materials app bill में नहीं) के विपरीत है। इसे बदलते समय पुराने payout rows/paid entries/refunds का historical reconciliation और no-double-payout idempotency आवश्यक है; मौजूदा trigger को अभी नहीं बदला गया।
- Booking audit trigger का allowlist अभी `status/payment_status/quoted_amount/quote_status/service_charge/materials_amount/commission_amount` जैसे fields तक सीमित है; नई immutable bill snapshot और rate-tier snapshot के audit events के लिए अलग audit strategy चाहिए।
- Next implementation sequence: (1) final-bill snapshot schema + immutable constraints/RPC, (2) server timer start/stop/reject/dispute transition rewrite with cap removal, (3) payment/cash/Razorpay/manual-payment/payout/refund consumers rebind to snapshot, (4) legacy booking compatibility and reconciliation tests, (5) pgTAP + isolated integration tests. किसी भी चरण में materials को customer labour bill में शामिल नहीं करना।
- यह केवल read-only dependency audit और source documentation है। कोई migration apply, live schema/function change, payment action या deployment नहीं हुआ।

### 19.12 Canonical category और rate-tier guard review — अतिरिक्त read-only audit (13-11-2026)
- Live service_bookings schema में service_type केवल text है; कोई अलग canonical selected_category/category-key field नहीं मिला। इसलिए पुराने service_type display text को बिना explicit allowlist/versioned mapping के commercial billing key नहीं मानना है। Final bill snapshot से पहले booking creation/API में canonical customer-selected category key सुरक्षित रूप से persist करना और पुरानी bookings को unclassified/legacy रखना होगा; skills या text matching से category infer नहीं होगी।
- Live electrician_profiles में canonical approved rate-tier fields अभी मौजूद नहीं हैं; वे केवल Feature Branch migration draft में हैं। Migration source को apply करने की अनुमति नहीं मिली है।
- Rate-tier migration review में activation guard का पहला draft केवल INSERT और UPDATE OF active पर fire होता था। इससे active profile के rate-tier approval fields को सीधे clear/change करने पर guard fire नहीं होता। Feature Branch source में trigger event अब INSERT OR UPDATE OF active, approved_rate_tier, approved_rate_card_version, rate_tier_approved_by, rate_tier_approved_at किया गया है, ताकि approval tuple के किसी भी बदलाव पर consistency validate हो।
- pgTAP test plan 12 से 13 assertions किया गया; नया assertion verify करता है कि trigger सभी approval fields की UPDATE event पर fire होता है। Test source में है, अभी pgTAP run नहीं हुआ।
- Live booking financial columns में quoted_amount, service_charge, materials_amount, commission_rate और commission_amount legacy dependencies के रूप में मौजूद हैं। srk_electrician_payouts में historical materials_amount column भी है; इसे नई labour-only bill/payout calculation में शामिल नहीं करना, पर historical rows/paid records को migrate करने से पहले reconcile करना होगा।
- service_bookings पर Admin audit, commission calculation, work-approval transition guard, status history और payable creation triggers मौजूद हैं। Payable trigger अभी paid+completed+approved quote state पर चलता है; इसे snapshot ledger migration में safe replacement/reconciliation के बिना drop या bypass नहीं करना है।
- Final bill snapshot implementation से पहले अनिवार्य blockers: (1) booking category key persistence, (2) approved rate-tier migration + applicant/Admin UI integration, (3) 32-bit timer field migration/consumer compatibility, (4) immutable bill snapshot and completion-approval transaction design, (5) payment/refund/payout ledger rebind with no duplicate payout and explicit commission/platform-fee policy.
- यह source review और test-source update है। कोई Supabase migration apply, live DDL/DML/function edit, profile activation, payment, deployment या production setting change नहीं हुआ।

### 19.13 Admin rate-tier controls — Feature Branch source update (13-11-2026)
- Current Admin partner table में Admin-approved rate tier चुनने और guarded RPC srk_admin_set_electrician_rate_tier से approve/update करने का control जोड़ा गया। Applicant table में requested_category उपलब्ध होने पर दिखेगा; पुराने records के लिए स्पष्ट legacy/unavailable label रहेगा।
- चारों option keys migration के canonical allowlist से मिलाए गए; static source check में premium_electrical_specialist सहित सभी keys/ RPC reference मौजूद मिले। Admin HTML के inline JavaScript block का syntax compile check PASS हुआ।
- Migration अभी Supabase पर apply नहीं है; इसलिए नया control अभी source integration है, live Admin runtime/approval success का प्रमाण नहीं। Active profile को tier approval के बिना activate करने पर DB guard से rejection अपेक्षित है; यह behavior runtime पर test नहीं हुआ।
- Electrician applicant-facing form अभी current Feature Branch में locate नहीं हुआ; requested_category capture करना बाकी है। Customer booking form अभी category की जगह service_type display labels भेजता है और 1–8 घंटे duration input नहीं रखता। create-booking.js केवल service_type text persist करता है। इसलिए canonical customer-selected category और selected duration को API/database में जोड़ना अगला आवश्यक चरण है।
- इस UI source update में कोई migration apply, live profile/category change, customer booking, payment, production setting या deployment नहीं हुआ। Manual browser/mobile/desktop QA अंतिम consolidated batch तक स्थगित है।

### 19.14 Customer booking category और 1–8 घंटे duration — Feature Branch source integration (13-11-2026)
- `service_bookings` में `selected_category` और `selected_duration_hours` के nullable columns जोड़ने की migration source बनाई। Valid customer work categories: `home_wiring`, `electrical_repair`, `light_fan_fitting`, `home_repair`, `other`; duration केवल integer 1–8 hours। दोनों fields साथ NULL या साथ valid होंगे।
- Legacy bookings को nullable/unclassified रखा गया है; `service_type` text या electrician `skills` से कोई category/duration backfill/inference नहीं किया गया। पुराने records का historical meaning नहीं बदलेगा।
- Customer booking form में canonical category dropdown और 1–8 hour duration dropdown जोड़े गए। अवधि को साफ तौर पर estimate-only बताया गया है; यह advance या final bill cap नहीं। Final labour bill अभी भी actual server-recorded duration और Admin-approved electrician rate tier पर निर्भर होगा।
- Customer-selected work category और electrician का Admin-approved commercial rate tier अलग concepts हैं। Customer category केवल requested work बताती है; वह electrician tier या rate तय नहीं करती।
- `create-booking.js` अब category allowlist server-side validate करता है, JSON number के रूप में duration 1–8 validate करता है, client-supplied display label पर भरोसा न करके `service_type` label स्वयं derive करता है, और दोनों canonical fields insert करता है।
- API test suite में 4 नए cases जोड़े: unknown category reject, 9-hour reject, string duration reject, और server-derived label + canonical persistence verify। कुल 16 test cases source में हैं; `npm run test:booking` अभी execute नहीं हुआ। Database pgTAP test plan 6 assertions के साथ जोड़ा गया; test run नहीं हुआ।
- Static checks: booking inline JS syntax PASS; API source syntax PASS; test source syntax PASS; package.json JSON parse PASS; पांचों category keys, form/API wiring, migration fields और no-backfill check PASS।
- **महत्वपूर्ण runtime dependency:** migration Supabase पर लागू नहीं हुई है। इसलिए live database में ये columns अभी उपलब्ध नहीं हैं; API runtime/integration test और deployment तब तक नहीं करना है जब तक migration अलग से स्वीकृत और सुरक्षित रूप से लागू न हो। कोई migration apply, live booking, payment, production change या deployment नहीं हुआ।

### 19.15 Electrician applicant form और requested commercial category — Feature Branch source integration (13-11-2026)
- Live schema/RLS read-only audit में `electrician_applications` table पर Admin-only SELECT/UPDATE policies मिलीं; public/anonymous direct INSERT policy नहीं है। इसलिए आवेदन मौजूदा server-side `apply-electrician.js` handler के service-role insert और IP rate-limit check से भेजा जाता है; client को service key नहीं दी जाती।
- नया `apply-electrician.html` आवेदन पेज बनाया: नाम, मोबाइल, राज्य, जिला, PIN, अनुभव, कौशल/काम और चार में से requested commercial category। आवेदन status pending और active=false रहता है; आवेदन जमा करने से profile activate या rate-tier approve नहीं होता।
- मौजूदा `apply-electrician.js` handler में चार canonical requested category keys की server-side allowlist validation और `electrician_applications.requested_category` insert जोड़ा। Unknown/missing category reject होती है। Existing rate-limit और input-size controls बरकरार हैं।
- मौजूदा Netlify adapter की पुष्टि की; `/api/apply-electrician` redirect पहले से configured है। Homepage पर ग्राहक booking और electrician application के स्पष्ट entry buttons जोड़े।
- Admin partner/application table पहले से `requested_category` दिखाती है और अलग guarded RPC से approved tier चुनती है। Requested category और approved tier अलग रहते हैं।
- आवेदन API के लिए 7 test cases जोड़े और `npm run test:application` script जोड़ी। Static source checks PASS: application page inline JS, handler JS, Netlify adapter, test source syntax, package JSON, category options consistency, homepage link और Admin requested-category display। Tests execute नहीं हुए; live application insert/verification नहीं किया गया।
- Rate-tier migration अभी unapplied है। Applicant form requested tier को केवल application record में रखता है; Admin approval RPC तभी चलेगा जब migration authorized होकर apply होगी। No production deploy, live DB change, applicant record creation, profile activation या rate-tier approval हुआ।

### 19.17 Customer work category और Admin-approved commercial rate-tier का matching integration — Feature Branch source update (13-11-2026)
- दोनों dimensions का स्पष्ट अंतर रखा गया: `service_bookings.selected_category` ग्राहक के काम का प्रकार है (home_wiring, electrical_repair, light_fan_fitting, home_repair, other); `electrician_profiles.approved_rate_tier` electrician का Admin-approved labour pricing tier है (Electrical Assistant, Skilled, Expert, Premium)। ये एक-दूसरे के समान taxonomy नहीं हैं; इन्हें key-to-key compare नहीं करना है।
- `srk_admin_offer_booking(uuid)` source को harden किया: अब offer केवल Active + KYC-approved + Auth-linked profile को जाएगा, जिसके approved_rate_tier, rate-card version, approver और approval timestamp चारों मौजूद हों। Existing exact PIN-first, district fallback और duplicate-offer protection कायम हैं।
- Legacy bookings जिनका selected_category NULL है, अभी भी geographic matching में eligible हैं; कोई category inference `service_type` या `skills` text से नहीं होता।
- `srk_get_my_offer_details()` RPC को selected_category, selected_duration_hours और electrician का approved_rate_tier return करने के लिए recreate किया। Customer name/phone/address/location अभी भी assignment के बाद ही लौटते हैं।
- `electrician.html` में प्रत्येक offer पर ग्राहक का काम/category और booked duration estimate दिखता है; profile में Admin-approved commercial rate-tier अलग से दिखता है। UI स्पष्ट करता है कि दोनों अलग हैं।
- Existing category/duration pgTAP test plan 6 से 14 किया। 8 नए assertions RPC presence, complete rate-tier gate, geographic matching, category/duration exposure, approved tier exposure, pre-assignment phone privacy और गलत category-tier equivalence रोकने के लिए जोड़े।
- Static checks PASS: inline electrician JS syntax, migration source function/tier gate, extended RPC fields, PIN/district fallback, 14/14 assertion count, category/tier UI labels, legacy NULL preservation। pgTAP अभी execute नहीं हुआ; live RPC/browser test नहीं हुआ।
- सभी बदलाव approved feature branch source में हैं। Migration apply, production DB, deployment, profile activation या actual job offers पर कोई कार्रवाई नहीं की गई।

### 19.18 Structured electrician skills और Admin-controlled category matching — Feature Branch source update (13-11-2026)
- Free-text `electrician_applications.skills` / `electrician_profiles.skills` केवल विवरण हैं; automatic matching में उनका उपयोग नहीं होगा।
- Applicant form अब canonical structured skills में से कम-से-कम एक चुनता है। API allowlist, 1–10 skill limit, duplicate normalization और invalid key rejection लागू करता है। आवेदन की skill list `requested_skill_keys` में सेव होती है।
- KYC approval applicant की declared skill list profile में copy करता है, लेकिन `approved_skill_keys` खाली रखता है। इसलिए KYC approval अपने-आप किसी skill को verified नहीं बनाता।
- Admin केवल applicant द्वारा घोषित skills में से चुनकर अलग से verify कर सकता है। `srk_admin_set_electrician_skills` Admin guard, KYC approval, applicant-declared subset validation, private transaction authorization और audit log लागू करता है। Direct table UPDATE से approved skills बदलना trigger रोकता है।
- `srk_customer_category_skill_rules` में Admin हर customer work category के लिए एक या अधिक verified skill keys configure करता है। Mapping update केवल `srk_admin_set_category_skill_rules` से होता है और उसका audit record बनता है। Empty mapping जानबूझकर automatic offers रोकती है।
- Categorized नई booking का offer केवल ऐसे Active + KYC-approved + Auth-linked + complete Admin rate-tier-approved electrician को जाएगा जिसके `approved_skill_keys` में उस customer category की Admin-mapped skill कम-से-कम एक मौजूद हो। PIN-first / district fallback इसी filtered eligible set पर चलता है।
- Category mapping मौजूद न हो या योग्य verified-skill partner न मिले तो RPC fail-closed result लौटाता है; free-text skills, applicant requested commercial category या customer category से अनुमान नहीं लगाया जाता। Legacy `selected_category IS NULL` bookings पुरानी geographic matching path पर रहती हैं, लेकिन complete approved rate tier फिर भी जरूरी है।
- Admin Panel में applicant-declared skills, profile verified-skill selector, और customer category mapping controls जोड़े। Electrician portal में अपनी verified skills दिखती हैं।
- Isolated mocked application API checks: 11/11 PASS (HTTP method, payload size, IP rate limit, invalid category/skill, success persistence pending/inactive, DB insert failure, duplicate normalization)। Admin, applicant और electrician inline JS syntax checks PASS।
- pgTAP test `verified_electrician_skills_category_matching.test.sql` में 24 assertions हैं; अभी execute नहीं हुए। Live Supabase migration, RLS runtime, Admin RPC, application insert, real matching और browser/mobile tests नहीं हुए।
- Supabase के 2026-10-30 API exposure बदलाव के अनुसार नई public tables स्वतः Data API पर expose नहीं मानी जातीं। Admin mapping read के लिए अलग Admin-only RPC उपयोग होता है; skill tables पर authenticated grants और Admin-only RLS policies हैं, और सीधे table write बंद हैं। No production migration or deployment performed.
- सभी बदलाव approved feature branch source-only हैं। Admin mapping rows seed नहीं की गईं: लागू होने के बाद Admin को हर Category की सही skills खुद configure करनी होंगी। जब तक mapping खाली है, उस Category पर automatic offer नहीं जाएगा।

### 19.19 Server-authoritative timer, final labour bill और Platform Fee ledger — Feature Branch source update (13-11-2026)
- New categorized booking में customer-selected work category और electrician Admin-approved commercial rate tier अलग रहते हैं। Customer की काम शुरू करने की मंजूरी के बाद ही server clock से timer शुरू होता है।
- Timer का exact accumulated elapsed time numeric seconds में और compatibility whole seconds bigint में सुरक्षित होता है। 7-day cap हटाया गया; multiple days/continuous work supported है। Start rejection पर पुराना status restore होता है; completion rejection पर timer उसी accumulated duration से resume होता है; dispute पर timer रुका रहता है।
- Electrician completion request पर server timer freeze होता है। Final bill केवल customer द्वारा completion approve करने पर उसी transaction में snapshot होता है; disputed/rejected completion पर bill नहीं बनता। Snapshot में assigned electrician का rate tier, 8-hour rate (integer paise), rate-card version, exact elapsed seconds, billable minutes, gross labour और amount सुरक्षित हैं।
- Positive partial minute ceiling से billable minute बनेगा; final paise amount half-up rounding से। Final labour = approved 8-hour rate × billable minutes ÷ 480.
- Master §5.3 के explicit 15% Platform Fee को bill snapshot में अलग policy version/rate/amount के रूप में दर्ज किया जाता है। यह नई flow में legacy commission_rate से infer नहीं होता; commission_amount null रहता है। Electrician net payable = gross labour − Platform Fee. Customer को gross labour bill, electrician को केवल net rate/net payable, Admin को gross + Platform Fee + net breakdown मिलता है।
- Cash payment पर electrician wallet में idempotent platform_fee_due debit बनता है; कोई platform bank payout row नहीं बनती क्योंकि gross cash electrician ने सीधे लिया। Online/manual platform-received payment पर gross booking credit, Platform Fee debit, पुराने cash dues का labour-share-only settlement/recovery, और pending net payout debit अलग-अलग ledger entries बनते हैं। पुराना cash due customer से अतिरिक्त नहीं लिया जाता और material से कभी recover नहीं होता।
- Admin द्वारा वास्तविक bank/UPI transfer और reference दर्ज करने पर ही pending payout ledger debit posted होता है और payout Paid बनता है। Refund पर original wallet entries idempotently reverse होती हैं; paid payout होने पर automatic refund path block रहता है और अलग Admin recovery जरूरी है।
- Razorpay order creation, payment verification और webhook अब new categorized bookings के लिए केवल service-role-only final labour bill snapshot amount से reconcile होते हैं; legacy NULL-category bookings के लिए पुराना quote path compatibility हेतु सुरक्षित है। Cash confirmation, Admin manual payment, payout settlement, refund preparation, Admin finance report और electrician earnings भी snapshot से जुड़ते हैं।
- Customer, Electrician और Admin UI में start approval, live display-only timer, completion approval, final labour bill, online/cash payment status, Admin bill breakdown और wallet Platform Fee due/collected display जोड़े/बदले गए। Electrician rate display में केवल approved net 8-hour rates ₹764.15 / ₹1,019.15 / ₹1,359.15 / ₹1,699.15 दिखते हैं।
- Phone contact RPC में awaiting_work_start_approval जोड़ा और completed हटाया; customer API completion के बाद electrician phone नहीं लौटाती।
- Razorpay handlers के लिए 7 mocked isolated runtime checks PASS: snapshot amount order creation, missing bill fail-closed, customer ownership, payment amount verification, mismatch rejection, webhook reconciliation और mismatch rejection. Admin/customer/electrician/payment-handler JavaScript syntax checks PASS.
- Database test server_authoritative_labour_timer_and_bill_snapshot.test.sql में 96 pgTAP assertions हैं; अभी execute नहीं हुए। Migration source-only/unapplied है; live RLS/RPC/trigger/ledger, real Razorpay Test Mode, cash wallet, payout, refund और browser tests अभी बाकी हैं।
- कोई production migration apply, payment transfer, live refund, production setting change या deployment नहीं किया गया। Final consolidated mobile + desktop QA सभी checklist tasks के बाद ही होगा।

### 19.20 Automatic offer matching और electrician offer RPC privacy hardening (13-11-2026)
- Booking INSERT का automatic offer trigger और Admin का manual offer action अब एक ही private SECURITY DEFINER matching function से गुजरते हैं।
- केवल new/confirmed और unpaid booking पर offer बन सकता है। Electrician का KYC approved, active, Auth-linked, complete Admin-approved rate tier और rate-card version होना जरूरी है।
- Categorized booking में Admin द्वारा configured category-skill mapping मौजूद होना और electrician का उसी mapping में कम-से-कम एक Admin-verified skill होना जरूरी है। Mapping missing या match missing होने पर fail-closed; free-text skills इस्तेमाल नहीं होते।
- PIN match प्राथमिक; योग्य PIN partner न मिलने पर उसी state/district में fallback। Legacy NULL-category booking में skill mapping नहीं थोपी जाती, लेकिन approved rate-tier guard लागू रहता है।
- Electrician offer RPC से quoted_amount, service_charge, materials_amount, quote_status और quote_note return fields हटाए गए।
- नई 15% Platform Fee और पुराने records की historical commission अब अलग fields/totals हैं; legacy commission को Platform Fee total में नहीं जोड़ा जाता। Electrician earnings और Admin report दोनों में अलग दिखता है।
- Admin Platform Fee report copy को भी ठीक किया: नई categorized booking पर अलग 15% policy स्पष्ट है; legacy historical calculation अलग रहती है; UI में सामग्री/सामान या `commission_rate` आधारित नई गणना का उल्लेख नहीं है। अब server timer seconds, selected category/duration, approved rate tier/skills और payment status जैसे जरूरी fields ही लौटते हैं।
- Assigned active work statuses में electrician को customer contact/address मिल सकता है; completed booking पर RPC customer name/phone/address/location वापस नहीं करता।
- Migration source में 101 pgTAP assertions मौजूद हैं;
- Admin finance report और electrician earnings RPC में नई categorized booking की immutable Platform Fee तथा legacy booking की पुरानी commission अलग-अलग fields/totals में दिखाई जाती हैं। Global fee collected/due totals केवल `wallet_type='electrician'` ledger से बनते हैं; legacy commission को नई Platform Fee नहीं माना जाता।
 अभी execute नहीं हुए। कोई live database migration apply नहीं की गई।


### 19.21 Timer/Platform Fee regression audit follow-up (13-11-2026)
- Customer work-start approval में duplicate transaction authorization INSERT मिला था, जिससे unique key conflict के कारण approval fail हो सकता था। Duplicate हटाया; अब exactly one transaction-scoped authorization बनता है। pgTAP regression assertion जोड़ा।
- Cash Platform Fee due, online due-settlement और refund reversal का हिसाब अब wallet summary, Admin overview/report, cash eligibility और cash-offer reservation में एक समान refund-aware ledger formula से reconcile होता है। Cash fee refund होने पर पुराना due हटता है; online booking refund होने पर previously settled cash due फिर outstanding बनता है और refunded online fee collected total से घटती है।
- admin.html के payout table से wildcard select('*') हटाकर explicit safe columns चुने गए; payout UI अब legacy materials_amount column को select नहीं करता। service_bookings और payout tables पर column-level grant design के साथ Admin UI queries align की गईं।
- Updated SQL test file में 91 assertions घोषित हैं; अभी pgTAP execute नहीं हुआ। JavaScript syntax source checks pass; live database, payment provider और browser runtime tests अभी बाकी हैं।


### 19.22 Immutable final labour bill snapshot hardening (13-11-2026)
- Final labour bill table पर BEFORE INSERT/UPDATE/DELETE trigger जोड़ा गया। UPDATE/DELETE हमेशा block होंगे; bill केवल एक बार insert हो सकता है।
- Insert trigger customer-approved completion RPC के transaction-scoped authorization को verify करता है, booking row FOR UPDATE lock करता है, stopped timer/pending completion approval/owner/electrician/category/rate snapshot verify करता है और billable minutes, labour paise, 15% Platform Fee paise तथा electrician net amount स्वयं दोबारा calculate करके incoming snapshot से compare करता है।
- इससे service-role या accidental direct insert भी ग्राहक की मंजूरी, server timer और approved rate से अलग amount/bill नहीं बना सकता। Customer completion approval और bill insert एक ही transaction में रहते हैं।
- Database test file अब 96 pgTAP assertions घोषित करती है; execute अभी बाकी है। Migration source-only/unapplied है।

### 19.21 Source regression और isolated database CI विस्तार (13-11-2026)
- Feature branch का Node regression workflow अब OTP के साथ labour calculator, booking handler, electrician application handler और Razorpay payment handler test suites भी चलाता है।
- Isolated Supabase workflow को सभी pending feature migrations तक बढ़ाया गया; migration apply केवल temporary local Supabase database में होता है। इसके बाद सभी pgTAP database tests, schema lint और critical object smoke checks चलेंगे।
- Supabase workflow केवल manual dispatch पर चलता है और SUPABASE_DB_URL के लिए dedicated schema-only, least-privilege credential आवश्यक है। इसे अभी dispatch नहीं किया गया; कोई production write या migration apply नहीं हुआ।
- नवीनतम branch commits पर Vercel check अभी build-rate-limit failure दिखाता है; सफल Vercel build/CI का दावा नहीं है।


## 17.118 — Master Checklist Item 14.1: Customer पाँच-मेनू Source Audit और Regression Coverage (13 Nov 2026)

- 14.1 की मूल पाँच-मेनू आवश्यकता और Issue #5 के क्रम में Feature Branch पर `booking.html` का source audit किया गया। Existing navigation पहले से मौजूद है; duplicate tabs या duplicate menu shell नहीं जोड़ा गया।
- Existing menu order source में ठीक यही है: Home → My Bookings → Payments → Help & Support → My Profile. ARIA tablist/tab/tabpanel roles, selected state, keyboard Arrow/Home/End navigation और single active panel switching मौजूद हैं।
- Home: authenticated customer dashboard, signed-in identity, नई booking action और existing booking form तक navigation मौजूद है। Booking form dashboard के बाहर shared page section है; booking submission के लिए existing authenticated API path ही इस्तेमाल होता है।
- My Bookings: booking list refresh, server-backed work timeline, work-start approval, live timer display, completion approval/rejection/dispute, final labour bill, payment action, cancellation request और refund request/history के source paths मौजूद हैं। इनकी वास्तविक Supabase runtime/E2E verification अलग से लंबित है।
- Payments: verified payment history pagination और server RPC आधारित payment receipt/print-to-PDF path मौजूद है। Receipt code स्पष्ट करता है कि यह tax invoice नहीं है। इस audit में कोई नया payment-collection control Payments menu में नहीं जोड़ा गया; existing payment initiation path My Bookings के final bill context में है।
- Help & Support: complaint creation, booking association, category/description, complaint selection/status, private message thread और allowed file attachments के UI/handler paths मौजूद हैं; Admin reply linkage अलग backend implementation में है। Storage/RLS/RPC runtime access tests अभी आवश्यक हैं।
- My Profile: customer name, read-only OTP phone, avatar upload/preview, language preference, profile save और saved-address navigation मौजूद हैं। Saved-address CRUD controls existing booking form के saved-address panel में हैं; Profile link उसी section तक scroll/focus करता है।
- इस pass में वास्तविक gap यह था कि पाँच menu navigation तथा इन panels/actions के बीच wiring के लिए अलग source regression suite नहीं थी। `tests/customer-menu.test.cjs` जोड़ी गई और `test:customer-menu` script को `.github/workflows/otp-source-tests.yml` में शामिल किया गया।
- Verification: source regression workflow Run `43433887243` (SHA `369c25c990f48cf0d3b6ce651798389a6d287cff`) **Success**. Prior Customer Login/session fix workflow Run `43433513585` (SHA `740049cdc0fc16d79f305b6169af4510fe4f0a57`) भी **Success**.
- **Status: In Progress — source navigation/panel wiring and regression coverage verified; Customer App menu acceptance अभी पूर्ण नहीं।** Pending: database migration history/schema drift reconciliation; Supabase RPC/RLS/storage runtime tests; legacy payment/order/webhook/finalizer compatibility audit; complete ratings/reviews/notification/privacy/security subfeatures; browser functional test; final consolidated mobile/Desktop QA (इसे सभी checklist tasks के बाद ही करना है)।
- कोई production database, customer data, Auth/provider setting, payment/payout, Main merge या deployment नहीं बदला। किसी menu को पूर्ण घोषित नहीं किया गया।


## 17.119 — Electrician Portal Login/Dashboard Initial Source Audit (13 Nov 2026)

- Customer five-menu audit के बाद अगला role Electrician है। Feature Branch electrician.html और संबंधित migrations का initial source audit किया गया; existing functions को duplicate नहीं किया गया।
- वर्तमान portal में OTP login, authenticated dashboard, profile row lookup, active/verification state, realtime job-offer refresh, booking offer response, customer details display, earnings, Platform Fee due, wallet/ledger read views, server-authoritative work-start request, work-completion request, final labour bill read और actual cash receipt confirmation paths मौजूद हैं।
- **मुख्य menu gap:** वर्तमान HTML में कोई navigation/tab/menu shell नहीं है। Offers, Earnings, Platform Fee due और Wallet सभी एक ही लंबी dashboard surface पर हैं। अलग My Work/Bookings view, Profile/ID panel और Help & Support panel source में प्रमाणित नहीं हुए।
- **Profile gap:** dashboard approved name, phone, district/state/PIN, approved rate tier और verified skill keys को read-only summary में दिखाता है; electrician self-service profile edit, document/ID management, profile photo या notification preferences का panel नहीं मिला। Admin-approved fields को electrician द्वारा बदलने की अनुमति स्वतः नहीं जोड़नी है।
- **Support gap:** उपलब्ध complaint/message RPC migration customer ownership (customer_user_id = auth.uid()) और Admin reply के लिए है। Electrician-specific complaint/message/attachment RPC तथा storage ownership policy इस inspected migration set में नहीं मिली। Customer-only RPC को electrician UI से call करना गलत authorization होगा; साझा ticket model या electrician-scoped policy/API के बिना support panel activate नहीं किया जाएगा।
- **Security fix:** dashboard status string में database-derived verification_status को innerHTML में interpolate किया जा रहा था। इसे textContent और controlled class assignment से बदला गया ताकि stored HTML/markup execute न हो। बदलाव commit 4755d998b957e6e0780032d03ca5a21d47160975 में है।
- Added tests/electrician-portal.test.cjs for safe status rendering, offer/contact UI markers, work lifecycle RPC wiring and read-only earnings/wallet/payout boundaries; test:electrician-portal script and CI workflow step also added.
- **Status: In Progress — initial audit and one source-safety correction implemented; full Electrician role menu/features not complete.** Pending: exact offer-vs-assigned-work lifecycle audit; electrician timeline read API/UI; proper six-section navigation; profile/ID management contract; electrician support ticket/message/attachment API and RLS; rating/review and notification requirements; backend runtime and browser tests.
- No live booking, customer/electrician contact data, payout, bank transfer, database, Auth/provider setting, production deployment or Main merge changed. Final mobile/Desktop QA remains deferred until all checklist tasks are complete.


## 17.120 — Electrician App के छह Sections और Work/Offers विभाजन (13 Nov 2026)

- Master checklist 14.1.8 के अनुसार Electrician App के छह आवश्यक भाग: Home, New Booking Offers, My Work/Bookings, Earnings & Wallet, Profile/ID और Help & Support.
- Feature Branch `electrician.html` में पहले कोई menu navigation नहीं था; सभी cards एक ही dashboard पर थे। अब छह accessible menu tabs/panels जोड़े गए हैं, keyboard Arrow/Home/End navigation और selected-tab state सहित।
- New Booking Offers और My Work/Bookings अब अलग-अलग views हैं। Server RPC `srk_get_my_offer_details` से प्राप्त rows को offered बनाम accepted/assigned/active/completed booking status के आधार पर विभाजित किया जाता है; existing offer/work action renderer साझा है, duplicate data/API नहीं बनाया गया।
- Earnings & Wallet में existing earnings, payout history, Cash Platform Fee due, wallet summary/ledger और bank-link read-only display समूहित हैं। Payout/bank mutation controls सक्रिय नहीं किए गए।
- Profile/ID panel केवल existing Admin-approved profile summary दिखाता है; sensitive approved fields को electrician self-edit करने का विकल्प नहीं जोड़ा गया।
- Help & Support panel स्पष्ट रूप से बताता है कि electrician-specific ticket/message/attachment API और RLS अभी उपलब्ध नहीं हैं। Customer-only support RPC को गलत तरीके से reuse नहीं किया गया और कोई नकली support submission control नहीं दिखाया गया।
- Dashboard verification status की prior XSS-safe `textContent` rendering बनी हुई है।
- Regression suite `tests/electrician-portal.test.cjs` में six-tab order, unique panel mapping, keyboard navigation, offer/work separation, support limitation और inline JavaScript parsing के tests हैं। Run `43434702321`, SHA `ffb543f54c9eb38f33cd2a4fe6a0a6102cc6e12d` — **Success**. Earlier feature markup run `43434536078` भी Success; बीच के test parser assertion में एक syntax error आया था, जिसे ठीक कर बाद के passing run में validate किया गया।
- **Status: In Progress — six-section navigation and separate offers/work source views verified; Electrician App पूर्ण नहीं।** Pending: electrician timeline API/UI; electrician-specific support backend/RLS/attachments; unique digital ID and document management; rating/review and notifications; accepted/completed-state contact/data removal proof; Supabase runtime/JWT tests; browser E2E; final mobile/Desktop QA.
- कोई production DB, live booking/contact, bank transfer/payout, Auth setting, Main merge या deployment नहीं बदला।
