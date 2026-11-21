# SRK ELECTRONIC — लाइव प्रगति डैशबोर्ड

**अंतिम सत्यापित अपडेट:** 21 नवम्बर 2026  
**वर्तमान staging branch:** tmp/master-final-ui-20261121  
**Feature base:** feature/master-rating-ui-followup-v2-20261121  
**सत्यापित source HEAD:** 1478a4ae221d969ae39ec2d707064f124876842b

> Source implementation, Node CI, PostgreSQL/pgTAP runtime, Browser E2E, Preview, Production migration और Owner approval अलग-अलग gates हैं। किसी एक का PASS दूसरे का प्रमाण नहीं है।

## एक नज़र में

| चरण | स्थिति | विवरण |
|---|---|---|
| Source implementation | जारी, काफी विस्तारित | Shared Technician onboarding/KYC/Admin approval, Master dispatch, Customer workday decisions/team GPS, GST final bill/invoice, cash payment/refund और wallet credits UI source में मौजूद। |
| Node CI | **PASS** | Exact HEAD 1478a4ae पर GitHub Actions run 44907394337: **573 passed / 0 failed**। |
| Database runtime | अवरुद्ध / NOT RUN | Supabase Pro Development Branch सुविधा उपलब्ध नहीं। Local replay attempt में authoritative core baseline missing होने से migration replay शुरू नहीं हो सका। कोई pgTAP test execute नहीं हुआ। |
| Browser E2E | बाकी | OTP/SMS, KYC Storage, dispatch, timer, bill, payment/refund, payout, actor isolation और browser workflows runtime verify करने हैं। |
| Preview / Visual QA | वर्तमान staging HEAD पर नहीं चला | Netlify/Vercel Preview और desktop/mobile visual acceptance को current staging PR पर अलग verify करना होगा। पुराने Preview statuses current HEAD पर लागू नहीं। |
| Main PR / Release | अभी नहीं | Current staging changes का feature-branch review बाकी है। Main PR, merge, Production migration और deployment नहीं किए गए। |

## वर्तमान source में शामिल मुख्य काम

- Shared Technician App: OTP-first application, multiple service categories/skills, private KYC upload, Admin skill/KYC review और approval gate।
- Master dispatch: unified offer inbox, online/GPS presence, 30 km eligibility, Admin dispatch queue और retry।
- Customer: Assigned Technician names/team, booking-scoped GPS, workday start approval, तीन daily decisions, normal/overtime breakdown।
- Billing: immutable Master final bill, configurable GST snapshot, Customer GST invoice/credit-note view।
- Admin manual payment verification: completed unpaid cash/UPI/bank bookings; Razorpay-linked bookings excluded; GST-inclusive total due और actual receipt/UTR check।
- Cash refund: Technician inbox केवल Admin-approved refund requests दिखाता है; Admin finalization GST-inclusive amount validate करती है; commission reversal और recovered-commission wallet credit payout flow से जुड़ा है।
- Technician Wallet: commission refund credit available/requested/paid/history दिखाता है।
- Rates: 36 active confirmed rate levels; 6 pending Admin rows। Customer booking list में Technician/Helper hourly तथा 8-hour salary और combined total।
- New Master booking में quote approval flow नहीं है; historical quote data archival compatibility के लिए preserved है।

## अभी वास्तविक blockers

1. Road-distance travel fee 3 km free, फिर ₹4/km one-way अभी implement/runtime-verified नहीं। GPS straight-line distance को road distance नहीं मानेंगे। Approved routing provider और server-side API credential/configuration चाहिए।
2. AC Installation/Repair का ₹437/hour combined team total दर्ज है, लेकिन Technician/Helper pay split pending है। Basic Electrician Helper, Pump Repair और 20 HP से ऊपर की Motor/Cooler winding rates भी Admin approval तक pending हैं।
3. Founder का actual approved original photo अभी upload नहीं हुआ। कोई generated/alternate portrait substitute नहीं होगी।
4. 112 SQL migrations और 55 pgTAP test files source में हैं; authoritative pre-existing core schema/Auth/Storage baseline और duplicate migration-version history reconcile करनी है। इसके बाद disposable PostgreSQL/Supabase में migration replay और सभी pgTAP tests चलेंगे।
5. Hosted schema/role parity, OTP/SMS, KYC Storage, Push provider delivery, concurrency/actor ACL, ledger reconciliation, backup/restore integrity और full Browser E2E।
6. Current staging branch पर Netlify/Vercel Preview, desktop/mobile QA और owner acceptance बाकी।

## सुरक्षा और रिलीज़ नियंत्रण

