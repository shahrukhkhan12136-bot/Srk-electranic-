# SRK ELECTRONIC

SRK ELECTRONIC वेबसाइट और electrician booking marketplace का मुख्य repository.

## मुख्य product requirements

**एकमात्र समेकित business/product requirements source:**

- [SRK ELECTRONIC Master Requirements (Hindi)](docs/SRK_ELECTRONIC_MASTER_REQUIREMENTS_HI.md)

इस दस्तावेज़ में customer booking, electrician categories/verification, server timer और actual-minute billing, Cash/Online payment, Platform Fee/wallet, cancellation, phone privacy, Help, ratings, Admin staff permissions, company expenses, Master Dashboard, Emergency Controls और implementation guardrails के वर्तमान स्वीकृत नियम हैं।

नियमों में टकराव होने पर Master Requirements में दर्ज नया निर्णय पुराने प्रस्ताव को supersede करेगा। पुराने code, database columns, RPCs या migrations को dependency audit और सुरक्षित migration के बिना delete नहीं करना है।

## Project architecture

- Frontend: static HTML/JavaScript pages
- Hosting/functions target: Netlify
- Backend/database/auth: Supabase
- Online payment integration: Razorpay
- Primary Supabase project: `gnqhoaqatmoiwwhgzkgm`

Repository में ऐतिहासिक रूप से `/`, `/admin.html`, `/electrician.html` और Netlify API functions जैसे `/api/create-booking`, `/api/apply-electrician`, `/api/create-order`, `/api/verify-payment` रहे हैं। इनके वर्तमान व्यवहार और production availability को implementation status समझने से पहले branch और deployment पर verify करें।

## Security

- Supabase service-role key और Razorpay secrets केवल server-side environment variables में रहें; browser code, commits या chat में नहीं।
- Authorization केवल UI पर निर्भर न हो; server/API/RPC और Supabase RLS पर लागू हो।
- Payment, timer, wallet, cancellation, category eligibility और staff permissions का authoritative निर्णय server-side हो।
- Financial ledger और audit history को silently edit/delete न किया जाए।

## Development and deployment guardrails

- Consolidated requirements और technical audit के बाद ही Feature Branch पर implementation करें।
- `main` merge, production Supabase migrations, Netlify production deployment और live-money movement के लिए अलग स्पष्ट अनुमति आवश्यक है।
- Netlify production deploy availability और Razorpay live permissions को deployment से पहले verify करें।
- सभी features को complete तभी कहें जब UI, API/RPC, database security, regression tests और end-to-end tests सफल हों।
