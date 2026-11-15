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


### Push delivery monitoring, failure alerts और dead-letter recovery — 15 November 2026
- [x] Service-role-only health RPC जो Outbox और per-device Ledger के pending/processing/delivered/dead counts तथा oldest pending timestamps देता है; payload, endpoint, user ID या private error text expose नहीं करता।
- [x] Netlify worker structured healthy/degraded logs लिखता है; sender/finish/health failures अलग event names से दर्ज होते हैं।
- [x] Retry, health RPC failure या dead-letter मौजूद होने पर scheduled invocation HTTP 502 लौटाती है ताकि platform-level function monitoring में degraded run दिखे।
- [x] केवल exact dead outbox UUID पर service-role-only manual recovery RPC; delivered device rows को delivered ही रखता है और केवल dead device rows reset करता है।
- [x] Worker monitoring और guarded recovery के source-contract assertions जोड़े।
- [ ] Approved isolated DB में health counts, unauthorized RPC denial, manual recovery state transitions और delivered-row preservation execute/verify करें।
- [ ] Netlify scheduled invocation/log alert integration को test environment में verify करें; alert delivery अभी runtime में प्रमाणित नहीं।
- [ ] Node test suite execute करें; अभी source assertions लिखे हैं, run result नहीं।
 
**Safety boundary:** Health/recovery migration केवल Feature Branch में है; अभी किसी database पर apply नहीं हुई। कोई dead letter वास्तव में requeue नहीं किया, कोई push/provider call, production change, deployment, worker activation या mobile QA नहीं हुआ।


### Final Push Security Audit — Lease Fencing सुधार — 15 November 2026
- [x] Audit में stale-worker race मिला: यदि worker का lease expire हो और दूसरा worker उसी row को reclaim कर ले, तो पुराना worker देर से finish RPC करके नए worker की स्थिति overwrite कर सकता था।
- [x] नया migration `20261115200000_push_delivery_lease_fencing.sql`: Outbox और per-device finish RPC अब claimed `attempt_count` fencing token मांगते हैं; status `processing` और वही attempt count न होने पर stale result reject होता है।
- [x] Netlify worker और Edge sender अब अपने claim response का attempt count finish RPC में भेजते हैं।
- [x] Outbox और per-device fencing के source-contract assertions जोड़े।
- [ ] Node/Deno suite execute करें और concurrent reclaim + stale finish race को isolated DB में चलाकर verify करें।
- [ ] Provider call की transport-level duplicate संभावना बनी रहती है यदि पुराना worker lease expire होने के बाद भी provider request पूरा कर दे; fencing केवल stale DB completion को रोकती है, exactly-once delivery नहीं देती।

**सुरक्षा सीमा:** Migration feature branch पर ही है; अभी apply/deploy नहीं हुई। कोई production mutation, real push, worker activation या mobile QA नहीं किया गया।


### Push RPC signature और claim/finish payload dependency audit — 15 November 2026
- [x] Original Outbox और per-device finish RPC signatures की fencing migration के DROP FUNCTION signatures से तुलना।
- [x] दोनों claim RPCs में attempt_count लौटने और finish calls में वही fencing token भेजे जाने का source audit।
- [x] Edge sender के तीनों per-device finish call paths (malformed identity, success, transient failure) में attempt token verify करने के लिए regression assertion।
- [x] Outbox और device fencing migrations के नए exact function signatures तथा service-role-only grants के source assertions।
- [x] Health RPC के JSON keys (outbox, devices) और worker के consumed keys का मिलान; table column names (created_at, updated_at, delivery_status) source definitions से मेल खाते हैं।
- [ ] Node test suite चलाएँ; अभी केवल assertions जोड़े/समीक्षा किए गए हैं, execution प्रमाणित नहीं।
- [ ] Isolated PostgreSQL में migration chain apply करके SQL syntax, grants, claim→finish RPC scalar response, stale token rejection, health counts और recovery transitions verify करें।

**स्थिति:** इस चरण में कोई DB query/write, migration apply, deployment या push नहीं किया गया।

### Fencing RPC false-result handling — 15 November 2026
- [x] Audit में एक acknowledgement gap मिला: fencing RPC stale attempt पर SQL `false` लौटाता था, लेकिन callers HTTP 200 के साथ `false` को सफलता मान सकते थे।
- [x] Netlify worker अब Outbox finish RPC का JSON boolean `true` अनिवार्य मानता है; `false`/invalid response finish failure और retry/alert path में जाता है।
- [x] Edge sender अब per-device finish RPC में `data === true` अनिवार्य मानता है; stale/rejected finish successful send count नहीं होता।
- [x] दोनों callers के लिए source-contract regression assertions जोड़े।
- [ ] Node test suite और isolated concurrent stale-worker race test execute करें।

**सीमा:** अभी कोई test execute, migration apply, deployment या real push नहीं किया गया।

### Push Node source-contract test execution — 15 November 2026
- [x] Disposable Vercel Sandbox में feature branch commit `bcf6b91dc6ab641c9684616d0f4f1445500dde96` checkout करके targeted Push tests चलाए।
- [x] `push-delivery-outbox`, `push-subscription-delivery-ledger`, `push-job-offer-sender`: **37/37 PASS**।
- [x] Run से मिले दो test assertion defects सुधारे: availability preflight column-name matcher और public GET response secret-leak matcher; updated targeted run फिर 37/37 PASS।
- [x] Netlify worker का `node --check` सफल।
- [ ] पूरे repository test suite के 5 शेष unrelated failures ठीक/जाँचें: accepted electrician-contact projection; Razorpay refund GET exact stored ID; तीन refund-webhook reconciliation cases। वर्तमान full run: **82 PASS / 5 FAIL / 87 total**।
- [ ] Deno type/runtime check और PostgreSQL migration/RPC concurrency test चलाएँ; sandbox में Deno और PostgreSQL tools उपलब्ध नहीं थे।

