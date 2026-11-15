# GPT-2 Dependency Matrix — Base, Identity, RLS, Support and ACL — 16 Nov 2026

स्थिति: current Git branch की static source inspection। कोई SQL/pgTAP execute नहीं किया; कोई DB connect, Production query, migration replay/repair, DDL, data write, deployment या app source edit नहीं हुआ।

## A. Dependency matrix

| Object / migration | Required earlier object(s) | Source evidence | Status |
|---|---|---|---|
| `public.service_bookings` | Canonical starter schema; `pgcrypto` for `gen_random_uuid()` | Base table केवल historical `COMPLETE_DATABASE_SETUP.sql` / `SUPABASE_SCHEMA.sql` में मिली; migrations में create-table baseline नहीं मिला | **BLOCKER: approved versioned baseline missing** |
| `public.electrician_profiles`, `public.job_offers` | `electrician_applications`, `service_bookings`, Auth schema | Historical setup SQL creates them; migrations alter/use them | **BLOCKER: same baseline dependency** |
| `public.srk_admin_users` | `auth.users` | Historical setup SQL creates allowlist table | **BLOCKER: baseline dependency** |
| `public.is_srk_admin()` | `srk_admin_users`, `auth.uid()` | Definition found in `COMPLETE_DATABASE_SETUP.sql` / `ADMIN_EMAIL_LOGIN_SETUP.sql`; no introducing migration found in current migration directory search | **BLOCKER: no versioned introduction located** |
| `20261108120608_add_public_api_rate_limiting.sql` | Supabase roles; private schema creation; `pg_catalog` | Creates `private.srk_public_api_rate_limits`; grants service_role only | Source-local dependency appears self-contained apart from platform roles |
| `20261108121115_add_customer_account_booking_access.sql` | `service_bookings`, `auth.users` | Adds `customer_user_id` FK and own-booking SELECT policy | Depends on base table/Auth |
| `20261108234000_combine_booking_read_policy.sql` | `service_bookings.customer_user_id`, `public.is_srk_admin()`, authenticated role | Drops two earlier policies and creates combined Admin-or-customer policy | **BLOCKED by missing helper/baseline proof** |
| `20261109000500_harden_electrician_profile_identity_linking.sql` | `electrician_profiles.user_id`, phone/status fields, `auth.users` | Adds `auth_user_id`, consistency/backfill/index/triggers | Depends on base profile/Auth |
| `20261109001000_add_google_maps_location_support.sql` | `service_bookings`, `electrician_applications`, `electrician_profiles`, `public.is_srk_admin()`, identity columns | Adds GPS columns/checks and replaces Admin application-review RPC | Depends on baseline + identity hardening + Admin helper |
| `20261109002000_expose_assigned_booking_map_pin.sql` | `job_offers`, `electrician_profiles.user_id`, `service_bookings`, GPS columns | Creates map/offer details RPC | Must follow identity and GPS prerequisites |
| `20261109_electrician_inspection_quotes_and_service_only_commission.sql` | Booking base + `customer_user_id`, profile identity, offers, GPS, quote/payment columns | Adds quote fields/RPCs and replaces offer-details function | Must follow customer, identity, GPS, and base prerequisites; function replacement order matters |
| `20261109003000_secure_commission_reporting.sql` | `public.is_srk_admin()`, `amount_paid`, `commission_amount`, booking/profile base | Creates Admin/partner reports and adjusts column UPDATE grants | **Order risk:** `amount_paid` restore file is later in branch |
| `20261109010000_create_secure_wallet_ledger_foundation.sql` | `auth.users`, electrician profile identity fields, `public.is_srk_admin()`, UUID generation | Creates wallet tables/RPCs; reads profile and Admin helper | Depends on identity and Admin helper |
| `20261109103143_move_customer_call_contact_lookup_to_private.sql` | `service_bookings.customer_user_id`, assigned profile fields, `private` schema | Creates private implementation + public invoker wrapper | Depends on customer identity and profile baseline |
| `20261113230000_support_attachment_paths_and_admin_message_list.sql` | `srk_booking_complaints`, complaint messages, attachment table, customer ownership, `public.is_srk_admin()` | Functions only reference these tables; this file does not create the complaint base tables | **BLOCKER: complaint table/bucket baseline and helper provenance not established here** |
| `20261114150000_customer_booking_submission_idempotency.sql` | `service_bookings` | Adds request key/fingerprint, check and unique partial index | Depends on base booking table |
| `20261116200000_restore_service_bookings_amount_paid.sql` | `service_bookings` | Adds nullable `amount_paid` and nonnegative CHECK | Exists in source, but after earlier quote/commission references |

