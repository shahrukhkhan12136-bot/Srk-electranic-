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


### Live Location GPS failure cleanup — 15 November 2026
- [x] GPS watch error और location-update RPC failure अब server-side stop RPC भी चलाते हैं।
- [x] Local retry tracking केवल server stop की पुष्टि के बाद हटती है; stop failure पर Logout retry path सुरक्षित रहता है।
- [x] तीन source-level regression assertions जोड़े (अभी execute नहीं किए गए)।
- [x] Live-location server source में consent, assigned-booking/customer scoping, coordinate validation, stale-read cutoff और booking transition cleanup की समीक्षा की।
- [ ] Node source test और live-location pgTAP/RPC behavior को approved isolated test environment में चलाएँ।
- [ ] सभी implementation समाप्त होने के बाद Customer–Electrician location sharing का consolidated desktop/mobile QA करें।

**Evidence boundary:** केवल source fix/review; वास्तविक GPS share, migration apply, runtime test या deployment नहीं हुआ।


### Push Notification और New Job Offer Alert Audit — 15 November 2026
- [x] Electrician opt-in UI, browser permission handling, VAPID public-key retrieval, service-worker registration और local subscription enable/disable source review।
- [x] Service worker push display और same-origin notification-click navigation source review।
- [x] Sequential offer create/decline/expiry dispatch और scheduled expiry worker source review।
- [ ] Offer dispatch/next-offer event से trusted server-side Web Push sender जोड़ें; अभी branch में delivery invocation प्रमाणित नहीं।
- [ ] Push subscription storage के लिए owner-scoped RLS/RPC contract और invalid endpoint cleanup verify/implement करें; current client direct table upsert/delete की authoritative policy अभी verify नहीं।
- [ ] Durable idempotent notification outbox, bounded retries और offer-state revalidation लागू करें; केवल live active offer पर notification भेजें।
- [ ] Notification click पर Electrician dashboard में संबंधित offer highlight/open करें।
- [ ] Approved isolated environment में permission, delivery, duplicate/retry, expired/accepted offer, invalid endpoint और logout/account-switch tests चलाएँ।
- [ ] Final consolidated mobile QA और production rollout सभी implementation पूरे होने और अलग explicit approval के बाद ही।

**Evidence boundary:** UI/service-worker/dispatch source review पूरा; वास्तविक push delivery, subscription RLS proof, runtime test, production Edge Function inspection/deploy या mobile QA का दावा नहीं।


### Push Notification click-to-offer routing hardening — 15 November 2026
- [x] Notification click अब केवल same-origin Electrician Dashboard खोलता है; payload से arbitrary same-origin path स्वीकार नहीं होता।
- [x] Valid UUID offerId dashboard URL में जोड़ा जाता है; dashboard matching offer card को scroll/highlight करता है।
- [x] Malformed offerId reject और Service Worker cache version bump किया।
- [x] Source-contract assertions जोड़े (अभी execute नहीं किए गए)।
- [ ] Trusted server-side Push sender, durable idempotent outbox/retry, subscription RLS/RPC और invalid endpoint cleanup implement/verify करें।
- [ ] Approved isolated environment में push delivery और race/retry/permission tests; final mobile QA implementation पूर्ण होने के बाद।

**Evidence boundary:** Deep-link source change committed; वास्तविक Push delivery, runtime test, production deploy या mobile QA नहीं हुआ।