**सीमा:** ये Node source-contract tests हैं; Supabase migrations apply नहीं हुईं, SQL runtime/permissions/concurrency सत्यापित नहीं हुए। Production या live push पर कोई कार्रवाई नहीं हुई।

### Full Node suite और Edge Function type-check — 15 November 2026
- [x] तीनों Push test files: **37/37 PASS**।
- [x] Full repository `npm test`: **87/87 PASS**, 0 failures।
- [x] Test suite के पुराने/गलत fixtures और SQL-format-sensitive assertions सुधारे: customer phone CASE multiline matcher, provider refund identity note, valid Razorpay payment-ID fixtures; Push preflight और public-config assertions भी सही किए। कोई production business logic बदलने की आवश्यकता नहीं पड़ी।
- [x] Deno `check --no-config --no-lock supabase/functions/push-job-offer/index.ts` सफल।
- [x] Netlify worker तथा Razorpay refund/webhook Node files पर `node --check` सफल; working tree clean।
- [ ] PostgreSQL migration parser/apply, role grants, RPC behavior और concurrent lease-reclaim/stale-token test isolated DB में करें।

**सीमा:** Node/Deno checks source/runtime type checks हैं; SQL migrations अभी किसी DB पर apply नहीं हुईं।

### Consolidated Node test rerun — 15 November 2026
- [x] Latest feature-branch snapshot पर `npm test` चलाया: **87/87 PASS, 0 FAIL** (Node test runner, 87 total)।
- [x] Six focused security/regression files भी अलग run में **55/55 PASS**: customer/electrician contact visibility, Razorpay refund status, Razorpay webhook inbox, push outbox, per-subscription ledger, push sender.
- [x] `node --check netlify/functions/deliver-push-outbox.js` सफल।
- [x] पुराने sandbox snapshot के पाँच failures को नवीनतम branch से दोबारा जाँचा: वे stale snapshot/test fixtures/assertions के mismatch थे; latest branch पर full suite green है। Refund-status test fixture अब provider identity note के साथ है।
- [ ] Deno type/runtime check और PostgreSQL migration/RPC concurrency test बाकी हैं; उपलब्ध sandbox में Deno/PostgreSQL tools नहीं थे।

**सीमा:** ये Node source-contract tests हैं। Supabase migrations अभी apply नहीं हुईं; database runtime, SQL permissions/concurrency, वास्तविक push delivery और mobile QA सत्यापित नहीं हुए। कोई production बदलाव/deployment नहीं हुआ।

### PostgreSQL isolated runtime + dead-letter correctness audit — 15 November 2026
- [x] Disposable local PostgreSQL 18.6 database में minimal Supabase-compatible fixture बनाकर चारों Push migrations क्रम से apply कीं: durable outbox, per-subscription ledger, health/recovery, lease fencing। यह local throwaway DB था; Supabase project/paid branch नहीं।
- [x] Runtime test ने Outbox claim RPC में `RETURNS TABLE(... attempt_count ...)` output variable बनाम unqualified column का वास्तविक ambiguity error पकड़ा। Migration `20261115170000` में update target alias `o` से columns qualify किए; migration re-apply और claim सफल।
- [x] Runtime audit ने dead device rows को complete मान लेने का logic gap पकड़ा: outbox delivered हो सकता था और dead device rows manual recovery से बाहर रह जातीं। Migration `20261115180000` के claim और completion checks अब तभी complete कहते हैं जब हर device row `delivered` हो; dead row outbox को retry/dead-letter path में रखती है।
- [x] दोनों fixes के लिए Node source-contract tests अपडेट किए।
- [x] Outbox/device claim, claim→finish, current fencing token success और stale token rejection after reclaim execute किए।
- [x] Outbox और per-device concurrent claim tests: transaction lock hold के दौरान दूसरा worker `SKIP LOCKED` से वही row नहीं लेता (second worker claim count 0)।
- [x] Exhausted lease recovery execute की: outbox attempt 8 और device attempt 5 expired leases dead-letter बने।
- [x] Unauthorized `anon` RPC execution denied; private `srk_private` table access denied। Authenticated RLS test में owner को अपनी 2 subscriptions दिखीं और दूसरे user को 0।
- [x] Health RPC counts और manual dead-letter recovery execute की; recovery ने dead device row reset की और delivered device row को delivered ही रखा।
- [x] Deno `check --no-config --no-lock supabase/functions/push-job-offer/index.ts` सफल; Netlify worker `node --check` सफल।
- [x] नवीनतम source पर full `npm test`: **87/87 PASS**।
- [ ] Supabase के वास्तविक managed project schema/roles पर parity verification और scheduled worker/Edge integration test बाकी; इसके लिए पहले approved isolated staging environment चाहिए।

**सीमा:** PostgreSQL परीक्षण local disposable DB + minimal fixture पर हुआ, वास्तविक Supabase project पर नहीं। कोई production/staging migration apply, deployment, real push या mobile QA नहीं। Web Push provider timeout के बाद transport-level duplicate संभावना अभी भी बनी रहती है।