# SRK ELECTRONIC — Backend / Database Progress Audit
तारीख: 21-11-2026
सुरक्षित Feature Branch: `feature/master-gst-accounting-20261121`
Latest verified source before audit refresh: `35c2f357583276fd6da1386672e43aa084b3082b`
Repository: `shahrukhkhan12136-bot/Srk-electranic-`

## सत्यापित स्थिति

- इस branch पर Master backend के लिए migrations, RPCs, endpoint changes, API contracts और Node/pgTAP source tests मौजूद हैं।
- नवीनतम GitHub Actions Node suite: **526 passed, 0 failed** (latest verified run `44895311921`, commit `35c2f357583276fd6da1386672e43aa084b3082b`).
- यह source/contract verification है; PostgreSQL migration replay, pgTAP runtime, full browser/E2E और Production readiness का प्रमाण नहीं।
- Supabase Production migration history पुराने baseline पर है; 21-Nov के Master migrations Production में लागू नहीं हैं।
- Vercel status में build rate-limit failure आया; कोई successful deployment प्रमाणित नहीं।
- कोई Production DB, Main Branch, live payment या payout operation इस काम में नहीं किया गया।

## तैयार / source मौजूद (पर runtime rollout शेष)

1. Canonical Technician identity और unified completion counter; तीसरी, छठी आदि हर तीसरी Completed booking पर online-only gate.
2. Shared OTP-first Technician application, category/skill selections, private KYC metadata, Admin review और approval gate.
3. Category-neutral Technician dispatch, presence/location और assignment model.
4. Master service/rate catalogue, versioned Admin rate changes और immutable booking rate snapshots.
5. Per-Technician daily work timer, lunch/overtime calculation, append-only labour ledger और customer day-end decisions.
6. Final bill, customer material approval और automatic final-bill issuance.
7. Razorpay payment verification/webhook, Admin manual payment, per-Technician 85/15 payable split, refund/receipt integration.
8. Technician wallet, payout request, company Razorpay settlement evidence, Admin manual UPI/bank transfer, UTR और Paid gate.
9. GST future-ready accounting; no company GST registration means no GST charged and no GST tax invoice.
10. 21-Nov branch update: Technician's own approved-skill 85% rate list, all-category 85% reference list, Admin skill-level assignment RPC, two-way booking rating submit RPCs and Admin moderation audit.\n11. 21-Nov branch update: cash collected directly by Technician creates a 15% SRK commission due; subsequent company-collected Razorpay/UPI/bank Technician share offsets outstanding dues oldest-first. Wallet shows cash collected, outstanding commission, recovered commission, offset and due history. Technician wallet UI updated.

## अभी शेष Backend / Database कार्य

1. **Cash collected directly by Technician — implemented in Feature Branch source:** a trigger now classifies cash-collected Technician shares as already received, records 15% SRK commission due in a separate due ledger, and offsets the due against future company-collected Razorpay/UPI/bank earnings oldest-first. Wallet RPC and Technician Wallet UI show outstanding dues, recovered commission and booking-level due history. Still needs pgTAP runtime/replay, refund edge-case review and Admin-side due reporting.
2. **Rating read / profile aggregates:** submit and Admin hide/restore RPCs exist; customer/Technician/Admin list APIs, published average/count, report/appeal workflow and UI integration are not yet complete.
3. **Verified skill level workflow:** Admin RPC now assigns an active rate level to an approved skill. Admin UI, Technician profile display, pending-level handling and regression/runtime coverage remain.
4. **Rate catalogue completeness:** only the three explicitly confirmed Plumber rates are seeded active. Electrician, Painter, AC, Fridge, Motor/Pump and Cooler conflicting/unconfirmed prices remain pending Admin configuration; do not activate guessed rates.
5. **Admin GST configuration and invoice screens:** backend report/accounting foundation exists; full company GST profile/rate configuration form and final customer invoice/credit-note display integration remain.
6. **Clean database replay and pgTAP:** run all migrations in dependency order on a disposable PostgreSQL/Supabase Development database, fix replay errors, execute all pgTAP tests, then run security advisors and RLS/grant actor matrix. This is intentionally deferred until the user-authorized single Development Branch at the end.
7. **Full end-to-end runtime:** Customer OTP → booking → dispatch → multiple Technician acceptance → timer → material approval → final bill → cash/online payment → commission → payout/UTR → refund/credit note. Node contract tests do not replace this.
8. **Legacy compatibility and retirement:** preserve historical quote records, but finish verifying every live legacy payment/refund/booking dependency and ensure Master booking never depends on quote approval. Do not delete history.
9. **Security/operations validation:** resolve/close the outstanding private-schema RLS advisory after dependency/grant review; verify storage policies, Auth actor boundaries, backup/restore and ledger integrity on the isolated test database.
10. **Provider settlement proof:** current Razorpay settlement evidence is Admin-entered evidence, not an automatic bank/provider reconciliation feed. Verify actual provider settlement reports and reconciliation before live payouts.

