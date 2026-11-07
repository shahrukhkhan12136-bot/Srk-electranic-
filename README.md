# SRK ELECTRONIC — Razorpay Checkout (Netlify)

This is a static website with Netlify serverless functions for secure Razorpay Standard Checkout.

## Required Netlify setup

1. In Netlify, open the site for `srkelectronic.netlify.app`.
2. Go to **Site configuration → Environment variables**.
3. Add these server-side variables (use your Razorpay **Test Mode** credentials first):
   - `RAZORPAY_KEY_ID`
   - `RAZORPAY_KEY_SECRET`
4. Do not put `RAZORPAY_KEY_SECRET` in frontend code or a `NEXT_PUBLIC_` / `VITE_` / `REACT_APP_` variable.
5. Deploy this project from the folder containing `netlify.toml`. Netlify installs the `razorpay` dependency from `package.json` and publishes `netlify/functions`.

## Payment flow

- Customer selects online payment and enters an amount of at least ₹1.
- `POST /api/create-order` creates an INR order through Razorpay.
- Razorpay Standard Checkout opens with that `order_id`.
- `POST /api/verify-payment` checks HMAC-SHA256 on the server, then fetches the payment directly from Razorpay and accepts it only when its status is `captured`, currency is INR, and its order ID matches.
- Cash / pay-later bookings continue to WhatsApp.

## Local development

Install Node.js, then run `npm install`. Install Netlify CLI (`npm install -g netlify-cli`) and run `netlify dev` from this folder. Set `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` in your local `.env` file. The `.env` file is ignored by Git and is intentionally not included in the distributable ZIP.

## Test safely

Use Razorpay Test Mode keys and test payment methods from Razorpay's test checkout instructions. Test payments do not collect real money. Switch to Live Mode credentials only after your Razorpay account and website are approved and you have tested order creation and signature verification.

## Notes

- This project does not create a database or store booking/payment records. The WhatsApp booking message is customer-initiated; the website does not automatically create a service-job record.
- For production reliability, configure Razorpay webhooks (`payment.captured`, `payment.failed`, `order.paid`) and a persistent order ledger before relying on unattended reconciliation. The website must never treat a browser success message alone as proof of payment.


## Important account and safety requirements

- The Razorpay merchant account, KYC, and settlement bank account must belong to the legally eligible adult/business owner who is responsible for this service. Do not use another person's credentials without their permission.
- Keep both API keys private. Add them only in Netlify environment variables; never send the Key Secret in WhatsApp, email, or website code.
- Start with Test Mode. Test payments are simulated and do not transfer real money. Only the verified account owner should activate Live Mode after Razorpay approves the account and website.
- Confirm the payment shows `captured` in Razorpay Dashboard → Transactions → Payments before starting paid work.


## All-India marketplace starter update

- Customer booking now collects state, district and PIN code.
- A separate electrician application form is included.
- Current forms hand off to WhatsApp; persistent database submission and automatic job assignment are not live yet.
- `SUPABASE_SCHEMA.sql` provides the initial database tables and public insert-only policies.
- Read `IMPLEMENTATION_PLAN_HI.md` for deployment, commission and security requirements.
- Suggested initial platform commission: 15% on completed jobs, configurable and disclosed before booking.
- Electrician payouts require an approved marketplace payout product (for example Razorpay Route) and KYC; Standard Checkout alone does not split payouts.


## All-India booking + electrician offer queue (new)

This build adds server-side booking/application submission and a job-offer queue. When a customer submits a booking, `create-booking` saves it to Supabase, then creates an offer for **every approved and active electrician** matching the exact PIN code. If none match that PIN code, it falls back to the same state + district. Offers are stored in `job_offers`. This is an offer queue, not yet a live push/SMS/WhatsApp notification; delivery requires a configured messaging provider and an electrician app/dashboard to read and respond to offers.

### Setup required before deployment
1. Create a Supabase project.
2. Run all of `SUPABASE_SCHEMA.sql` in Supabase SQL Editor.
3. In Netlify environment variables set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (keep the service-role key secret; never put it in browser code or ZIP shared publicly). Keep Razorpay variables as separately documented.
4. Deploy this folder to the existing Netlify site.
5. Review applications and create/activate electrician profiles only after identity, skill, and safety checks. Set `verification_status='approved'` and `active=true` only for approved providers.
6. Test bookings in a controlled pilot district.

