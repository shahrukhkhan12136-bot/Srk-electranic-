# SRK ELECTRONIC — Shared Technician Onboarding API Contract

Date: 21 November 2026  
Backend source: Feature Branch only  
Migration: `20261121130000_shared_technician_otp_onboarding.sql`  
Audience: GPT-1 Frontend integration

## Authentication rule

The applicant first signs in through Supabase phone OTP. Every application/KYC RPC below requires the authenticated Supabase session. The backend derives the mobile number from `auth.users.phone` and requires `phone_confirmed_at`. There is deliberately no phone/mobile parameter in the application-submit RPC. The app must not send a phone number as proof of OTP verification.

## Applicant flow

1. Supabase phone OTP login.
2. Fetch the active service catalogue using `rpc/srk_technician_list_service_catalogue`.
3. Applicant fills name, address, district, state, PIN code, total experience, optional about text, selected category codes and skill codes.
4. Submit through `rpc/srk_technician_submit_application`.
5. Upload KYC bytes to the private Storage bucket `srk-technician-verification` using path:
   `<auth-user-uuid>/<document_type>/<unique-file-name>`.
6. Register each uploaded file using `rpc/srk_technician_submit_kyc_document`.
7. Poll/read application state through `rpc/srk_technician_get_my_applications`.
8. Show Pending / Under Review / Approved / Rejected and Admin rejection reason. No dispatch/availability permission is granted by this onboarding migration; generic dispatch must separately require an approved application and approved skill/category mapping.

## RPC request shapes

### Catalogue

`POST /rest/v1/rpc/srk_technician_list_service_catalogue`

Body: `{}`

Returns active category rows with skill code/name and `requires_separate_assessment`. AC Technician and Fridge Technician are separate skills and must be assessed separately.

### Submit application

`POST /rest/v1/rpc/srk_technician_submit_application`

```json
{
  "p_full_name": "Applicant full name",
  "p_address": "House / street / locality",
  "p_district": "District",
  "p_state": "State",
  "p_pincode": "208001",
  "p_experience_years": 4,
  "p_about": "Optional introduction",
  "p_category_codes": ["electrician"],
  "p_skill_codes": ["residential_wiring"]
}
```

- Do not send `phone`, `mobile`, `auth_user_id`, `technician_id`, `status` or Admin fields.
- Category and skill codes must be active. Every selected category must have at least one selected skill.
- Duplicate/unknown categories or skills are rejected.
- One open pending/under-review application per Technician is allowed. A rejected applicant may submit a new application; prior application and event history remain.
- Returns `success`, `technician_id`, `application_id`, `status: pending`.

### Submit KYC metadata

Upload the file first to the private bucket. Allowed MIME types: PDF/JPEG/PNG; maximum 5 MiB. The bucket is private.

`POST /rest/v1/rpc/srk_technician_submit_kyc_document`

```json
{
  "p_application_id": "application UUID",
  "p_document_type": "identity_proof",
  "p_application_skill_id": null,
  "p_storage_path": "<auth-user-uuid>/identity_proof/id-front.pdf",
  "p_file_name": "id-front.pdf",
  "p_mime_type": "application/pdf",
  "p_file_size_bytes": 123456
}
```

- `document_type`: `identity_proof`, `address_proof`, or `skill_certificate`.
- For `skill_certificate`, `p_application_skill_id` must belong to this application; for identity/address proof it must be null.
- Backend verifies the object exists in the private bucket, path belongs to the signed-in UID, metadata is valid, and application belongs to the signed-in Technician.
- Returns document ID and pending review status.

### Applicant status

`POST /rest/v1/rpc/srk_technician_get_my_applications`

Body: `{}`

Returns the signed-in Technician's own applications, category/skill selections, review states, KYC metadata and rejection reason. It does not return private storage object paths.

## Admin contracts

All Admin RPCs require an authenticated user accepted by `public.is_srk_admin()`.

- `srk_admin_list_technician_applications(p_status text, p_limit integer)`: returns the Admin review queue, applicant details, verified phone, categories, skills and KYC storage paths.
- `srk_admin_review_technician_kyc(p_document_id uuid, p_review_status text, p_admin_note text)`: reviews one pending KYC document. Rejection/resubmission requires a reason.
- `srk_admin_review_technician_skill(p_application_skill_id uuid, p_review_status text, p_admin_note text)`: separately reviews each selected skill. Rejected/needs-resubmission skills can be reviewed again; approved skill rows are locked.
- `srk_admin_review_technician_application(p_application_id uuid, p_decision text, p_rejection_reason text)`: decisions: `under_review`, `approved`, `rejected`. Rejection requires a 5–1000 character reason. Approval requires the latest identity and address KYC documents to be approved and every selected skill to be approved.
- `srk_admin_upsert_service_category(p_category_code, p_display_name, p_is_active, p_sort_order)`: add/update categories; deactivate rather than delete historical categories.
- `srk_admin_upsert_service_skill(p_category_code, p_skill_code, p_display_name, p_is_active, p_requires_separate_assessment)`: add/update skills and assessment requirements.

## Error handling

Treat RPC errors as failures; do not show an application as submitted/approved until the RPC returns success. Key machine-readable errors include:

- `TECHNICIAN_LOGIN_REQUIRED`
- `OTP_VERIFIED_MOBILE_REQUIRED`
- `VERIFIED_PHONE_CONFLICT_REQUIRES_ADMIN_RECONCILIATION`
- `TECHNICIAN_APPLICATION_ALREADY_UNDER_REVIEW`
- `UNKNOWN_DUPLICATE_OR_INACTIVE_TECHNICIAN_CATEGORY`
- `UNKNOWN_DUPLICATE_OR_UNSELECTED_TECHNICIAN_SKILL`
- `EACH_SELECTED_CATEGORY_REQUIRES_AT_LEAST_ONE_SKILL`
- `OWN_PENDING_TECHNICIAN_APPLICATION_REQUIRED`
- `LATEST_IDENTITY_AND_ADDRESS_KYC_MUST_BE_APPROVED`
- `ALL_SELECTED_TECHNICIAN_SKILLS_REQUIRE_SEPARATE_ADMIN_APPROVAL`

## Current integration limitations

- This migration is source code on the Feature Branch only. It has not been applied to Production or to the partial TEST project.
- The current Electrician portal and `apply-electrician.js` remain legacy Electrician-specific. Do not point the shared app at that old endpoint.
- Generic category-neutral dispatch, approved-skill eligibility, online availability, booking assignment, Technician GPS and payouts are separate remaining integration tasks.
- The app should not offer online/availability or receive jobs solely because the user has submitted an application.
