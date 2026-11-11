# Production Push Notifications — Deployment Checklist

This integration is prepared on branch `feature/production-push-notifications`. It is not deployed and the production database has not been changed.

## Components prepared
- `public.srk_push_subscriptions` migration with per-user RLS.
- `public.srk_save_push_subscription(...)` authenticated RPC to safely transfer a browser endpoint to the currently signed-in account without weakening table RLS.
- `push-job-offer` Edge Function for new-offer and offer-closed notifications.
- Root `sw.js` push display and notification-click handling.
- Electrician dashboard subscription button and `offerId` deep-link highlighting.
- Browser config placeholder `SUPABASE_VAPID_PUBLIC_KEY` (intentionally blank).

## Required before enabling in Production
1. Generate one VAPID key pair for this Production environment.
2. Add only the VAPID public key to `window.SRK_CONFIG.SUPABASE_VAPID_PUBLIC_KEY`.
3. Store the VAPID private key, VAPID subject, and a strong random webhook secret as Supabase Edge Function secrets. Never commit these values or put the private key in browser code.
4. Apply the subscription-table migration to the Production database.
5. Deploy the `push-job-offer` Edge Function with JWT verification disabled for the database webhook endpoint (for example, `--no-verify-jwt`). The function independently validates the high-entropy `x-srk-push-secret`; do not leave the endpoint unprotected. Verify all required Supabase/VAPID secrets are present.
6. Configure a Supabase Database Webhook for `public.job_offers` on INSERT and UPDATE, targeting:
   `https://gnqhoaqatmoiwwhgzkgm.supabase.co/functions/v1/push-job-offer`
   Include JSON content type, the project publishable key in the `apikey` header, and the custom header `x-srk-push-secret` with the same strong secret stored in the Edge Function.
7. Enable the project's `pg_net` extension before creating the Database Webhook; Supabase documents Database Webhooks as asynchronous triggers built on `pg_net`. Confirm webhook calls complete successfully. The webhook payload includes `old_record: null` for INSERT and the previous row in `old_record` for UPDATE, which the function uses to detect a genuine transition out of `offered` and avoid repeat closure alerts.
8. For this project’s `sb_publishable_...` client key, the Edge Function must remain configured with JWT verification disabled; the platform does not authenticate the new publishable key for Edge Function requests in that mode. The function’s `x-srk-push-secret` comparison is the actual webhook authorization check. Do not treat the publishable `apikey` header as a secret. Keep the custom webhook secret strong and private; if using a Supabase secret API key in webhook headers, follow Supabase guidance to store it in Vault rather than hard-coding it in webhook configuration.
9. Test with an approved, active electrician account on Android Chrome: subscribe, create a real test booking in a controlled test window, verify one notification, tap it, confirm the electrician dashboard opens the matching offer, then accept/reject and verify closure behavior.
10. Review webhook request/response logs and Edge Function logs. Confirm no duplicate notifications and no notification to inactive/unapproved electricians.
11. Only after all checks pass, merge this branch and perform the single consolidated Netlify deployment.

## Safety notes
- The current `job_offers` rows are created by the existing `broadcast_new_booking` trigger on `service_bookings`; the push webhook must listen to `job_offers`, not directly to bookings.
- The existing offer list uses `srk_get_my_offer_details()`; the push URL carries that row's `offer_id`.
- Do not expose service-role credentials or the VAPID private key.
- Do not enable push while the public VAPID key is blank.
- No production migration, Edge Function deployment, webhook creation, secret configuration, merge, or website deployment has been performed as part of this preparation.
