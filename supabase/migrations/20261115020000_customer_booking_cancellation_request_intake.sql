-- Customer cancellation request intake and Admin review queue.
-- Phase 1 only: this migration does NOT cancel bookings, assess fees, or settle money.
-- Final Admin decision is intentionally gated until travel evidence and fee/payment
-- accounting dependencies are implemented together.

BEGIN;

CREATE TABLE IF NOT EXISTS public.srk_booking_cancellation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  customer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  idempotency_key uuid NOT NULL,
  customer_reason text NOT NULL CHECK (length(btrim(customer_reason)) BETWEEN 20 AND 1000),
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','in_review')),
  admin_note text CHECK (admin_note IS NULL OR length(btrim(admin_note)) BETWEEN 10 AND 2000),
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT srk_booking_cancellation_request_idempotency_uniq
    UNIQUE (customer_user_id,idempotency_key)
);

CREATE UNIQUE INDEX IF NOT EXISTS srk_booking_cancellation_one_open_per_booking
  ON public.srk_booking_cancellation_requests(booking_id)
  WHERE status IN ('requested','in_review');
CREATE INDEX IF NOT EXISTS srk_booking_cancellation_customer_created_idx
  ON public.srk_booking_cancellation_requests(customer_user_id,created_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS srk_booking_cancellation_status_created_idx
  ON public.srk_booking_cancellation_requests(status,created_at ASC,id ASC);

ALTER TABLE public.srk_booking_cancellation_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_booking_cancellation_requests FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS public.srk_booking_cancellation_request_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id uuid NOT NULL REFERENCES public.srk_booking_cancellation_requests(id) ON DELETE RESTRICT,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  actor_user_id uuid,
  actor_role text NOT NULL CHECK (actor_role IN ('customer','admin')),
  event_type text NOT NULL CHECK (event_type IN ('requested','review_started')),
  old_status text,
  new_status text NOT NULL CHECK (new_status IN ('requested','in_review')),
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 10 AND 2000),
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS srk_booking_cancellation_events_request_idx
  ON public.srk_booking_cancellation_request_events(request_id,occurred_at,id);
ALTER TABLE public.srk_booking_cancellation_request_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_booking_cancellation_request_events FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_guard_immutable_booking_cancellation_request_event()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'Cancellation request events are append-only'
    USING ERRCODE='42501';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_immutable_booking_cancellation_request_event() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_guard_immutable_booking_cancellation_request_event
  ON public.srk_booking_cancellation_request_events;
CREATE TRIGGER srk_guard_immutable_booking_cancellation_request_event
  BEFORE UPDATE OR DELETE ON public.srk_booking_cancellation_request_events
  FOR EACH ROW EXECUTE FUNCTION public.srk_guard_immutable_booking_cancellation_request_event();

