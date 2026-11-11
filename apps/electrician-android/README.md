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

## Rate Card — Required feature (Owner-confirmed: 2026-11-11)

The Electrician App must include a clear Rate Card list. Keep the four previously approved 8-hour Labour rates; do not replace them with a ₹899–₹999 range.

| Electrician category | 8-hour Labour charge | Electrician net Labour amount |
|---|---:|---:|
| Helper | ₹899.00 | ₹764.15 |
| Ordinary | ₹1,199.00 | ₹1,019.15 |
| Skilled | ₹1,599.00 | ₹1,359.15 |
| Master | ₹1,999.00 | ₹1,699.15 |

### Required behaviour
- Show all four categories with the 8-hour Labour charge and net Labour amount payable to the electrician. **Never display commission percentage, commission amount, or a commission-deduction row anywhere in the electrician-facing Rate Card.**
- Prominently identify the signed-in electrician's own Admin-approved category and highlight its net amount.
- Read category assignment from the authoritative server profile; never trust a category or rate supplied by the app client. Electricians cannot self-upgrade or edit assigned category. Admin changes must be authorized, versioned and audited.
- The backend calculates the net Labour amount using the approved Labour-only commission rule. Commission details remain internal and must not be exposed in the electrician-facing Rate Card. Materials/parts and other separately approved charges are excluded from this calculation and remain separately itemized.
- The Rate Card is informational. A booking's immutable server-side rate snapshot remains authoritative for that booking and its final invoice.
- Display INR to two decimal places. Preserve calculation precision and apply half-up rounding at final paise settlement. Do not invent hourly net pay, taxes, incentives or extra deductions.
- Include loading, unavailable-category, network-error, accessibility and small-screen states. Do not silently default a missing category.

### Acceptance tests
1. Verify all four gross Labour charges and net Labour amounts against the table above; assert that no commission label, percentage, amount or deduction row is rendered.
2. Verify only the signed-in electrician's own assigned category is highlighted; no other electrician's private assignment is exposed.
3. Verify electrician cannot alter category/rate through UI or API; server authorization rejects tampering.
4. Verify materials are excluded from the commission base.
5. Verify historical/current booking snapshots are not changed by later Rate Card updates.
6. Verify responsive UI, large text, loading, offline and error states.

**Status: REQUIREMENT APPROVED / NOT IMPLEMENTED.** This directory remains a README-only scaffold; no installable Android app or tested Rate Card screen exists yet.