## Latest 21-Nov change details

Migration: `supabase/migrations/20261121250000_master_technician_rates_and_two_way_ratings.sql` (source revision `e956b735181bac6bf4b59ba1b305a8700b1f2d3e`)

- Adds Admin-assigned approved skill level.
- Adds Technician own-skill 85% rate-list RPC and all-category 85% reference RPC; the latter is informational only and does not grant work eligibility.
- Adds Customer→Technician and Technician→Customer rating RPCs restricted to completed, customer-approved booking participants.
- Adds one-rating-per-side/booking indexes and Admin hide/restore moderation with reason and append-only event.
- Node contract tests: `tests/master-technician-rates-two-way-ratings.test.js`.
- pgTAP source: `supabase/tests/database/master_technician_rates_two_way_ratings.test.sql`.
- API contract: `docs/GPT2_MASTER_TECHNICIAN_RATES_TWO_WAY_RATINGS_20261121_HI.md`.

## Safety / next sequence

Continue only on this Feature Branch. Do not apply migrations to Production, merge to Main, create a paid Development Branch, deploy, or execute real payments/payouts without separate explicit authorization. Finish source implementation and review first; the one Development Branch and full database replay remain deferred until the end as already requested.


## Cash commission follow-up — 21-Nov-2026
Migration: `supabase/migrations/20261121260000_master_cash_commission_due_and_online_offset.sql`
- Cash-collected booking creates a separate 15% company commission due for each Technician based on the allocated commission snapshot.
- Cash-collected 85% is marked as already collected; it is not put into the Admin payout queue again.
- Next company-collected online/manual UPI/bank Technician payable is reduced by oldest outstanding cash commission due, up to the Technician's 85% labour share. Materials reimbursement is excluded from recovery.
- Wallet summary exposes outstanding due, recovered commission, cash already collected, and offset details.
- `electrician.html` Master Wallet shows these values and due history; SRK platform commission is not shown in Technician Rate Lists.
- Node contract tests and pgTAP source added. Latest Node CI run `44895311921`: 526 passed, 0 failed.
- Important remaining checks: execute migration replay and pgTAP in disposable PostgreSQL; review cash-booking refund/reversal behavior; add Admin company-side outstanding commission due report; run browser E2E. No production migration applied.


## Admin SRK Cash Commission report — 21-Nov-2026
- Added Main Admin-only read-only RPC `srk_admin_list_master_commission_dues()`.
- Admin Panel now shows original 15% cash commission, recovered amount, outstanding amount, open due count, Technician-wise totals and booking-wise due history.
- The report is read-only; it cannot waive, edit, or manually mark commission as recovered. Actual recovery remains transactionally tied to future company-collected Technician payables.
- Tests added: `tests/master-admin-cash-commission-report.test.js` and `supabase/tests/database/master_admin_cash_commission_report.test.sql`.
- Cash booking refund remains a separate gap: the existing Master refund RPC is specifically for verified Razorpay payments; no cash-refund reversal RPC is being claimed as complete.


## Current consolidated source checkpoint — 21-Nov-2026

यह section ऊपर के पुराने “अभी शेष” snapshots को supersede करता है। पुराने paragraphs ऐतिहासिक audit trail हैं; नीचे latest staging state है।