## B. Newly confirmed specific findings

### 1. Public API rate limiting
`20261108120608` creates the `private` schema if absent, creates its own rate-limit table, revokes access from public/anon/authenticated, and grants service-role access. Its function execution is also service-role only. Static source inspection found no dependency on customer or booking tables.

### 2. Customer call-contact lookup
`20261109103143` moves implementation into `private.srk_get_customer_call_contacts_impl()`. It requires a signed-in customer and filters bookings by `customer_user_id = auth.uid()`; it joins the assigned electrician profile. It therefore depends on customer-account migration and the core booking/profile schema.

### 3. Complaint attachment/message RPCs
`20261113230000` defines customer and Admin list RPCs, but it does not create the referenced complaint, message, or attachment tables. Admin RPCs call `public.is_srk_admin()`. The migration's comment calls attachments private, but this file alone does not prove the Storage bucket, object policies, or base tables exist. Their authoritative introducing source still needs locating and matching.

### 4. Commission ACL
`20261109003000` revokes broad authenticated UPDATE on `service_bookings`, then grants column UPDATE on `status`, `quoted_amount`, `amount_paid`, and `payment_status`. Its own comment says RLS must limit rows. This source grant is not by itself proof that only Main Admin can update rows; the effective result also depends on all applicable policies, later grants/revokes, function paths and runtime role tests. Do not infer effective Production privileges from this migration alone.

### 5. Amount-paid chronology
The quote/commission source reads `amount_paid`; its explicit add-column source is `20261116200000_restore_service_bookings_amount_paid.sql`. If the approved baseline does not already contain that column, source order is inconsistent for a clean replay. This is a source-level ordering risk, not a proven live failure.

## C. Dependency order — partial, not a replay plan

The following relative relationships are supported by source references/comments:
1. Core starter schema + platform Auth/roles/extensions must precede migrations that alter/use core tables.
2. Customer-account column migration must precede combined customer/Admin booking read policy and customer-scoped contact RPCs.
3. Electrician identity hardening precedes GPS migration (explicit source comment), and GPS precedes map RPC.
4. Map RPC precedes quote migration's replacement/extension of that same RPC; replaying the older map migration afterward risks replacing the extended return shape.
5. Complaint base tables and Admin helper must precede support message/attachment RPCs.
6. `amount_paid` must exist before quote/commission/reporting runtime paths that reference it; current explicit restore migration is later in source sequence.

This is not a complete topological ordering and must not be used to run migrations. Duplicate 8-digit `20261109` version lineage, helper provenance, full baseline and remote history remain unresolved.

## D. Evidence still required before any disposable replay

- Approved, versioned starter baseline for core booking/electrician/offer/admin/complaint tables, columns, constraints, indexes, RLS and grants.
- Authoritative migration source/approved placement for `public.is_srk_admin()`; clarify whether `srk_is_admin()` remains a separate legacy helper.
- Complaint attachment table and Storage bucket/object-policy introducing source.
- Full scan of all 87 migrations for referenced columns/functions/policies/grants and replacement ordering.
- DBA/Database Owner read-only evidence for remote migration lineage and any Production divergence.
- Explicit approval of a disposable local replay baseline and pinned CLI/PostgreSQL/pgTAP versions.

Until then: no reset, replay, test execution against any shared/remote database, migration repair, rename/delete/reorder, or deployment. No GPT-1 application source changes.
