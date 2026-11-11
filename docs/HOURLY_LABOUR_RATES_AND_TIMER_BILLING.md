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


---

# Customer Visit, Cancellation Approval, Work Timer & Cash Settlement
**Status: Approved business requirements / implementation pending**

## 1. Booking and visit lifecycle
1. Customer creates a service booking.
2. Matching electrician receives the offer and accepts it.
3. Electrician travels to the customer's address and reaches the location.
4. Arrival/visit is recorded separately from the paid-work timer. Merely accepting the job or travelling to the customer must not start labour billing.
5. Once the customer and electrician are ready for work, electrician starts the work timer. The server records the authoritative start timestamp.
6. When work is finished, electrician stops the timer. The server records the stop timestamp and calculates elapsed billable time and labour amount using the category rate saved on that booking.
7. Customer sees the generated bill and a Cash (नकद) payment option.
8. Electrician confirms receipt of cash. Only after this confirmation should the booking/payment show as cash received/paid. Record who confirmed and when.

## 2. Four electrician categories and standard rates
Rates are for an 8-hour standard workday; hourly equivalent is shown for server-side calculation.

| Category | 8-hour labour rate | Hourly equivalent |
|---|---:|---:|
| Helper Electrician (हेल्पर इलेक्ट्रिशियन) | ₹900 | ₹112.50 |
| Ordinary Electrician (साधारण इलेक्ट्रिशियन) | ₹1,200 | ₹150.00 |
| Skilled Electrician (कुशल इलेक्ट्रिशियन) | ₹1,600 | ₹200.00 |
| Master Electrician (मास्टर इलेक्ट्रिशियन) | ₹2,000 | ₹250.00 |

The category and rate used must be snapshotted on the booking/work session so later rate changes do not rewrite an existing bill.

## 3. Labour and materials must remain separate
- The timer calculates labour only.
- Materials/parts are a separate itemized amount and must never be silently included in labour.
- Customer can supply materials themselves.
- If electrician supplies materials, show item names, quantities and prices separately; customer must approve them.
- No unauthorized material markup or hidden charge.

## 4. Cancellation is a request requiring Admin approval
- Customer and electrician both see a **Request Cancellation** button; do not hide the button.
- Pressing it does NOT cancel the booking. It creates a cancellation request with requester role, reason, timestamp and booking state.
- Booking remains active/in its existing state while awaiting Admin decision. Both parties are informed that Admin approval is pending.
- Only an authenticated/authorized Admin can approve or reject the request.
- On approval, server changes booking to cancelled, records Admin ID, decision, reason, timestamp and any applicable cancellation charge; notify both parties.
- On rejection, booking remains active and both parties are notified.
- Customer/electrician must not be able to directly set booking status to cancelled through browser, API, RPC or database writes.
- Apply the cancellation charge only according to an Admin-approved policy and show it clearly before final settlement. Do not invent or hard-code a fee until its amount/rule is approved.
- Admin must not accidentally cancel a completed booking through the normal cancellation flow. Any exceptional correction should be a separately authorized and audited action.

## 5. Server-side integrity and audit requirements
- Server/database timestamps are authoritative; never trust client device clock or client-submitted duration/amount.
- Start/stop actions must be authenticated, idempotent and restricted to the electrician assigned to that booking.
- Prevent duplicate active timers, stopping a timer that was never started, restarting a completed session, and overlapping work sessions for the same booking.
- Preserve immutable start/stop timestamps, category/rate snapshot, calculated duration, labour amount, materials breakdown, payment method, cash confirmation, cancellation requests and Admin decisions.
- Use database constraints/RLS and secure server-side functions; hiding UI controls is not sufficient.
- Use a defined billing increment/rounding rule (for example per-minute or per-15-minute billing) only after the business owner approves it. Until then, do not silently assume a rounding rule.
- Handle disputes, timer corrections and payment reversals through audited Admin actions, not direct edits by customer/electrician.

## 6. Booking state flow (proposed)
new → offered → accepted/assigned → electrician_arrived → work_in_progress (timer running) → work_stopped/bill_generated → cash_pending → cash_confirmed/completed.

Cancellation side-flow:
active booking → cancellation_requested → (Admin approves → cancelled) OR (Admin rejects → return to prior active state).

## 7. Decisions still required before implementation
1. Cancellation charge: fixed amount, percentage, or travel/visit-based amount; exact amount and when it applies.
2. Whether cancellation charge differs for customer-requested vs electrician-requested cancellation.
3. Whether the charge applies only after electrician reaches the customer's address, or also after acceptance/before arrival.
4. Billable-time rounding: per minute, per 15 minutes, per half-hour, or another rule; minimum charge if any.
5. What happens if customer disputes the cash amount or electrician does not confirm cash receipt.
6. Whether Admin may waive a cancellation charge and what reason/audit is mandatory.

**No application code, database migration, production database, or production deployment is changed by this specification update.**