Example manual activation (replace values; run only after verifying the electrician):
```sql
update public.electrician_profiles
set verification_status = 'approved', active = true
where id = 'ELECTRICIAN_PROFILE_UUID';
```

**Important:** The site is not automatically live-updated by creating this ZIP. Database-backed booking and offer matching will work only after Supabase schema and Netlify environment variables are configured and the updated project is deployed. The current matching is PIN-code first, then district/state; true distance-based nearby matching needs customer/provider coordinates and a maps/geocoding integration.

## Admin panel + electrician login (new portal update)

New pages:
- `/admin.html` — OTP login, booking status updates, application approval/rejection, partner activation/deactivation, booking/partner counts, completed-job commission summary.
- `/electrician.html` — OTP login, own profile, job offers, accept/decline actions. When a partner accepts first, the database assigns the job and expires competing offers.
- `PORTAL_SCHEMA.sql` — RLS policies, admin allowlist, verified-phone profile linking, secure accept/decline RPC, admin application review RPC, 15% commission calculation on completion.
- `srk-config.example.js` — browser-safe Supabase URL + anon/publishable key template.

### One-time setup (must be done before the portals work)
1. In Supabase, enable **Phone Auth / SMS OTP** and configure an SMS provider. Test OTP delivery before launch.
2. Run `SUPABASE_SCHEMA.sql`, then run `PORTAL_SCHEMA.sql` in the Supabase SQL Editor.
3. Copy `srk-config.example.js` to `srk-config.js`; replace the Supabase project URL and anon/publishable key. Deploy `srk-config.js` with the site. This key is designed for browser use; **never place the service-role key in this file**.
4. In Supabase Auth, create/sign in with the owner/admin phone and complete OTP verification. In Authentication → Users, copy that user's UUID. Add the owner to the admin allowlist in SQL:
   ```sql
   insert into public.srk_admin_users(user_id)
   values ('PASTE_OWNER_AUTH_USER_UUID_HERE');
   ```
5. Sign in at `/admin.html`. If the owner is not in `srk_admin_users`, data access is intentionally denied.
6. Review electrician applications. Approve only after manually checking identity, address, skill and relevant documents. The approved profile is linked to the matching verified Supabase phone login. Activate only after checks are complete.
7. Electrician signs in at `/electrician.html` with the exact verified mobile number used in the application. If the profile was approved before the verified phone login was created, the auth trigger links it when the phone is confirmed; otherwise ask the partner to sign out/in once after approval.
8. Test with two demo electricians and a demo booking in one district. Confirm that only the matching profiles see the offer and only the first accepted electrician receives the job.

### Important production limitations
- The admin allowlist is a manual owner-controlled list. Never expose the service-role key in browser code.
- Phone OTP requires an SMS provider, possible per-message charges, and rate limits. Configure abuse protection/CAPTCHA before public launch.
- The offer queue is visible in the electrician portal after login. Push/SMS/WhatsApp notifications are **not** configured by this update.
- 15% is a proposed commission, not a live collection mechanism. Commission is calculated on a completed booking only when `quoted_amount` is set. Payment collection, GST/invoices, refunds, provider payouts and a marketplace split-settlement integration need separate configuration and legal/accounting review.
- Customer and electrician data are sensitive. Keep access restricted, publish privacy/terms/refund policies, and do not collect Aadhaar numbers or document images until a compliant secure KYC workflow is in place.
- This ZIP is not deployed automatically. The live website changes only after the owner configures Supabase and deploys this folder to Netlify.


## Customer privacy hardening (November 2026)
Run `PORTAL_SECURITY_UPDATE.sql` after the two existing schema files. It removes the policy that allowed every offer recipient to read the full customer booking row and adds the `srk_get_my_offer_details()` RPC. Before assignment, electricians see only the job summary and broad area. Only the electrician assigned to the job can see the customer's name, phone number and exact address. The electrician portal now uses this RPC rather than joining the bookings table directly.

Do not launch the public electrician portal until all three SQL files have been applied and the two-electrician privacy/assignment test in `PORTAL_SETUP_HINDI.md` passes.


## Admin email login update
See `ADMIN_SETUP_HINDI.md` and run `ADMIN_EMAIL_LOGIN_SETUP.sql` once before deploying the updated `admin.html`.
