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



## Owner-approved mobile visual direction (2026-11-12)

The three-phone reference image establishes the visual direction for the shared splash and Customer Dashboard: Royal Blue / White / Gold, clear SRK ELECTRONIC branding, founder waist-up portrait on the splash, concise dashboard cards, clear booking shortcuts and accessible bottom navigation. Treat sample location, counts, prices, ratings, wallet balance and booking records in the image as illustrative only; render only authenticated live data. The Customer Android app remains unimplemented; this approval does not mean a native app or build exists.
