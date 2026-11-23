-- Complete the remaining FK-side indexes identified by the Supabase performance advisor.
-- These partial indexes omit NULL references where the column is nullable.
create index if not exists srk_razorpay_payment_orders_final_bill_id_idx
  on public.srk_razorpay_payment_orders(final_bill_id)
  where final_bill_id is not null;

create index if not exists srk_razorpay_settlement_recon_history_actor_idx
  on public.srk_razorpay_settlement_reconciliation_history(actor_user_id)
  where actor_user_id is not null;

create index if not exists srk_razorpay_settlements_recorded_by_idx
  on public.srk_razorpay_settlements(recorded_by)
  where recorded_by is not null;

create index if not exists srk_razorpay_settlements_verified_by_idx
  on public.srk_razorpay_settlements(verified_by)
  where verified_by is not null;

create index if not exists srk_worker_cash_commission_refund_allocations_earning_idx
  on public.srk_worker_cash_commission_refund_allocations(earning_id);

create index if not exists srk_worker_cash_commission_refund_allocations_worker_idx
  on public.srk_worker_cash_commission_refund_allocations(worker_id);

create index if not exists srk_worker_payout_earning_allocations_earning_idx
  on public.srk_worker_payout_earning_allocations(earning_id);
