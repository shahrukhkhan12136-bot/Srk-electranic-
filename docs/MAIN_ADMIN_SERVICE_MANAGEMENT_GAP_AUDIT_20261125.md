# Main Admin and service-management gap audit — 2026-11-25

**Project:** Main Supabase `gnqhoaqatmoiwwhgzkgm`  
**Method:** Read-only SQL inspection. No rows or schema were changed.  
**Purpose:** Record the actual state before implementing remaining Admin workflows; do not recreate existing objects.

## Confirmed existing foundation

### Six active service categories

| Category | Active service types | Active skills |
|---|---:|---:|
| Electrician | 4 | 19 |
| Plumber | 4 | 13 |
| Painter | 5 | 15 |
| AC + Fridge Technician | 3 | 17 |
| Motor & Pump Technician | 6 | 14 |
| Cooler Technician | 4 | 12 |
| **Total** | **26** | **90** |

There are 27 service-type rows including Motor Winding, which is already inactive and has zero active skills. Preserve its historical rows; do not reactivate it.

Existing catalog objects include:
- `srk_service_categories`
- `srk_service_types`
- `srk_service_skills`
- `srk_skill_levels`
- `srk_worker_skills`

### Commission

- `srk_system_settings.company_commission_rate` currently equals **15**.
- `srk_system_setting_history` exists and contains columns for old/new values, actor, reason, timestamp and whether the change applies only to new bookings.
- Current history row count: **0**.
- `srk_admin_commission_report()` exists.
- Therefore a commission setting foundation exists, but end-to-end Admin edit permission, audit-history recording and booking-time snapshot behaviour still need tests.

### Geographic master

- `states` exists with 36 active rows: 28 states and 8 Union Territories.
- No district master table was found in the inspected public tables.
- Existing state master is not sufficient for the required State/UT → District selection or district-specific price lookup.

### Existing work and audit data

- `srk_admin_audit_events` exists with 3 rows and stores entity type/id, booking, action, actor, changed fields and before/after JSON.
- `srk_admin_list_audit_events(p_limit integer)` exists.
- `srk_admin_get_worker_full_profile(p_worker_id uuid)` exists.
- `srk_get_customer_booking_timeline()` exists.
- Booking/session/event tables already exist, including booking status history, worker session events, work sessions, timer events, booking worker events, payout and evidence tables.

## Verified gaps from the current data snapshot

| Area | Read-only result | Required next work |
|---|---|---|
| Worker skill assignment | `srk_worker_skills` has 0 rows | Connect approved application skills to verified worker-skill records; then calculate category/skill counts |
| Rate model | Two parallel models have uneven coverage | Reconcile `srk_service_rates` and `srk_service_pricing_rules` into one unambiguous source of truth |
| Rate coverage in pricing rules | Electrician 2 current service rows; Plumber 0; Painter 0; AC/Fridge 0; Motor/Pump 6; Cooler 4 | Complete missing approved rate coverage, with district scope and effective-date history |
| Rate coverage in service rates | Electrician 4 current rows; Plumber 12; Painter 15; AC/Fridge 3; Motor/Pump 0; Cooler 0 | Reconcile duplicate/parallel records before any new writes |
| District rates | No district master table found | Add complete India district master and district/category/service rate resolution |
| Commission history | 0 setting-history rows | Verify trigger/RPC records each authorized change and preserve old/new value, reason, actor and effective scope |
| Generic ID lookup | Worker full-profile RPC exists; no general customer/worker/helper/staff/booking ID report RPC was found in the inspected function names | Build permission-checked cross-entity ID search and a unified activity timeline |
| Date-range PDF report | No date-range report/PDF export RPC found in inspected function names | Add exact start/end filters, complete pagination, PDF generation and audit trail |
| Live operational data | Applications, worker profiles, earnings, payout requests, documents, customer profiles, bookings and booking workers each returned 0 rows in this snapshot | Do not treat empty demo/test data as a successful live workflow; validate each flow with isolated approved test identities before release |

## Implementation order (avoid duplication)

1. Inspect and test the existing Admin RPCs and RLS policies before creating replacements.
2. Reconcile the two pricing tables and preserve existing approved rates and history.
3. Add a district master sourced from an authoritative India administrative dataset; link every district to its state/UT.
4. Add district-scoped rate history and an Admin editor with reason, actor, effective date and approval controls.
5. Verify commission edit path using the existing `company_commission_rate` setting and append-only history table; preserve booking-level commission snapshots.
6. Connect verified worker skills to the six categories and produce accurate technician/helper skill counts.
7. Build an authorized ID lookup for customer, technician, helper and staff, with entity-specific profile plus booking/work/payout/complaint/audit timeline.
8. Add date filters (one day, multiple days, custom start/end), complete pagination, and PDF export. PDF must show selected entity, date range, counts, work details, earnings/payouts, disputes and audit notes, with role-based redaction.
9. Test payout request → Admin review → manual UPI payment evidence/UTR → confirmed paid status; never infer success from launching a UPI app.
10. Verify the Admin UI against real isolated test data before considering release.

## Safety boundary

- This audit is documentation only.
- No Main database schema, rows, RLS policies, functions, migration history or payment settings were changed.
- Do not merge or deploy this branch as production.
- Do not create duplicate tables or RPCs before checking the existing objects listed above.
