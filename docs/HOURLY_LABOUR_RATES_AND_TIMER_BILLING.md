# SRK ELECTRONIC — Hourly Labour Rates & Server-Based Work Timer

**Approval status:** Rates approved by the user.
**Project status:** Specification saved; implementation and end-to-end testing are still pending.
**Environment:** Feature branch only. No production deployment or production database changes.

## Approved electrician categories and rates

The standard workday is 8 hours. The approved labour rates are:

| Category | 8-hour labour rate | Derived hourly rate |
|---|---:|---:|
| Helper Electrician (हेल्पर इलेक्ट्रिशियन) | ₹899 | ₹112.375/hour |
| Ordinary Electrician (साधारण इलेक्ट्रिशियन) | ₹1,199 | ₹149.875/hour |
| Skilled Electrician (कुशल इलेक्ट्रिशियन) | ₹1,599 | ₹199.875/hour |
| Master Electrician (मास्टर इलेक्ट्रिशियन) | ₹1,999 | ₹249.875/hour |

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
1. Customer selects the service and sees the electrician category and its hourly labour rate clearly before confirming the booking. The booking screen must display the selected category and applicable hourly charge (for example, हेल्पर इलेक्ट्रिशियन — ₹112.375/hour; साधारण इलेक्ट्रिशियन — ₹149.875/hour; कुशल इलेक्ट्रिशियन — ₹199.875/hour; मास्टर इलेक्ट्रिशियन — ₹249.875/hour).
2. The selected/assigned electrician category and hourly rate are saved as a snapshot on the booking and shown to the customer before booking confirmation and in booking details. Any change must be disclosed and accepted before work starts.
3. Matching electrician receives the offer and accepts it.
4. Electrician travels to the customer's address and reaches the location; arrival must be recorded.
5. Arrival/visit is recorded separately from the paid-work timer. Merely accepting the job or travelling to the customer must not start labour billing.
6. Mutual-consent timer start: the electrician presses **Start Timer** to send a start request to the customer. The timer must remain NOT RUNNING while customer approval is pending. The customer reviews and accepts the start request; only then does the server record the authoritative start timestamp and mark the timer as running. If the customer rejects the request, the timer does not start and the rejection is recorded.
7. Mutual-consent timer stop: after finishing the work, the electrician presses **Finish / Request Stop** to send a stop request to the customer. The timer continues running while customer approval is pending; it must not stop merely because the electrician requested a stop. The customer reviews and accepts the stop request; only then does the server record the authoritative stop timestamp and stop the timer. If the customer rejects the stop request, the timer remains running and the rejection is recorded so the parties can resolve the discrepancy.
8. The server calculates elapsed billable time between the accepted start timestamp and accepted stop timestamp, using the category rate saved on that booking. Billable work duration is accounted for per minute, not in 15-minute or 30-minute blocks. Both parties see the approved start/stop timestamps, elapsed duration and calculated labour bill.
9. Only after the electrician requests timer stop and the customer accepts that stop request (so the timer is actually stopped) does the system generate/show the final bill and reveal payment options. Before this point, no payment button, Cash option, Online Payment option, payment collection request, or checkout flow is shown.
10. After the final bill is generated, the customer may choose either Cash (नकद) or Online Payment. For Cash, the electrician confirms actual receipt; only after that confirmation should the booking/payment show as cash received/paid, recording who confirmed and when. For Online Payment, create/enable the online payment flow only at this post-completion stage and mark payment paid only after verified provider confirmation/webhook.

## 2. Four electrician categories and standard rates
Rates are for an 8-hour standard workday; hourly equivalent is shown for server-side calculation.

| Category | 8-hour labour rate | Hourly equivalent |
|---|---:|---:|
| Helper Electrician (हेल्पर इलेक्ट्रिशियन) | ₹899 | ₹112.375 |
| Ordinary Electrician (साधारण इलेक्ट्रिशियन) | ₹1,199 | ₹149.875 |
| Skilled Electrician (कुशल इलेक्ट्रिशियन) | ₹1,599 | ₹199.875 |
| Master Electrician (मास्टर इलेक्ट्रिशियन) | ₹1,999 | ₹249.875 |

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
- If the customer requests cancellation after the electrician has actually reached the customer's address and the arrival is recorded, create a cancellation-charge record for Admin review/approval. The exact cancellation-charge amount/formula is still to be decided; do not invent or hard-code an amount.
- If the electrician does not reach the customer's address, no cancellation charge is applied to the customer. Record the non-arrival/cancellation reason and timestamps for audit.
- Apply/collect any cancellation charge only through the Admin-approved decision and show it clearly to the customer before settlement. Do not treat a pending cancellation request as a payable charge.
- Admin must not accidentally cancel a completed booking through the normal cancellation flow. Any exceptional correction should be a separately authorized and audited action.

