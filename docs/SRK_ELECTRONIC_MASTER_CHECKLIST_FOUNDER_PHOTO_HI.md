# SRK ELECTRONIC — Master Checklist Addendum: Founder Welcome-Screen Photo

**Status date:** 15 November 2026  
**Applies to:** Website Welcome Screen / founder identity visual asset  
**Approved asset:** The latest founder portrait uploaded in the conversation on 15 November 2026 (black button-up shirt, arms folded, waist-up framing, blue corporate background).  
**Conversation attachment ID:** `file_000000005f588210ac3459ffcfa3fdfe`  
**Current working copy (this session):** `/mnt/data/18339.png`

## Owner-approved requirement

- [ ] Use the exact latest founder portrait identified above. Do not substitute the older garden portrait.
- [ ] Preserve the subject's natural proportions; do not stretch or distort the image.
- [ ] Display a professional waist-up crop with arms folded and sensible focal positioning.
- [ ] Keep the final asset hosted within the SRK ELECTRONIC Vercel project; do not upload it to a third-party image-hosting website.
- [ ] Integrate the asset into the Welcome Screen and verify the built page loads it correctly.
- [ ] Verify desktop and responsive layout during the consolidated final mobile QA pass; do not run separate mobile QA before all implementation is complete.

## Evidence / current state

- [x] Owner supplied and explicitly selected the latest portrait as the final photo.
- [ ] Persistent reference-image/library save — attempted, but the image-reference service returned `image_unavailable`; do not claim it is saved persistently yet.
- [ ] Add the image binary to the approved feature branch repository.
- [ ] Integrate the image into the Welcome Screen source.
- [ ] Run relevant automated tests and build checks.
- [ ] Confirm Vercel preview build serves the image correctly.
- [ ] Owner visual acceptance.

**Important:** This addendum records the approved requirement and the current conversation attachment identifier. It does not mean the binary has been committed, uploaded to Vercel, integrated, or deployed. Keep Production unchanged until separately authorized.

## Recovery audit — 15 November 2026, 00:20 IST

- The previous Vercel Sandbox session returned `sandbox_stopped`; its filesystem could not be inspected or modified further.
- A recursive Git tree check of the approved feature branch did not find a committed `assets/founder-portrait.webp` (or another founder-photo binary). The earlier sandbox listing is not proof of a Git commit.
- The current branch's `index.html` redirects visitors to `/booking.html`. The customer booking page is not the required three-role website Welcome Screen.
- Therefore, the founder photo is still **not verified as present in the repository, integrated, built, or deployed**. Do not mark these items complete until a fresh working session verifies the exact approved image and page behavior.
- Continue only on `feat/customer-login-first-dashboard-20261114`; do not change Production or deploy without separate approval.


---

# Project-wide Master Checklist Addendum — Admin Refund / Support Staff Audit

**Status date:** 15 November 2026  
**Working branch:** `feat/customer-login-first-dashboard-20261114`

- [x] Hide customer-refund launch action after provider refund is confirmed `processed`.
- [x] Separate Support Staff portal UI from Main Admin modules.
- [x] Verify Staff invitation server-side Main Admin authorization and fixed Support role in source.
- [x] Verify Staff support inbox ownership is assignment-scoped and private phone projections are absent in the reviewed RBAC migration.
- [x] Add source-level regression tests for these contracts.
- [ ] Execute Node source tests and database pgTAP suites in the approved test environment.
- [ ] Verify Admin/Staff workflows end-to-end after all implementation work is complete.
- [ ] Complete consolidated desktop/mobile QA after all implementation work is complete.
- [ ] Obtain explicit owner approval before any production deployment or live changes.

**Evidence boundary:** The checked items above are source review/code changes only. No runtime test, live Staff invitation, provider refund, migration apply, deployment or mobile QA is claimed. See `docs/SRK_ELECTRONIC_PROJECT_PROGRESS_HI.md` for detailed audit notes.


## Additional security checklist — Server-timed booking lifecycle

- [x] Admin booking save handler refuses direct status or quoted-rate changes for new-category/server-timed bookings.
- [x] Database trigger protects new-category category immutability and requires protected workflow authorization for timer start and completion status transitions.
- [x] Approved cancellation remains on the dedicated evidence-backed cancellation decision workflow.
- [x] Add Node and pgTAP regression assertions (pgTAP plan 19; source only).
- [ ] Run Node tests and pgTAP in an approved test environment; verify the legitimate offer-accept, customer work-start approval, completion approval, and cancellation paths end-to-end.
- [ ] Keep final consolidated mobile QA and production rollout deferred until all implementation work is complete and explicit approval is obtained.

**Important:** Runtime validation has not been performed. The migration is committed only as feature-branch source and has not been applied to any database.


### Sequential offer assignment integrity
- [x] New-category assignment requires a matching accepted `job_offers` record for the same booking and electrician.
- [x] Offer response records acceptance before the booking assignment update in the same transaction.
- [x] Added two pgTAP assertions (plan 21; not executed).
- [ ] Run dispatch/acceptance, expiry/decline advancement and assignment-trigger tests in the approved test environment.


### Electrician offer acceptance live revalidation
- [x] Offer acceptance rechecks electrician's current state/district against the booking.
- [x] Offer acceptance rechecks exact selected commercial tier and Admin-approved tier metadata.
- [x] Added 2 pgTAP source assertions (sequential offer dispatch plan 16; not executed).
- [ ] Execute relocation-vs-acceptance concurrency, stale-offer, and exact-tier acceptance tests in the approved isolated environment.


### Electrician availability / relocation / KYC source audit — 15 November 2026
- [x] Availability self-toggle is gated to the authenticated linked, Active, Admin-approved electrician profile.
- [x] Offline transition closes only unaccepted offers and advances sequential dispatch; accepted assignments remain untouched in the reviewed source.
- [x] Relocation request validates active approval, changed operating area, PIN/reason and one-pending-request constraint.
- [x] Admin relocation review locks the request/profile, changes the active operating area only on approval, and closes/re-dispatches old-area unaccepted offers.
- [x] Electrician KYC upload/list/preview and Admin review UI source paths reviewed, including private owner-scoped document-path RPC and short-lived signed preview.
- [ ] Execute availability/relocation/KYC RLS, Storage and RPC tests in the approved isolated test environment.
- [ ] Complete end-to-end electrician/Admin workflows after implementation is complete; final mobile QA remains deferred.

**Evidence boundary:** This is source inspection only. No live availability/relocation/KYC mutation, migration apply, deployment or runtime verification is claimed.
