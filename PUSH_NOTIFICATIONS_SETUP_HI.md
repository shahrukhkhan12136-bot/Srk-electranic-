# Electrician booking push notifications (staged)

This feature is staged on `feature/electrician-categories-hourly-booking`; it is not live in production.

## Required secrets
Generate a VAPID key pair using a trusted Web Push key generator or `web-push generate-vapid-keys`. Keep the private key secret. Configure these Supabase Edge Function secrets:
- `VAPID_PUBLIC_KEY`
- `VAPID_PRIVATE_KEY`
- `PUSH_WEBHOOK_SECRET` (long random secret; configure the same value as a custom header on the database webhook)

Expose only the public key in `window.SRK_CONFIG.PUSH_VAPID_PUBLIC_KEY` in `srk-config.js`.

## Supabase setup after migration review
1. Apply the migration that creates `srk_push_subscriptions`.
2. Deploy Edge Function `push-job-offer`.
3. In Supabase Database Webhooks, create a webhook for `public.job_offers` on INSERT and UPDATE, targeting the `push-job-offer` Edge Function.
4. Add header `x-srk-push-secret: <same PUSH_WEBHOOK_SECRET>` and Content-Type `application/json`.
5. Test an offer INSERT and then an UPDATE to accepted/expired; verify the notification appears and closes.

## Device requirements
- HTTPS, supported Android browser/PWA, user login, and explicit notification permission.
- User must press Enable Push on each device.
- Android/browser notification sound and vibration are controlled by OS/browser notification settings. Web Push cannot force a native telephone ringtone or guarantee delivery when the OS restricts background activity.
- Foreground app also uses the in-app audible ringer after the user unlocks audio once.
