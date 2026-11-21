# SRK ELECTRONIC — Backend / Database Progress Audit
तारीख: 21-11-2026
सुरक्षित Feature Branch: `feature/master-gst-accounting-20261121`
Audit head: `43cef7f665a80ea5425f5d5381d8dbdfd14104e7`
Repository: `shahrukhkhan12136-bot/Srk-electranic-`

## सत्यापित स्थिति

- इस branch पर Master backend के लिए migrations, RPCs, endpoint changes, API contracts और Node/pgTAP source tests मौजूद हैं।
- नवीनतम GitHub Actions Node suite: **521 passed, 0 failed** (run `44894545415`).
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
10. 21-Nov branch update: Technician's own approved-skill 85% rate list, all-category 85% reference list, Admin skill-level assignment RPC, two-way booking rating submit RPCs and Admin moderation audit.

## अभी शेष Backend / Database कार्य

1. **Cash collected directly by Technician — commission due and recovery:** current Master manual-payment function creates Technician 85% payable rows for a manually recorded cash payment. It does not yet represent the separate case where Technician already collected the full cash amount and owes the Company 15%. Add a distinct collection-source/evidence state, append-only commission-due ledger, wallet due display and exact offset/recovery against future online earnings without double deduction.
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

Migration: `supabase/migrations/20261121250000_master_technician_rates_and_two_way_ratings.sql`

- Adds Admin-assigned approved skill level.
- Adds Technician own-skill 85% rate-list RPC and all-category 85% reference RPC; the latter is informational only and does not grant work eligibility.
- Adds Customer→Technician and Technician→Customer rating RPCs restricted to completed, customer-approved booking participants.
- Adds one-rating-per-side/booking indexes and Admin hide/restore moderation with reason and append-only event.
- Node contract tests: `tests/master-technician-rates-two-way-ratings.test.js`.
- pgTAP source: `supabase/tests/database/master_technician_rates_two_way_ratings.test.sql`.
- API contract: `docs/GPT2_MASTER_TECHNICIAN_RATES_TWO_WAY_RATINGS_20261121_HI.md`.

## Safety / next sequence

Continue only on this Feature Branch. Do not apply migrations to Production, merge to Main, create a paid Development Branch, deploy, or execute real payments/payouts without separate explicit authorization. Finish source implementation and review first; the one Development Branch and full database replay remain deferred until the end as already requested.
