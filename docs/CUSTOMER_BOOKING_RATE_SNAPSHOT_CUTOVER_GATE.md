# Customer booking and rate-snapshot cutover

Date: 2026-11-11
Branch: `feature/production-push-notifications`
Status: **implemented on Feature Branch; disposable SQL CI passed; not released**

## Verified Production booking schema

A read-only `information_schema.columns` inspection of `public.service_bookings` confirmed:

- Required fields: `customer_name`, `phone`, `state`, `district`, `pincode`, `address`, `service_type`.
- `preferred_date`, `preferred_time`, `work_details`, coordinates and `customer_user_id` are nullable in the existing schema.
- Legacy `payment_method` is NOT NULL with default `'Cash'`.
- Legacy `quoted_amount` is nullable.
- `status` defaults to `'new'`; `payment_status` defaults to `'unpaid'`.
- `materials_amount` is NOT NULL default `0`; `quote_status` is NOT NULL default `'not_submitted'`.
- Legacy quote, payment, and `work_started_at` columns remain present and are not the new timer/bill authority.

No shared TEST or Production database writes were performed.

## Approved rate catalogue

| Code | Customer label | 8-hour reference | Hourly snapshot |
|---|---|---:|---:|
| `helper` | Helper | ₹899 | ₹112.375 |
| `ordinary` | Ordinary | ₹1,199 | ₹149.875 |
| `skilled` | Skilled | ₹1,599 | ₹199.875 |
| `master` | Master | ₹1,999 | ₹249.875 |

These are labour-only rates. Materials/parts remain separate, itemized, and subject to customer approval. Category is never inferred from free-text electrician skills.

## Feature Branch implementation

### Database migration

`supabase/migrations/202611110005_server_authoritative_booking_creation.sql`:

- Adds a private booking-request idempotency ledger with RLS enabled and browser access revoked.
- Adds authenticated `SECURITY DEFINER` RPC `srk_create_customer_booking(jsonb,uuid)` with empty search path.
- Requires `auth.uid()`, checks the JWT phone claim against the normalized submitted 10-digit phone, and binds `customer_user_id` to the authenticated user.
- Accepts only the approved booking payload keys; client payment choice and amount/quote fields are rejected.
- Maps category label and hourly rate on the server; no browser-supplied price is trusted.
- Validates required fields and paired/ranged coordinates.
- Uses a transaction-scoped advisory lock and idempotency key so a retry returns the same booking instead of creating duplicate offers.
- Inserts the category/rate snapshot with the booking in one transaction.
- Leaves legacy `payment_method` at its database default solely for schema compatibility; it is not offered to the customer.
- Adds a trigger guard preventing later changes to category/rate snapshot columns.
- Does not create offers itself; the existing booking broadcast trigger remains the sole offer creator.

### API

Root `create-booking.js` now:

- Keeps the existing public IP rate-limit check.
- Verifies the customer's bearer token and matching verified phone.
- Calls the new RPC using the customer's access token so database `auth.uid()` is authoritative.
- Passes only the validated booking fields, category code, and idempotency key.
- Reads the offer queue after the insert using the service-role client; it does not manually create offers.

### Customer UI

`index.html` now:

- Requires one of the four categories and displays its approved 8-hour and hourly labour rate.
- Explains that materials/parts are separate and require itemized customer approval.
- Removes the Cash/Online booking-time selector and payment-choice text from the booking WhatsApp request.
- Sends only the selected category code, never the rate or quote amount.
- Preserves the same idempotency key during retries within the active page session.
- Displays the saved category and hourly snapshot in booking history.
- Indicates payment is not due before a final bill exists.

### Regression tests and CI

Added `supabase/tests/server_authoritative_booking_creation_assertions.sql` and extended the disposable PostgreSQL harness/workflow. Tests cover:

- unauthenticated rejection;
- verified-phone mismatch rejection;
- invalid category rejection;
- rejection of client-supplied payment/quote fields;
- exact server rates for all four categories;
- customer identity and category/rate snapshot on insert;
- exactly one synthetic broadcast offer;
- idempotent replay returning the same booking and not duplicating offers;
- safe second application of the migration.

