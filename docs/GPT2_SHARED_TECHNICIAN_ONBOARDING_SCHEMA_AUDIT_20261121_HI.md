# SRK ELECTRONIC — Shared Technician Onboarding Schema Audit

Date: 21 November 2026  
Branch: `feature/master-technician-payment-cycle-20261121`  
Status: **Read-only source audit; no schema or production changes**

## Verified source evidence

The current KYC implementation is complete enough to preserve as an Electrician legacy workflow, but it is not a shared Technician onboarding model.

- `20261109000500_harden_electrician_profile_identity_linking.sql` links `electrician_profiles.user_id` and `auth_user_id`, rejects mismatched IDs, and checks the Auth user's confirmed phone against the profile phone. It also rejects ambiguous verified Auth identities for an Electrician phone.
- `20261115140000_electrician_kyc_review_and_activation_gate.sql` creates the private `srk-electrician-verification` Storage bucket and `srk_electrician_verification_documents` / `srk_electrician_verification_document_events` tables. Both tables are keyed to `electrician_profile_id`; document types are limited to identity proof, address proof and skill certificate.
- The same migration provides Electrician-named upload/list/Admin-review RPCs. Activation requires approved identity and address documents, a confirmed Auth phone matching the profile, Admin approval and an Admin-approved rate tier.
- `20261114330000_electrician_private_kyc_document_preview.sql` resolves document paths through the caller's own `electrician_profiles` row.
- `20261116150000_pin_admin_application_review_search_path.sql` hardens the existing `srk_admin_review_application(uuid,text)` function's search path; it does not make the application workflow category-neutral.

## Consequence for the Master System

Do not point Plumber, Painter, AC/Fridge, Motor/Pump or Cooler applicants at the existing Electrician KYC RPCs or create a fake `electrician_profiles` row for them. That would misclassify the worker and couple shared identity to Electrician-only rate approval and activation rules.

Keep the existing Electrician KYC tables, Storage bucket, RPCs and review history intact as legacy compatibility. Build a category-neutral application/KYC layer that references the canonical Technician ID and verified Auth user, while retaining a category/skill relation for each application.

## Required shared onboarding contract

1. Require a valid Supabase Auth Bearer access token and resolve the user server-side through Supabase Auth. Require `phone_confirmed_at`; derive the canonical phone from the Auth user, not from a request-body phone field.
2. Enforce one canonical Technician identity per verified Auth user and prevent duplicate/ambiguous verified-phone identities. Do not merge accounts automatically when multiple Auth identities share a normalized phone; fail closed for Admin reconciliation.
3. Create or resume a pending application only after OTP verification. Capture full name, address, district/state/PIN, selected service categories, individual skills, experience and required KYC metadata.
4. Keep application state explicit: `pending`, `under_review`, `approved`, `rejected`. Store a mandatory Admin rejection reason and append-only review events.
5. Store KYC objects in a private bucket, scoped to the authenticated user's UID and document type. Validate object ownership, MIME allowlist, size and path server-side; do not expose service-role credentials to the app.
6. Support category-specific required evidence and skill checks. AC and Fridge competency must be separately reviewable even if both are grouped under one app category.
7. Prevent dispatch, online availability and job acceptance until Admin approval and all required KYC checks are satisfied.
8. Link approved applications to the canonical Technician ID. Preserve legacy Electrician profile IDs and their historical KYC/review events through an explicit mapping, not destructive migration.
9. Expose stable shared APIs/RPCs for application submit/status, KYC upload/list, Admin review, activation, category/skill management and Technician profile retrieval. Admin actions must be role-checked and audited.

## Implementation gate

Before adding a migration or endpoint, inspect the full authoritative migration chain and current application/profile/Admin review table definitions, including triggers and grants. The shared identity must not be based on an unverified client-supplied phone. The new model must not change live Production, Main Branch, existing KYC records, payments, payouts or deployment without separate permission.

## Verification status

- Source files fetched from the Feature Branch and reviewed: identity-linking migration, private KYC preview migration, KYC review/activation migration and Admin review search-path migration.
- This document is an audit artifact only. No database DDL, DML, Storage policy, API endpoint, Main Branch, Production, payment, payout or deployment was changed.
- No test is claimed for this documentation-only change.