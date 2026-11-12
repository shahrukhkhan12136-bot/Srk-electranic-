# SRK ELECTRONIC — Repository Inventory & Gap Audit

**Audit date:** 12 November 2026  
**Audited ref:** `feature/production-push-notifications`  
**Audited HEAD:** `f79fd9cbd4ad82b804b1d883b98f3a4e5a706ed8`  
**Scope:** GitHub repository tree, workflow history, selected app scaffolds, Admin UI, timer caller audit and migration families.  
**Important:** This is a source-repository audit, not a live Production database verification or real-device E2E report.

## 1. Repository inventory (observed)

Recursive Git tree returned 167 files and was not truncated.

| Area | Count / observed |
|---|---:|
| Supabase migrations | 56 |
| Supabase SQL test/fixture files | 24 |
| Node test files | 4 |
| GitHub Actions workflows | 7 |
| Netlify serverless functions | 8 |
| Mobile workspace files | 7 |
| Documentation files | 23 |

### Main application surfaces
- Customer website/PWA source: root `index.html`.
- Electrician website/PWA source: root `electrician.html`.
- Admin web dashboard: root `admin.html`.
- Staff: `staff/README.md` only; README explicitly says no live Staff login, role, UI or production DB change.
- Customer Android: `apps/customer-android/README.md` only; explicitly README-only scaffold, no installable native app.
- Electrician Android: `apps/electrician-android/README.md` only; explicitly README-only scaffold, no installable native app.
- Customer Capacitor POC: `apps/mobile-poc/customer/`; this is a proof-of-concept, not production Customer Android.
- Netlify functions: create booking, create order, create snapshot order, verify payment, verify snapshot payment, Razorpay webhook, refund, electrician application.

## 2. Recent CI evidence

Latest observed runs for commit `47bf4c4dd15a80fa64ff0c416438310ca9d13142`:
- `43164503299` — effective rate catalogue workflow — completed SUCCESS.
- `43164503307` — Customer Capacitor POC workflow — completed SUCCESS.

Experience field commit `375ee9345a8cc8fc3ebe88b212a0300a9313e0ea` had successful observed runs:
- `43162949748` — Refund Workflow Tests.
- `43162949804` — effective rate catalogue workflow.
- `43162949934` — Timer billing SQL tests.

These successes validate only the jobs/commit shown; they do not establish real Android device testing, Production parity, or complete E2E acceptance.

The two latest planning-document commits (`e57b86f`, `f79fd9c`) are documentation-only. The current HEAD is `f79fd9c...`; no workflow run for that docs-only HEAD was present in the inspected recent run list. Do not report the current HEAD itself as freshly CI-tested.

## 3. High-priority structural findings

### A. Migration families need a controlled consolidation/release map
There are 56 migration files. The timer/billing family exists in two timestamped series:
- Original series: `202611110001` through `202611110011`.
- Later forward-copy series: `20261111160000` through `20261111160015`.

Several filenames describe the same feature sequence (timer/material foundation, integrity extensions, customer-approved timer RPCs, scoped bill read, authoritative booking creation, precision, material approvals, payable snapshot, Razorpay order ledger, cash receipt, rounding, cancellation, timer/commission integration). This is a **potential duplicate/overlapping migration family**, not yet proven safe to apply sequentially. The migration headers themselves distinguish source/foundation vs forward-only release copy. Before any deployment, compare function/table/constraint definitions, migration history and production schema; establish one canonical ordered release plan and replay it twice on a disposable Production-parity database. Never apply both series blindly.

### B. Timer cutover callers are not fully migrated
Existing caller audit records:
- Electrician portal still has legacy `srk_update_booking_work_status` and legacy quote submission path.
- Customer page lacked timer approval UI/RPC integration in the inspected audit.
- Admin has timer display/decision read path but generic legacy booking editing must stay isolated from timer/financial columns.
- Timer cutover audit says new arrival + customer-approved start/stop UI and migration of payment/webhook to immutable final bill identifiers are required before retiring legacy RPC paths.

### C. Native app gap
- Customer Android and Electrician Android are README-only scaffolds.
- Customer Capacitor POC is not the production app and previously showed the browser-vs-WebView session bridge gap.
- No claim of signed AAB, production app, Play Store package, or physical-device E2E is supported by this inventory.

### D. Staff panel gap
Staff README-only scaffold. Individual staff authentication, server-side least-privilege role checks, complaint/support UI, audit events, SLA and escalation remain to implement and test. Staff must not gain refund/payout/rate/commission approval rights.

### E. Welcome photo gap
Customer POC HTML references `./assets/founder-shahrukh-khan.webp`. This audit did not establish that the newest user-provided original photo has replaced the repository asset. Keep old asset until new original binary is committed and rendered/tested. The founder photo integration remains OPEN.

