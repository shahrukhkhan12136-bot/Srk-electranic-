# SRK ELECTRONIC — Unified System Index (GPT-1 + GPT-2)

**Last repository scan:** 15 November 2026  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**Branch:** `feat/customer-login-first-dashboard-20261114`  
**PR:** #8 — Open, Draft, not merged  
**Current index commit at creation:** `4842b37105d8fa8abb4e8112d76dc06785423dbe`

## 1. This is the single starting point

इस index का उद्देश्य पूरे SRK ELECTRONIC platform के source systems को एक जगह से खोलना है। अब हर बार code, migration, database test, Node test या integration dependency को शून्य से ढूँढ़ना नहीं है।

यह repository/source inventory है; **मौजूद होना ≠ runtime verified होना ≠ Production पर deployed होना**। कोई नया product feature या scope इसमें नहीं जोड़ा गया।

## 2. Owner-wise consolidated inventories

| Owner | जिम्मेदारी | एकीकृत inventory |
|---|---|---|
| GPT-1 | Customer App, Electrician App, Welcome Screen/founder-photo integration | `docs/GPT1_UNIFIED_DELIVERY_INVENTORY_HI.md` |
| GPT-2 | Admin Panel, Support Staff/RBAC, Main Supabase Database, Payments/Refunds/Payouts, Commission/Accounting, Security/Permissions, SOS backend/Admin | `docs/GPT2_UNIFIED_DELIVERY_INVENTORY_HI.md` |

**Ownership boundary:** GPT-1 Customer/Electrician UI and client integration owns; GPT-2 owns shared database/security/admin/financial backend. Shared contracts require coordination. Do not edit the other owner's files or database scope without coordination. Welcome Screen/founder-photo is treated as complete per the standing project instruction; do not reopen it.

## 3. Repository-wide source inventory

Recursive Git tree at inspected PR head `eed50b086218ed6dfa095102150651992933de87` was not truncated.

| Component | Count |
|---|---:|
| Tracked files | 213 |
| Supabase SQL migrations | 78 |
| Supabase database contract / pgTAP tests | 32 |
| Node regression test files | 33 |
| Netlify Functions | 10 |
| Supabase Edge Function source entries | 3 |
| GitHub Actions workflows | 3 |

GPT-2 inventory contains the full migration, SQL-test, Node-test and workflow filename lists. GPT-1 inventory contains the Customer/Electrician workflow-to-source/migration/test maps. This master index deliberately points to those inventories instead of copying large lists and creating conflicting duplicates.

## 4. Shared end-to-end system chains

| System chain | GPT-1 side | GPT-2 side | Verification still needed |
|---|---|---|---|
| Customer booking → dispatch → electrician offer | Customer booking form/client, session and booking history; Electrician offer inbox/respond | Booking schema, offer dispatch, row locks, server-side ownership and transition guards | Full clean migration replay; customer/electrician/anon actor tests; duplicate/concurrency/race runtime |
| Customer payment → receipt → refund → payout | Customer payment choice/history/receipt/refund UI; Electrician earnings display | Payment verification, refund review/recovery, cancellation fee and payout/accounting ledgers | pgTAP execution, isolated DB and authorized provider sandbox; no live financial operations |
| Customer support ↔ Electrician support ↔ Admin inbox | Customer complaints/messages/attachments; Electrician tickets/replies | Complaint base schema, staff RBAC, support assignment, Admin inbox and attachment ACL | End-to-end role/ownership/storage matrix |
| Electrician KYC → Admin review → activation | Electrician application, upload, preview and status UI | Private Storage policies, KYC review/audit, activation and permission gates | Storage/Auth/DB runtime with actor-by-actor authorization |
| Electrician availability/relocation → offer eligibility | Availability toggle and relocation request UI | Profile fields, approval workflow, dispatch revalidation, database grants | Availability/relocation security pgTAP and dispatch-race tests |
| Electrician live location → customer/admin visibility | Consent, start/stop, GPS cleanup and UI rendering | Booking-scoped location table/RPC, owner/assignment authorization | DB RPC ownership/security tests and isolated runtime; mobile QA deferred |
| Electrician phone change → OTP → Admin decision | UI and Edge Function caller | Protected RPCs, request lifecycle, Admin approval and audit | Source signatures matched; full OTP/Admin lifecycle pgTAP/runtime test absent |
| Offer push → device → offer deep link | Electrician opt-in, service worker, click-to-offer route | Subscription, outbox, per-device ledger, sender, retry/lease and health | Managed schema/provider integration, partial failures and delivery runtime |
| Customer/Electrician auth and contact visibility | OTP/session gating and accepted-booking call controls | Supabase Auth configuration, identity link, RLS and private contact lookup | Real SMS/Auth and actor/permission runtime; phone reveal only after acceptance |

