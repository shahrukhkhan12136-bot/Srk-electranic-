# SRK ELECTRONIC — AI खर्च बजट सुरक्षा योजना

**स्थिति:** स्वीकृत योजना / अभी लागू नहीं  
**तारीख:** 20 नवंबर 2026  
**कार्य शाखा:** `feat/ai-rate-management-foundation-20261118`

## 1. मालिक द्वारा तय प्रस्तावित सीमा

| नियंत्रण | प्रस्तावित सीमा |
|---|---:|
| दैनिक AI खर्च | ₹20 |
| मासिक AI खर्च | ₹500 |
| चेतावनी सीमा | 80% — दैनिक ₹16, मासिक ₹400 |
| दैनिक समय-क्षेत्र | `Asia/Kolkata` |
| मासिक समय-क्षेत्र | `Asia/Kolkata` |

मासिक ₹500 सीमा निर्णायक होगी। 30 दिन × ₹20 = ₹600 हो सकता है, इसलिए मासिक ₹500 पार नहीं होने देना है।

ये सीमाएँ अभी केवल योजना हैं। इन्हें किसी लाइव सिस्टम में सक्रिय नहीं किया गया है।

## 2. जरूरी तकनीकी तथ्य

Vercel AI Gateway का खर्च मॉडल, provider और input/output tokens पर निर्भर करता है। Generation ID से `GET /v1/generation?id=...` द्वारा वास्तविक USD लागत बाद में प्राप्त की जा सकती है। Usage रिकॉर्ड कुछ समय बाद उपलब्ध हो सकता है, इसलिए lookup में retry/backoff चाहिए।

Vercel Gateway के अपने budgets को अकेला hard stop नहीं मानना है: Gateway budget soft cap है — सीमा पार कराने वाला एक अनुरोध पूरा हो सकता है। BYOK अनुरोध भी Gateway budgets में नहीं गिने जाते। इसलिए ऐप के अपने सर्वर/डेटाबेस पर अलग atomic बजट नियंत्रण जरूरी है।

## 3. लागू करने का सुरक्षित क्रम

1. **पहले अनुरोध की लागत आरक्षित करें:** AI Gateway को कॉल करने से पहले डेटाबेस में उस अनुरोध के लिए अधिकतम सत्यापित संभावित लागत आरक्षित हो।
2. **एक ही atomic निर्णय:** डेटाबेस transaction/row lock दैनिक और मासिक उपलब्ध राशि जाँचे; एक साथ आए अनुरोध सीमा को पार करके आरक्षण न ले सकें।
3. **अज्ञात मॉडल पर रोक:** मॉडल/provider का सटीक चयन, अधिकतम input/output token सीमा और मौजूदा मूल्य सत्यापित न हों तो AI अनुरोध न भेजें।
4. **अधिकतम अनुरोध लागत का प्रमाण:** प्रति-अनुरोध आरक्षण चुने गए मॉडल, provider route, token ceilings और वर्तमान मूल्य से निकले worst-case ceiling से कम नहीं होना चाहिए। केवल औसत कीमत या अनुमान पर निर्भर न रहें।
5. **मुद्रा रूपांतरण का प्रमाण:** USD→INR दर, स्रोत और समय को हर आरक्षण के साथ snapshot करें। पुरानी/अनुपलब्ध दर होने पर fail closed करें; कोई hardcoded विनिमय दर नहीं।
6. **वास्तविक खर्च मिलान:** Generation ID से Gateway की वास्तविक लागत लें और उसी आरक्षण को वास्तविक INR लागत से settle करें।
7. **लागत अभी न मिली हो:** आरक्षण को pending रखें। जब तक लागत का मिलान न हो, राशि को उपलब्ध बजट में वापस न जोड़ें।
8. **वास्तविक लागत आरक्षण से अधिक हो:** घटना को budget breach के रूप में दर्ज करें और आगे के अनुरोध रोकें; इसे छिपाएँ या शून्य लागत न मानें।
9. **सीमा और चेतावनी:** वास्तविक खर्च + लंबित आरक्षण दोनों को उपयोग में गिनें। 80% पर चेतावनी; सीमा पर नए अनुरोध बंद।
10. **ऑडिट:** प्रत्येक आरक्षण, settlement, FX दर/स्रोत, चेतावनी, असफल lookup और admin सीमा परिवर्तन का append-only audit record रखें।

