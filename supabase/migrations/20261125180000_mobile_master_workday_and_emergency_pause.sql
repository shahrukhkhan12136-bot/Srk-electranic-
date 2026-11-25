-- Mobile integration for the shared Master Technician workday ledger.
-- Feature branch only. Do not apply to Main/TEST without explicit approval.

ALTER TABLE public.srk_booking_technician_workdays
  DROP CONSTRAINT IF EXISTS srk_booking_technician_workdays_status_check;
ALTER TABLE public.srk_booking_technician_workdays
  ADD CONSTRAINT srk_booking_technician_workdays_status_check
  CHECK (status IN ('start_pending','start_rejected','running','paused','lunch_paused','emergency_paused','stopped'));

ALTER TABLE public.srk_booking_technician_workdays
  ADD COLUMN IF NOT EXISTS emergency_pause_reason text;
ALTER TABLE public.srk_booking_technician_workdays
  DROP CONSTRAINT IF EXISTS srk_booking_technician_workdays_emergency_pause_reason_check;
ALTER TABLE public.srk_booking_technician_workdays
  ADD CONSTRAINT srk_booking_technician_workdays_emergency_pause_reason_check
  CHECK (emergency_pause_reason IS NULL OR length(btrim(emergency_pause_reason)) BETWEEN 5 AND 500);

ALTER TABLE public.srk_booking_technician_work_events
  DROP CONSTRAINT IF EXISTS srk_booking_technician_work_events_event_type_check;
ALTER TABLE public.srk_booking_technician_work_events
  ADD CONSTRAINT srk_booking_technician_work_events_event_type_check
  CHECK (event_type IN (
    'start_requested','start_approved','start_rejected','paused','resumed',
    'lunch_auto_paused','lunch_auto_resumed','day_stopped',
    'customer_tomorrow_accepted','customer_completed','customer_technician_replaced',
    'emergency_paused','emergency_resumed'
  ));

