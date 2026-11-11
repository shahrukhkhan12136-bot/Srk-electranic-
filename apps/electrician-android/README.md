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

| Electrician category | काम की अवधि | Electrician को मिलने वाली Labour राशि |
|---|---:|---:|
| Helper | 8 घंटे | ₹764.15 |
| Ordinary | 8 घंटे | ₹1,019.15 |
| Skilled | 8 घंटे | ₹1,359.15 |
| Master | 8 घंटे | ₹1,699.15 |

### Required behaviour
- Show all four categories with the **8-hour work duration** and **only** the net Labour amount payable to the electrician. Do not show the 8-hour Labour charge/gross amount, commission percentage, commission amount, or any deduction row/label anywhere in the electrician-facing Rate Card.
- Prominently identify the signed-in electrician's own Admin-approved category and highlight its net amount.
- Read category assignment from the authoritative server profile; never trust a category or rate supplied by the app client. Electricians cannot self-upgrade or edit assigned category. Admin changes must be authorized, versioned and audited.
- The backend calculates the net Labour amount using the approved Labour-only commission rule. Commission details remain internal and must not be exposed in the electrician-facing Rate Card. Materials/parts and other separately approved charges are excluded from this calculation and remain separately itemized.
- The Rate Card is informational. A booking's immutable server-side rate snapshot remains authoritative for that booking and its final invoice.
- Display INR to two decimal places. Preserve calculation precision and apply half-up rounding at final paise settlement. Do not invent hourly net pay, taxes, incentives or extra deductions.
- Include loading, unavailable-category, network-error, accessibility and small-screen states. Do not silently default a missing category.

### Acceptance tests
1. Verify the 8-hour duration and all four electrician net Labour amounts against the table above; assert that no gross Labour charge, commission label, percentage, amount or deduction row is rendered.
2. Verify only the signed-in electrician's own assigned category is highlighted; no other electrician's private assignment is exposed.
3. Verify electrician cannot alter category/rate through UI or API; server authorization rejects tampering.
4. Verify materials are excluded from the commission base.
5. Verify historical/current booking snapshots are not changed by later Rate Card updates.
6. Verify responsive UI, large text, loading, offline and error states.

**Status: REQUIREMENT APPROVED / NOT IMPLEMENTED.** This directory remains a README-only scaffold; no installable Android app or tested Rate Card screen exists yet.


## Electrician ID / Profile — own category display (Owner-confirmed: 2026-11-11)

The electrician must be able to identify their approved skill category directly from their own **Electrician ID / Profile** screen.

- Show a prominent category name and badge: **Helper, Ordinary, Skilled, or Master**.
- Resolve the value only from the signed-in electrician's authoritative, Admin-approved server profile/application assignment. Never trust a category label sent by the app.
- The electrician cannot edit, upgrade, or downgrade this assignment. Only an authorized Admin workflow may change it, with audit history and versioning.
- For pending, rejected, suspended, inactive, or missing assignments, show the real status or a clear unavailable state; never silently default to Helper or another category.
- Expose only the signed-in electrician's own assignment. Do not reveal another electrician's private category.
- The category shown on the ID/Profile must match the category highlighted in the Rate Card; both must use the same authoritative profile value.
- Include accessible Hindi/English labels and mobile, loading, offline, stale-data, and server-error states.

Acceptance tests: profile ownership/RLS, client-tampering rejection, Admin change audit/versioning, all application-status states, and mobile end-to-end display.

**Status: REQUIREMENT APPROVED / NOT IMPLEMENTED.** The Android workspace remains a README-only scaffold.


## Electrician ID Number — proposed format

Every approved and activated electrician receives a permanent unique display ID, for example:

- SRK-EL-000001
- SRK-EL-000002
- SRK-EL-000003

The server generates the number after Admin approval and activation. It is unique, permanent, never recycled, and cannot be edited by the electrician. Keep the internal database UUID separate from this readable ID. Do not encode phone number, Aadhaar, date of birth, or other personal data.

The Electrician ID/Profile card should show:
- SRK ELECTRONIC Electrician ID number
- Electrician's approved category badge (Helper / Ordinary / Skilled / Master)
- Display name and approval/account status

Changing an electrician's approved category does not change their ID number. ID number alone is never an authentication credential.

**Status: PROPOSED FORMAT / OWNER CONFIRMATION PENDING / NOT IMPLEMENTED.**