- Current staging branch: tmp/master-final-ui-20261121; base feature branch: feature/master-rating-ui-followup-v2-20261121.
- Latest exact-head GitHub Node CI: **573 passed, 0 failed**, run 44906291585, commit 4cfdc869b3b69e3875e89fdf989ed215fcc351ab.
- Repository में 112 SQL migrations और 55 pgTAP database test files हैं। Node CI source/contract tests चलाता है; इससे PostgreSQL/pgTAP runtime pass प्रमाणित नहीं होता।
- Shared Technician App source अब OTP-first application, multiple categories/skills, private KYC, Admin skill/KYC review/approval, approved-skill 85% rate list, Master dispatch inbox, GPS presence, two-way ratings और Admin moderation UI तक जुड़ा है।
- Customer source अब assigned Technician team/name, booking-scoped GPS, daily workday start approval, तीन day-end decisions, final bill/GST breakdown और GST invoice/credit-note view दिखाता है। Stopped workday पर normal/overtime breakdown भी दिखता है।
- Admin source में Master dispatch retry queue, Technician applications/KYC/skill review, service/rate catalogue, GST accounting, completed cash/manual payment verification, cash refund review और payout integration है।
- Master cash/manual payment verification queue केवल completed unpaid cash/UPI/bank bookings दिखाती है; Razorpay order/payment ID वाले booking को queue से बाहर रखती है। Admin RPC GST-inclusive total due पर payment record करती है।
- Technician cash refund inbox केवल उसी Technician की assigned, completed, paid cash booking और Admin-approved Customer refund request दिखाता है। Admin finalization अब tax snapshot के total_due_paise को verify करती है; previously used subtotal-only comparison को ठीक किया गया है। Recovered commission का wallet credit payout workflow और Technician wallet UI में available/requested/paid/history रूप में दिखता है।
- Confirmed service rate seed: **36 active rate levels** — Electrician, Plumber, Painter, Fridge, Motor Winding, Cooler Repair और Cooler Motor Winding. **6 pending Admin rows** — AC Installation/Repair ₹437/hour team split, Basic Electrician Helper, Pump Repair और Motor/Cooler winding above 20 HP. Pending rows customer-bookable नहीं हैं।
- New Master booking flow में quotation approval नहीं है। Historical quote columns/records सुरक्षित हैं; पुराने historical-only accounting compatibility को बिना dependency audit नहीं हटाया जाएगा।

### अभी वास्तविक शेष gates

1. **Road-distance travel fee source अभी नहीं बना:** 3 km free, फिर ₹4/km one-way के लिए GPS straight-line को road distance नहीं मानेंगे। Approved Google Routes/Maps या अन्य routing provider और server-side credential/configuration चाहिए; इसके बिना fee को सही रूप में calculate/charge करने का दावा नहीं।
2. **Rate owner inputs:** AC ₹437 combined team rate का Technician/Helper split, Basic Electrician Helper, Pump Repair और 20 HP से ऊपर की rates Admin/owner approval तक pending।
3. **Founder photo:** actual approved original photo अभी upload नहीं हुआ; Customer और shared Technician App में लगाना बाकी है। कोई generated/alternate portrait नहीं।
4. **Database runtime:** Supabase Development Branch Pro Plan पर निर्भर है और current plan में unavailable रही। GitHub-hosted disposable Supabase CLI trial migration replay से पहले fail हुआ क्योंकि repository migration chain में authoritative pre-existing core schema (जैसे service_bookings) baseline मौजूद नहीं है। उस premature local workflow को हटाया; no database migration applied, no pgTAP executed। 55 pgTAP files source में हैं, runtime NOT RUN।
5. **Baseline/lineage:** authoritative core schema/Auth/Storage fixture, duplicate legacy migration-version evidence और dependency order reconcile करना; उसके बाद disposable PostgreSQL/Supabase पर पूरी migration replay और pgTAP execution।
6. **Runtime/E2E:** hosted schema/role parity, OTP/SMS, KYC Storage, dispatch concurrency, timer, Customer/Technician/Admin actor ACL, payment/refund/payout ledger reconciliation, Push provider delivery और browser end-to-end tests।
7. **Operations/QA:** backup/restore integrity test, Vercel Preview (पूर्व build-rate-limit issue), Netlify Deploy Preview, desktop/mobile consolidated QA और owner visual acceptance।
8. **Release gate:** Main Branch PR अभी नहीं खोला; कोई Main merge, Production migration, live payment/payout, provider action या deployment नहीं किया।