## 5. One canonical migration/test directory

- All SQL migrations: `supabase/migrations/` — 78 files.
- All database contract tests: `supabase/tests/database/` — 32 files.
- All Node regression tests: `tests/` — 33 files.
- All Edge Functions: `supabase/functions/`.
- All Netlify Functions: `netlify/functions/`.
- CI workflows: `.github/workflows/`.

Dependency/replay reference documents:
- `docs/MIGRATION_REPLAY_MANIFEST_HI.md`
- `docs/MIGRATION_DEPENDENCY_INVENTORY_HI.md`
- `docs/MIGRATION_DEPENDENCY_MATRIX_HI.md`
- `docs/BASE_SCHEMA_MIGRATION_DEPENDENCY_GAPS_20261115.md`
- `docs/BASE_COLUMN_DDL_EVIDENCE_AUDIT_20261115.md`
- `docs/CORE_BASELINE_DDL_CONTRACT_HI.md`

**Important:** dependency/replay documents contain static analysis and earlier snapshots; they are not yet a proven full clean replay order. The dependency matrix previously scanned 73 migrations, while the current repository contains 78. Treat it as needing refresh against the full 78 before using it for replay.

## 6. Confirmed cross-system discrepancy / correction status

- Customer payment-method pgTAP test previously contained mojibake. At PR head `eed50b086218ed6dfa095102150651992933de87`, the test now asserts canonical UTF-8 `razorpay ऑनलाइन भुगतान`, matching the corrective migration. This source mismatch is corrected in shared branch.
- The corrected pgTAP test source is present; this alone does not prove pgTAP execution.
- GPT-1 inventory was refreshed to include the shared cross-GPT dependency map and latest source correction.
- Main baseline authoritative DDL for `service_bookings.amount_paid` and `electrician_profiles.auth_user_id` remains unresolved in the audit documents. Do not guess types, defaults, nullability, foreign keys or indexes.
- Current Supabase schema CI is not a complete replay harness for all 78 migrations and is pinned to a different branch. Node CI is not a replacement for pgTAP/runtime tests.
- PR #8 remains Draft/unmerged. No Production migration, deployment, payment/refund/payout operation or mobile QA was performed in this inventory step.

## 7. Required workflow from here

1. Start here, then open the relevant GPT-1 or GPT-2 inventory section.
2. Follow the existing chain: **UI/client → API/Edge/Netlify → SQL RPC/table → migration → pgTAP → Node test → runtime evidence**.
3. Record each link as **present**, **missing**, **mismatch**, or **runtime unverified**. Never label a feature complete based only on file presence.
4. Reconcile all 78 migrations and all 32 SQL tests against their actual dependencies, baseline DDL and current PR head before any replay plan.
5. Resolve shared-owner mismatches with the responsible GPT before editing.
6. Only after source inventory/dependency reconciliation, continue already-approved unfinished implementation. Do not invent features.
7. Keep all manual mobile checks until implementation is complete; then run one consolidated sequential mobile QA pass.
8. No Production deployment/schema change. No new paid Supabase branch now. Staging decision only when implementation is complete and consolidated end-to-end testing is next, after cost disclosure and explicit user approval.

## 8. Changes made by this index

This document is documentation-only. It does not change application source, migrations, tests, database objects, Auth/Storage settings, Production configuration, payments, refunds, payouts, providers or deployment.
