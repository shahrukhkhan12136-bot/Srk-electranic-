-- Preserve the unrounded labour calculation in the final bill.
-- The customer-facing payable snapshot remains rounded to paise later.
begin;
alter table public.srk_final_bills
  alter column labour_amount type numeric(20,10)
  using labour_amount::numeric(20,10);
comment on column public.srk_final_bills.labour_amount is
  'Unrounded labour calculation retained to 10 decimal places; final payable total is rounded half-up to INR paise.';
commit;
