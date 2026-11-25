CREATE OR REPLACE FUNCTION public.srk_admin_prepare_razorpay_refund(p_booking_id uuid,p_reason text)
RETURNS TABLE(refund_record_id uuid,booking_id uuid,payment_id text,amount_paise bigint,idempotency_key text,status text,previous_payout_note text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp
AS $function$
DECLARE
  v_booking public.service_bookings%rowtype;
  v_refund public.srk_razorpay_refunds%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_total numeric(12,2);
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 20 AND 250 THEN
    RAISE EXCEPTION 'Refund reason must be 20 to 250 characters';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
  IF v_booking.payment_status<>'paid' OR v_booking.payment_verified_at IS NULL
     OR v_booking.razorpay_payment_id IS NULL OR v_booking.amount_paid IS NULL
     OR v_booking.amount_paid<=0 OR v_booking.quote_status<>'approved' THEN
    RAISE EXCEPTION 'Only verified Razorpay-paid bookings can be refunded';
  END IF;
  IF v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$' THEN
    RAISE EXCEPTION 'Invalid Razorpay payment ID';
  END IF;
  v_total:=round(v_booking.amount_paid,2);
  IF v_booking.quoted_amount IS NULL OR v_booking.service_charge IS NULL OR v_booking.materials_amount IS NULL
     OR v_total<>round(v_booking.quoted_amount,2)
     OR v_total<>round(v_booking.service_charge+v_booking.materials_amount,2) THEN
    RAISE EXCEPTION 'Paid amount does not match approved quote';
  END IF;

  SELECT * INTO v_refund FROM public.srk_razorpay_refunds WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND THEN
    IF v_refund.status='failed' THEN RAISE EXCEPTION 'Previous Razorpay refund failed; reconcile before creating another request'; END IF;
    RETURN QUERY SELECT v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
    RETURN;
  END IF;

  SELECT * INTO v_payout FROM public.srk_electrician_payouts WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND THEN
    IF v_payout.payout_status='paid' THEN
      RAISE EXCEPTION 'Electrician payout is already paid; recovery requires separate Admin reconciliation';
    END IF;
    IF v_payout.payout_status<>'pending' THEN
      RAISE EXCEPTION 'Electrician payout is not pending; reconcile payout before refund';
    END IF;
    UPDATE public.srk_electrician_payouts
      SET payout_status='blocked',payout_note='Razorpay refund pending',updated_at=now()
      WHERE id=v_payout.id;
  END IF;

  INSERT INTO public.srk_razorpay_refunds
    (booking_id,payment_id,amount,amount_paise,idempotency_key,status,reason,admin_user_id,previous_payout_note)
  VALUES
    (p_booking_id,v_booking.razorpay_payment_id,v_total,round(v_total*100)::bigint,
     replace(gen_random_uuid()::text,'-',''), 'requested',btrim(p_reason),auth.uid(),v_payout.payout_note)
  RETURNING * INTO v_refund;
  RETURN QUERY SELECT v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_prepare_razorpay_refund(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_prepare_razorpay_refund(uuid,text) TO authenticated;