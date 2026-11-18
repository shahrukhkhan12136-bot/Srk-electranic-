BEGIN;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.srk_payment_order_locks (
  booking_id uuid PRIMARY KEY REFERENCES public.service_bookings(id) ON DELETE CASCADE,
  lock_token uuid NOT NULL,
  claimed_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);
REVOKE ALL ON TABLE private.srk_payment_order_locks FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.srk_claim_payment_order_lock(p_booking_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','private','auth'
AS $function$
DECLARE
  v_token uuid := gen_random_uuid();
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_ONLY' USING errcode='42501';
  END IF;
  PERFORM 1 FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RETURN NULL; END IF;

  INSERT INTO private.srk_payment_order_locks(booking_id,lock_token,claimed_at,expires_at)
  VALUES(p_booking_id,v_token,now(),now()+interval '2 minutes')
  ON CONFLICT(booking_id) DO UPDATE
    SET lock_token=EXCLUDED.lock_token,claimed_at=EXCLUDED.claimed_at,expires_at=EXCLUDED.expires_at
    WHERE private.srk_payment_order_locks.expires_at <= now()
  RETURNING lock_token INTO v_token;

  RETURN v_token;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_release_payment_order_lock(
  p_booking_id uuid,
  p_lock_token uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','private','auth'
AS $function$
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_ONLY' USING errcode='42501';
  END IF;
  DELETE FROM private.srk_payment_order_locks
  WHERE booking_id=p_booking_id AND lock_token=p_lock_token;
  RETURN FOUND;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_service_role_link_payment_order(
  p_booking_id uuid,
  p_lock_token uuid,
  p_order_id text,
  p_amount_paise bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','private','auth'
AS $function$
DECLARE
  v_lock private.srk_payment_order_locks%rowtype;
  v_booking public.service_bookings%rowtype;
  v_breakdown jsonb;
  v_expected bigint;
  v_quote_total numeric;
BEGIN
  IF coalesce(auth.jwt()->>'role','') <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_ONLY' USING errcode='42501';
  END IF;
  IF p_order_id IS NULL OR p_order_id !~ '^order_[A-Za-z0-9]+$'
     OR p_amount_paise IS NULL OR p_amount_paise < 100 THEN
    RAISE EXCEPTION 'INVALID_ORDER_OR_AMOUNT';
  END IF;

  -- Keep the same row-lock order as the claim RPC (booking, then lock row)
  -- to avoid a claim/link deadlock under concurrent checkout requests.
  SELECT * INTO v_booking
  FROM public.service_bookings
  WHERE id=p_booking_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND'; END IF;

  SELECT * INTO v_lock
  FROM private.srk_payment_order_locks
  WHERE booking_id=p_booking_id
  FOR UPDATE;
  IF NOT FOUND OR v_lock.lock_token IS DISTINCT FROM p_lock_token
     OR v_lock.expires_at <= now() THEN
    RAISE EXCEPTION 'PAYMENT_ORDER_LOCK_INVALID_OR_EXPIRED';
  END IF;
  IF v_booking.status <> 'completed' THEN RAISE EXCEPTION 'BOOKING_NOT_COMPLETED'; END IF;
  IF v_booking.payment_status IN ('paid','refunded') THEN RAISE EXCEPTION 'BOOKING_ALREADY_PAID_OR_REFUNDED'; END IF;
  IF v_booking.payment_status NOT IN ('unpaid','pending') THEN RAISE EXCEPTION 'BOOKING_PAYMENT_STATE_NOT_PAYABLE'; END IF;
  IF lower(coalesce(v_booking.payment_method,'')) NOT LIKE '%razorpay%'
     AND lower(coalesce(v_booking.payment_method,'')) NOT LIKE '%online%' THEN
    RAISE EXCEPTION 'BOOKING_PAYMENT_METHOD_IS_NOT_ONLINE';
  END IF;
  IF v_booking.razorpay_order_id IS NOT NULL
     AND v_booking.razorpay_order_id <> p_order_id THEN
    RAISE EXCEPTION 'BOOKING_ALREADY_HAS_DIFFERENT_RAZORPAY_ORDER';
  END IF;

  IF v_booking.selected_category IS NOT NULL THEN
    v_breakdown := public.srk_service_role_get_booking_payment_breakdown(p_booking_id);
    v_expected := (v_breakdown->>'total_amount_paise')::bigint;
  ELSE
    IF v_booking.quote_status <> 'approved' THEN
      RAISE EXCEPTION 'APPROVED_QUOTE_REQUIRED';
    END IF;
    v_quote_total := coalesce(v_booking.service_charge,0)+coalesce(v_booking.materials_amount,0);
    IF v_quote_total <= 0
       OR round(v_quote_total*100) <> round(coalesce(v_booking.quoted_amount,0)*100) THEN
      RAISE EXCEPTION 'APPROVED_QUOTE_TOTAL_MISMATCH';
    END IF;
    v_expected := round(v_quote_total*100)::bigint;
  END IF;

  IF v_expected IS NULL OR v_expected <> p_amount_paise THEN
    RAISE EXCEPTION 'RAZORPAY_ORDER_AMOUNT_MISMATCH';
  END IF;

  UPDATE public.service_bookings
  SET razorpay_order_id=p_order_id,payment_status='pending'
  WHERE id=p_booking_id;

  RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'order_id',p_order_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_claim_payment_order_lock(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_claim_payment_order_lock(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.srk_release_payment_order_lock(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_release_payment_order_lock(uuid,uuid) TO service_role;
REVOKE ALL ON FUNCTION public.srk_service_role_link_payment_order(uuid,uuid,text,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_role_link_payment_order(uuid,uuid,text,bigint) TO service_role;

COMMIT;
