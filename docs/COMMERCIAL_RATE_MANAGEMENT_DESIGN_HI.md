# SRK ELECTRONIC — Commercial Rate List Management (Design Only)

**Status (18 नवंबर 2026):** यह दस्तावेज़ मूल डिजाइन आवश्यकताओं का रिकॉर्ड है। नीचे दिए गए पुराने प्रस्तावित API/स्कीमा को वर्तमान implementation न समझें। संबंधित SQL migrations और source tests repository में मौजूद हैं, लेकिन इन्हें किसी live/hosted database पर लागू करने या rate बदलने की पुष्टि नहीं है।

## 0. Repository implementation status

Rate List के लिए source migrations मौजूद हैं:

- `20261118050000_versioned_rate_catalogue_and_multi_category_electricians.sql`: versioned published catalogue, चार rate tiers, category approvals, Main Admin publish RPC, customer catalogue read RPC और electrician net-rate RPC।
- `20261118070000_admin_rate_catalogue_read_rpcs.sql`: Main Admin के लिए approved electrician/category read RPC।
- `20261118240000_rate_catalogue_draft_scheduled_workflow.sql`: Main Admin-only Draft/Scheduled queue, सुरक्षित draft save/update, list और version-checked publish RPC। Scheduled बदलाव publish होने पर immutable published version में future `effective_at` के साथ दर्ज होता है; ग्राहक की active-rate query समय आने पर अपने आप नया version चुनती है।
- `admin.html`: Main Admin panel में Draft/Scheduled सेव करना, queue देखना और publish/schedule पुष्टि करना।
- `20261118080000_align_offer_85_rate_and_payout_reconciliation.sql` और `20261118110000_unify_electrician_rate_rounding.sql`: electrician offer/net और payout गणना को एक rounding नियम से मिलाते हैं।
- `20261118090000_enforce_booking_rate_snapshot_immutability.sql`: booking के rate estimate snapshot को बदलने से रोकता है।

**Draft/Scheduled workflow (नई migration):** Drafts अलग private table में रहते हैं और customer/electrician read RPC उन्हें नहीं पढ़ते। Draft queue, save और publish तीनों RPC Main Admin जाँच करते हैं। Draft publish करते समय वर्तमान published version का expected ID फिर जाँचा जाता है; mismatch पर publish रुकता है। Published draft record immutable रहता है। Future effective time वाला publish अभी से active नहीं होता; customer catalogue केवल `effective_at<=now()` version लौटाता है।

**वास्तविक schema और इस दस्तावेज़ के पुराने प्रस्ताव में अंतर:**

- वर्तमान migration में catalogue versions का status केवल `published` है। Draft/scheduled status workflow अभी schema में नहीं है।
- Future `effective_at` स्वीकार किया जाता है, लेकिन अलग scheduled-status/approval queue नहीं है।
- वास्तविक audit table का नाम `srk_rate_catalogue_audit` है; इसमें tier-wise पुराने/नए paise, actor और reason दर्ज होते हैं।
- Admin publish RPC चारों tier keys, positive integer paise, reason और expected-current-version की जाँच करता है।
- Main Admin authorization database RPC में `public.is_srk_admin()` से जाँचा जाता है।
- Customer और electrician read RPC अलग हैं; electrician को केवल अपनी active approved categories की net rate मिलती है।
- Booking estimate snapshot immutable है; पुरानी booking की कीमत को नए catalogue से दोबारा नहीं निकाला जाता।
- Main Admin UI `admin.html` में मौजूद है: चारों tier rates का INR input, बदलाव का कारण, effective time, current published catalogue read, version-checked publish और electrician approved-category management। UI इन actions को केवल `adminPortalMode === 'main_admin'` पर चलाता है।
- UI राशि को integer paise में बदलकर `srk_admin_publish_rate_catalogue` RPC बुलाता है; Main Admin authorization और expected-current-version concurrency guard database में भी लागू हैं।

यहां “migration मौजूद” का अर्थ केवल Git branch में source file होना है। इसका अर्थ PostgreSQL replay, hosted DB update, deployment या production verification नहीं है। इन कार्यों के लिए अलग स्पष्ट अनुमति आवश्यक है।

**नवीनतम CI प्रमाण (18 नवम्बर 2026, commit `f813fea97f9b9f1a7e36ee4a9755b36ef3639e61`):** Repository Node tests सफल (702 tests); disposable local PostgreSQL में booking rate snapshot के 15/15 pgTAP assertions सफल। अलग full-migration replay workflow ने commit `e98df69841038929ace8b9acb8306664d91178be` पर 110 migrations सफलतापूर्वक लागू कीं और Rate Catalogue tables/RLS/RPC schema assertions पास किए। Snapshot workflow ने केवल संबंधित guard migration को isolated fixture database पर लागू किया; यह hosted/live DB या production verification नहीं है।


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