## 5. Server-side integrity and audit requirements
- Server/database timestamps are authoritative; never trust client device clock or client-submitted duration/amount.
- Timer start/stop requests must be authenticated and idempotent. Only the assigned electrician may initiate a start/stop request, and only the booking's customer may approve/reject it. A timer starts/stops only after the corresponding customer approval is recorded server-side.
- Prevent duplicate pending requests, duplicate approvals, duplicate active timers, stopping a timer that was never started, restarting a completed session, and overlapping work sessions for the same booking. Enforce valid state transitions on the server/database.
- Preserve immutable start/stop timestamps, category/rate snapshot, calculated duration, labour amount, materials breakdown, payment method, cash confirmation, cancellation requests and Admin decisions.
- Use database constraints/RLS and secure server-side functions; hiding UI controls is not sufficient.
- Work duration is to be accounted for per minute. The server must calculate the amount from the authoritative timer timestamps and the saved hourly category rate; do not round up to 15-minute or 30-minute blocks. Define and document the exact treatment of partial minutes (seconds) consistently before implementation.
- Handle disputes, timer corrections and payment reversals through audited Admin actions, not direct edits by customer/electrician.

## 6. Booking state flow (proposed)
new → offered → accepted/assigned → electrician_arrived → timer_start_requested → (customer approves → work_in_progress / timer running) → timer_stop_requested → (customer approves → work_stopped/bill_generated) → cash_pending → cash_confirmed/completed.

Cancellation side-flow:
active booking → cancellation_requested → (Admin approves → cancelled) OR (Admin rejects → return to prior active state).

## 7. Decisions still required before implementation
1. Approved customer cancellation charge: ₹99 fixed when the electrician has reached the customer's address and arrival is recorded, subject to the cancellation request being approved by Admin. No charge if the electrician has not reached the address. Admin decision and audit requirements apply.
2. Whether the customer cancellation charge differs by reason or circumstance after arrival.
3. Exact treatment of partial minutes/seconds in per-minute billing and whether any minimum labour charge applies.
4. What happens if customer disputes the cash amount or electrician does not confirm cash receipt.
5. Whether Admin may waive a cancellation charge and what reason/audit is mandatory.

**No application code, database migration, production database, or production deployment is changed by this specification update.**


## 8. Customer approval is required for both timer actions
- Electrician initiates the timer start; customer approval is mandatory before the timer starts.
- Electrician initiates the timer stop after finishing; customer approval is mandatory before the timer stops.
- A pending start request is not billable time. A pending stop request does not stop the timer; time continues until the customer approves the stop request.
- Store each request, customer decision, actor ID, server timestamp, and any rejection reason in an audit trail.
- Customer must be able to see the requested action and approve or reject it from their booking screen; electrician must see the decision/status.
- Do not allow either party to alter timestamps or directly edit elapsed duration/amount. If the customer rejects a start/stop request or does not respond, keep the request pending/rejected as appropriate and provide an Admin-mediated, audited dispute-resolution path. Do not silently start/stop the timer or invent a timeout rule.


## 9. Remove the electrician quotation-sending workflow
**User decision:** The electrician quotation/estimate submission and customer quote-approval workflow is to be removed from SRK ELECTRONIC.