GitHub Actions run **43013732402** completed successfully on commit `4cfd9a26eb01d7cadc3022557a39a7c4f2d0189b`. The booking migration application, replay-safety step, booking assertions, and billing arithmetic tests all passed in PostgreSQL 16 disposable CI. This is a synthetic harness, not a Production-equivalent full-schema integration test.

JavaScript syntax checks also passed for `create-booking.js` and the inline customer scripts after the UI/API changes. No live booking was submitted.

## Remaining release gates

1. Latest UI-only history display change was committed after the passing SQL CI run; rerun CI after the next SQL/workflow change and perform a browser-level preview test before release.
2. API/runtime integration has not been exercised against a live preview environment. Do not claim production behavior is verified.
3. The customer booking RPC is not yet applied to shared TEST or Production. No deployment has occurred.
4. The old payment/order/verify/webhook paths still depend on legacy quote and amount fields. Their coordinated cutover is unfinished.
5. Customer/electrician/Admin timer and material approval screens, material revision RPCs, cancellation approval RPCs, cash receipt evidence and webhook ledger processing remain separate work.
6. The legacy `srk_update_booking_work_status` caller and authenticated EXECUTE grant must not be retired until all UI callers are migrated and tested.
7. The legacy `payment_method` NOT NULL default must not be changed in isolation. Final payment cutover must coordinate customer/electrician/Admin displays, Razorpay order creation, verification, webhook reconciliation, cash receipt evidence and legacy quote paths.

### Customer/electrician timer UI and calculation precision update (2026-11-11)

Feature Branch now wires the customer booking history to `srk_get_booking_timer_bill_details` and the exact customer decision RPCs:

- Customer can see the timer state and pending start/stop requests.
- Customer approval/rejection calls `srk_customer_decide_timer_start(uuid,text)` or `srk_customer_decide_timer_stop(uuid,text)`.
- The customer UI suppresses legacy quote and payment controls for bookings with a server-saved service category.
- The final labour bill is displayed separately; materials remain described as a separate itemized proposal requiring a future material-approval UI.

The electrician dashboard now:

- Loads scoped timer/bill details only for offers that already expose the assigned customer's details.
- Provides arrival recording, timer-start request, and timer-stop request controls using the exact RPC argument names and fresh idempotency keys.
- Hides the legacy inspection/quote/work-status/cash controls when a booking has a category snapshot, preserving those controls only for legacy bookings.

A review of the timer SQL found premature rounding: labour was being rounded to two decimal places before the final payable calculation. Feature Branch now retains the labour calculation at `numeric(20,10)` precision in `srk_final_bills`; the payable snapshot remains the later paise-rounded payment boundary. Migration `202611110006_preserve_labour_calculation_precision.sql` supports an additive type upgrade. The timer lifecycle assertion now checks the retained ten-decimal calculation.

The CI workflow now includes both customer and electrician HTML files in its path filters and parses their inline JavaScript with Node before running the disposable PostgreSQL tests. This change is committed but its new CI run still needs to finish and be inspected. JavaScript syntax was also checked locally through the GitHub file content parser after the UI edits.

### Remaining release gates (updated)

- Admin timer/bill/material/cancellation review and override UI is not wired.
- Material revision create/submit/customer approval RPCs and UI are not complete.
- Cancellation request/Admin decision RPCs are not complete.
- Payable snapshot creation and the Razorpay order/signature/webhook cutover remain incomplete; do not expose payment for timer bookings yet.
- Cash receipt confirmation must be bound to the immutable payable snapshot; the legacy cash confirmation is not the timer-billing flow.
- Full browser-level preview testing and an isolated shared TEST validation remain outstanding; no shared TEST or Production DB changes have been made.

### Admin audit and separate materials approval update (2026-11-11)

Feature Branch now adds an Admin read-only audit section that uses the ownership-scoped timer/bill RPC to display:

- Category/rate snapshot, arrival, timer state and customer decisions.
- Final labour-only bill and billable minutes.
- Material proposal revisions and itemized lines, including supplier and receipt reference.
- Payable snapshots and cash receipt evidence when those records exist.