CREATE OR REPLACE FUNCTION public.srk_customer_request_booking_cancellation(
  p_booking_id uuid,
  p_reason text,
  p_idempotency_key uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_booking public.service_bookings%ROWTYPE;
  v_existing public.srk_booking_cancellation_requests%ROWTYPE;
  v_request public.srk_booking_cancellation_requests%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000';
  END IF;
  IF p_booking_id IS NULL OR p_idempotency_key IS NULL
     OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 20 AND 1000 THEN
    RAISE EXCEPTION 'INVALID_CANCELLATION_REQUEST' USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_existing
    FROM public.srk_booking_cancellation_requests
   WHERE customer_user_id=v_uid AND idempotency_key=p_idempotency_key;
  IF FOUND THEN
    IF v_existing.booking_id<>p_booking_id THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_FOR_ANOTHER_BOOKING' USING ERRCODE='23505';
    END IF;
    RETURN jsonb_build_object(
      'success',true,'request_id',v_existing.id,'booking_id',v_existing.booking_id,
      'status',v_existing.status,'replayed',true
    );
  END IF;

  SELECT * INTO v_booking
    FROM public.service_bookings
   WHERE id=p_booking_id AND customer_user_id=v_uid
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND_OR_NOT_OWNED' USING ERRCODE='42501';
  END IF;

  -- Recheck the idempotency key after acquiring the booking lock. Concurrent
  -- requests with the same key must converge on the first committed request.
  SELECT * INTO v_existing
    FROM public.srk_booking_cancellation_requests
   WHERE customer_user_id=v_uid AND idempotency_key=p_idempotency_key;
  IF FOUND THEN
    IF v_existing.booking_id<>p_booking_id THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_FOR_ANOTHER_BOOKING' USING ERRCODE='23505';
    END IF;
    RETURN jsonb_build_object(
      'success',true,'request_id',v_existing.id,'booking_id',v_existing.booking_id,
      'status',v_existing.status,'replayed',true
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.srk_booking_cancellation_requests
     WHERE booking_id=p_booking_id AND status IN ('requested','in_review')
  ) THEN
    RAISE EXCEPTION 'CANCELLATION_REQUEST_ALREADY_OPEN' USING ERRCODE='23505';
  END IF;

  -- Only early, unpaid booking states are accepted in this first safe phase.
  -- Work, completion, payment, refund and legacy states require separate reconciliation.
  IF v_booking.status NOT IN ('new','confirmed','assigned')
     OR COALESCE(v_booking.payment_status,'unpaid')<>'unpaid'
     OR COALESCE(v_booking.work_timer_running,false) IS TRUE
     OR COALESCE(v_booking.work_timer_elapsed_seconds,0)>0
     OR EXISTS (
       SELECT 1 FROM public.srk_booking_labour_bills lb
        WHERE lb.booking_id=p_booking_id
     ) THEN
    RAISE EXCEPTION 'BOOKING_STATE_REQUIRES_ADMIN_RECONCILIATION' USING ERRCODE='55000';
  END IF;

  INSERT INTO public.srk_booking_cancellation_requests(
    booking_id,customer_user_id,idempotency_key,customer_reason
  ) VALUES (
    p_booking_id,v_uid,p_idempotency_key,btrim(p_reason)
  ) RETURNING * INTO v_request;

  INSERT INTO public.srk_booking_cancellation_request_events(
    request_id,booking_id,actor_user_id,actor_role,event_type,
    old_status,new_status,reason
  ) VALUES (
    v_request.id,p_booking_id,v_uid,'customer','requested',
    NULL,'requested',btrim(p_reason)
  );

  RETURN jsonb_build_object(
    'success',true,'request_id',v_request.id,'booking_id',p_booking_id,
    'status',v_request.status,'replayed',false
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_list_my_booking_cancellation_requests(
  p_limit integer DEFAULT 25,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  request_id uuid,booking_id uuid,customer_reason text,status text,
  admin_note text,created_at timestamptz,updated_at timestamptz,reviewed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000';
  END IF;
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
     OR p_offset IS NULL OR p_offset<0 THEN
    RAISE EXCEPTION 'INVALID_PAGE' USING ERRCODE='22023';
  END IF;
  RETURN QUERY
  SELECT r.id,r.booking_id,r.customer_reason,r.status,r.admin_note,
         r.created_at,r.updated_at,r.reviewed_at
    FROM public.srk_booking_cancellation_requests r
   WHERE r.customer_user_id=auth.uid()
   ORDER BY r.created_at DESC,r.id DESC
   LIMIT p_limit OFFSET p_offset;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_list_booking_cancellation_requests()
RETURNS TABLE(
  request_id uuid,booking_id uuid,customer_user_id uuid,customer_name text,
  customer_phone text,service_type text,booking_status text,payment_status text,
  preferred_date date,preferred_time text,customer_reason text,request_status text,
  admin_note text,created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT r.id,r.booking_id,r.customer_user_id,b.customer_name::text,b.phone::text,
         b.service_type::text,b.status::text,b.payment_status::text,
         b.preferred_date,b.preferred_time::text,r.customer_reason,r.status,
         r.admin_note,r.created_at
    FROM public.srk_booking_cancellation_requests r
    JOIN public.service_bookings b ON b.id=r.booking_id
   WHERE r.status IN ('requested','in_review')
   ORDER BY CASE r.status WHEN 'requested' THEN 0 ELSE 1 END,r.created_at ASC,r.id ASC
   LIMIT 300;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_start_booking_cancellation_review(
  p_request_id uuid,
  p_admin_note text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_request public.srk_booking_cancellation_requests%ROWTYPE;
  v_booking public.service_bookings%ROWTYPE;
  v_note text:=btrim(coalesce(p_admin_note,''));
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_request_id IS NULL OR length(v_note) NOT BETWEEN 10 AND 2000 THEN
    RAISE EXCEPTION 'ADMIN_REVIEW_NOTE_REQUIRED' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_request FROM public.srk_booking_cancellation_requests
   WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CANCELLATION_REQUEST_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  IF v_request.status='in_review' THEN
    RETURN jsonb_build_object('success',true,'request_id',v_request.id,'status','in_review','replayed',true);
  END IF;
  IF v_request.status<>'requested' THEN
    RAISE EXCEPTION 'INVALID_CANCELLATION_REVIEW_TRANSITION' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=v_request.booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE='P0002'; END IF;

  UPDATE public.srk_booking_cancellation_requests
     SET status='in_review',admin_note=v_note,reviewed_by=auth.uid(),
         reviewed_at=clock_timestamp(),updated_at=clock_timestamp()
   WHERE id=v_request.id;

  INSERT INTO public.srk_booking_cancellation_request_events(
    request_id,booking_id,actor_user_id,actor_role,event_type,
    old_status,new_status,reason
  ) VALUES (
    v_request.id,v_request.booking_id,auth.uid(),'admin','review_started',
    'requested','in_review',v_note
  );
  RETURN jsonb_build_object('success',true,'request_id',v_request.id,'status','in_review','replayed',false);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_customer_request_booking_cancellation(uuid,text,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_customer_list_my_booking_cancellation_requests(integer,integer) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_admin_list_booking_cancellation_requests() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_admin_start_booking_cancellation_review(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_request_booking_cancellation(uuid,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_customer_list_my_booking_cancellation_requests(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_booking_cancellation_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_admin_start_booking_cancellation_review(uuid,text) TO authenticated;

COMMENT ON TABLE public.srk_booking_cancellation_requests IS
  'Customer cancellation requests only. Phase 1 never cancels bookings or assesses/settles cancellation fees.';
COMMENT ON TABLE public.srk_booking_cancellation_request_events IS
  'Append-only audit events for customer cancellation request intake and Admin review start.';

COMMIT;
