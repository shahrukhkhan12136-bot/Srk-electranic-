# Job-offer acceptance audit for timer authorization

Date: 2026-11-11
Scope: read-only Production function catalog inspection.

## Verified acceptance paths

Production currently contains two SECURITY DEFINER acceptance/response functions:

### `accept_electrician_job(p_offer_id uuid)`

- Resolves the profile using `electrician_profiles.auth_user_id = auth.uid()`.
- Requires active=true and verification_status='approved'.
- Locks the matching offered row in `job_offers`.
- Locks the booking only when status='new' and assigned_electrician_id IS NULL.
- Sets booking assigned_electrician_id and status='assigned'.
- Marks the chosen offer accepted and other offered rows declined.
- Returns text.
- Uses the legacy non-empty search_path configuration `pg_catalog, public, auth, pg_temp`.

### `srk_respond_to_offer(p_offer_id uuid,p_response text)`

- Requires authenticated caller and response accepted/declined.
- Resolves profile using `electrician_profiles.user_id = auth.uid()` (not auth_user_id).
- Requires active=true and verification_status='approved'.
- Locks the offer row.
- On acceptance, updates booking only when unassigned and status is new or confirmed; then marks offer accepted and competing offered rows expired.
- On decline, only updates the offer.
- Returns JSONB.
- Uses the same legacy non-empty search_path configuration.

## Additional offer read functions

- `srk_get_my_offer_details()` filters profiles using user_id only and returns customer contact/address fields when the booking is assigned and in selected statuses.
- `srk_get_my_offer_price_details()` supports user_id OR auth_user_id.
- These read paths are not proof of acceptance by themselves; the authoritative assignment is the locked booking row plus accepted offer.

## Risks and required timer-RPC behavior

1. There are multiple acceptance paths with inconsistent identity-link handling and slightly different allowed initial booking statuses.
2. Both acceptance paths require active + approved profile and write the assignment/status, but the exact caller distribution and grants must be checked before retiring either path.
3. New timer RPC must require BOTH:
   - booking.assigned_electrician_id = the matched profile.id; and
   - an accepted `job_offers` row for the same booking/profile, unless a verified Admin assignment workflow explicitly documents another valid assignment route.
4. Resolve the authenticated profile by `user_id = auth.uid() OR auth_user_id = auth.uid()`, but reject ambiguous results if more than one profile matches.
5. Do not trust client-supplied electrician profile IDs.
6. The booking row must be locked before checking assignment, accepted offer, arrival state, or timer state.
7. No timer start until independent arrival evidence exists and the customer approves the start request.
8. The new RPC should use a hardened empty search_path and minimum EXECUTE grants; do not copy legacy SECURITY DEFINER configuration.
9. The older `accept_electrician_job` and `srk_respond_to_offer` functions must not be changed in this timer-only task. Their deprecation requires repository caller audit and regression tests.

## No-write confirmation

All information above came from catalog metadata and function definitions. No rows, schema objects, grants, functions, or migrations were changed. No database or site deployment was performed.