CREATE OR REPLACE FUNCTION public.srk_technician_get_my_workdays(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_technician uuid; v_result jsonb; v_workday_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_technician FROM public.srk_technicians
   WHERE auth_user_id=v_uid AND account_status='active';
  IF v_technician IS NULL OR NOT EXISTS(
    SELECT 1 FROM public.srk_booking_technician_assignments a
     WHERE a.booking_id=p_booking_id AND a.technician_id=v_technician
       AND a.assignment_status IN ('accepted','active','completed')
  ) THEN RAISE EXCEPTION 'OWN_ACCEPTED_BOOKING_REQUIRED' USING ERRCODE='42501'; END IF;

  FOR v_workday_id IN SELECT w.id FROM public.srk_booking_technician_workdays w
    WHERE w.booking_id=p_booking_id AND w.technician_id=v_technician
      AND w.status IN ('running','lunch_paused')
  LOOP
    PERFORM srk_private.srk_normalize_technician_workday_lunch(v_workday_id);
  END LOOP;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'workday_id',w.id,'booking_id',w.booking_id,'work_date',w.work_date,'status',w.status,
    'start_requested_at',w.start_requested_at,'customer_approved_at',w.customer_approved_at,
    'elapsed_work_seconds',CASE
      WHEN w.status='running' THEN w.accumulated_work_seconds+
        greatest(extract(epoch FROM (clock_timestamp()-w.running_started_at)),0)
      WHEN w.status='lunch_paused' THEN 14400 ELSE w.accumulated_work_seconds END,
    'lunch_ends_at',w.lunch_ends_at,'emergency_pause_reason',w.emergency_pause_reason,
    'normal_work_seconds',w.normal_work_seconds,'overtime_work_seconds',w.overtime_work_seconds,
    'customer_decision',(SELECT d.decision FROM public.srk_booking_workday_customer_decisions d
      WHERE d.booking_id=w.booking_id AND d.work_date=w.work_date)
  ) ORDER BY w.work_date DESC),'[]'::jsonb)
  INTO v_result FROM public.srk_booking_technician_workdays w
  WHERE w.booking_id=p_booking_id AND w.technician_id=v_technician;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_get_my_workdays(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_get_my_workdays(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_emergency_pause_workday(
  p_workday_id uuid,p_reason text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_technician uuid; w public.srk_booking_technician_workdays%rowtype;
  v_elapsed numeric(20,3); v_reason text:=btrim(coalesce(p_reason,''));
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF length(v_reason) NOT BETWEEN 5 AND 500 THEN RAISE EXCEPTION 'EMERGENCY_REASON_REQUIRED' USING ERRCODE='22023'; END IF;
  SELECT id INTO v_technician FROM public.srk_technicians
   WHERE auth_user_id=v_uid AND account_status='active';
  SELECT * INTO w FROM public.srk_booking_technician_workdays
   WHERE id=p_workday_id AND technician_id=v_technician FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OWN_WORKDAY_REQUIRED' USING ERRCODE='42501'; END IF;
  PERFORM srk_private.srk_normalize_technician_workday_lunch(w.id);
  SELECT * INTO w FROM public.srk_booking_technician_workdays WHERE id=p_workday_id FOR UPDATE;
  IF w.status<>'running' THEN RAISE EXCEPTION 'RUNNING_WORKDAY_REQUIRED' USING ERRCODE='55000'; END IF;
  v_elapsed:=w.accumulated_work_seconds+
    greatest(extract(epoch FROM (clock_timestamp()-w.running_started_at)),0);
  UPDATE public.srk_booking_technician_workdays SET status='emergency_paused',
    accumulated_work_seconds=v_elapsed,running_started_at=NULL,
    emergency_pause_reason=v_reason,updated_at=clock_timestamp()
   WHERE id=w.id;
  INSERT INTO public.srk_booking_technician_work_events(
    workday_id,booking_id,technician_id,actor_user_id,event_type,event_data
  ) VALUES(w.id,w.booking_id,w.technician_id,v_uid,'emergency_paused',
    jsonb_build_object('reason',v_reason,'elapsed_seconds',v_elapsed));
  RETURN jsonb_build_object('success',true,'status','emergency_paused','elapsed_work_seconds',v_elapsed);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_emergency_pause_workday(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_emergency_pause_workday(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_resume_emergency_workday(
  p_workday_id uuid,p_note text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_technician uuid; w public.srk_booking_technician_workdays%rowtype;
  v_note text:=btrim(coalesce(p_note,''));
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF length(v_note) NOT BETWEEN 5 AND 500 THEN RAISE EXCEPTION 'EMERGENCY_RESUME_NOTE_REQUIRED' USING ERRCODE='22023'; END IF;
  SELECT id INTO v_technician FROM public.srk_technicians
   WHERE auth_user_id=v_uid AND account_status='active';
  SELECT * INTO w FROM public.srk_booking_technician_workdays
   WHERE id=p_workday_id AND technician_id=v_technician FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OWN_WORKDAY_REQUIRED' USING ERRCODE='42501'; END IF;
  IF w.status<>'emergency_paused' THEN RAISE EXCEPTION 'EMERGENCY_PAUSED_WORKDAY_REQUIRED' USING ERRCODE='55000'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.service_bookings b
    WHERE b.id=w.booking_id AND b.status='in_progress') THEN
    RAISE EXCEPTION 'BOOKING_NOT_ACTIVE' USING ERRCODE='55000';
  END IF;
  UPDATE public.srk_booking_technician_workdays SET status='running',
    running_started_at=clock_timestamp(),emergency_pause_reason=NULL,updated_at=clock_timestamp()
   WHERE id=w.id;
  INSERT INTO public.srk_booking_technician_work_events(
    workday_id,booking_id,technician_id,actor_user_id,event_type,event_data
  ) VALUES(w.id,w.booking_id,w.technician_id,v_uid,'emergency_resumed',
    jsonb_build_object('note',v_note));
  RETURN jsonb_build_object('success',true,'status','running');
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_resume_emergency_workday(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_resume_emergency_workday(uuid,text) TO authenticated;

COMMENT ON FUNCTION public.srk_technician_get_my_workdays(uuid) IS
  'Returns only the authenticated assigned Technician own workday records for a booking.';
COMMENT ON FUNCTION public.srk_technician_emergency_pause_workday(uuid,text) IS
  'Separate emergency stop from normal pause and automatic lunch; appends an immutable reason event.';
