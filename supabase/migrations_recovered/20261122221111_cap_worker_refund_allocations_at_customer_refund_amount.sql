
CREATE OR REPLACE FUNCTION public.srk_admin_resolve_worker_refund_allocation(
  p_refund_request_id uuid,
  p_earning_id uuid,
  p_worker_refund_amount numeric,
  p_note text
) RETURNS public.srk_worker_refund_allocations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_refund public.srk_booking_refund_requests%rowtype;
  v_earning public.srk_worker_earnings%rowtype;
  v_alloc public.srk_worker_refund_allocations%rowtype;
  v_allocated numeric(12,2);
BEGIN
  IF auth.uid() IS NULL OR NOT public.srk_has_admin_permission('refunds.manage') THEN
    RAISE EXCEPTION 'Refund management permission required' USING ERRCODE='42501';
  END IF;
  IF p_refund_request_id IS NULL OR p_earning_id IS NULL
     OR p_worker_refund_amount IS NULL OR p_worker_refund_amount < 0
     OR p_note IS NULL OR length(btrim(p_note)) NOT BETWEEN 10 AND 2000 THEN
    RAISE EXCEPTION 'Valid refund, earning, non-negative amount and 10-2000 character note required'
      USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_refund
  FROM public.srk_booking_refund_requests
  WHERE id=p_refund_request_id AND status='processed'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Refund must be processed before worker allocation' USING ERRCODE='55000';
  END IF;

  SELECT * INTO v_earning
  FROM public.srk_worker_earnings
  WHERE id=p_earning_id AND booking_id=v_refund.booking_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Worker earning not found for this booking';
  END IF;
  IF p_worker_refund_amount > v_earning.net_earning THEN
    RAISE EXCEPTION 'Worker refund allocation exceeds net earning';
  END IF;

  SELECT coalesce(sum(worker_refund_amount),0)
  INTO v_allocated
  FROM public.srk_worker_refund_allocations
  WHERE refund_request_id=p_refund_request_id;

  IF v_allocated + p_worker_refund_amount > v_refund.amount THEN
    RAISE EXCEPTION 'Combined worker refund allocations cannot exceed the customer refund amount';
  END IF;

  INSERT INTO public.srk_worker_refund_allocations
    (refund_request_id,earning_id,worker_refund_amount,admin_note,created_by)
  VALUES
    (p_refund_request_id,p_earning_id,p_worker_refund_amount,btrim(p_note),auth.uid())
  RETURNING * INTO v_alloc;

  IF p_worker_refund_amount > 0 THEN
    INSERT INTO public.srk_worker_wallet_ledger
      (worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
    VALUES
      (v_earning.worker_id,v_earning.booking_id,v_earning.id,'refund_adjustment',
       p_worker_refund_amount,-p_worker_refund_amount,
       'Admin refund allocation: '||btrim(p_note),
       'worker-refund:'||p_refund_request_id::text||':'||p_earning_id::text)
    ON CONFLICT(idempotency_key) DO NOTHING;
  END IF;

  UPDATE public.srk_worker_earnings
  SET payout_status='pending',
      settlement_status=CASE
        WHEN p_worker_refund_amount>=net_earning THEN 'reversed'
        WHEN payment_method='cash' AND worker_role='technician' THEN 'cash_commission_due'
        WHEN payment_method='cash' AND worker_role='helper' THEN 'cash_split_pending'
        ELSE 'available'
      END,
      updated_at=clock_timestamp()
  WHERE id=p_earning_id;

  RETURN v_alloc;
END
$function$;
