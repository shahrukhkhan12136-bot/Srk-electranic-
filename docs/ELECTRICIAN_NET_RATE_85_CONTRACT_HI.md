# SRK ELECTRONIC — Electrician 85% Rate List & Completed-Work Accounting Contract

Status: GPT-1 owns the combined app, database, API, and accounting implementation after the Issue #11 handoff. This remains a source contract; production booking, payout, and API activation are not claimed.

## 1. One Admin-approved source rate

The Main Admin-approved customer labour catalogue is the single source of truth. The commercial split is 85% electrician / 15% company. To remain consistent with the payout ledger, the implemented canonical paise rule is: company commission = round-half-up(customer gross × 15%); electrician net = customer gross − rounded company commission. This is mathematically equivalent to an 85/15 split except at half-paise ties, where the commission-first rule is authoritative.

- Baseline catalogue duration: 8 hours.
- Electrician 8-hour category net = Admin-approved 8-hour customer gross − round-half-up(15% of that gross).
- Use integer paise; half-up rounding is applied to the 15% company commission, and the electrician receives the exact remaining paise.
- For another duration, prorate from the same published 8-hour category rate using the existing agreed duration policy.
- Both customer and electrician views must reference the same `rate_version_id` and effective timestamp. Never calculate from different rate versions.

Initial 8-hour examples:

| Category | Customer rate (Admin catalogue) | Electrician 85% rate |
|---|---:|---:|
| Electrical Assistant | ₹899.00 | ₹764.15 |
| Skilled Electrician | ₹1,199.00 | ₹1,019.15 |
| Expert Electrician | ₹1,599.00 | ₹1,359.15 |
| Premium Electrical Specialist | ₹1,999.00 | ₹1,699.15 |

These are the current baseline examples; the active values must always come from the published Admin rate version, not hard-coded frontend values.

## 2. What the electrician sees in the rate list

The Electrician App must have its own **85% electrician rate list**:
- Show only the electrician's own approved/assigned skill category or categories.
- Show the 8-hour net payable rate for each category visible to that electrician.
- If the electrician has multiple Admin-approved categories, show only those approved categories.
- Never show the customer gross rate, the full customer rate catalogue, company 15% share, commission, platform fee, or internal accounting details in this rate-list view.
- The rate list is available as a category-based earning reference; it is not proof that a particular customer has paid or that a payout has been transferred.

## 3. Admin rate increases/decreases automatically flow through

Whenever Main Admin publishes a new customer rate version, the corresponding electrician 85% rate list must automatically recalculate from that same version.

Examples:
- Skilled Electrician customer rate ₹1,199.00 → electrician rate ₹1,019.15.
- If Admin changes customer rate to ₹999.00 → electrician rate becomes ₹849.15.
- If Admin changes customer rate to ₹1,499.00 → electrician rate becomes ₹1,274.15.

No separate electrician-rate edit is allowed; the electrician rate is derived from the Admin-published customer rate. The new version becomes visible according to its effective timestamp. Previously published versions and existing booking snapshots remain unchanged.

## 4. Per-job visibility before and after completion

**Before work completion:**
- The electrician may see their own category-based 85% rate list described above.
- The electrician must not see the customer's gross amount for the assigned booking, company share, commission, platform fee, or Admin accounting details.
- Do not expose the customer's rate card or other categories' rates unless those categories are also approved for that electrician.

**After the assigned work is marked completed:**
- Show the financial breakdown for that completed job, based on its immutable booking/payment snapshot:
  - Customer amount actually paid/received.
  - Company fee/share for that job.
  - Electrician's 85% payable/earned amount.
- The completed-job breakdown may show these three amounts together. It must not expose the full customer rate catalogue or unrelated category rates.
- Clearly distinguish customer payment received from Admin payout sent to the electrician. Customer payment does not by itself mean the electrician's bank/UPI payout is complete.
- For refunded, reversed, unpaid, or disputed jobs, show the actual recorded status and amounts; never label an expected amount as received or paid.
- Summary totals may aggregate only eligible completed jobs and must reconcile to the per-job records.

