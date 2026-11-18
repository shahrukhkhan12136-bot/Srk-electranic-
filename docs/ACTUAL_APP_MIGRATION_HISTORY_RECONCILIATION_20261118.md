# Actual Application Migration History Reconciliation — 18 Nov 2026

Branch: feat/ai-rate-management-foundation-20261118
Branch HEAD observed during review: a6f54f1b04a21bfcd5b8dff5a7377757c8ec0e1d
Supabase project: Srk electranic
Method: read-only Supabase project status and migration-history listing; Git tree inventory only.

## Authoritative application ledger result

The connected Supabase project named Srk electranic was ACTIVE_HEALTHY. Its read-only migration-history listing returned 87 applied migration records.

The current feature branch contains 103 SQL migration files, with 102 distinct numeric version prefixes and one duplicate version group.

Comparing numeric versions:
- Exact version overlap: 7
- Applied application-ledger versions not present as exact prefixes in the branch: 80
- Branch migration versions not present in the application ledger: 96

Comparing migration names without their numeric prefixes:
- Same migration names found in both places: 16
- Of those, only 7 also have the same version.
- The remaining 9 have the same name but different version numbers.

This is substantial migration-ledger/version drift. A version-prefix comparison alone is not sufficient to decide which branch files are safe to replay or rename.

The nine same-name/different-version pairs are:
- add_google_maps_location_support: branch 20261109001000; ledger 20261108183027
- expose_assigned_booking_map_pin: branch 20261109002000; ledger 20261108183324
- create_secure_wallet_ledger_foundation: branch 20261109010000; ledger 20261108190047
- create_server_only_razorpay_route_transfer_ledger: branch 20261109020000; ledger 20261108193506
- electrician_inspection_quotes_and_service_only_commission: branch 20261109; ledger 20261109075837
- allow_quote_approval_booking_states: branch 20261109; ledger 20261109080400
- customer_admin_complaints: branch 20261110040000; ledger 20261109203132
- restore_missing_customer_booking_quote_columns: branch 20261110140000; ledger 20261110133835
- add_electrician_push_subscriptions: branch 20261111020000; ledger 20261111072823

There are 71 application-ledger records whose migration names do not appear in the branch file set. Conversely, 87 branch migration files have names not found in the application ledger. The application ledger also contains the name add_assigned_electrician_cash_payment_status twice, at versions 20261111082515 and 20261111083811; this needs separate review because the ledger's name is not unique.

Important scope limitation: Supabase's migration listing exposes only version and name metadata. It does not expose the SQL body or a checksum for the already-applied migration. Therefore this is a complete metadata reconciliation, not a byte-for-byte or semantic SQL-content reconciliation.

## Resolution of the 20261109 duplicate identity

The branch contains these two colliding filenames:
- supabase/migrations/20261109_electrician_inspection_quotes_and_service_only_commission.sql
- supabase/migrations/20261109_allow_quote_approval_booking_states.sql

The application ledger records the corresponding names as two distinct applied versions:
- 20261109075837 — electrician_inspection_quotes_and_service_only_commission
- 20261109080400 — allow_quote_approval_booking_states

Therefore the duplicate prefix in the branch does not represent a duplicate version in the application's migration ledger. The application ledger preserves two separate identities and their order.

However, the ledger listing provides only version/name metadata. It does not prove the exact SQL bytes previously applied. Do not rename or rewrite the branch files solely from this mapping until their contents and the full migration history are reconciled.

## Feature branch deployment status

The application ledger contains no 20261118 versions. The current rate-catalogue and booking-snapshot migrations dated 18 Nov are therefore not recorded as applied in this application's migration ledger at the time of this read-only check.

No migration was applied as part of this review.

## Safe conclusions and remaining work

1. The earlier test-project ledger was not representative of the application project. This review used the actual application project's read-only migration list.
2. The two 20261109 migration names are separately present in the application ledger at versions 20261109075837 and 20261109080400.
3. The branch still has a duplicate filename prefix and substantial migration version drift relative to the application ledger.
4. The amount_paid clean-replay ordering concern remains open and needs isolated local replay validation.
5. Before changing migration filenames or SQL, reconcile all 87 applied records against the 103 branch files, including changed version numbers and migration contents.
6. Do not run hosted migrations, alter the application schema/data, or deploy this feature as part of this review.

No hosted schema/data was changed. Only project status and migration metadata were read. AI remains disabled.