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

## Safety boundary

All code and SQL changes described above are Feature Branch only. No shared TEST/Production migration, database write, live payment, or deployment was performed. Do not deploy until the remaining payment, timer UI, material, cancellation, audit, and full integration tests are complete and the user explicitly approves.
