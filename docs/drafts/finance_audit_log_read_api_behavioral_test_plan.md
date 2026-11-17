# Finance Audit Log Read API — Behavioral Test Plan (Draft)

**Status:** Planning artifact only. Not executable SQL and not part of the active pgTAP runner.
**Scope:** Proposed `public.srk_admin_list_financial_audit_events(...)` read RPC.
**Safety:** Use an isolated disposable PostgreSQL/Supabase test database only. Do not run against Production or shared Test Supabase.

## Preconditions

1. The final RPC migration is approved and installed only in the isolated test database.
2. Test identities exist for Main Admin, Support Staff, ordinary authenticated customer, electrician, and anon.
3. Seeded audit rows include multiple entity types/actions, multiple actors, multiple bookings, and records sharing the same `created_at` timestamp but having distinct UUIDs.
4. The test fixture contains synthetic values only; never use real customer contact data, payment references, provider IDs, or free-text notes.
5. Record the exact schema/table definition and the approved entity/action allow-lists before asserting expected results.

## Behavioral test matrix

| ID | Identity / input | Expected result |
|---|---|---|
| B01 | anon invokes RPC | Permission denied; no audit rows disclosed |
| B02 | authenticated customer invokes RPC | Main Admin authorization error; no rows disclosed |
| B03 | authenticated electrician invokes RPC | Main Admin authorization error; no rows disclosed |
| B04 | authenticated Support Staff invokes RPC | Main Admin authorization error; no rows disclosed |
| B05 | authenticated Main Admin invokes with defaults | Only allow-listed metadata returned; bounded page size |
| B06 | Main Admin requests limit NULL, 0, 1, 100, 101, and a very large integer | Defaults/clamps to documented 1..100 contract; never returns more than 100 |
| B07 | Main Admin supplies only cursor timestamp or only cursor UUID | Explicit invalid-parameter error |
| B08 | Main Admin supplies valid composite cursor | Next page strictly continues after `(created_at,id)`; no duplicate or skipped seeded rows |
| B09 | Several rows share identical `created_at` | UUID tie-breaker makes page ordering deterministic |
| B10 | Main Admin filters by allowed entity type/action | Only matching rows returned |
| B11 | Main Admin supplies unknown entity type/action | Explicit validation error; no broad unfiltered fallback |
| B12 | Main Admin filters by booking UUID and actor UUID | Both filters are applied together (AND semantics) |
| B13 | Main Admin requests rows containing synthetic before/after JSON secrets | Raw JSON and secret values are absent from RPC result |
| B14 | authenticated role attempts direct SELECT on audit table | Denied; RPC remains the only approved read path |
| B15 | anon attempts EXECUTE on RPC | Denied by function ACL |
| B16 | Main Admin reads an empty result set / final page | Empty page is returned safely; cursor handling remains stable |

## Required assertions and evidence

- Capture identity/role used for each call and SQLSTATE/message for denied calls.
- For B01–B04, assert both authorization failure and zero data disclosure.
- For B08–B09, compare the complete ordered fixture IDs across all pages against one expected ordered sequence.
- For B13, assert the exact output column set and verify synthetic secret sentinels do not appear anywhere in serialized output.
- For B14–B15, inspect effective privileges as well as attempted access.
- Include rollback/cleanup so fixtures cannot persist beyond the isolated test run.

## Open decisions before implementation

1. Confirm whether the RPC should expose `actor_user_id` and `changed_fields` to Main Admin.
2. Approve the final entity/action allow-lists against the actual audit schema and observed action vocabulary.
3. Decide retention/lookback bounds and whether reads themselves require a separate access log.
4. Confirm whether Support Staff must remain categorically excluded.
5. Review whether booking/actor UUID filters and the current cursor shape are sufficient for the intended UI.

## Exit criteria

Do not promote the draft to `supabase/tests/database` until the RPC contract and field policy are approved, actual schema compatibility is checked, and the isolated DB is available. Do not claim behavioral coverage until the tests are executed and their output is retained.