### Push sender और subscription security — 15 November 2026
- [x] Production read-only inspection से ACTIVE `push-job-offer` Edge Function और `job_offers` INSERT/UPDATE webhook trigger मौजूद होने की पुष्टि।
- [x] Production subscription table पर owner-scoped RLS policies की पुष्टि; authenticated role के अनावश्यक TRUNCATE/TRIGGER/REFERENCES grants मिले — revoke करना बाकी।
- [x] Feature branch में webhook-authenticated sender source जोड़ा: current offer/expiry, booking state/assignment और electrician active/approved/available revalidation; invalid/expired endpoints cleanup।
- [x] Public GET response में केवल VAPID public key; private configuration response में नहीं।
- [x] छह source-contract tests जोड़े; execute नहीं किए।
- [ ] Migration में authenticated के TRUNCATE/TRIGGER/REFERENCES revoke करें और आवश्यक CRUD grants ही रखें; RLS owner scope verify करें।
- [ ] Durable idempotent push outbox, bounded retry/backoff, delivery audit/dead-letter लागू करें; direct webhook request alone पर्याप्त नहीं।
- [ ] Feature-branch schema और Production schema align करें; Production inventory में `job_offers.expires_at` तथा `electrician_profiles.available_for_work` अनुपस्थित दिखे, इसलिए अभी Edge Function deploy निषिद्ध।
- [ ] Isolated environment में sender + webhook + subscription + expiry/acceptance race tests चलाएँ; उसके बाद ही final mobile QA।

**Evidence boundary:** Production inspection read-only; branch Edge Function/source tests committed; runtime test, push send, migration apply, Edge Function deploy और mobile QA नहीं हुए।


### Durable Push Outbox — 15 November 2026
- [x] Feature-branch migration में owner-scoped subscription CRUD policies और least-privilege grants।
- [x] Unique offer outbox row और private delivery-state table।
- [x] Service-role-only claim/finish RPCs, lease, max attempts, exponential retry और dead-letter state।
- [x] प्रति मिनट scheduled Netlify worker और छह source-contract assertions।
- [ ] Per-subscription delivery ledger/idempotency ताकि partial failure retry पर सफल recipients को duplicate push न मिले।
- [ ] Existing Production direct HTTP trigger और नए outbox के coexistence/rollout plan को duplicate delivery से सुरक्षित करें।
- [ ] Production/branch schema parity स्थापित करें; उसके बाद isolated DB + Edge Function + Netlify integration tests।
- [ ] सभी implementation और internal checks पूरे होने पर consolidated final mobile QA; उससे पहले नहीं।

**स्थिति:** Feature branch source और docs updated; tests run नहीं; migration/deploy/push नहीं। At-least-once retries हैं, exactly-once guarantee नहीं।


### Per-subscription Push Delivery और Schema Parity — 15 November 2026
- [x] Unique per-outbox/per-subscription delivery ledger; private table और service-role-only RPCs।
- [x] Row-lock claim, per-subscription attempts, lease, retry/backoff, delivered/dead terminal states।
- [x] Edge sender per-device result दर्ज करता है; outbox तभी delivered जब सभी target rows terminal हों।
- [x] सात source-contract tests जोड़े; execute नहीं किए।
- [ ] Provider timeout के ambiguous outcome को monitor/alert करें; Web Push exactly-once transport guarantee उपलब्ध नहीं।
- [ ] Production schema parity: Production में `job_offers.expires_at` और `electrician_profiles.available_for_work` absent; पहले approved migration rollout और isolated verification चाहिए।
- [ ] पुराने Production direct HTTP trigger और नए outbox के duplicate-safe migration plan की पुष्टि।
- [ ] Isolated integration tests (parallel claims, success replay, timeout, 404/410 cleanup, retry exhaustion) चलाएँ।

**स्थिति:** Feature branch source updated; runtime tests/deploy/migration apply/push नहीं हुए। Production compatibility अभी अवरुद्ध है।

- [x] Malformed per-subscription claim target को stuck processing state में छोड़ने के बजाय retry/dead-letter path में भेजने का guard और assertion।


