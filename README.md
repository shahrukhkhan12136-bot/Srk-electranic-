# SRK ELECTRONIC — Vercel + Supabase + Razorpay

This package is a nationwide electrician booking marketplace starter. Deploy the folder contents to Vercel (Other framework, no build command). Read `VERCEL_DEPLOY_HINDI.md` before deploying.

## Main pages
- `/` customer booking and electrician application
- `/admin.html` admin email/password portal
- `/electrician.html` electrician phone OTP portal

## Server-side environment variables (Vercel only)
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`

Never place the service-role key or Razorpay secret in browser code, GitHub, or chat. The browser config contains only the Supabase publishable key.

## Database
Run `COMPLETE_DATABASE_SETUP.sql` once in Supabase SQL Editor. It includes base tables, secure portal policies, customer privacy protection, admin email login compatibility, and Razorpay payment tracking. Existing records are not dropped.

## Matching and privacy
Booking offers go to all approved/active electricians at the exact PIN code; if none are available, the system falls back to the same state and district. Only the electrician who wins assignment receives customer phone/name/full address.

## Payment safety
The server creates an order from the saved booking amount, verifies Razorpay HMAC signature, checks the payment is captured and INR, matches the payment amount to the booking, then marks the booking paid. Start with Razorpay Test Mode.

## Not automatically activated
Deploying code does not create account credentials, enable SMS OTP, configure real-time push notifications, approve electricians, or complete Razorpay merchant KYC. Follow the Hindi deployment guide and test each flow before accepting real bookings.
