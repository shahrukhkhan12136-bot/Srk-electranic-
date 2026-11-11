# SRK ELECTRONIC — Hourly Labour Rates & Server-Based Work Timer

**Approval status:** Rates approved by the user.
**Project status:** Specification saved; implementation and end-to-end testing are still pending.
**Environment:** Feature branch only. No production deployment or production database changes.

## Approved electrician categories and rates

The standard workday is 8 hours. The approved labour rates are:

| Category | 8-hour labour rate | Derived hourly rate |
|---|---:|---:|
| Helper Electrician (हेल्पर इलेक्ट्रिशियन) | ₹900 | ₹112.50/hour |
| Ordinary Electrician (साधारण इलेक्ट्रिशियन) | ₹1,200 | ₹150/hour |
| Skilled Electrician (कुशल इलेक्ट्रिशियन) | ₹1,600 | ₹200/hour |
| Master Electrician (मास्टर इलेक्ट्रिशियन) | ₹2,000 | ₹250/hour |

These rates are labour charges only.

## Required timer and automatic billing flow

1. Customer selects/books the service and the system assigns or matches an electrician.
2. Before beginning the work, the assigned electrician uses **Start Timer**.
3. The server records the authoritative start timestamp for the booking/work session.
4. When the work is finished, the electrician uses **Stop Timer**.
5. The server records the stop timestamp and calculates the elapsed work duration.
6. The server calculates the labour charge using the hourly rate for the electrician category selected/approved for that booking and the recorded elapsed duration.
7. The generated bill is made visible to both the customer and electrician.

## Separate materials policy

- Labour and materials must always be itemized and billed separately.
- Materials must never be included in the electrician labour amount.
- If the electrician supplies materials, each item must appear on a separate itemized bill/receipt.
- The customer may instead purchase materials independently.
- No unauthorized material markup or charge is allowed.
- The customer must be able to review and approve labour and materials separately.

## Implementation and verification requirements

- Enforce timer actions on the server; do not trust a client/device clock or a client-calculated amount.
- Associate each timer session with the correct booking, customer, assigned electrician, and approved category/rate.
- Prevent unauthorized users from starting, stopping, editing, or duplicating another booking's timer.
- Prevent duplicate or conflicting active timer sessions for the same booking.
- Calculate the final amount on the server from recorded timestamps and the approved rate; return the same authoritative bill to both parties.
- Test all four rates, start/stop flow, invalid/repeated actions, interrupted sessions, permissions, and customer/electrician bill visibility before release.
- Any policy not explicitly approved here (for example, minimum billable duration, rounding, pauses/breaks, overtime, cancellation, or timer correction) must be clarified before implementation; do not invent such rules.

**Important:** This document records the user's approved rate chart and required workflow. It does not claim that timer billing has already been implemented. Production deployment remains subject to full testing and the user's explicit approval.


## Booking cancellation authority

- Customers and electricians must not be able to cancel a booking on their own.
- A booking may be cancelled only by an authorized admin through the admin panel.
- Enforce this permission on the server/database layer as well as in the user interface; hiding or disabling a button alone is not sufficient.
- Record the admin who cancelled the booking, the booking, timestamp, and any reason entered, so the action is auditable.
- Test that customer and electrician cancellation attempts are rejected, while an authorized admin can cancel.
