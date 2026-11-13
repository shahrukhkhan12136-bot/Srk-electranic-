-- Atomic payment-order linking and captured-payment finalization.
-- This migration is feature-branch source only; do not apply to Production without approval.
CREATE SCHEMA IF NOT EXISTS srk_private;
REVOKE ALL ON SCHEMA srk_private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS srk_private.payment_order_locks (
  booking_id uuid PRIMARY KEY REFERENCES public.service_bookings(id) ON DELETE CASCADE,
  lock_token uuid NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON srk_private.payment_order_locks FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.srk_claim_payment_order_lock(p_booking_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE v_booking public.service_bookings%ROWTYPE; v_token uuid:=gen_random_uuid();
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role only' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
  IF v_booking.status<>'completed'
     OR lower(trim(coalesce(v_booking.payment_method,'')))<>'razorpay ऑनलाइन भुगतान'
     OR v_booking.payment_status NOT IN ('unpaid','pending')
     OR v_booking.payment_verified_at IS NOT NULL
     OR v_booking.razorpay_payment_id IS NOT NULL
     OR (v_booking.selected_category IS NOT NULL AND v_booking.completion_approval_status<>'approved')
     OR (v_booking.selected_category IS NULL AND v_booking.quote_status<>'approved') THEN
    RAISE EXCEPTION 'Booking is not eligible for an online payment order';
  END IF;
  INSERT INTO srk_private.payment_order_locks(booking_id,lock_token,expires_at)
  VALUES(p_booking_id,v_token,clock_timestamp()+interval '90 seconds')
  ON CONFLICT(booking_id) DO UPDATE
    SET lock_token=excluded.lock_token,expires_at=excluded.expires_at,created_at=clock_timestamp()
    WHERE srk_private.payment_order_locks.expires_at < clock_timestamp()
  RETURNING lock_token INTO v_token;
  IF v_token IS NULL THEN RETURN NULL; END IF;
  RETURN v_token;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_link_payment_order(
  p_booking_id uuid,p_lock_token uuid,p_razorpay_order_id text,p_amount_paise bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE v_booking public.service_bookings%ROWTYPE; v_bill public.srk_booking_labour_bills%ROWTYPE; v_expected bigint;
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role only' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL OR p_lock_token IS NULL
     OR p_razorpay_order_id !~ '^order_[A-Za-z0-9]+$'
     OR p_amount_paise IS NULL OR p_amount_paise<100 THEN
    RAISE EXCEPTION 'Invalid payment order details' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
  IF NOT EXISTS(SELECT 1 FROM srk_private.payment_order_locks
    WHERE booking_id=p_booking_id AND lock_token=p_lock_token AND expires_at>clock_timestamp()
    FOR UPDATE) THEN
    RAISE EXCEPTION 'Payment order lock expired or invalid' USING ERRCODE='42501';
  END IF;
  IF v_booking.status<>'completed'
     OR lower(trim(coalesce(v_booking.payment_method,'')))<>'razorpay ऑनलाइन भुगतान'
     OR v_booking.payment_status NOT IN ('unpaid','pending')
     OR v_booking.payment_verified_at IS NOT NULL
     OR v_booking.razorpay_payment_id IS NOT NULL
     OR (v_booking.selected_category IS NOT NULL AND v_booking.completion_approval_status<>'approved')
     OR (v_booking.selected_category IS NULL AND v_booking.quote_status<>'approved') THEN
    RAISE EXCEPTION 'Booking state changed; payment order cannot be linked';
  END IF;
  IF v_booking.selected_category IS NOT NULL THEN
    SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Final labour bill missing'; END IF;
    v_expected:=v_bill.labour_amount_paise;
  ELSE
    IF v_booking.service_charge IS NULL OR coalesce(v_booking.materials_amount,0)<0
       OR round(v_booking.quoted_amount,2)<>round(v_booking.service_charge+coalesce(v_booking.materials_amount,0),2) THEN
      RAISE EXCEPTION 'Legacy approved quote does not reconcile';
    END IF;
    v_expected:=round((v_booking.service_charge+coalesce(v_booking.materials_amount,0))*100)::bigint;
  END IF;
  IF v_expected<>p_amount_paise THEN RAISE EXCEPTION 'Order amount does not match approved bill'; END IF;
  UPDATE public.service_bookings
     SET razorpay_order_id=p_razorpay_order_id,payment_status='pending'
   WHERE id=p_booking_id;
  DELETE FROM srk_private.payment_order_locks WHERE booking_id=p_booking_id AND lock_token=p_lock_token;
  RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'razorpay_order_id',p_razorpay_order_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_release_payment_order_lock(p_booking_id uuid,p_lock_token uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role only' USING ERRCODE='42501';
  END IF;
  DELETE FROM srk_private.payment_order_locks
   WHERE booking_id=p_booking_id AND lock_token=p_lock_token;
  RETURN FOUND;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_service_finalize_captured_payment(
  p_booking_id uuid,p_razorpay_order_id text,p_razorpay_payment_id text,
  p_amount_paise bigint,p_currency text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE v_booking public.service_bookings%ROWTYPE; v_bill public.srk_booking_labour_bills%ROWTYPE; v_expected bigint;
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role only' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL OR p_razorpay_order_id IS NULL OR p_razorpay_order_id !~ '^order_[A-Za-z0-9]+
    RAISE EXCEPTION 'Invalid captured payment details' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE='P0002'; END IF;
  IF v_booking.razorpay_order_id IS DISTINCT FROM p_razorpay_order_id THEN
    RAISE EXCEPTION 'Payment order does not belong to this booking' USING ERRCODE='42501';
  END IF;
  IF v_booking.payment_status='paid' THEN
    IF v_booking.razorpay_payment_id=p_razorpay_payment_id THEN
      RETURN jsonb_build_object('success',true,'already_processed',true);
    END IF;
    RAISE EXCEPTION 'A different payment is already recorded' USING ERRCODE='23505';
  END IF;
  IF v_booking.status<>'completed'
     OR lower(trim(coalesce(v_booking.payment_method,'')))<>'razorpay ऑनलाइन भुगतान'
     OR v_booking.payment_status NOT IN ('unpaid','pending')
     OR v_booking.payment_verified_at IS NOT NULL
     OR v_booking.razorpay_payment_id IS NOT NULL
     OR (v_booking.selected_category IS NOT NULL AND v_booking.completion_approval_status<>'approved')
     OR (v_booking.selected_category IS NULL AND v_booking.quote_status<>'approved') THEN
    RAISE EXCEPTION 'Booking is not in a payable state';
  END IF;
  IF v_booking.selected_category IS NOT NULL THEN
    SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Final labour bill missing'; END IF;
    v_expected:=v_bill.labour_amount_paise;
  ELSE
    IF v_booking.service_charge IS NULL OR coalesce(v_booking.materials_amount,0)<0
       OR round(v_booking.quoted_amount,2)<>round(v_booking.service_charge+coalesce(v_booking.materials_amount,0),2) THEN
      RAISE EXCEPTION 'Legacy approved quote does not reconcile';
    END IF;
    v_expected:=round((v_booking.service_charge+coalesce(v_booking.materials_amount,0))*100)::bigint;
  END IF;
  IF v_expected<>p_amount_paise THEN RAISE EXCEPTION 'Captured amount does not match approved booking amount'; END IF;
  UPDATE public.service_bookings
     SET payment_status='paid',amount_paid=(p_amount_paise::numeric/100),
         razorpay_payment_id=p_razorpay_payment_id,payment_verified_at=clock_timestamp()
   WHERE id=p_booking_id;
  RETURN jsonb_build_object('success',true,'already_processed',false,'booking_id',p_booking_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_claim_payment_order_lock(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_link_payment_order(uuid,uuid,text,bigint) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_release_payment_order_lock(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_claim_payment_order_lock(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_link_payment_order(uuid,uuid,text,bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_release_payment_order_lock(uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text) TO service_role;

COMMENT ON FUNCTION public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text) IS
'Atomically locks and revalidates booking state, approved final bill/legacy quote, Razorpay order, currency and amount before recording a captured payment. Service-role only; idempotent for the same payment ID.';

     OR p_razorpay_payment_id IS NULL OR p_razorpay_payment_id !~ '^pay_[A-Za-z0-9]+
    RAISE EXCEPTION 'Invalid captured payment details' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE='P0002'; END IF;
  IF v_booking.razorpay_order_id IS DISTINCT FROM p_razorpay_order_id THEN
    RAISE EXCEPTION 'Payment order does not belong to this booking' USING ERRCODE='42501';
  END IF;
  IF v_booking.payment_status='paid' THEN
    IF v_booking.razorpay_payment_id=p_razorpay_payment_id THEN
      RETURN jsonb_build_object('success',true,'already_processed',true);
    END IF;
    RAISE EXCEPTION 'A different payment is already recorded' USING ERRCODE='23505';
  END IF;
  IF v_booking.status<>'completed'
     OR lower(trim(coalesce(v_booking.payment_method,'')))<>'razorpay ऑनलाइन भुगतान'
     OR v_booking.payment_status NOT IN ('unpaid','pending')
     OR v_booking.payment_verified_at IS NOT NULL
     OR v_booking.razorpay_payment_id IS NOT NULL
     OR (v_booking.selected_category IS NOT NULL AND v_booking.completion_approval_status<>'approved')
     OR (v_booking.selected_category IS NULL AND v_booking.quote_status<>'approved') THEN
    RAISE EXCEPTION 'Booking is not in a payable state';
  END IF;
  IF v_booking.selected_category IS NOT NULL THEN
    SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Final labour bill missing'; END IF;
    v_expected:=v_bill.labour_amount_paise;
  ELSE
    IF v_booking.service_charge IS NULL OR coalesce(v_booking.materials_amount,0)<0
       OR round(v_booking.quoted_amount,2)<>round(v_booking.service_charge+coalesce(v_booking.materials_amount,0),2) THEN
      RAISE EXCEPTION 'Legacy approved quote does not reconcile';
    END IF;
    v_expected:=round((v_booking.service_charge+coalesce(v_booking.materials_amount,0))*100)::bigint;
  END IF;
  IF v_expected<>p_amount_paise THEN RAISE EXCEPTION 'Captured amount does not match approved booking amount'; END IF;
  UPDATE public.service_bookings
     SET payment_status='paid',amount_paid=(p_amount_paise::numeric/100),
         razorpay_payment_id=p_razorpay_payment_id,payment_verified_at=clock_timestamp()
   WHERE id=p_booking_id;
  RETURN jsonb_build_object('success',true,'already_processed',false,'booking_id',p_booking_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_claim_payment_order_lock(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_link_payment_order(uuid,uuid,text,bigint) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_release_payment_order_lock(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_claim_payment_order_lock(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_link_payment_order(uuid,uuid,text,bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_release_payment_order_lock(uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text) TO service_role;

COMMENT ON FUNCTION public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text) IS
'Atomically locks and revalidates booking state, approved final bill/legacy quote, Razorpay order, currency and amount before recording a captured payment. Service-role only; idempotent for the same payment ID.';

     OR p_amount_paise IS NULL OR p_amount_paise<100 OR p_currency IS DISTINCT FROM 'INR' THEN
    RAISE EXCEPTION 'Invalid captured payment details' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE='P0002'; END IF;
  IF v_booking.razorpay_order_id IS DISTINCT FROM p_razorpay_order_id THEN
    RAISE EXCEPTION 'Payment order does not belong to this booking' USING ERRCODE='42501';
  END IF;
  IF v_booking.payment_status='paid' THEN
    IF v_booking.razorpay_payment_id=p_razorpay_payment_id THEN
      RETURN jsonb_build_object('success',true,'already_processed',true);
    END IF;
    RAISE EXCEPTION 'A different payment is already recorded' USING ERRCODE='23505';
  END IF;
  IF v_booking.status<>'completed'
     OR lower(trim(coalesce(v_booking.payment_method,'')))<>'razorpay ऑनलाइन भुगतान'
     OR v_booking.payment_status NOT IN ('unpaid','pending')
     OR v_booking.payment_verified_at IS NOT NULL
     OR v_booking.razorpay_payment_id IS NOT NULL
     OR (v_booking.selected_category IS NOT NULL AND v_booking.completion_approval_status<>'approved')
     OR (v_booking.selected_category IS NULL AND v_booking.quote_status<>'approved') THEN
    RAISE EXCEPTION 'Booking is not in a payable state';
  END IF;
  IF v_booking.selected_category IS NOT NULL THEN
    SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Final labour bill missing'; END IF;
    v_expected:=v_bill.labour_amount_paise;
  ELSE
    IF v_booking.service_charge IS NULL OR coalesce(v_booking.materials_amount,0)<0
       OR round(v_booking.quoted_amount,2)<>round(v_booking.service_charge+coalesce(v_booking.materials_amount,0),2) THEN
      RAISE EXCEPTION 'Legacy approved quote does not reconcile';
    END IF;
    v_expected:=round((v_booking.service_charge+coalesce(v_booking.materials_amount,0))*100)::bigint;
  END IF;
  IF v_expected<>p_amount_paise THEN RAISE EXCEPTION 'Captured amount does not match approved booking amount'; END IF;
  UPDATE public.service_bookings
     SET payment_status='paid',amount_paid=(p_amount_paise::numeric/100),
         razorpay_payment_id=p_razorpay_payment_id,payment_verified_at=clock_timestamp()
   WHERE id=p_booking_id;
  RETURN jsonb_build_object('success',true,'already_processed',false,'booking_id',p_booking_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_claim_payment_order_lock(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_link_payment_order(uuid,uuid,text,bigint) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_release_payment_order_lock(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_claim_payment_order_lock(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_link_payment_order(uuid,uuid,text,bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_release_payment_order_lock(uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text) TO service_role;

COMMENT ON FUNCTION public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text) IS
'Atomically locks and revalidates booking state, approved final bill/legacy quote, Razorpay order, currency and amount before recording a captured payment. Service-role only; idempotent for the same payment ID.';
