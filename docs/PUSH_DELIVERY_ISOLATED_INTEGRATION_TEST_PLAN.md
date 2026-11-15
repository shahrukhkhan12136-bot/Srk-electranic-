# SRK ELECTRONIC — Push Delivery Isolated Integration Test Plan

**Status:** Test plan only. No test environment has been provisioned, no migration has been applied, and no push has been sent.

## 1. Preconditions / stop gates

Run only in a separately approved isolated Supabase project and isolated Netlify site. Never point these tests at production.

1. Confirm the project URL/ref is the isolated project; confirm no production service-role key or VAPID key is present in the test runner.
2. Apply prerequisite migrations in repository order through:
   - `20261114210000_sequential_nearest_offer_dispatch.sql` (`job_offers.expires_at`)
   - `20261114310000_electrician_self_availability.sql` (`electrician_profiles.available_for_work`)
   - `20261115170000_durable_push_delivery_outbox.sql`
   - `20261115180000_push_subscription_delivery_ledger.sql`
3. Verify subscription columns: `id,user_id,endpoint,p256dh,auth`; electrician columns: `id,user_id,auth_user_id,active,available_for_work,verification_status`; booking and offer columns used by sender.
4. Verify only the new `trg_srk_enqueue_job_offer_push` trigger remains active for push on `job_offers`; legacy `trg_srk_push_job_offer` must be absent. Verify exactly one outbox row per offer.
5. Configure isolated-only secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `PUSH_WEBHOOK_SECRET`, `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`. Keep private keys out of logs and browser bundles.
6. Deploy the Edge Function to the isolated project, then configure a disabled/paused worker. Enable the isolated scheduled worker only after sender smoke tests pass.
7. Use dedicated test customer/electrician identities, test subscriptions and synthetic bookings/offers. Do not use real customer data or real payment/provider credentials.

## 2. Migration / privilege checks

- Apply migrations in a transaction-capable migration runner; a failed preflight must leave no partial schema change.
- Confirm private outbox and delivery tables have RLS/privileges inaccessible to anon/authenticated; service-role-only RPC execution.
- Confirm authenticated subscription CRUD is owner-scoped and cannot read/write another user's subscriptions.
- Confirm service-role RPC calls succeed and anon/authenticated calls fail with authorization error.
- Confirm legacy direct HTTP trigger is removed atomically with outbox trigger installation.
- Confirm duplicate INSERT processing creates one outbox row because `offer_id` is unique.
- Confirm an UPDATE to an existing offer does not enqueue a second notification.

## 3. Delivery behavior matrix

| Case | Setup / action | Expected result |
|---|---|---|
| Happy path | One eligible electrician, one valid subscription, unexpired offered row | One outbox row, one ledger row, one push, terminal delivered |
| Multiple devices | Same user has 2–3 valid subscriptions | One ledger row and one attempt per subscription |
| Replay | Reinvoke sender after all deliveries are delivered | No additional provider send; completion true |
| Partial failure | One device succeeds, another transiently fails | Success remains delivered; only failed device is retried |
| Retry exhaustion | One device fails through 5 attempts | That ledger row becomes dead; no infinite retries |
| Gone endpoint | Provider returns 404 or 410 | Subscription removed; FK cascade removes its ledger row |
| No subscription | Eligible user has no subscriptions | Empty target set completes without provider send |
| Offer expired | Offer expires before sender re-reads it | Ignored; no push |
| Offer accepted/cancelled | Booking or offer is no longer offerable | Ignored; no push |
| Electrician ineligible | Inactive, unavailable, unapproved or missing user link | Ignored; no push |
| Bad secret | Missing/incorrect webhook secret | 401; no database claim |
| Oversized/malformed body | >32 KB or invalid payload/outbox UUID | 413/400; no database claim |
| Parallel worker claim | Two workers claim same due outbox batch concurrently | Row locks prevent duplicate outbox claims |
| Parallel device claim | Two sender requests claim same outbox/user concurrently | Row locks prevent same live delivery row being claimed twice |
| Worker timeout | Worker loses sender response after provider accepted request | Document ambiguity; monitor possible duplicate on lease retry |
| Dead-letter outbox | Force repeated sender-level failures | Outbox reaches dead at configured cap; alert generated |

## 4. Operational / observability checks

- Record counts only: claimed, delivered, retry, dead, stale lease reclaimed; never log endpoint URLs, auth keys, payload PII or secrets.
- Explicitly simulate a worker crash after the final allowed outbox attempt and a sender crash after the final allowed device attempt; expired leases must become dead-letter rows rather than remain processing forever.
- Current worker batch is capped at 3 because requests are processed sequentially; validate actual Netlify execution time against the 5-minute lease before increasing it.
- Alert on dead outbox rows, dead subscription rows, repeated worker failures, missing secrets, and outbox age above agreed SLO.
- Verify worker timeout budgets fit the 5-minute database lease and scheduled cadence; the current worker claims at most 3 outbox rows sequentially. Re-measure in isolation; reduce batch/concurrency or extend the lease if observed worst-case duration approaches the lease.
- Verify cleanup/retention policy for delivered/dead outbox and ledger rows before enabling in production.
- Document that Web Push is at-least-once: provider timeout after acceptance is ambiguous and transport-level exactly-once cannot be guaranteed.

## 5. Exit criteria

All migration, privilege, delivery, retry, concurrency, stale-state, and monitoring checks pass in isolation; no duplicate send on confirmed-success replay; partial failure retries only undelivered subscriptions; legacy trigger absent; rollback rehearsed. Only after these criteria and a separate explicit approval may any production rollout be considered.