- Main Branch और Production Database untouched हैं।
- कोई migration किसी database पर apply नहीं हुई।
- कोई live payment, refund, payout, SMS/Push provider action या deployment नहीं किया गया।
- Pro Plan restriction के कारण Supabase Development Branch नहीं बनी। GitHub-hosted local replay attempt भी baseline dependency पर fail हुआ; premature workflow हटा दिया गया। इसलिए pgTAP runtime को PASS नहीं कहा जाएगा।
- Main PR अभी नहीं खोला गया; merge/deploy/Production migration के लिए अलग owner approval आवश्यक रहेगा।

---

## प्रगति इतिहास — 2026-11-16 (नवीनतम)

### Customer App — SOS account-switch isolation
- समस्या: SOS RPC लंबित रहते अकाउंट बदलने पर पुराने अनुरोध का परिणाम नई session UI को प्रभावित कर सकता था।
- सुधार: SOS submit अब account generation snapshot और auth.getSession() से वर्तमान session पहचानता है; stale response/error UI में लागू नहीं होता और busy/button state केवल उसी generation में restore होती है। Auth change पर SOS busy set साफ होता है।
- Regression test: tests/sos-two-step-ui-contract.test.js में Customer SOS generation/session/finally guards के assertions जोड़े।
- Commits: source 91a47765859570ffb6d87d7fdc031875414a19d2; test 6c4652458a8afc787b9af4d279ffa76e732de4b0।
- सत्यापन: latest source/test blob re-fetched; latest HEAD पर GitHub Actions run उपलब्ध नहीं। Runtime/Supabase और browser परीक्षण बाकी।

### Customer App — Saved Address save/delete account isolation
- समस्या: Save/Delete address RPC, reconciliation lookup या list refresh के दौरान अकाउंट बदलने पर पुराने request का परिणाम नई session की address list/status/button को बदल सकता था।
- सुधार: दोनों actions में account generation और session user ID capture; हर async boundary के बाद generation/session re-check; stale request UI update नहीं करता और finally केवल उसी session में button restore करता है।
- Commit: 1ec27f8dc7fbbe7c6200f1920481f80388b919bb।
- सत्यापन: source update commit हुआ; regression tests अभी जोड़ने/जाँचने बाकी हैं। GitHub Actions run उपलब्ध नहीं। Runtime और browser परीक्षण बाकी।

### शेष / अगला कदम
- Saved Address Save/Delete के लिए focused regression tests जोड़ना और Default Address action की account-switch isolation जाँचना।
- Customer payment-method change सहित बाकी async mutations का source audit।
- इसके बाद Electrician App के शेष स्वीकृत items और Master Checklist reconcile करना।
- Manual mobile QA, Browser E2E और DB runtime परीक्षण implementation समाप्त होने तक स्थगित हैं।

सुरक्षा: PR #8 OPEN / DRAFT / UNMERGED; Production deploy, Production DB बदलाव और paid staging creation नहीं किए गए।


## प्रगति प्रतिशत रिपोर्टिंग नियम — 2026-11-16

आगे से हर प्रगति रिपोर्ट में प्रतिशत अनिवार्य होगा। प्रतिशत हमेशा सत्यापित checklist के पूरे/कुल items से निकलेगा; अनुमान या मनमाना प्रतिशत नहीं दिया जाएगा। जहाँ denominator या item status reconcile नहीं हुआ है, वहाँ स्पष्ट रूप से 'प्रतिशत अभी सत्यापित नहीं' लिखा जाएगा। अलग-अलग हिस्सों के प्रतिशत अलग दिखेंगे:
- पूरे SRK ELECTRONIC प्रोजेक्ट का प्रतिशत।
- GPT-1 Customer App का प्रतिशत।
- GPT-1 Electrician App का प्रतिशत।
- Welcome Screen/Founder-photo का प्रतिशत (पूर्ण कार्य दोबारा नहीं खोला जाएगा, जब तक defect न मिले)।
- Implementation, Source Tests, Database Runtime, Browser E2E और Final Mobile QA के अलग-अलग प्रतिशत।

पुराने dashboard snapshot में Master Checklist के 86 items में 56 पूरे (65%) दर्ज थे। यह पुराना मापा हुआ आंकड़ा है; अगली रिपोर्ट में वर्तमान checklist को दोबारा reconcile करके ही इसे अद्यतन किया जाएगा। Source code में बदलाव को runtime या QA completion नहीं गिना जाएगा।