The legacy Admin booking editor now refuses to save any booking with a server-saved service category. Its old payment/status update path cannot be used to complete or collect payment for the new timer-based workflow. Legacy booking rows continue using the existing Admin controls.

Migration `202611110007_material_revision_customer_approval_rpcs.sql` adds:
- An assigned, active, approved electrician-only RPC to submit a separate itemized material proposal after the final labour bill exists.
- A customer-only RPC to approve or reject the exact pending revision.
- Idempotent electrician submission keys, one open revision per bill, audit events, and a decision ledger.
- A mandatory receipt/bill reference for electrician-supplied materials.
- Customer-supplied items must have ₹0 unit price and ₹0 line total, so they cannot be added to the customer's payable amount.

The electrician panel now provides a multi-line material proposal form after the timer is stopped and the labour bill exists. The customer panel displays each material item and can approve/reject the exact revision. The Admin panel displays the same material history read-only. Material approval does not yet create a payable snapshot or enable payment; that remains a separate server-side payment cutover gate.

The workflow adds the migration and SQL assertion file to disposable PostgreSQL CI and includes the Admin dashboard in JavaScript syntax checks. These latest CI results still need to be inspected before this work can be called verified.

### Remaining release gates (updated)

- Payable snapshot creation must use the final labour bill plus only customer-approved electrician-supplied material lines; customer-supplied materials must remain excluded.
- Razorpay order creation, payment verification and webhook reconciliation must bind to one immutable payable snapshot.
- Cash receipt confirmation must be bound to the exact payable snapshot and confirmed by the assigned electrician.
- Admin cancellation request review and the ₹99 arrival-evidence rule still need their dedicated RPC and UI.
- Full browser-level preview testing and isolated shared TEST validation remain outstanding; no shared TEST or Production DB changes have been made.

Latest validation note (2026-11-11): the three dashboard inline-script syntax checks passed locally after the Admin/material UI changes. The updated SQL workflow includes migration 007, replay testing and the material approval assertion file, but a completed GitHub Actions result for this latest change has not yet been confirmed. The Vercel status check currently reports a build-rate-limit/upgrade block; this is a preview build restriction, not a successful deployment. Do not treat it as a production deploy or as evidence that the SQL workflow passed.

### Immutable payable snapshot update (2026-11-11)

Migration `202611110008_customer_payable_snapshot_rpc.sql` adds a customer-owned RPC to create the payable snapshot only after the server-generated final timer bill exists and no material revision is pending.

- The snapshot binds the booking, exact final bill/version, and the latest customer-approved material revision.
- Only electrician-supplied lines from that approved revision are included. Customer-supplied items remain ₹0 and are excluded from the material total.
- Labour retains its 10-decimal calculation precision in the snapshot; only the combined labour-plus-material total is rounded half-up to paise.
- The booking row is locked while the snapshot is created. Repeated customer requests return the same snapshot.
- Once a snapshot exists, the material submission RPC refuses further revisions for that bill.
- Customer UI now displays the separate labour/material breakdown and asks the customer to confirm creation of the locked total. The UI does not yet expose Razorpay or Cash payment for this new flow.

CI now applies and replays migration 008 before running the combined material-approval/payable-snapshot assertions. The latest GitHub Actions result still needs confirmation; no shared TEST/Production database changes or deployment have occurred.

### Remaining payment cutover gates

- Add a Razorpay order ledger bound to exactly one payable snapshot and its paise amount.
- Update order creation, checkout verification and webhook reconciliation to use that snapshot only; old quote-based endpoints must reject new timer-category bookings.
- Add electrician-confirmed Cash receipt against the same snapshot.
- Browser-level end-to-end testing, isolated shared TEST validation, and one consolidated Production release remain outstanding.

## Safety boundary

All code and SQL changes described above are Feature Branch only. No shared TEST/Production migration, database write, live payment, or deployment was performed. Do not deploy until the remaining payment, timer UI, material, cancellation, audit, and full integration tests are complete and the user explicitly approves.