### Legacy Push Trigger और सुरक्षित Rollout — 15 November 2026
- [x] Production catalog में legacy `trg_srk_push_job_offer` (`AFTER INSERT OR UPDATE`) और direct HTTP function की पहचान; old payload में `outbox_id` नहीं।
- [x] Outbox migration में legacy trigger को उसी transaction में drop करके INSERT-only outbox trigger बनाना।
- [x] Source test: legacy trigger drop, outbox trigger creation से पहले होना चाहिए।
- [ ] Isolated schema prerequisites और migration ordering verify करें; Production schema अभी branch से पीछे है।
- [ ] Isolated rollout में worker pause → schema/trigger swap → Edge Function deploy → synthetic delivery verify → worker enable क्रम जाँचें।
- [ ] Rollback migration और monitoring/alert thresholds approve करें।

**Production safety:** अभी कोई migration/trigger/deploy/worker action नहीं किया गया। Rollout plan केवल branch documentation है और अलग approval आवश्यक है।


### Push Migration Preconditions और Isolated Integration Plan — 15 November 2026
- [x] Outbox migration में private schema, subscription columns, `job_offers.expires_at`, `electrician_profiles.available_for_work` और electrician identity/approval columns के fail-fast guards।
- [x] Delivery ledger migration में outbox table तथा subscription identity columns के prerequisite guards।
- [x] दोनों migration preflight guards के source assertions।
- [x] अलग isolated integration plan: migration ordering, grants/RLS, trigger swap, delivery matrix, retries, concurrency, stale offers, secrets, monitoring और exit criteria।
- [ ] Isolated Supabase project और isolated Netlify site पर migration apply तथा वास्तविक integration tests (अभी नहीं बनाए/चलाए)।
- [ ] Worker timeout बनाम 2-minute lease का load verification; जरूरत पर batch/concurrency/lease tuning।
- [ ] Dead-letter alerting, retention/cleanup और rollback rehearsal।

**नोट:** Production में आवश्यक offer expiry और electrician availability columns अभी absent हैं। इसलिए Production rollout blocked है। कोई Production write/deploy नहीं हुआ।


### Push Retry/Lease Deep Audit — 15 November 2026
- [x] Outbox exhausted lease (8th attempt) expiry पर dead-letter recovery।
- [x] Device delivery exhausted lease (5th attempt) expiry पर dead-letter recovery।
- [x] NULL lock lease भी stale/recoverable।
- [x] सभी push SECURITY DEFINER RPCs में NULL-safe service-role guard।
- [x] Sequential worker batch 20 से 3; database lease 5 मिनट।
- [ ] Isolated load test में Netlify execution duration और 5-minute lease verify करना।
- [ ] Crash/reclaim scenarios का वास्तविक database integration test चलाना।

**स्थिति:** Source-level सुधार और assertions feature branch में हैं; runtime tests अभी नहीं चले। Production में कोई बदलाव नहीं।


### Push delivery partial-failure / duplicate-risk audit — 15 November 2026
- [x] Sender सभी claimed device targets पर completion की प्रतीक्षा करता है; per-device success/failure ledger RPC का source review।
- [x] 404/410 endpoint cleanup और subscription delete पर ledger cascade का source review।
- [x] Retry केवल pending/expired-lease delivery rows पर; confirmed delivered rows claim query से बाहर रहती हैं।
- [x] Partial delivery, all-target completion और endpoint cleanup के लिए source-contract assertions जोड़े।
- [ ] Node/Deno tests execute करें और approved isolated DB में concurrent claims, partial provider failure, cleanup cascade तथा lease recovery verify करें।
- [ ] Provider timeout या provider success के बाद finish-RPC failure जैसे ambiguous outcomes के लिए metrics/alerting जोड़ें और duplicate risk monitor करें।

**महत्वपूर्ण सीमा:** Web Push provider के सफल send के बाद response खो जाने या ledger success write विफल होने पर transport-level exactly-once guarantee संभव नहीं; lease expiry के बाद retry से duplicate notification संभव है। Confirmed delivered rows जानबूझकर दोबारा नहीं भेजी जातीं। अभी कोई runtime test, migration apply, real push या deployment नहीं हुआ।
