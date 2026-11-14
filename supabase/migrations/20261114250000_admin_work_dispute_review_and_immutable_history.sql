-- Admin-only review of customer completion disputes and append-only work lifecycle history.
-- Source-only migration; do not apply to a live project without explicit approval.

CREATE TABLE IF NOT EXISTS public.srk_booking_work_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  actor_user_id uuid,
  event_type text NOT NULL,
  old_state jsonb,
  new_state jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT srk_booking_work_events_type_check CHECK (
    event_type IN ('work_start_requested','work_start_approved','work_start_rejected',
      'work_completion_requested','work_completion_approved','work_completion_rejected',
      'work_completion_disputed','timer_state_changed','work_status_changed')
  )
);
CREATE INDEX IF NOT EXISTS srk_booking_work_events_booking_created_idx
  ON public.srk_booking_work_events(booking_id,created_at,id);
ALTER TABLE public.srk_booking_work_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_booking_work_events FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_capture_booking_work_event()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_type text;
BEGIN
  v_old := CASE WHEN TG_OP='INSERT' THEN NULL ELSE jsonb_build_object(
    'status',OLD.status,'work_start_approval_status',OLD.work_start_approval_status,
    'completion_approval_status',OLD.completion_approval_status,
    'work_timer_elapsed_seconds',OLD.work_timer_elapsed_seconds,
    'work_timer_running',OLD.work_timer_running,'work_started_at',OLD.work_started_at,
    'completion_requested_at',OLD.completion_requested_at) END;
  v_new := jsonb_build_object(
    'status',NEW.status,'work_start_approval_status',NEW.work_start_approval_status,
    'completion_approval_status',NEW.completion_approval_status,
    'work_timer_elapsed_seconds',NEW.work_timer_elapsed_seconds,
    'work_timer_running',NEW.work_timer_running,'work_started_at',NEW.work_started_at,
    'completion_requested_at',NEW.completion_requested_at);
  IF TG_OP='UPDATE' AND v_old=v_new THEN RETURN NEW; END IF;
  v_type := CASE
    WHEN NEW.completion_approval_status='disputed' AND (TG_OP='INSERT' OR OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status) THEN 'work_completion_disputed'
    WHEN NEW.completion_approval_status='approved' AND (TG_OP='INSERT' OR OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status) THEN 'work_completion_approved'
    WHEN NEW.completion_approval_status='rejected' AND (TG_OP='INSERT' OR OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status) THEN 'work_completion_rejected'
    WHEN NEW.completion_approval_status='pending' AND (TG_OP='INSERT' OR OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status) THEN 'work_completion_requested'
    WHEN NEW.work_start_approval_status='approved' AND (TG_OP='INSERT' OR OLD.work_start_approval_status IS DISTINCT FROM NEW.work_start_approval_status) THEN 'work_start_approved'
    WHEN NEW.work_start_approval_status='rejected' AND (TG_OP='INSERT' OR OLD.work_start_approval_status IS DISTINCT FROM NEW.work_start_approval_status) THEN 'work_start_rejected'
    WHEN NEW.work_start_approval_status='pending' AND (TG_OP='INSERT' OR OLD.work_start_approval_status IS DISTINCT FROM NEW.work_start_approval_status) THEN 'work_start_requested'
    WHEN NEW.status IS DISTINCT FROM CASE WHEN TG_OP='INSERT' THEN NULL ELSE OLD.status END THEN 'work_status_changed'
    ELSE 'timer_state_changed' END;
  INSERT INTO public.srk_booking_work_events(booking_id,actor_user_id,event_type,old_state,new_state)
  VALUES(NEW.id,auth.uid(),v_type,v_old,v_new);
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS srk_capture_booking_work_event ON public.service_bookings;
CREATE TRIGGER srk_capture_booking_work_event
AFTER INSERT OR UPDATE OF status,work_start_approval_status,completion_approval_status,
  work_timer_elapsed_seconds,work_timer_running,work_started_at,completion_requested_at
ON public.service_bookings
FOR EACH ROW EXECUTE FUNCTION public.srk_capture_booking_work_event();

CREATE OR REPLACE FUNCTION public.srk_admin_get_booking_work_review(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_events jsonb;
  v_bill jsonb;
  v_complaints jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL THEN RAISE EXCEPTION 'BOOKING_ID_REQUIRED' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE='22023'; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.created_at,e.id),'[]'::jsonb)
    INTO v_events FROM public.srk_booking_work_events e WHERE e.booking_id=p_booking_id;
  SELECT to_jsonb(b) INTO v_bill FROM public.srk_booking_labour_bills b WHERE b.booking_id=p_booking_id;

  IF to_regclass('public.srk_booking_complaints') IS NOT NULL THEN
    EXECUTE 'SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY c.created_at,c.id),''[]''::jsonb)
      FROM public.srk_booking_complaints c WHERE c.booking_id=$1'
      INTO v_complaints USING p_booking_id;
  END IF;

  RETURN jsonb_build_object(
    'booking',jsonb_build_object('id',v_booking.id,'customer_name',v_booking.customer_name,
      'service_type',v_booking.service_type,'selected_category',v_booking.selected_category,
      'selected_duration_hours',v_booking.selected_duration_hours,'selected_rate_tier',v_booking.selected_rate_tier,
      'status',v_booking.status,'work_start_approval_status',v_booking.work_start_approval_status,
      'completion_approval_status',v_booking.completion_approval_status,
      'work_timer_elapsed_seconds',v_booking.work_timer_elapsed_seconds,
      'work_timer_running',v_booking.work_timer_running,'work_started_at',v_booking.work_started_at,
      'completion_requested_at',v_booking.completion_requested_at,
      'customer_completed_at',v_booking.customer_completed_at),
    'events',v_events,'labour_bill',v_bill,'complaints',v_complaints);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_get_booking_work_review(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_get_booking_work_review(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_capture_booking_work_event() FROM PUBLIC,anon,authenticated;
