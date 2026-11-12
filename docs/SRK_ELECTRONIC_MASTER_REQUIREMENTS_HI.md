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