### 2026-11-16 — Customer Saved Address और Payment Method account-switch audit (जारी)
- Save और Delete Saved Address handlers में account-generation तथा session-user validation जोड़ी; RPC, uncertain-result reconciliation और list refresh के बाद पुरानी session UI update नहीं कर सकती।
- Default Saved Address handler को भी generation/session guards दिए। Source correction के दौरान original Default handler वापस जोड़ा और async declarations सत्यापित कीं; अंतिम fetched source में duplicate async declaration नहीं है।
- Auth बदलने पर Save/Delete/Default buttons reset होते हैं, ताकि पुराना in-flight request controls को disabled न छोड़े।
- Customer payment-method change RPC और उसके reconciliation/refresh paths में भी session generation guard जोड़ा।
- Regression tests: tests/customer-profile-auth-isolation.test.js में Save/Delete, Default, Payment Method तथा auth-change button reset के चार focused source-contract tests जोड़े। कुल इस फ़ाइल में 7 tests मौजूद हैं।
- Commits: source 9b300c3c1e4d297a89be3dda388f74faa0859f77 और a8a10edfc5f37161c214c6c62571578af3c0431b; tests 307c0aaa7f7de7fe4a400bdf81d2e3a217944c22।
- अंतिम recheck: booking.html और test file के latest blob IDs fetch किए; सभी चार handlers मौजूद और async declaration marker सही। Current HEAD a8a10edfc5f37161c214c6c62571578af3c0431b पर GitHub Actions run उपलब्ध नहीं; tests execute नहीं हुए माने जाएँ।

**इस सीमित Customer async-isolation workstream की प्रगति:** Code changes 100%; regression tests लिखे 100%; automated execution/CI 0% (अभी run उपलब्ध नहीं); Supabase runtime/browser validation 0% (final QA चरण में)। यह workstream प्रतिशत है, पूरे Customer App या पूरे project का नया प्रतिशत नहीं। पूरे project का पिछला सत्यापित checklist snapshot 56/86 = 65% था; current checklist recount अभी बाकी है।


### 2026-11-16 — Customer Payment Receipt session isolation
- Audit में `customerPrintPaymentReceipt()` मिला: receipt RPC pending रहते session बदलने पर पुराने ग्राहक की receipt popup में render हो सकती थी।
- सुधार: receipt action अब customer action generation और वर्तमान auth session user ID capture करता है; receipt RPC के बाद session दोबारा जाँची जाती है। Session stale होने पर popup बंद होता है और stale session के नाम पर error alert नहीं दिखता।
- Regression test: `tests/customer-electrician-payment-history-contract.test.js` में receipt popup stale-session guard का source-contract test जोड़ा। इस test file में अब 14 tests हैं।
- Commits: source `5150f1d7f9d10e26bb689f510f4e14d8eee046b6`; test `ed611b06c90aded0401aa4d49c2a9f1f2f241886`।
- अंतिम source/test re-fetch: receipt में generation/session guard और stale होने पर popup close verified। Current HEAD `ed611b06c90aded0401aa4d49c2a9f1f2f241886` पर GitHub Actions run उपलब्ध नहीं; automated tests execute होने का प्रमाण नहीं।
- उसी source pass में Support Messages/Attachments के render path की जाँच की: attachment/message results outer thread generation + request ID check के बाद ही UI में render होते हैं। OTP send/verify और logout auth-transition flows को अलग से देखा; इस pass में उन पर कोई बदलाव नहीं किया।

**Customer async account-isolation audit workstream (अब तक किए गए इन handlers के दायरे में):** source changes 100%; regression tests लिखे 100%; automated execution/CI 0%; Supabase runtime validation 0%; browser/mobile validation 0% (implementation के बाद final QA)। ये प्रतिशत केवल इस audit workstream के हैं; पूरे Customer App या project के नहीं।


### 2026-11-16 — Customer Razorpay payment session isolation
- Audit में Razorpay create-order/checkout/verify flow मिला: भुगतान के दौरान ग्राहक session बदलने पर पुराना payment callback नई session की payment status UI या reconciliation को प्रभावित कर सकता था।
- सुधार: payment start पर customer action generation capture; create-order के बाद session re-check; verify request पुराने captured bearer token से ही server पर जाती है; UI status, reconciliation और final button reset केवल original generation/session के लिए। Payment callback account switch के बाद नई session में UI update नहीं करता।
- Regression test: `tests/customer-electrician-payment-history-contract.test.js` में Razorpay account-switch guard का focused source-contract test जोड़ा। इस file में अब 15 tests हैं।
- Commits: source `4e68624b4a492c69398f68c5b305dd3742f38479`; test `c6d764bff4946a986a74e458d86a2a7195dffdb7`।
- सावधानी: अगर payment verification का network result account switch के बाद uncertain हो, पुरानी session के reconciliation RPC को नई session से नहीं चलाया जाता; ग्राहक दोबारा original account में लॉगिन कर payment history जाँच सकता है। Duplicate payment का जोखिम बढ़ाने वाला auto-retry नहीं जोड़ा।
- Current HEAD `c6d764bff4946a986a74e458d86a2a7195dffdb7` पर GitHub Actions run उपलब्ध नहीं; test execution का दावा नहीं।

