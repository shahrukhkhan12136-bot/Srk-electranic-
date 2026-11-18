# SRK ELECTRONIC — 85% Electrician Net Rate Contract

Status: shared GPT-1/GPT-2 source contract proposal; not yet wired into production booking, payout, or API flows.

## Authoritative rate and calculation

The Main Admin-approved commercial rate catalogue is the single source of truth. Every new booking must snapshot the same published `rate_version_id`, effective timestamp, tier, duration, and customer labour amount. Electrician net amount is calculated from that same snapshot:

- Customer labour amount = Admin-approved rate prorated to booking duration.
- Electrician payable = floor(customer labour amount in paise * 85 / 100), with an explicitly documented integer rounding policy.
- Internal company share = customer labour amount - electrician payable.

Example at 8 hours: customer labour ₹1,000.00; electrician payable ₹850.00; internal accounting residual ₹150.00.

Do not independently look up a different rate version for electrician earnings. Materials, travel, taxes, cancellation fees, tips, adjustments, and existing platform commission must remain separately classified and must not be silently folded into this labour split.

## Electrician privacy boundary

Electrician-facing endpoints and payloads may expose only fields required for the electrician's own work and payable amount, such as `electrician_payable_paise`, booking status, and payout status. They must not expose gross/customer labour amount, company residual/share, commission amount/rate, platform fee, internal accounting labels, or admin-only reconciliation fields.

This is a backend/API boundary, not merely a UI hiding rule. Do not select or serialize forbidden columns into electrician responses. The UI must render only the sanitized DTO. Existing direct table reads and RPC return types must be audited for indirect leakage.

## Admin/accounting boundary

Admin/accounting retains customer gross labour, electrician net, internal residual, source rate version, calculation policy/version, and historical payout snapshot. Access is limited to authorized Admin/accounting roles. Audit and reconciliation remain available internally.

## Existing records and commission compatibility

- Existing bookings, bills, rate snapshots, payout snapshots, and ledger rows are immutable under this change.
- Apply the new 85/15 labour split only to eligible new bookings after an explicitly approved effective time.
- Preserve the existing 15% platform commission rule and its historical snapshots. Before implementation, trace whether that commission currently represents the same economic share or a separate fee. Do not double-charge, double-subtract, or silently replace one rule with the other.
- If the current commission is already the exact 15% withheld from labour, implementation must reconcile the accounting representation without charging an additional 15%. If it is a separate rule, obtain explicit business confirmation before combining them.

## Backend controls and test requirements

- Resolve one published rate version on the server at booking creation.
- Persist immutable gross/net/version snapshots atomically.
- Use integer paise; validate positive amounts and overflow.
- Enforce authenticated electrician ownership and booking assignment on every read.
- Use least-privilege RPC return types and grants. No service-role key in clients.
- Test authenticated electrician response schema for absence of forbidden fields and values, including nested objects and error/debug responses.
- Test 1000 -> 850, 899 -> 764.15 under half-up paise arithmetic, zero/negative rejection, version consistency, rounding, refunds/reversals, payout totals, and legacy snapshot preservation.
- Test that Admin accounting can still reconcile gross, net, and residual.
- Do not modify or replay migrations until separately authorized.

## GPT-1 work

Electrician App must display only the backend-supplied net payable amount and payout status. Remove UI calculations/labels for gross, company share, commission, or platform fee only after backend responses have been sanitized. Never assume hiding a DOM element is access control.

## GPT-2 work

Own rate version resolution, server-side split calculation, immutable snapshots, private accounting representation, sanitized electrician API/RPC DTOs, grants/RLS review, and backend regression tests. Coordinate the final field names with GPT-1 before app integration.
