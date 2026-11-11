# Customer booking and rate-snapshot cutover — implementation gate

Date: 2026-11-11
Branch: `feature/production-push-notifications`
Status: **design and production-schema audit complete; implementation not yet applied**

## Verified Production booking schema

A read-only `information_schema.columns` inspection of `public.service_bookings` confirmed:

- Required, no-default fields: `customer_name`, `phone`, `state`, `district`, `pincode`, `address`, `service_type`.
- `preferred_date` and `preferred_time` are nullable date/time columns.
- `work_details`, `location_lat`, `location_lng`, `customer_user_id` are nullable.
- Legacy `payment_method` is NOT NULL with default `'Cash'`.
- Legacy `quoted_amount` is nullable.
- `status` defaults to `'new'`; `payment_status` defaults to `'unpaid'`.
- `materials_amount` is NOT NULL default `0`; `quote_status` is NOT NULL default `'not_submitted'`.
- Legacy quote, payment, and `work_started_at` columns remain present and must not be used as the new timer/bill authority.

No database writes were performed.

## Existing API behavior confirmed

The current root `create-booking.js`:

1. Enforces a public IP rate limit using the service-role client.
2. Verifies the Supabase bearer token against Auth and checks that the submitted phone matches the verified phone.
3. Accepts browser-supplied `payment_method` and `quoted_amount`.
4. Inserts directly into `service_bookings` with the service-role key.
5. Relies on the database `broadcast_new_booking` trigger to create matching offers, then reads the resulting `job_offers`.

The API must stop accepting payment choice and quoted amount. The browser must never set category rates or any bill amount.

## Approved rate catalogue

| Code | Customer label | 8-hour reference | Hourly snapshot |
|---|---|---:|---:|
| `helper` | Helper | ₹899 | ₹112.375 |
| `ordinary` | Ordinary | ₹1,199 | ₹149.875 |
| `skilled` | Skilled | ₹1,599 | ₹199.875 |
| `master` | Master | ₹1,999 | ₹249.875 |

These are labour-only rates. Materials/parts remain separate, itemized, and subject to customer approval. Do not infer category from free-text electrician skills.

## Required coordinated implementation

### 1. Database RPC (next implementation unit)

Create a narrow authenticated `SECURITY DEFINER` RPC for booking creation that:

- Requires `auth.uid()` and binds `customer_user_id` to that identity.
- Confirms the Auth phone claim matches the normalized booking phone.
- Accepts only the four category codes and maps rate/label exclusively on the server.
- Validates required customer/address/service/date/time fields and paired coordinate values.
- Inserts the immutable category, label, and hourly-rate snapshot in the same booking insert.
- Does not accept `payment_method`, `quoted_amount`, `service_charge`, or `materials_amount` from the client.
- Uses the legacy `payment_method` default/compatibility value internally only until the coordinated payment cutover; it must not expose a booking-time payment choice.
- Preserves existing `broadcast_new_booking` trigger behavior; do not manually duplicate `job_offers`.
- Returns only the created booking ID and safe offer summary.
- Revokes default PUBLIC/anon execution and grants execution only to authenticated.

### 2. API

Keep service-role use for the existing rate-limit check and post-insert offer-queue read only. Invoke the booking RPC with the customer's verified bearer token so `auth.uid()` is meaningful. Reject missing/invalid category. Ignore/reject any legacy browser `payment_method` or `quoted_amount` rather than persisting it.

### 3. Customer UI

- Add a required category selector with the approved 8-hour and hourly display.
- Submit only category code; server owns the rate snapshot.
- Remove Cash/Online selector and all payment-method text from the booking form/WhatsApp booking request.
- Keep payment controls hidden until the final bill is generated and the customer has approved the stop request.
- Clearly state that materials are separate and require an itemized approval.

### 4. Regression tests

Run the RPC in the disposable PostgreSQL harness with tests for:
- unauthenticated rejection;
- mismatched Auth phone rejection;
- invalid category rejection;
- each category maps to the exact approved rate;
- browser-supplied payment/quote amounts cannot affect stored booking;
- category/rate snapshot is present on insert;
- existing broadcast trigger fires exactly once;
- repeated client submission does not create duplicate offers (idempotency to be added before public rollout);
- no direct Production/TEST migration or deployment as part of this work.

## Explicit compatibility hazard

The Production `payment_method` column is `NOT NULL DEFAULT 'Cash'`. Do not drop, relax, or repurpose it in isolation. The final payment cutover must coordinate booking creation, customer/electrician/Admin displays, Razorpay order creation, payment verification, webhook reconciliation, cash receipt evidence, and legacy quote paths. Internal default compatibility is not permission to display or collect a payment choice at booking time.

## Release gate

This document records an audit and implementation contract only. No migration was applied to shared TEST or Production; no API/UI behavior was changed; no deployment was made. The booking RPC, API integration, customer form, and matching tests must be implemented and verified together before this workflow is considered ready.
