-- Require a complete, provider-net-backed bank verification before a settlement can be marked matched.
-- This protects the invariant even for service-role imports and future ingestion jobs.
alter table public.srk_razorpay_settlements
  add constraint srk_razorpay_settlement_matched_requires_bank_evidence
  check (
    reconciliation_status <> 'matched'
    or (
      settlement_status = 'processed'
      and provider_net_amount_paise is not null
      and bank_credit_amount_paise is not null
      and bank_credit_at is not null
      and length(trim(coalesce(bank_reference, ''))) >= 4
      and verified_by is not null
      and verified_at is not null
    )
  ) not valid;

alter table public.srk_razorpay_settlements
  validate constraint srk_razorpay_settlement_matched_requires_bank_evidence;
