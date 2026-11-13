-- Durable Razorpay refund provider execution and recovery.
-- Provider response is persisted before booking/ledger reconciliation.
BEGIN;

CREATE TABLE IF NOT EXISTS public.srk_razorpay_refund_events (
  event_id text PRIMARY KEY,
  event_name text NOT NULL,
  refund_id text,
  payment_id text,
  payload jsonb NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  reconciled_at timestamptz,
  reconciliation_error text,
  CONSTRAINT srk_refund_event_id_nonempty CHECK (length(event_id) BETWEEN 1 AND 200)
);
CREATE INDEX IF NOT EXISTS srk_refund_events_refund_received_idx
  ON public.srk_razorpay_refund_events(refund_id,received_at DESC);
ALTER TABLE public.srk_razorpay_refund_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_razorpay_refund_events FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_claim_razorpay_refund(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_req public.srk_booking_refund_requests%ROWTYPE;
  v_ref public.srk_razorpay_refunds%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_req FROM public.srk_booking_refund_requests
   WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND OR v_req.status NOT IN ('approved','processing','unknown') OR v_req.refund_record_id IS NULL THEN
    RAISE EXCEPTION 'APPROVED_PREPARED_REFUND_REQUIRED' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_ref FROM public.srk_razorpay_refunds
   WHERE id=v_req.refund_record_id AND booking_id=v_req.booking_id FOR UPDATE;
  IF NOT FOUND OR v_ref.status NOT IN ('requested','processing','unknown') THEN
    RAISE EXCEPTION 'REFUND_NOT_EXECUTABLE_OR_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  UPDATE public.srk_razorpay_refunds
     SET status='processing',updated_at=clock_timestamp(),last_error=NULL
   WHERE id=v_ref.id RETURNING * INTO v_ref;
  UPDATE public.srk_booking_refund_requests
     SET status='processing',updated_at=clock_timestamp()
   WHERE id=v_req.id;
  RETURN jsonb_build_object(
    'success',true,'refund_record_id',v_ref.id,'booking_id',v_ref.booking_id,
    'payment_id',v_ref.payment_id,'amount_paise',v_ref.amount_paise,
    'idempotency_key',v_ref.idempotency_key,'refund_id',v_ref.refund_id,
    'provider_status',v_ref.provider_status,'status',v_ref.status
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_service_record_razorpay_refund_result(
  p_refund_record_id uuid,p_provider_refund_id text,p_provider_status text,p_error text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_ref public.srk_razorpay_refunds%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_ref FROM public.srk_razorpay_refunds
   WHERE id=p_refund_record_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'REFUND_RECORD_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  IF p_provider_refund_id IS NOT NULL AND p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$' THEN
    RAISE EXCEPTION 'INVALID_PROVIDER_REFUND_ID' USING ERRCODE='22023';
  END IF;
  IF p_provider_status IS NOT NULL AND p_provider_status NOT IN ('pending','processed','failed') THEN
    RAISE EXCEPTION 'INVALID_PROVIDER_REFUND_STATUS' USING ERRCODE='22023';
  END IF;
  IF v_ref.refund_id IS NOT NULL AND p_provider_refund_id IS NOT NULL
     AND v_ref.refund_id<>p_provider_refund_id THEN
    RAISE EXCEPTION 'PROVIDER_REFUND_ID_CONFLICT' USING ERRCODE='55000';
  END IF;
  UPDATE public.srk_razorpay_refunds
     SET refund_id=coalesce(p_provider_refund_id,refund_id),
         provider_status=coalesce(p_provider_status,provider_status),
         status=CASE WHEN p_provider_status='failed' THEN 'failed' ELSE 'processing' END,
         last_error=left(nullif(p_error,''),500),
         updated_at=clock_timestamp()
   WHERE id=v_ref.id;
  RETURN jsonb_build_object('success',true,'refund_record_id',v_ref.id,
    'refund_id',coalesce(p_provider_refund_id,v_ref.refund_id),
    'provider_status',coalesce(p_provider_status,v_ref.provider_status),
    'internal_status',CASE WHEN p_provider_status='failed' THEN 'failed' ELSE 'processing' END);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_service_finalize_razorpay_refund(p_refund_record_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_ref public.srk_razorpay_refunds%ROWTYPE;
  v_booking public.service_bookings%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_ref FROM public.srk_razorpay_refunds
   WHERE id=p_refund_record_id FOR UPDATE;
  IF NOT FOUND OR v_ref.refund_id IS NULL OR v_ref.provider_status<>'processed'
     OR v_ref.status NOT IN ('processing','unknown','processed') THEN
    RAISE EXCEPTION 'PROVIDER_CONFIRMED_PROCESSED_REFUND_REQUIRED' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=v_ref.booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.razorpay_payment_id IS DISTINCT FROM v_ref.payment_id
     OR v_booking.payment_status NOT IN ('paid','refunded')
     OR round(coalesce(v_booking.amount_paid,0)*100)::bigint<>v_ref.amount_paise THEN
    RAISE EXCEPTION 'BOOKING_PAYMENT_NO_LONGER_MATCHES_REFUND' USING ERRCODE='55000';
  END IF;
  IF v_booking.payment_status<>'refunded' THEN
    UPDATE public.service_bookings SET payment_status='refunded'
     WHERE id=v_booking.id;
  END IF;
  UPDATE public.srk_razorpay_refunds
     SET status='processed',processed_at=coalesce(processed_at,clock_timestamp()),
         updated_at=clock_timestamp(),last_error=NULL
   WHERE id=v_ref.id;
  UPDATE public.srk_booking_refund_requests
     SET status='processed',processed_at=coalesce(processed_at,clock_timestamp()),
         updated_at=clock_timestamp()
   WHERE booking_id=v_ref.booking_id AND refund_record_id=v_ref.id;
  RETURN jsonb_build_object('success',true,'booking_id',v_booking.id,
    'refund_record_id',v_ref.id,'status','processed');
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_service_capture_razorpay_refund_event(
  p_event_id text,p_event_name text,p_refund_id text,p_payment_id text,p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_inserted integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_event_id IS NULL OR length(p_event_id) NOT BETWEEN 1 AND 200
     OR p_event_name NOT IN ('refund.processed','refund.failed','refund.created')
     OR p_refund_id !~ '^rfnd_[A-Za-z0-9]+$'
     OR p_payment_id !~ '^pay_[A-Za-z0-9]+$'
     OR p_payload IS NULL THEN
    RAISE EXCEPTION 'INVALID_REFUND_EVENT' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.srk_razorpay_refund_events(event_id,event_name,refund_id,payment_id,payload)
  VALUES(p_event_id,p_event_name,p_refund_id,p_payment_id,p_payload)
  ON CONFLICT(event_id) DO NOTHING;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN jsonb_build_object('success',true,'duplicate',v_inserted=0);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_claim_razorpay_refund(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_claim_razorpay_refund(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_service_record_razorpay_refund_result(uuid,text,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_service_finalize_razorpay_refund(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_service_capture_razorpay_refund_event(text,text,text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_record_razorpay_refund_result(uuid,text,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_service_finalize_razorpay_refund(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_service_capture_razorpay_refund_event(text,text,text,text,jsonb) TO service_role;

COMMIT;
