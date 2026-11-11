# Customer Android App — Scaffold

यह Customer Android App का नियोजित workspace है। अभी यह README-only scaffold है; यहाँ कोई installable app, signed build या Play Store package मौजूद होने का दावा नहीं है।

## Responsibilities
- Customer sign-in and secure session handling.
- Customer profile, addresses and serviceability.
- Service catalogue and booking.
- Eligible electrician offers/bids and selection.
- Booking status and accepted-booking contact visibility.
- Arrival/work approval, timer and final bill.
- Itemized materials approval.
- Cash/Online payment and receipts.
- Notifications, rating, complaints, cancellation/refund requests.
- Privacy, consent, account and data controls.

## Architecture guardrails
- Use the existing Supabase project/backend contracts; do not duplicate business rules in the client.
- Never embed Supabase service-role keys, Razorpay secrets or other privileged credentials.
- Enforce authorization in RPC/API and RLS, not only in UI.
- Keep labour and materials separate; commission applies to labour only.
- Customer must approve timer stop before final bill.
- Payment is due after completion/final bill; no upfront collection.
- Android native/code changes require signed AAB, internal testing and owner-approved Play release.

## To initialize
Choose and document the Android framework, minimum SDK/device support, applicationId, signing-key custody, build pipeline, crash reporting, privacy disclosures and push-notification configuration before generating the app project. Do not commit signing keys or secrets.