- Do not show an electrician control to prepare/send a labour quotation or combined quotation.
- Do not require customer approval of an electrician-submitted quotation before work can begin.
- During booking, show the four electrician categories and the applicable approved 8-hour and hourly labour rates clearly; the customer chooses/sees the applicable category/rate before confirming the booking.
- Final labour billing is generated from the mutually customer-approved work timer (electrician requests start/stop; customer approves each action) and the saved category rate, charged per minute.
- Materials/parts remain separate from labour. If materials are needed, list items, quantities and prices separately and obtain customer approval for those materials; do not treat this as an electrician labour quotation.
- The old quote status/approval states and quote-related RPCs/database columns must be retired safely through a reviewed migration, without deleting historical payment or booking records.
- Update customer, electrician and Admin screens and all payment/commission calculations so they use the approved timer-generated labour bill and separately approved materials, not the old quote amount.
- Do not simply hide the quotation button while leaving the old quote-gated state machine in place: replace the underlying workflow and test booking → assignment → arrival → customer-approved timer start/stop → final bill → payment end-to-end.
- Until that replacement is implemented and tested, do not claim the quotation system has been removed from the live app. This decision is recorded in the Feature Branch specification only; no production code or database has been changed by this update.


## 10. Payment options are shown only after customer-approved timer completion
- At booking time, show only the selected electrician category and its 8-hour/hourly labour rate as price information. Do not show a Pay Now button, cash payment choice, online payment choice, payment collection screen, or create a payment order at booking time.
- During electrician travel, arrival, timer-start request, active work, and timer-stop request pending customer approval, do not expose payment options or initiate payment collection.
- Only after the customer accepts the electrician's timer-stop request and the server records the timer as stopped may the system calculate the final per-minute labour bill and display the final amount with two payment methods: Cash (नकद) and Online Payment.
- Cash: customer pays the electrician after the final bill; electrician confirms actual cash receipt in the app. Do not mark paid before confirmation.
- Online: customer can initiate online payment only after the final bill is generated; use the verified payment gateway flow, signature/webhook validation and idempotency protections. Do not mark paid based only on a client-side success screen.
- If separately approved materials are added, show them as distinct line items in the final bill; do not merge them into the labour rate. The payment choices still appear only after the timer has been stopped with customer approval and the final bill is ready.
- Booking-time category/hourly rates are informational price display, not a request to pay the full 8-hour amount in advance. The actual labour payable is calculated from the approved timer duration.


## 11. Exact per-minute billing and rounding rule (user-confirmed)
- Labour is billed by the minute, not by 15-minute/30-minute blocks and not by per-second prorating.
- Calculate the authoritative elapsed duration from the server-recorded, customer-approved start and stop timestamps.
- Convert elapsed duration to billable whole minutes by rounding **any remaining seconds up to the next whole minute** (ceiling): for example, 1 minute 1 second is billed as 2 minutes; exactly 1 minute is billed as 1 minute.
- Calculate the labour amount as: (saved hourly category rate ÷ 60) × billable whole minutes.
- Keep full precision during calculation; round only the final labour total to the nearest ₹0.01 (one paisa), using decimal arithmetic and a documented half-up rounding mode. Do not round the hourly rate or per-minute rate before multiplying.
- Show the customer the actual elapsed time, billable whole minutes, per-minute rate, and final rounded labour amount as separate, understandable values.
- Apply this same deterministic rule in every server-side bill calculation, receipt, admin view, and payment amount. Never calculate the authoritative amount in the client.
- This rule does not introduce a minimum labour charge; no minimum has been approved.


## 12. Approved decision reconciliation (2026-11-11)
This section resolves older open questions above. If an earlier paragraph in this document conflicts with this section or Section 11, the later user-confirmed decisions below take precedence:

- **Partial minutes:** use the ceiling rule in Section 11. Any remaining seconds count as the next whole billable minute. There is no per-second prorating and no minimum labour charge.
- **Customer cancellation charge:** ₹99 fixed, and only if (a) the customer requests cancellation, (b) the electrician's actual arrival at the customer location has been recorded, and (c) Admin explicitly approves the cancellation request. No charge if arrival was not recorded. The request itself never creates an immediately payable fee.
- **Materials:** labour and materials remain separate; itemized materials require separate customer approval. Materials must not be included in the electrician labour amount or incur an unauthorized markup.
- **Payment:** no payment method or checkout at booking. Cash and Online Payment become available only after customer-approved timer stop and final bill generation. Cash is marked paid only after the assigned electrician confirms actual receipt; online is marked paid only after verified provider confirmation.

The implementation status remains pending. This document update changes no application code, database schema/data, payment configuration, or deployment.