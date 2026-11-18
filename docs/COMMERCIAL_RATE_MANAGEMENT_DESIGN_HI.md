# SRK ELECTRONIC — Commercial Rate List Management (Design Only)

**Status:** Source documentation only. No migration, SQL execution, database change, deployment, or live rate change has been performed.

## 1. Business requirements

Main Admin can independently increase or decrease all four commercial tiers without a percentage cap:
- Electrical Assistant: ₹899 per 8 hours (89,900 paise)
- Skilled Electrician: ₹1,199 per 8 hours (119,900 paise)
- Expert Electrician: ₹1,599 per 8 hours (159,900 paise)
- Premium Electrical Specialist: ₹1,999 per 8 hours (199,900 paise)

Example: Electrical Assistant ₹899 -> ₹599 is valid. ₹599 -> ₹999 is also valid. Reject zero, negative, malformed, non-finite, and out-of-policy maximum values. Values are INR integer paise; UI formats INR rupees.

No fixed percentage change limit. Each tier is independently editable. Future effective timestamps are supported.

## 2. Authorization

- Main Admin only: explicitly verify public.is_srk_admin() at the server/database operation boundary.
- Support Staff is denied even if a permission catalog entry is accidentally assigned. Do not rely only on srk_has_admin_permission(text) for this Main Admin-only operation.
- Customer, Electrician, anonymous, and AI identities have read-only access to the published catalogue only.
- AI cannot draft, edit, approve, or publish rate changes. AI may explain published rates only.
- All write operations require verified session, CSRF/origin protections appropriate to the endpoint, strict validation, and audit.

## 3. Versioned catalogue model (proposed)

Logical tables, names for review only:
- srk_rate_catalogue_versions: immutable version identity, status (draft, scheduled, published, superseded), currency, base duration, effective timestamp, created/published actor and timestamps, previous version ID.
- srk_rate_catalogue_items: one row per version and tier; unique (version_id, tier_key); positive integer rate_paise.
- srk_rate_change_audit: append-only old/new values per tier, actor, timestamp, reason, version IDs, request/correlation ID.

Constraints: INR only in this release; rate_paise > 0; all four tier keys required exactly once for a publishable version; published versions and their items cannot be updated/deleted; audit cannot be updated/deleted/truncated. Do not delete old versions.

## 4. Publishing and concurrency

- Admin edits a draft version; the currently published version is never edited in place.
- Publish transaction obtains a serialization lock, checks the expected current version ID, validates all four tiers and effective timestamp, closes/supersedes the previous active interval, publishes the new version, and appends audit rows atomically.
- If two Admin requests race, only one expected-version check can succeed; the other receives a conflict and must reload.
- Future versions are scheduled and become effective by server time. Never let client clock determine active pricing.
- Prevent overlapping active effective intervals and ambiguous same-time versions.
- A failed audit write means publish fails; no partial publication.

## 5. Proposed API contract

Read-only:
- GET /api/v1/rates/current
- GET /api/v1/rates/versions/:version_id

Main Admin only:
- POST /api/v1/admin/rates/drafts
- PATCH /api/v1/admin/rates/drafts/:version_id
- POST /api/v1/admin/rates/:version_id/publish

Every write includes idempotency key and expected current version. Publish response includes the exact version ID and effective timestamp. No public endpoint can mutate rates.

Catalogue response (paise):
{
  "rate_version_id": "uuid",
  "effective_at": "2026-12-01T00:00:00Z",
  "currency": "INR",
  "base_duration_hours": 8,
  "rates": {
    "electrical_assistant": 89900,
    "skilled_electrician": 119900,
    "expert_electrician": 159900,
    "premium_electrical_specialist": 199900
  }
}

## 6. Booking snapshot and compatibility

At booking creation, server resolves the rate version effective at the authoritative server timestamp and stores an immutable snapshot:
{
  "rate_version_id": "uuid",
  "rate_effective_at": "2026-12-01T00:00:00Z",
  "rate_tier": "skilled_electrician",
  "base_rate_paise": 119900,
  "duration_hours": 8,
  "estimated_labour_paise": 119900
}

Existing bookings retain their existing rate/bill snapshots. A later rate change affects only bookings created after the new version's effective time. Never recalculate old bills from the current catalogue. The server—not the browser—selects version and computes estimate/final labour. Customer and Electrician apps consume the same read-only catalogue contract.

## 7. Admin UI requirements

Admin screen shows current published rates, scheduled version, draft editor, old/new comparison, effective date/time, mandatory reason, and publish confirmation. Each tier is editable independently. Show validation errors per tier. Show version history and audit details read-only. Disable all controls for Support Staff and show an access-denied state. Do not expose an editable rate control to Customer or Electrician apps.

## 8. Invariants

- Existing 15% platform commission remains unchanged and separate from commercial tier rates.
- No old migration is deleted, renamed, or rewritten.
- No published version or audit record is deleted.
- Old booking snapshots and bills remain unchanged.
- New booking API validates the active version server-side.
- AI has read-only access to published rate data, never write access.
- Before DB branch/migration work, review compatibility with the existing selected-tier, timer, immutable bill, RBAC, and booking source contracts.

## 9. Explicit exclusions

This design does not create database objects, migrations, RPCs, UI code, API handlers, or live rates. No SQL execution, migration replay, paid database branch creation, deployment, or additional paid service is authorized by this document.
