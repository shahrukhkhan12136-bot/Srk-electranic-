# Base-column DDL evidence audit — 2026-11-15

## Scope and safety
This note records evidence recovered from the historical document
`docs/SRK_ELECTRONIC_MASTER_REQUIREMENTS_HI.md` on branch
`feature/platform-fee-cash-online-cycle`. That document describes earlier
read-only Production catalog snapshots. This is historical evidence only:
no current Production database was queried, no credentials were used, and no
migration was applied.

## `service_bookings.amount_paid`

### Evidence recovered
- Historical Master Requirements section 17.37 lists `amount_paid` among
  columns present in the Production `service_bookings` schema snapshot.
- Sections 17.23–17.24 describe legacy payment and payout functions reading
  and writing `amount_paid`, including reconciliation against quoted/service
  amounts.
- Section 17.22 records `amount_paid` in the historical Admin audit
  allow-list for booking financial fields.
- Earlier source-history searches found application and migration consumers,
  but no authoritative `CREATE TABLE` or `ALTER TABLE ADD COLUMN`
  declaration in the inspected Feature Branch / starter schema artifacts.

### Still unknown
The recovered historical inventory does not establish the SQL type,
precision/scale, nullability, default, CHECK constraints, foreign-key
relationships, indexes, column privileges, or the exact migration/deployment
artifact that introduced the column. Do not infer these from JavaScript or
SQL consumers.

## `electrician_profiles.auth_user_id`

### Evidence recovered
- Historical Master Requirements sections 17.15 and 17.19 document the
  Production SELECT policy using `auth_user_id/user_id = auth.uid()`.
- Section 17.19 records one approved+active profile in that snapshot with
  both identity-link columns set and no mismatch observed.
- An older alternate-branch identity-sync migration writes both
  `user_id` and `auth_user_id`, but does not create or define the latter.

### Still unknown
The historical policy and row observation establish use, not the column
definition. SQL type, nullability, default, FK target/on-delete behavior,
uniqueness/indexes, column grants, and introducing migration/deployment
artifact remain unverified.

## Decision
These findings narrow the evidence gap but do not authorize guessed DDL.
Keep both columns' base definitions marked **unresolved**. Do not add a
compatibility migration, rename migration versions, or change Production
schema until an owner/DB-admin-approved schema-only catalog export or the
original deployment SQL artifact establishes the complete contracts.

## Verification boundary
This is documentation-only evidence recording. It does not prove current
Production state or Feature Branch/Production parity. PostgreSQL and pgTAP
runtime tests remain pending; no checklist item is closed by this note.

## 2026-11-15 — अतिरिक्त cross-branch स्रोत-जाँच

इस audit के बाद पाँच refs पर समान starter-schema और संबंधित migration source को दोबारा fetch किया गया: `main`, `work/separate-customer-electrician-portals`, `feature/platform-fee-cash-online-cycle`, `safe-payment-refund-implementation`, और वर्तमान `feat/customer-login-first-dashboard-20261114`।

- पाँचों refs पर `SUPABASE_SCHEMA.sql` का blob SHA समान `8ae88a7035bc963b244f22c6c1450c22618ec88f` मिला। उसमें `service_bookings` और `electrician_profiles` की starter CREATE TABLE definitions हैं, पर `amount_paid` या `auth_user_id` नहीं हैं।
- पाँचों refs पर `20261109010000_create_secure_wallet_ledger_foundation.sql` मौजूद है। तीन refs में उसका blob SHA `6b5871d6fcc10fa225a5bbb8e26911b7027e2043`; `feature/platform-fee-cash-online-cycle` पर SHA `5394c85093a17c78dc910a4a03ee8de70c4639ba` मिला। निरीक्षित source में `auth_user_id` का उपयोग है, लेकिन column की CREATE/ADD definition नहीं मिली।
- चार refs पर `20261109_electrician_inspection_quotes_and_service_only_commission.sql` उपलब्ध था; जहाँ उपलब्ध, उसका blob SHA `014699d3190e45aacde4022ac7e7fa9ca4fec006` है। यह `amount_paid` को trigger logic में पढ़ता है, लेकिन निरीक्षित file में column की CREATE/ADD definition नहीं मिली। `feature/platform-fee-cash-online-cycle` पर इस पुराने filename का file नहीं मिला।
- इस सीमित cross-branch fetch से इन दो columns का authoritative DDL अभी भी नहीं मिला। यह हर Git object, deleted branch या external deployment artifact की exhaustive खोज का दावा नहीं है।

**निष्कर्ष:** दोनों base-column definitions unresolved रहेंगी। कोई guessed DDL या compatibility migration नहीं जोड़ी गई; Production/remote migration history query नहीं की गई। अगला विश्वसनीय प्रमाण owner/DB Admin का स्वीकृत schema-only export या original deployment SQL artifact है।
