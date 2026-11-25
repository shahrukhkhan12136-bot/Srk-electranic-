
alter table public.srk_worker_refund_allocations
  add constraint srk_worker_refund_amount_two_decimals
  check (worker_refund_amount = round(worker_refund_amount,2)) not valid;
alter table public.srk_worker_refund_allocations
  validate constraint srk_worker_refund_amount_two_decimals;

alter table public.srk_company_commission_refund_reconciliations
  add constraint srk_company_commission_refund_two_decimals
  check (commission_refund_amount = round(commission_refund_amount,2)) not valid;
alter table public.srk_company_commission_refund_reconciliations
  validate constraint srk_company_commission_refund_two_decimals;