**Customer async account-isolation audit — मापी गई उप-प्रगति:** इस audit batch में पहचाने गए और सुधारे गए handlers के source changes 100%; संबंधित source-contract tests लिखे 100%; automated execution/CI 0%; Supabase/payment-provider runtime 0%; Browser E2E और Final Mobile QA 0% (implementation पूर्ण होने के बाद)। यह केवल इस audit batch का प्रतिशत है; पूरे Customer App/Project का प्रतिशत नहीं।


### 2026-11-16 — Customer OTP Login / Logout और Session Synchronization audit
- Source audit में `syncCustomerSession()` के async getSession और sequential dashboard loads के दौरान auth generation बदलने पर पुरानी session का login/dashboard state लागू होने की संभावना मिली। अब generation snapshot लिया जाता है; session read और हर awaited loader के बाद stale generation पर flow रुकता है।
- `customerSendOtp()` में generation guard जोड़ा: पुराने OTP send response/error नई session UI नहीं बदलेगा; finally केवल उसी generation का busy/button state restore करता है।
- `customerVerifyOtp()` में OTP verification के बाद वर्तमान session दोबारा पढ़कर session user phone को requested phone से मिलाया जाता है; mismatch पर login success नहीं दिखता। Auth transition के बाद पुराने finally से नए request का busy state नहीं छेड़ा जाता।
- `customerLogout()` में stale logout result/error/message और finally button changes guard किए। Auth transition listener OTP busy state, OTP controls और Logout button recover करता है।
- Regression tests: `tests/customer-profile-auth-isolation.test.js` में session sync, OTP send, OTP verify, logout, auth transition OTP controls और logout button recovery के 6 focused assertions/tests जोड़े; file में कुल 13 tests हैं।
- Commits: source `ecc8ac44ad3a081a630d051a383a7b7f58e216a2`, `e100e29e23e4a37bcae8a7c3dd488607e8b32978`; tests `91786fd35a2d78edb7d3467e0363aab7f4adac0b`, `2a30881da6b2ed238840b6041cd90af2acf73194`।
- Final source/test re-fetch पर सभी मुख्य guards और handlers मौजूद; duplicate `async async` declaration नहीं मिली। Latest HEAD `f208be0a5d3943322a56c92c1d5951f877238291` पर GitHub Actions runs की सूची खाली; test execution/pass का दावा नहीं।

**इस Customer OTP/Logout audit batch की मापी हुई प्रगति:** source changes 100%; regression tests लिखे 100%; automated execution/CI 0%; Supabase Auth runtime validation 0%; Browser E2E 0%; Final Mobile QA 0% (implementation समाप्ति के बाद)। यह केवल इस batch का प्रतिशत है। पूरे Customer App/Project का प्रतिशत बदलने से पहले Master Checklist का पुनर्मिलान जरूरी है।


### 2026-11-16 — GPT-1 checklist count और latest HEAD reconciliation
- Master Checklist के Customer (10), Electrician (10) और Welcome/Founder Photo (8) sections के वास्तविक checkboxes पुनर्गिने: Customer 9 पूरे/1 बाकी; Electrician 9 पूरे/1 बाकी; Welcome 4 पूरे/4 बाकी। इसलिए GPT-1 कुल **22/28 = 79%**, **6 बाकी** है। पहले दर्ज 21/28 = 75% एक checkbox कम गिनने के कारण गलत था; Master Checklist header सुधारा गया।
- PR #8 latest source/documentation HEAD: `1c6a03bdd891fee61a71b368991b83ffd7acfb20`; PR OPEN / DRAFT / UNMERGED। इस HEAD पर GitHub Actions workflow run उपलब्ध नहीं; Vercel status build-rate-limit failure। इससे पहले source HEAD `5bd2896d898449a6290883c5750b5475a092eb68` पर Netlify Deploy Preview success और Vercel build-rate-limit failure मिला था।
- यह checklist/dashboard documentation correction है; Customer/Electrician application code, database, provider, deployment, merge या mobile QA में बदलाव नहीं।
