# Timer cutover caller and Admin-write audit

Date: 2026-11-11
Branch: `feature/production-push-notifications`
Scope: repository source inspection on the feature branch plus read-only Production policy inspection.

## Feature-branch callers found

### Electrician portal (`electrician.html`)

Direct RPC callers:
- `srk_respond_to_offer(p_offer_id,p_response)` — accept/decline offer.
- `srk_update_booking_work_status(p_booking_id,p_status)` — legacy inspection / in-progress / completed transitions.
- `srk_submit_booking_quote` — legacy quotation submission.
- `srk_get_my_offer_details`, `srk_get_my_offer_price_details` — offer/booking reads.
- Cash payment confirmation and wallet/earnings reads.
- Push subscription save.

The page currently has a single `workStatus(id,status)` UI path that invokes `srk_update_booking_work_status`. It must be replaced with arrival + customer-approved start/stop requests; simply changing button labels is not sufficient.

### Admin portal (`admin.html`)

Direct RPC callers include:
- `srk_admin_offer_booking`
- `srk_admin_record_manual_payment`
- wallet, payout, commission, and application-review functions.

Admin reads up to 300 booking rows from `service_bookings`, including legacy payment_method and quoted_amount fields. It has a direct UPDATE path to `service_bookings` for address/district/state/PIN corrections. The inspected direct update only writes address/location fields, not timer or financial fields. Preserve this narrowly scoped correction capability, but do not introduce timer or bill fields into generic Admin updates.

### Customer portal (`index.html`)

No direct `srk_update_booking_work_status`, offer-acceptance, or quote RPC call was found in the inspected source. Customer timer approval UI and RPC integration are not yet present in the inspected page.

## Production RLS observations

- `service_bookings`: authenticated SELECT policy allows Admin or the owning customer; authenticated UPDATE policy allows Admin only.
- `job_offers`: authenticated SELECT policy allows Admin or an active, approved electrician profile linked by user_id OR auth_user_id.
- These policies do not provide a direct customer write path for timer decisions, which is appropriate for a narrow server-side RPC design.
- The catalog query for function grants did not return a usable privilege result in this audit; do not infer or claim exact EXECUTE grants from it. A separate corrected grant query remains required before any migration.

## Cutover plan (not yet implemented)

1. Add narrowly scoped timer RPCs and append-only decision/bill tables with database-level mutation guards.
2. Add independent arrival recording and customer approval UI.
3. Replace the electrician `workStatus` path and legacy quote screens only after the new RPC contract is integrated.
4. Add customer start/stop decision controls and final bill/material approval views.
5. Update Admin booking view for timer audit and bill review; keep address corrections isolated.
6. Migrate payment creation, verification, and webhook amount validation to final-bill identifiers and immutable bill totals.
7. Retire legacy quote and work-status RPCs only after all callers are migrated, tests pass, and historical booking compatibility is proven.
8. Run end-to-end authenticated integration and concurrency tests in a disposable database reconstructed from a verified schema snapshot.

## Safety status

- Feature branch source was read; no source files were modified in this audit.
- Production queries were read-only; no data or schema was changed.
- No shared TEST database was changed.
- No RPC, migration, or UI implementation was deployed.
