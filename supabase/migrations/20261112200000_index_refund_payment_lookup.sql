-- Non-unique lookup index: webhook reconciliation intentionally detects
-- multiple refund rows for one provider payment and refuses ambiguous matching.
create index if not exists srk_razorpay_refunds_payment_id_idx
  on public.srk_razorpay_refunds (payment_id);
