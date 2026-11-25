alter table public.srk_worker_profiles
 alter column payout_details_change_status set default 'pending';

alter table public.srk_worker_profiles
 add constraint srk_worker_payout_details_approval_requires_review
 check (
  payout_details_change_status<>'approved'
  or (
   payout_details_reviewed_by is not null
   and payout_details_reviewed_at is not null
   and (nullif(btrim(upi_id),'') is not null or nullif(btrim(bank_account_last4),'') is not null)
  )
 );