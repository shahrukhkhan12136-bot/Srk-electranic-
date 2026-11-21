# SRK ELECTRONIC — Category-neutral Technician Dispatch Contract

Date: 21 November 2026  
Source: Feature Branch only  
Migration: `20261121140000_category_neutral_technician_dispatch.sql`  
Frontend integration: GPT-1

## Purpose

This dispatch layer extends the canonical Technician identity to all service categories without replacing or modifying the legacy Electrician `job_offers` table or its current broadcast path.

## Technician online / GPS

`POST /rest/v1/rpc/srk_technician_set_presence`

Example:

```json
{
  "p_is_online": true,
  "p_latitude": 26.4499,
  "p_longitude": 80.3319
}
```

- Requires an authenticated Supabase phone-OTP session, canonical Technician identity, verified phone, active account, and at least one Admin-approved application with approved skills.
- When going Online, provide a current GPS fix. A previously stored fix may be reused only while it is less than five minutes old.
- GPS updates are allowed only while Online or while an accepted booking is active. Going offline with no active job cannot submit fresh coordinates.
- GPS unavailable: do not fabricate coordinates or refresh the timestamp. The last fix and its original timestamp remain stored; stale fixes are not eligible for dispatch.
- An accepted Technician is set Offline for new offers and linked to the active booking. GPS updates may continue while that booking is active.
- Completion/cancellation releases the active booking and turns Online off; the Technician must explicitly go Online again.

## Booking-to-dispatch handoff

The booking row now has three canonical fields:

- \`srk_service_category_code\`: one of the Admin-managed service category codes
- \`srk_service_skill_code\`: an active skill belonging to that category
- \`srk_required_technician_count\`: 1–10, default 1

Both category and skill must be present together. On insert:

1. The existing \`broadcast_booking_job()\` trigger skips only rows with a canonical service category; legacy Electrician bookings continue through the old sequential Electrician dispatcher.
2. \`srk_start_category_neutral_booking_dispatch\` creates the shared dispatch request and immediately attempts the first nearest-Technician offer in the same database transaction.
3. A booking without GPS coordinates is still saved. Its dispatch remains searching with a \`work_location_gps_missing\` event and no Technician offer. If coordinates are added before any offer/assignment, the pending dispatch location snapshot is refreshed and the existing minute worker can retry.

This prevents new canonical bookings from receiving both legacy Electrician offers and shared Technician offers.

## Create a dispatch request — trusted backend only

`POST /rest/v1/rpc/srk_dispatch_create_for_booking`

```json
{
  "p_booking_id": "booking UUID",
  "p_category_code": "plumber",
  "p_skill_code": "residential_plumbing",
  "p_required_technician_count": 1,
  "p_offer_ttl_seconds": 60
}
```

- Callable only with the server-side Supabase service-role credential. Never call from browser/mobile using a service-role key.
- Category and skill must be active and belong together.
- Booking must exist and be non-terminal. GPS may be missing at creation; in that case dispatch waits without issuing offers until a valid work-site location is supplied.
- Requested Technician count is 1–10.
- Offer expiry is configurable per request from 15–300 seconds; default 60 seconds.
- Request is idempotent for identical booking/category/skill/count. Conflicting requirements for an already-created request are rejected.

## Matching / sequential offers

The trusted worker calls:

`POST /rest/v1/rpc/srk_dispatch_process_pending_queue`

This is added to the existing Netlify `expire-booking-offers` worker, which continues to process the legacy Electrician queue. The new RPC is backward-compatible: if the new migration is not yet installed and PostgREST returns 404, the old Electrician worker continues normally.

For each searching dispatch request, the server:
1. Expires overdue offers and appends expiry events.
2. Selects one nearest eligible Technician at a time.
3. Requires approved application, approved matching skill, Online status, no active booking, and a GPS fix newer than five minutes.
4. Uses straight-line GPS distance for ranking and only offers within 30 km.
5. Locks the presence row while selecting to avoid concurrent duplicate dispatch.
6. Sends one live offer at a time. A Technician cannot hold two live offers and a booking cannot have two live offers.
7. If declined/expired, the next nearest eligible Technician can receive the offer. The queue remains searching when no eligible Technician is currently available, so a later worker pass can retry.

The current code records straight-line distance for ranking. Road-distance travel fees are not calculated in this migration and must remain a separate verified routing calculation (first 3 km free, then ₹4/km one-way per the Master requirements).

## Technician offer inbox and response

Read own offers:

`POST /rest/v1/rpc/srk_technician_get_my_dispatch_offers`

Body: `{}`

Accept or decline:

`POST /rest/v1/rpc/srk_technician_respond_to_dispatch_offer`

```json
{
  "p_offer_id": "offer UUID",
  "p_response": "accepted"
}
```

`p_response` is `accepted` or `declined`.

- The server derives Technician identity from `auth.uid()`; clients cannot supply a Technician ID.
- Only the owner of a current, unexpired offer can respond.
- Acceptance atomically records the shared Technician assignment, updates presence to Offline/active booking, and increments the dispatch assigned count.
- If the booking requires multiple Technicians, the next offer is issued after the prior acceptance.
- Declining advances to the next candidate.
- Expired offers are rejected and the queue is advanced.
- Direct table access is revoked from `anon` and `authenticated`; use the RPCs.

## Booking completion/cancellation

A terminal booking update releases active Technician presence. The last GPS fix remains as last-known history; it is not refreshed while Offline. Cancellation marks active assignment rows cancelled and closes outstanding offers. Completion closes the dispatch request after the completion ledger records the assigned Technicians.

## Important remaining integration gates

- The existing customer `create-booking.js` is still Electrician-specific and does not call `srk_dispatch_create_for_booking`. GPT-1 / backend booking integration must pass the canonical category code and skill code after booking creation.
- The migration is source-only. It has not been applied to Production or the partial TEST project.
- The current minute worker can process the new queue only after the migration is installed; no deployment or hosted DB change has been performed.
- The old `broadcast_booking_job()` still broadcasts through legacy Electrician profiles. This migration intentionally does not replace it. A separate, reviewed booking-trigger cutover is required once the category-neutral booking API is integrated, to prevent duplicate Electrician offers for new Electrician bookings.
- Admin manual assignment, road-distance travel fee calculation, dispatch notifications delivery, and full concurrent PostgreSQL tests remain separate tasks.
