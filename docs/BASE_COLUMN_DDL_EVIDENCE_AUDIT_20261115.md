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
