# Electrician Android App — Scaffold

यह Electrician Android App का नियोजित workspace है। अभी यह README-only scaffold है; कोई installable app, signed build या Play Store package मौजूद होने का दावा नहीं है।

## Responsibilities
- Electrician sign-in and secure session handling.
- Application/profile and verification status.
- Admin-approved activation and service area.
- Availability and eligible job offers.
- Bid/quote, accept/reject and booking assignment.
- Customer contact only after booking acceptance.
- Arrival evidence, work start, server-authoritative timer.
- Separate itemized materials proposal and approval.
- Completion, Cash receipt confirmation and commission remittance.
- Online earnings, wallet and payout status.
- Push notifications, support, complaints and account controls.

## Architecture guardrails
- Use existing Supabase backend contracts; no privileged service key in the app.
- Enforce assignment, approval and ownership on the server and through RLS.
- No customer phone visibility before electrician accepts/receives the booking.
- Timer uses server timestamps and immutable rate snapshot.
- Materials are separate from labour; no unauthorized markup.
- Cash and online settlement must reconcile to immutable ledger/provider evidence.
- Do not represent a payout as paid without actual transfer evidence.

## To initialize
Choose and document framework, minimum SDK/device support, applicationId, signing-key custody, CI build, crash reporting, privacy disclosures and push configuration. Never commit signing keys or secrets.