## 5. Backend/API enforcement

This must be enforced by backend authorization and response schemas, not only by hiding UI elements:
- A dedicated electrician-rate-list response may return only approved category identifier/name, 8-hour electrician net paise, duration, currency, active rate version, and effective timestamp. It must omit customer gross and company share.
- The response must be filtered server-side to the authenticated electrician's Admin-approved categories.
- Before completion, booking/job responses must omit customer gross, company share, commission, platform fee, and other accounting fields.
- Completed-job accounting responses may include that assigned electrician's completed-job customer-paid amount, company share, electrician payable, and necessary payment/payout statuses.
- Every query must enforce authenticated electrician identity and booking assignment. Changing a booking ID must never expose another electrician's records.
- Do not return unrelated bookings, unapproved categories, or the full customer catalogue.
- Audit RPC return types, direct table reads, grants, RLS policies, nested JSON, and error/debug responses for leakage.
- Keep Admin/accounting full access to rate catalogue, gross/net/share, rate version, and reconciliation records.

## 6. Admin/accounting boundary

Admin/accounting retains the full customer rate catalogue and all financial details, including customer gross, company share, electrician net, source rate version, calculation policy/version, and historical payout snapshot. Access is limited to authorized Admin/accounting roles. Audit and reconciliation remain available internally.

## 7. Existing records and commission compatibility

- Existing bookings, bills, rate snapshots, payout snapshots, and ledger rows are immutable under this change.
- New rate versions apply only from their explicitly published effective timestamp.
- Preserve the existing 15% platform commission rule and its historical snapshots. Before implementation, trace whether that commission already represents the same economic share as this 85/15 labour split or is a separate fee. Do not double-charge, double-subtract, or silently replace one rule with the other.
- If the current commission is already the exact 15% withheld from labour, reconcile the accounting representation without charging an additional 15%. If it is a separate rule, obtain explicit business confirmation before combining them.

## 8. Backend controls and regression tests

- Resolve one published rate version on the server at booking creation.
- Derive and persist immutable customer amount, company share, electrician payable, rate-version, and calculation-policy snapshots atomically.
- Use integer paise; validate positive amounts and overflow.
- Test the four baseline 8-hour category calculations above.
- Test that Admin rate increases/decreases automatically change the next published electrician 85% list, including effective-time behavior.
- Test that old bookings and old rate versions do not change after an Admin edit.
- Test that the rate-list API returns only the electrician's approved category/categories and never returns customer gross/company share.
- Test that pre-completion booking responses omit customer gross/company share and that completed-job responses show the three correct amounts only for that electrician's completed jobs.
- Test nested objects, error/debug responses, refunded/reversed/unpaid states, customer-payment vs Admin-payout distinction, rounding, version consistency, payout totals, and legacy snapshot preservation.
- Test that Admin accounting can still reconcile gross, net, and company share.
- Do not modify or replay database migrations until separately authorized.

## 9. Combined GPT-1 ownership after Issue #11 handoff

GPT-1 owns the complete remaining scope, including both app-side and formerly GPT-2 backend/database/accounting work:
- Display each electrician's own category-based 85% net rate list (8-hour baseline); never show customer gross or company share in that rate-list view.
- Own rate-version resolution, commission-first 15% rounding, category-filtered electrician rate DTO, immutable booking and payout snapshots, and completed-job accounting DTOs.
- Own grants/RLS review, RPC authorization, audit records, and accounting reconciliation.
- Keep customer payment received distinct from Admin bank/UPI payout sent.
- Render server-authoritative snapshots only; do not guess or recalculate financial figures in the client.
- Complete isolated PostgreSQL migration replay, security, regression, and concurrency validation before any live activation.
