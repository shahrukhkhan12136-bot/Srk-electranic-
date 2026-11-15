# Supabase Migration Dependency Matrix (Hindi)

तारीख: 15 नवम्बर 2026  
जाँची गई शाखा: `feat/customer-login-first-dashboard-20261114`  
जाँचा गया commit: `3050e35fd0f1af9f42097f9bc1f12d4d16152965`  
दायरा: `supabase/migrations/` में 73 SQL फाइलों का static source scan.

## महत्वपूर्ण सीमा

यह dependency map SQL text की static inspection है। यह PostgreSQL parser, migration replay, pgTAP, live schema catalog या Supabase `schema_migrations` history का विकल्प नहीं है। नीचे दी गई dependencies source में दिखने वाले references/DDL पर आधारित हैं; dynamic SQL, trigger side-effects, grants, policies, storage और functions की पूरी transitive dependency chain अलग runtime review माँगती है। इसे अभी executable replay order या Production parity प्रमाण न मानें।

## Object dependency clusters

| Cluster | पहले से उपलब्ध होने वाले आधार | इस cluster में बने/बदले objects | आगे निर्भर भाग |
|---|---|---|---|
| Core booking & identity | `service_bookings`, `electrician_profiles`, `electrician_applications`, `job_offers`, `auth.users` | Customer booking access, map/location columns, quote/work-state columns, booking idempotency, rate-tier audit, offer dispatch | Timer/work events, cancellation, receipts, support, payment, refund, SOS |
| Commission & wallet | `service_bookings`, `electrician_profiles`, `auth.users` | Wallet accounts, wallet ledger, wallet bank links; commission reporting RPCs | Cancellation-fee accounting, cash collection, payout/accounting reconciliation |
| Route transfer ledger | `service_bookings`, `auth.users` | `srk_route_transfers` and restricted server-side access | Route recipient validation and Admin reconciliation; independent provider settlement proof remains absent |
| Customer support conversation | Existing `srk_booking_complaints` and `auth.users` | Complaint messages and attachment metadata; customer/admin message RPCs | Admin staff RBAC reads and updates complaint/message records |
| Financial audit core | `service_bookings`, `electrician_profiles`, `auth.users` | Labour bills, manual payment entries, electrician payouts, admin audit events, Razorpay refunds, booking refund requests, manual refund entries | Payout reconciliation, receipts, cancellation fees, manual refunds, Razorpay recovery/reconciliation |
| Work timer & immutable history | Booking/profile identity plus labour-bill contract | Server work timer guards, immutable labour bills, work events and append-only history | Accounting, customer receipt, refund amount verification |
| Cancellation & fee accounting | Booking/cancellation requests, wallet ledger and identity | Cancellation requests/events, customer fee debts, fee items and fee ledger | Full refund reversal, future booking cash/payment breakdown, accounting reconciliation |
| Admin staff & support | Existing complaint messages, electrician support tickets/messages, auth users | Staff, permissions, role permissions, sessions, staff audit events, support assignments and RBAC RPCs | Permission-gated SOS queue and support operations |
| Push delivery | Existing `job_offers` and historical `srk_push_subscriptions` base table | Durable push outbox, subscription delivery ledger, health monitoring and lease fencing | Requires provider configuration and delivery runtime; no live push send verified |
| KYC & electrician activation | `electrician_profiles`, auth users, storage contracts | KYC documents/events, review RPCs and activation gates | Electrician eligibility, offer dispatch and account activation |
| SOS emergency support | Bookings, customer booking ownership, electrician profile ownership, Admin RBAC | SOS alert/event tables, create/list/acknowledge RPCs | Admin/Support queue; provider delivery and live location are not configured |

## High-priority ordering gates

1. **Base schema gate:** original authoritative definitions for `service_bookings.amount_paid` and `electrician_profiles.auth_user_id` are still not recovered. Quote/commission, payment/refund/SOS and electrician ownership code references them. Do not invent types, defaults, nullability, FK or indexes.
2. **Complaint base gate:** support conversation and RBAC migrations expect the earlier `srk_booking_complaints` / complaint event contract.
3. **Push subscription base gate:** push outbox alters `srk_push_subscriptions`; the base subscription table must exist before outbox/ledger/health/lease migrations.
4. **Financial audit gate:** labour bills, manual payment entries, payout, refund and audit tables are introduced by `20261114125844_restore_financial_audit_core_schema.sql`; downstream financial migrations depend on these objects.
5. **Wallet/cancellation gate:** cancellation-fee accounting alters and consumes `srk_wallet_ledger`; wallet foundation must precede fee accounting.
6. **RBAC gate:** staff permission checks and support assignment functionality depend on the RBAC foundation and existing support/complaint objects.
7. **SOS gate:** SOS electrician ownership lookup references `electrician_profiles.auth_user_id`; this remains blocked by the base-schema gate.

## Migration filename/version observations

- कुल 73 SQL files मिलीं।
- दो legacy files का version prefix एक जैसा `20261109` है: `20261109_allow_quote_approval_booking_states.sql` और `20261109_electrician_inspection_quotes_and_service_only_commission.sql`. इनके बीच duplicate constraints और remote applied-history का सवाल अलग से unresolved है।
- 8-digit और 14-digit version filenames दोनों मौजूद हैं। Pinned Supabase CLI 3.0.0 TypeScript db-push source inspection में shared-prefix sorting test मिला था; इसलिए CLI sorting को confirmed failure नहीं कहा जा रहा। फिर भी exact replay runtime यहाँ नहीं चला।
- दो multi-profile electrician labour-bill access correction migrations अलग-अलग timestamp पर मौजूद हैं; इनके क्रम और final function body का replay test आवश्यक है।
- Route transfer ledger retire/legacy migration files भी inventory में हैं; इनके वास्तविक remote applied status का प्रमाण नहीं है।

## Safe validation plan

1. Approved read-only schema-only export और migration history artifact लें; कोई production write/DDL नहीं।
2. Base column contracts और existing complaint/push tables के catalog definitions verify करें।
3. Isolated PostgreSQL/Supabase test database में clean replay और upgrade replay दोनों चलाएँ।
4. हर migration के बाद object-level smoke tests; अंत में pgTAP और Node tests।
5. Duplicate legacy version और repeated function replacements को replay results के साथ resolve करें; अभी rename/delete न करें।

## Execution status

- Static inventory: 73/73 migration files inspected at source level.
- PostgreSQL/pgTAP runtime: not executed.
- Production schema/history query: not performed.
- Production migrations, payments, refunds, transfers, SMS/push sends: not performed.
- This document does not close a GPT-2 checklist item or change the reported 69% progress.