### F. Monitoring gap
Three scheduled checks are active per existing project record: 10:00 security, 12:30 CI, 19:00 CI/test. They do not yet prove continuous operational monitoring of stuck bookings, payment mismatch, push delivery, crashes, backup/restore, finance reconciliation or complaint SLA. Add these as monitor definitions and acceptance tests; do not create additional automations while task capacity is full.

## 4. Panel ownership — confirmed target

| Feature | Customer | Electrician | Admin web | Staff restricted view |
|---|---|---|---|---|
| OTP/profile | Own profile and booking identity | Own profile/application | Admin auth/MFA | Individual staff login |
| Booking | Create/view/cancel request | Receive/accept/reject eligible offer | Global oversight and audited reassignment | Lookup assigned case only |
| Contact visibility | Electrician number only after accepted booking | Customer number only after accepted booking | Authorized audit access | No unrestricted disclosure |
| Timer | Approve/reject start and stop | Arrival evidence, request start/stop | Read/audit, resolve approved exceptions | No timer override |
| Materials | Approve/reject itemized revision | Propose separate itemized materials | Dispute/audit | Support notes only |
| Payment | Pay after final bill; receipt/refund request | Cash receipt confirmation, commission remittance, online payable | Reconcile, approve controlled actions | No payout/refund execution |
| Complaints | Create/track | Create/track | Triage/escalation/decision | Create/update assigned support case |
| Reports | Own history | Own work/earnings | Business/finance/security | Case SLA only |

Only two Android apps are in scope: Customer and Electrician. Admin and Staff are secure web dashboards.

## 5. Prioritized implementation backlog

| Priority | Work | Status from this audit | Acceptance evidence required |
|---|---|---|---|
| P0 | Migration canonical map + Production parity audit | OPEN / BLOCKER | diff report, ordered plan, two clean replays, legacy preservation |
| P0 | Timer customer/electrician UI cutover | PARTIAL / BLOCKER | real role-based E2E; approval rejection and replay/concurrency |
| P0 | Payment tied to final immutable bill | PARTIAL / BLOCKER | webhook signature/replay, exact amount snapshot, ledger reconciliation |
| P0 | Customer/electrician booking assignment + phone privacy | PARTIAL | acceptance race tests and pre/post-accept visibility E2E |
| P0 | Admin permission and generic-write boundaries | PARTIAL | role matrix, negative authorization tests |
| P1 | Staff dashboard and role system | NOT IMPLEMENTED | staff login, RLS/RPC restrictions, complaint SLA workflow |
| P1 | Customer native Android | NOT IMPLEMENTED (POC only) | signed internal build, Auth bridge, full screen/device E2E |
| P1 | Electrician native Android | NOT IMPLEMENTED | signed internal build, offer/timer/payment E2E |
| P1 | Founder original photo replacement | OPEN | exact binary asset commit + on-device visual check |
| P1 | Push delivery and notification preferences | PARTIAL | token lifecycle, delivery/failure/retry/deep-link tests |
| P1 | Backup and restore drill | NOT VERIFIED | successful backup evidence and restore rehearsal |
| P1 | Financial reconciliation dashboard | PARTIAL | labour-only 15%, materials 0%, cash remittance and online payable invariants |
| P2 | Support/complaint escalation and SLA monitor | PARTIAL / NOT VERIFIED | queue, ownership, timestamps, escalation tests |
| P2 | App version/maintenance controls | NOT VERIFIED | Admin control, minimum supported version, rollback behavior |
| P2 | Crash/uptime/booking-stuck monitors | NOT VERIFIED | alert fixtures, severity, deduplication and runbooks |

## 6. Immediate next execution order

1. Inspect all 56 migrations and build a dependency/overlap matrix; compare the 16 timer-family pairs and identify canonical migrations.
2. Read all 24 SQL tests and 4 Node test files; map each feature to positive, negative, replay and concurrency coverage.
3. Inspect all 8 Netlify functions and all client RPC callers; identify legacy endpoints and cutover risks.
4. Complete Customer/Electrician/Admin/Staff role-action matrix, then add missing UI only against verified server contracts.
5. Implement missing timer UI and immutable-final-bill payment cutover on Feature Branch; no Production migration.
6. Implement Staff web view and native Android workspaces after backend contracts are fixed.
7. Integrate exact original founder image binary; verify actual app rendering.
8. Add operational monitoring definitions and backup/restore/reconciliation test harness.
9. Run all CI and targeted E2E; record failures honestly.
10. Only after every release gate passes, prepare a release proposal. Production changes still require separate explicit owner approval.

## 7. Safety / scope

- This audit is read-only except for the documentation file containing the audit.
- No Supabase Production migration, data mutation, Netlify deploy, live Razorpay, paid provider, Play Store release or real-money test was performed.
- Do not infer Production schema from migration files or disposable SQL fixtures.
- Do not mark any feature COMPLETE without commit + relevant automated test + runtime E2E evidence.
