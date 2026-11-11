# Production Push Notifications — Deployment Checklist

This integration is prepared on branch `feature/production-push-notifications`. It is not deployed and the production database has not been changed.

## Components prepared
- `public.srk_push_subscriptions` migration with per-user RLS.
- `push-job-offer` Edge Function for new-offer and offer-closed notifications.
- Root `sw.js` push display and notification-click handling.
- Electrician dashboard subscription button and `offerId` deep-link highlighting.
- Browser config placeholder `SUPABASE_VAPID_PUBLIC_KEY` (intentionally blank).

## Required before enabling in Production
1. Generate one VAPID key pair for this Production environment.
2. Add only the VAPID public key to `window.SRK_CONFIG.SUPABASE_VAPID_PUBLIC_KEY`.
3. Store the VAPID private key, VAPID subject, and a strong random webhook secret as Supabase Edge Function secrets. Never commit these values or put the private key in browser code.
4. Apply the subscription-table migration to the Production database.
5. Deploy the `push-job-offer` Edge Function and verify its required Supabase/VAPID secrets are present.
6. Configure a Supabase Database Webhook for `public.job_offers` on INSERT and UPDATE, targeting:
   `https://gnqhoaqatmoiwwhgzkgm.supabase.co/functions/v1/push-job-offer`
   Include JSON content type and the custom header `x-srk-push-secret` with the same strong secret stored in the Edge Function.
7. Confirm the project's Database Webhooks/pg_net support is enabled. It was not listed among the extensions enabled at the time of inspection.
8. Test with an approved, active electrician account on Android Chrome: subscribe, create a real test booking in a controlled test window, verify one notification, tap it, confirm the electrician dashboard opens the matching offer, then accept/reject and verify closure behavior.
9. Review webhook request/response logs and Edge Function logs. Confirm no duplicate notifications and no notification to inactive/unapproved electricians.
10. Only after all checks pass, merge this branch and perform the single consolidated Netlify deployment.

## Safety notes
- The current `job_offers` rows are created by the existing `broadcast_new_booking` trigger on `service_bookings`; the push webhook must listen to `job_offers`, not directly to bookings.
- The existing offer list uses `srk_get_my_offer_details()`; the push URL carries that row's `offer_id`.
- Do not expose service-role credentials or the VAPID private key.
- Do not enable push while the public VAPID key is blank.
- No production migration, Edge Function deployment, webhook creation, secret configuration, merge, or website deployment has been performed as part of this preparation.