## 4. आवश्यक डेटाबेस/सेवा घटक

- निजी budget configuration: ₹20 daily, ₹500 monthly, 80% warning, `Asia/Kolkata`, default disabled।
- Atomic budget reservation RPC: प्रति अनुरोध अधिकतम सत्यापित INR ceiling reserve करे।
- Reservation ledger: attempt ID, daily/monthly period, reserved INR, FX snapshot, status और timestamps।
- Cost reconciliation worker: Gateway generation lookup, bounded retry/backoff, reported/unavailable status।
- Settlement RPC: केवल उसी attempt की reservation को एक बार settle करे; duplicate worker execution से दोहरी गिनती न हो।
- Admin read view/API: आज/इस महीने का वास्तविक खर्च, pending reservation, उपलब्ध सीमा, model-wise cost और warnings।
- Admin write permission: budget बढ़ाना/बदलना केवल अधिकृत Admin और audit trail के साथ; AI activation अलग explicit approval रहेगा।

## 5. Fail-closed स्थितियाँ

इनमें से किसी भी स्थिति में नया AI अनुरोध नहीं भेजना है:
- budget configuration disabled या missing हो;
- मॉडल/provider की कीमत या maximum request cost सत्यापित न हो;
- FX rate missing, stale या invalid हो;
- atomic reservation RPC विफल हो;
- दैनिक/मासिक उपलब्ध राशि अपर्याप्त हो;
- पिछली लागत की reconciliation अटकी हो और सुरक्षित आरक्षण उपलब्ध न हो।

किसी भी failure पर अनुमानित लागत को ₹0 नहीं लिखना है।

## 6. अनिवार्य परीक्षण

- ₹16 daily और ₹400 monthly पर 80% चेतावनी।
- ₹20 daily या ₹500 monthly की सीमा पर अगला अनुरोध अस्वीकृत।
- समान समय पर कई अनुरोध: atomic lock से सीमा पार आरक्षण न हो।
- भारत के स्थानीय दिन/महीने की सीमा पर सही reset।
- idempotent replay पर दूसरा reservation न बने।
- pending generation cost उपलब्ध बजट में सुरक्षित रूप से reserved रहे।
- Gateway cost 404/late response पर retry और pending state कायम रहे।
- invalid/stale FX या model pricing पर fail closed।
- actual cost reserve से अधिक हो तो breach दर्ज हो और आगे के अनुरोध रुकें।
- duplicate settlement से खर्च दो बार न जुड़े।
- browser roles को private ledger/config तक direct access न मिले।

## 7. Vercel Gateway की द्वितीयक सुरक्षा

बाद में, जब live provider/model और Vercel project/key स्पष्ट हों, तब Vercel AI Gateway पर उपलब्ध scope के अनुसार अतिरिक्त daily/monthly budget भी configure किया जा सकता है। इसे केवल दूसरी सुरक्षा परत मानें; ऐप का atomic INR budget इसका विकल्प नहीं है।

Gateway की budget settings, API keys, credits या live request अभी नहीं बदले जाएँगे।

## 8. अभी क्या नहीं किया गया

- कोई live AI request नहीं भेजी गई।
- कोई AI Gateway key, model, provider या budget सक्रिय/बदला नहीं गया।
- कोई hosted Supabase migration या database mutation नहीं हुई।
- कोई FX rate hardcode नहीं हुई।
- Admin Panel में live controls नहीं जोड़े गए।
- ऐप launch, Developer Branch, Main merge या production deployment नहीं हुआ।

## 9. अगला implementation gate

पहले cost reconciliation worker और उसके database claim/settle tests पूरे हों। उसके बाद exact model/provider और verified maximum per-request cost ceiling के आधार पर atomic INR reservation बनाएं। जब तक वह ceiling गणितीय रूप से ₹20/day और ₹500/month की सीमा में enforce न हो सके, budget guard को disabled रखें और AI को fail closed रखें।
