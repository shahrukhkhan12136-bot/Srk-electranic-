# Staff Dashboard — Scaffold

यह Staff Dashboard का नियोजित workspace है। अभी यह README-only scaffold है; कोई live Staff login, role, UI या production database change इससे लागू नहीं हुआ है।

## Intended workflow
1. Staff signs in using an individual account.
2. Verify caller/customer identity using approved safe matching.
3. Open only relevant customer, booking, assigned electrician, bill/payment and complaint context.
4. Create or update a complaint with category, priority, notes, owner, timestamps and SLA.
5. Follow approved cancellation-support script and inspect booking state, arrival evidence and Admin decision.
6. Escalate disputes, safety issues, refunds and exceptions to Admin.
7. Record staff actions in an auditable event history.

## Strict permission boundary
Staff cannot:
- Approve or execute refunds.
- Change commission, rates or payouts.
- Mark payments/payouts as received without evidence.
- access unrestricted customer lists or full database.
- reveal phone numbers outside authorized booking/support context.
- create or disclose Admin credentials or secrets.

## Cancellation support
Use the approved neutral script: “जी, आपकी बुकिंग कैंसिल करने में हम सहायता करेंगे। कैंसिलेशन चार्ज आपकी बुकिंग की स्थिति और हमारी पॉलिसी के अनुसार लागू हो सकता है। पहले हम आपकी बुकिंग की स्थिति जाँच लेते हैं।”

₹99 fee eligibility requires customer-requested cancellation + recorded electrician arrival evidence + Admin approval. Without evidence/no arrival, no fee. Actual collection is not implemented. Staff must not independently impose, approve or collect the fee.

## Future integrations
Cloud telephony/IVR, queues and up to 20 agents are a design target only. Provider, number, recording consent, concurrency, retention and pricing require review and explicit owner approval before activation or paid commitment.
