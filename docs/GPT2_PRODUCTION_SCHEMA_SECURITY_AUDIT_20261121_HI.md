# SRK ELECTRONIC — Production Schema Snapshot and Security Findings

Date: 21 November 2026  
Target: Supabase Production project metadata (read-only)  
Feature Branch: `feature/master-technician-payment-cycle-20261121`  
Status: **Read-only audit; no Production database changes**

## Production state verified

The read-only Supabase table inventory and migration inventory were inspected. Production migration history returned by Supabase ends at version `20261115092149` (`retire_unused_razorpay_route_transfer_ledger`). The Feature Branch contains later source migrations, including the unified Technician completion-cycle migration; those branch migrations are not evidence of Production deployment.

Relevant current Production schema:

- `public.electrician_applications`: Electrician-specific fields (full_name, phone, state, district, pincode, skills, experience_years, about, verification_status, active and optional coordinates). Status constraint is pending/approved/rejected/suspended. No shared category-neutral application identity is represented in this table.
- `public.electrician_profiles`: Electrician-specific profile, phone, location, skills, active/status, and Auth identity links (`user_id`, `auth_user_id`). It references the legacy application and Electrician profile history.
- `public.srk_electrician_verification_documents`: KYC document rows are linked to `electrician_profile_id` and/or the legacy application; document types are identity_proof, address_proof, skill_certificate.
- `public.srk_electrician_verification_events`: Review/upload events are linked to the Electrician profile and document.
- `public.services`: Simple service-name/description/active catalogue; no general category hierarchy, skill mapping or versioned service-rate model was visible in this table.
- `public.service_bookings`: Current booking schema remains Electrician-oriented (including `assigned_electrician_id`) and contains legacy quotation fields/status values. It does not yet expose the full category-neutral Technician booking model.
- `public.job_offers` is linked to `electrician_profiles` through `electrician_id`; this is not the generic Technician dispatch model.

## Critical security advisory surfaced by Supabase

Supabase table inspection returned a critical RLS advisory:

- Table: `srk_private.work_transition_authorizations`
- Current metadata: RLS disabled.
- Supabase advisory warns this table is exposed to anon/authenticated roles through client libraries and instructs that the issue must be surfaced to the owner.
- Suggested baseline SQL from the advisory:
  `ALTER TABLE "srk_private"."work_transition_authorizations" ENABLE ROW LEVEL SECURITY;`

**Do not run that SQL blindly.** Enabling RLS without carefully designed policies may block the internal trigger/RPC workflow. First inspect every function/trigger that reads or writes this authorization table, verify grants and schema exposure, then define least-privilege policies or revoke client-role access as appropriate. No remediation was applied in this audit.

## Implementation consequences

1. The shared Technician application/profile/KYC model must be introduced as a new category-neutral layer, not by storing non-Electricians as Electrician profiles.
2. Verified Supabase Auth identity must be resolved server-side; never trust a request-body phone number as OTP proof.
3. Existing Electrician application, profile, KYC document and review-event records must remain intact and be mapped explicitly to canonical Technician IDs where safe.
4. Do not add category/rate assumptions to the current simple `services` catalogue. Build category, subcategory, skill, service and versioned rate structures from the approved Master System requirements; disputed rates remain Admin-configurable.
5. Generic dispatch must coexist with the legacy `job_offers.electrician_id` flow until a tested compatibility migration exists.
6. Legacy quotation fields and historical records are still present in Production. The Feature Branch's quote-RPC retirement migration does not prove Production has retired those fields or all payment/refund dependencies.

## Verification and safety

- Production table/migration inventory only; no personal row data was queried.
- No DDL, DML, Storage, policy, API, payment, payout, Main Branch or deployment changes were made.
- The TEST project is not a full Production clone; do not treat it as a valid Production migration replay baseline.
- Before any migration, inspect complete function/trigger dependencies for `srk_private.work_transition_authorizations`, Admin application review, KYC storage, dispatch and booking/payment paths.


### Follow-up ACL inspection

A read-only ACL query was run after the RLS advisory. The observed table grants and schema ACL for `srk_private.work_transition_authorizations` showed only the `postgres` role; no direct table privileges or schema USAGE grants for `anon` or `authenticated` were returned. The table remains flagged by Supabase because RLS is disabled, but the ACL snapshot did **not** show direct client-role grants. This narrows the immediate exposure evidence; it does not replace fixing the RLS posture or reviewing all owner/definer paths. The table is accessed by SECURITY DEFINER work-approval functions and a booking trigger, so any remediation must preserve that internal transactional workflow. Do not apply the advisory SQL without that review.
