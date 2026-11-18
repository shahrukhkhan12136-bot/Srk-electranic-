# SRK ELECTRONIC — Electrician Rate Privacy & Completed-Work Accounting Contract

Status: updated GPT-1/GPT-2 source contract proposal; not yet wired into production booking, payout, or API flows.

## Authoritative rate and calculation

The Main Admin-approved commercial rate catalogue is the single source of truth. Every new booking must snapshot the same published `rate_version_id`, effective timestamp, tier, duration, and customer labour amount.

- Customer labour amount = Admin-approved rate prorated to booking duration.
- Electrician payable = 85% of the customer labour amount, calculated in integer paise with the documented half-up rounding policy.
- Company labour share = customer labour amount - electrician payable.

Example at 8 hours: customer labour amount ₹1,000.00; company labour share ₹150.00; electrician payable ₹850.00.

Do not independently look up a different rate version for electrician earnings. Materials, travel, taxes, cancellation fees, tips, adjustments, and existing platform commission must remain separately classified and must not be silently folded into this labour split.

## Electrician visibility — before and after work completion

**Before the work is completed:**
- Do not show the electrician the commercial rate list/catalogue, customer rate card, or the job's gross customer labour amount.
- Do not show company fee/share, commission, platform fee, or internal accounting details.
- The electrician may see job/service details and operational status needed to perform the assigned work, but not pricing/rate-list information.

**After the assigned work is marked completed:**
- Show the accounting for that completed job, subject to the authoritative booking/payment records:
  - Customer amount actually paid/received for the job.
  - Company fee/share for that job.
  - Electrician's payable/earned amount for that job.
- The completed-job view may show these three amounts together. It must not expose the entire commercial rate catalogue or rates for other service tiers.
- Clearly distinguish customer payment received from Admin payout sent to the electrician. A customer payment does not by itself mean the electrician's bank/UPI payout is complete.
- For refunded, reversed, unpaid, or disputed jobs, show the actual recorded status and amounts; do not present an expected amount as money received or paid.
- Summary totals may aggregate only eligible completed jobs and must reconcile to the per-job records.

This is an intentional stage-based disclosure rule: pricing is hidden while the electrician is preparing/performing the job; completed-job accounting is visible afterwards. It is not a blanket ban on showing company-fee information to the electrician.

## Backend/API enforcement

This rule must be enforced by the backend, not only by hiding UI elements:
- Pre-completion response DTOs must omit the rate catalogue, gross customer amount, company share, and other accounting fields.
- Completed-job accounting DTOs may include only that assigned electrician's completed-job customer-paid amount, company fee/share, electrician payable, and necessary payment/payout statuses.
- Every query must enforce authenticated electrician identity and booking assignment. A caller must not be able to request another electrician's completed job by changing a booking ID.
- Do not return the full rate catalogue or unrelated bookings in the completed-job response.
- Audit RPC return types, direct table reads, grants, RLS policies, nested JSON, and error/debug responses for leakage.
- Keep Admin/accounting full access to rate catalogue, gross/net/share, rate version, and reconciliation records.

## Admin/accounting boundary

Admin/accounting retains the full rate catalogue and all financial details, including customer gross, company share, electrician net, source rate version, calculation policy/version, and historical payout snapshot. Access is limited to authorized Admin/accounting roles. Audit and reconciliation remain available internally.

## Existing records and commission compatibility

- Existing bookings, bills, rate snapshots, payout snapshots, and ledger rows are immutable under this change.
- Apply the new 85/15 labour split only to eligible new bookings after an explicitly approved effective time.
- Preserve the existing 15% platform commission rule and its historical snapshots. Before implementation, trace whether that commission currently represents the same economic share or a separate fee. Do not double-charge, double-subtract, or silently replace one rule with the other.
- If the current commission is already the exact 15% withheld from labour, reconcile the accounting representation without charging an additional 15%. If it is a separate rule, obtain explicit business confirmation before combining them.

## Backend controls and test requirements

- Resolve one published rate version on the server at booking creation.
- Persist immutable customer amount, company share, electrician payable, rate-version, and calculation-policy snapshots atomically.
- Use integer paise; validate positive amounts and overflow.
- Enforce authenticated electrician ownership and booking assignment on every read.
- Test that pre-completion responses omit all pricing/accounting fields and never expose the rate catalogue.
- Test that completed-job responses include the correct three amounts only for that electrician's completed jobs, and exclude unrelated bookings and other rate tiers.
- Test nested objects, error/debug responses, refunded/reversed/unpaid states, customer-payment vs Admin-payout distinction, rounding, version consistency, payout totals, and legacy snapshot preservation.
- Test that Admin accounting can still reconcile gross, net, and company share.
- Do not modify or replay migrations until separately authorized.

## GPT-1 work

Electrician App must:
- Never display the rate catalogue or job price before completion.
- After completion, display the per-job customer-paid amount, company fee/share, and electrician earned/payable amount from the authorized completed-job DTO.
- Keep customer payment status distinct from Admin bank/UPI payout status.
- Avoid deriving financial figures from client-side guesses; render server-authoritative snapshots only.

## GPT-2 work

Own rate version resolution, server-side split calculation, immutable snapshots, stage-based API/RPC DTOs, grants/RLS review, accounting reconciliation, and backend regression tests. Coordinate exact field names and completion/payment state rules with GPT-1 before app integration.
