-- Shared Technician, customer-approved daily work timer.
-- Feature Branch source only. Do not apply to TEST or Production without separate approval.
-- Each assigned Technician has an independent daily record; historical Electrician timer rows remain untouched.

CREATE TABLE IF NOT EXISTS public.srk_booking_technician_workdays (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  work_date date NOT NULL DEFAULT ((clock_timestamp() AT TIME ZONE 'Asia/Kolkata')::date),
  status text NOT NULL DEFAULT 'start_pending'
    CHECK (status IN ('start_pending','start_rejected','running','paused','lunch_paused','stopped')),
  start_requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  customer_approved_at timestamptz,
  running_started_at timestamptz,
  accumulated_work_seconds numeric(20,3) NOT NULL DEFAULT 0 CHECK (accumulated_work_seconds>=0),
  lunch_started_at timestamptz,
  lunch_ends_at timestamptz,
  lunch_break_taken boolean NOT NULL DEFAULT false,
  technician_hourly_paise_snapshot bigint NOT NULL CHECK (technician_hourly_paise_snapshot>0),
  rate_version_snapshot text NOT NULL,
  stopped_at timestamptz,
  normal_work_seconds numeric(20,3),
  overtime_work_seconds numeric(20,3),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(booking_id,technician_id,work_date),
  CHECK ((status='running' AND running_started_at IS NOT NULL)
      OR (status<>'running' AND running_started_at IS NULL)),
  CHECK ((status='lunch_paused' AND lunch_started_at IS NOT NULL AND lunch_ends_at IS NOT NULL)
      OR (status<>'lunch_paused')),
  CHECK ((status='stopped' AND stopped_at IS NOT NULL
      AND normal_work_seconds IS NOT NULL AND overtime_work_seconds IS NOT NULL)
      OR (status<>'stopped'))
);
CREATE INDEX IF NOT EXISTS srk_booking_technician_workdays_booking_date_idx
  ON public.srk_booking_technician_workdays(booking_id,work_date,technician_id);
CREATE INDEX IF NOT EXISTS srk_booking_technician_workdays_technician_recent_idx
  ON public.srk_booking_technician_workdays(technician_id,work_date DESC);

CREATE TABLE IF NOT EXISTS public.srk_booking_technician_work_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workday_id uuid NOT NULL REFERENCES public.srk_booking_technician_workdays(id) ON DELETE RESTRICT,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_type text NOT NULL CHECK (event_type IN (
    'start_requested','start_approved','start_rejected','paused','resumed',
    'lunch_auto_paused','lunch_auto_resumed','day_stopped',
    'customer_tomorrow_accepted','customer_completed','customer_technician_replaced'
  )),
  event_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS srk_booking_technician_work_events_recent_idx
  ON public.srk_booking_technician_work_events(workday_id,created_at DESC,id DESC);

CREATE TABLE IF NOT EXISTS public.srk_booking_technician_labour_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  workday_id uuid NOT NULL UNIQUE REFERENCES public.srk_booking_technician_workdays(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  work_date date NOT NULL,
  technician_hourly_paise_snapshot bigint NOT NULL CHECK (technician_hourly_paise_snapshot>0),
  normal_work_seconds numeric(20,3) NOT NULL CHECK (normal_work_seconds>=0),
  overtime_work_seconds numeric(20,3) NOT NULL CHECK (overtime_work_seconds>=0),
  normal_amount_paise bigint NOT NULL CHECK (normal_amount_paise>=0),
  overtime_amount_paise bigint NOT NULL CHECK (overtime_amount_paise>=0),
  total_labour_paise bigint NOT NULL CHECK (total_labour_paise=normal_amount_paise+overtime_amount_paise),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(booking_id,technician_id,work_date)
);
CREATE INDEX IF NOT EXISTS srk_booking_technician_labour_ledger_booking_idx
  ON public.srk_booking_technician_labour_ledger(booking_id,work_date,technician_id);

CREATE TABLE IF NOT EXISTS public.srk_booking_workday_customer_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  work_date date NOT NULL,
  customer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  decision text NOT NULL CHECK (decision IN ('tomorrow','completed','replace_technician')),
  replaced_technician_id uuid REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(booking_id,work_date),
  CHECK ((decision='replace_technician' AND replaced_technician_id IS NOT NULL)
      OR (decision<>'replace_technician' AND replaced_technician_id IS NULL))
);

ALTER TABLE public.srk_booking_technician_workdays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_booking_technician_work_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_booking_technician_labour_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_booking_workday_customer_decisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_booking_technician_workdays,
  public.srk_booking_technician_work_events,public.srk_booking_technician_labour_ledger,
  public.srk_booking_workday_customer_decisions FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE public.srk_booking_technician_workdays,
  public.srk_booking_technician_work_events,public.srk_booking_technician_labour_ledger,
  public.srk_booking_workday_customer_decisions TO service_role;

CREATE OR REPLACE FUNCTION public.srk_guard_technician_work_event_append_only()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  RAISE EXCEPTION 'TECHNICIAN_WORK_EVENTS_ARE_APPEND_ONLY' USING ERRCODE='55000';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_technician_work_event_append_only() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_booking_technician_work_events_append_only
  ON public.srk_booking_technician_work_events;
CREATE TRIGGER srk_booking_technician_work_events_append_only
BEFORE UPDATE OR DELETE ON public.srk_booking_technician_work_events
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_technician_work_event_append_only();

CREATE OR REPLACE FUNCTION public.srk_guard_technician_labour_ledger_immutable()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  RAISE EXCEPTION 'TECHNICIAN_LABOUR_LEDGER_IS_IMMUTABLE' USING ERRCODE='55000';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_technician_labour_ledger_immutable() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_booking_technician_labour_ledger_immutable
  ON public.srk_booking_technician_labour_ledger;
CREATE TRIGGER srk_booking_technician_labour_ledger_immutable
BEFORE UPDATE OR DELETE ON public.srk_booking_technician_labour_ledger
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_technician_labour_ledger_immutable();

CREATE OR REPLACE FUNCTION srk_private.srk_normalize_technician_workday_lunch(p_workday_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE w public.srk_booking_technician_workdays%rowtype;
  v_elapsed numeric(20,3); v_lunch_start timestamptz; v_lunch_end timestamptz;
BEGIN
  SELECT * INTO w FROM public.srk_booking_technician_workdays WHERE id=p_workday_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF w.status='lunch_paused' AND clock_timestamp()>=w.lunch_ends_at THEN
    UPDATE public.srk_booking_technician_workdays SET status='running',
      running_started_at=lunch_ends_at,lunch_break_taken=true,updated_at=clock_timestamp()
    WHERE id=p_workday_id;
    INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,event_type,event_data)
    VALUES(w.id,w.booking_id,w.technician_id,'lunch_auto_resumed',
      jsonb_build_object('resumed_at',w.lunch_ends_at));
    RETURN;
  END IF;
  IF w.status<>'running' OR w.lunch_break_taken THEN RETURN; END IF;
  v_elapsed:=w.accumulated_work_seconds+
    greatest(extract(epoch FROM (clock_timestamp()-w.running_started_at)),0);
  IF v_elapsed<14400 THEN RETURN; END IF;
  v_lunch_start:=w.running_started_at+
    make_interval(secs=>greatest(14400-w.accumulated_work_seconds,0)::double precision);
  v_lunch_end:=v_lunch_start+interval '1 hour';
  IF clock_timestamp()<v_lunch_end THEN
    UPDATE public.srk_booking_technician_workdays SET status='lunch_paused',
      accumulated_work_seconds=14400,running_started_at=NULL,
      lunch_started_at=v_lunch_start,lunch_ends_at=v_lunch_end,updated_at=clock_timestamp()
    WHERE id=p_workday_id;
    INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,event_type,event_data)
    VALUES(w.id,w.booking_id,w.technician_id,'lunch_auto_paused',
      jsonb_build_object('paused_at',v_lunch_start,'auto_resume_at',v_lunch_end));
  ELSE
    UPDATE public.srk_booking_technician_workdays SET accumulated_work_seconds=14400,
      running_started_at=v_lunch_end,lunch_started_at=v_lunch_start,
      lunch_ends_at=v_lunch_end,lunch_break_taken=true,updated_at=clock_timestamp()
    WHERE id=p_workday_id;
    INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,event_type,event_data)
    VALUES(w.id,w.booking_id,w.technician_id,'lunch_auto_paused',
      jsonb_build_object('paused_at',v_lunch_start,'auto_resume_at',v_lunch_end));
    INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,event_type,event_data)
    VALUES(w.id,w.booking_id,w.technician_id,'lunch_auto_resumed',
      jsonb_build_object('resumed_at',v_lunch_end));
  END IF;
END;
$function$;
REVOKE ALL ON FUNCTION srk_private.srk_normalize_technician_workday_lunch(uuid)
  FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_request_workday_start(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_technician uuid; b public.service_bookings%rowtype;
  v_workday uuid; v_rate bigint; v_version text; v_date date;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_technician FROM public.srk_technicians
  WHERE auth_user_id=v_uid AND account_status='active' FOR SHARE;
  IF v_technician IS NULL THEN RAISE EXCEPTION 'ACTIVE_TECHNICIAN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT * INTO b FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR b.customer_user_id IS NULL OR b.srk_billing_model_snapshot<>'hourly'
     OR b.status NOT IN ('assigned','in_progress') THEN
    RAISE EXCEPTION 'ACTIVE_HOURLY_MASTER_BOOKING_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.srk_booking_technician_assignments a
    WHERE a.booking_id=p_booking_id AND a.technician_id=v_technician
      AND a.assignment_status IN ('accepted','active')) THEN
    RAISE EXCEPTION 'TECHNICIAN_ACCEPTED_ASSIGNMENT_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.srk_technician_presence p
      WHERE p.technician_id=v_technician AND p.active_booking_id=p_booking_id) THEN
    RAISE EXCEPTION 'TECHNICIAN_ACTIVE_BOOKING_PRESENCE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF b.srk_technician_hourly_paise_snapshot IS NULL OR b.srk_technician_hourly_paise_snapshot<=0
     OR b.srk_rate_version_snapshot IS NULL THEN
    RAISE EXCEPTION 'BOOKING_TECHNICIAN_RATE_SNAPSHOT_REQUIRED' USING ERRCODE='55000';
  END IF;
  v_date:=(clock_timestamp() AT TIME ZONE 'Asia/Kolkata')::date;
  IF EXISTS(SELECT 1 FROM public.srk_booking_technician_workdays
    WHERE booking_id=p_booking_id AND technician_id=v_technician AND work_date=v_date) THEN
    RAISE EXCEPTION 'TECHNICIAN_WORKDAY_ALREADY_EXISTS_FOR_TODAY' USING ERRCODE='23505';
  END IF;
  INSERT INTO public.srk_booking_technician_workdays(
    booking_id,technician_id,work_date,technician_hourly_paise_snapshot,rate_version_snapshot
  ) VALUES(p_booking_id,v_technician,v_date,b.srk_technician_hourly_paise_snapshot,b.srk_rate_version_snapshot)
  RETURNING id INTO v_workday;
  INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,actor_user_id,event_type)
  VALUES(v_workday,p_booking_id,v_technician,v_uid,'start_requested');
  RETURN jsonb_build_object('success',true,'workday_id',v_workday,'status','start_pending','work_date',v_date);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_respond_technician_workday_start(
  p_workday_id uuid,p_response text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); w public.srk_booking_technician_workdays%rowtype;
  b public.service_bookings%rowtype;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'CUSTOMER_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_response NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'INVALID_WORKDAY_START_RESPONSE' USING ERRCODE='22023'; END IF;
  SELECT * INTO w FROM public.srk_booking_technician_workdays WHERE id=p_workday_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'WORKDAY_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  SELECT * INTO b FROM public.service_bookings WHERE id=w.booking_id AND customer_user_id=v_uid FOR UPDATE;
  IF NOT FOUND OR w.status<>'start_pending' OR NOT EXISTS(
    SELECT 1 FROM public.srk_booking_technician_assignments a
    WHERE a.booking_id=w.booking_id AND a.technician_id=w.technician_id
      AND a.assignment_status IN ('accepted','active')) THEN
    RAISE EXCEPTION 'CUSTOMER_PENDING_WORKDAY_APPROVAL_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_response='rejected' THEN
    UPDATE public.srk_booking_technician_workdays SET status='start_rejected',updated_at=clock_timestamp()
    WHERE id=w.id;
    INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,actor_user_id,event_type)
    VALUES(w.id,w.booking_id,w.technician_id,v_uid,'start_rejected');
    RETURN jsonb_build_object('success',true,'status','start_rejected');
  END IF;
  UPDATE public.srk_booking_technician_workdays SET status='running',
    customer_approved_at=clock_timestamp(),running_started_at=clock_timestamp(),updated_at=clock_timestamp()
  WHERE id=w.id;
  UPDATE public.srk_booking_technician_assignments SET assignment_status='active'
  WHERE booking_id=w.booking_id AND technician_id=w.technician_id AND assignment_status='accepted';
  IF b.status='assigned' THEN
    INSERT INTO srk_private.work_transition_authorizations(transaction_id,booking_id,target_status)
    VALUES(pg_catalog.txid_current(),w.booking_id,'in_progress') ON CONFLICT DO NOTHING;
    UPDATE public.service_bookings SET status='in_progress' WHERE id=w.booking_id AND status='assigned';
    DELETE FROM srk_private.work_transition_authorizations
    WHERE transaction_id=pg_catalog.txid_current() AND booking_id=w.booking_id AND target_status='in_progress';
  END IF;
  INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,actor_user_id,event_type)
  VALUES(w.id,w.booking_id,w.technician_id,v_uid,'start_approved');
  RETURN jsonb_build_object('success',true,'status','running','approved_at',clock_timestamp());
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_technician_pause_workday(p_workday_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_technician uuid; w public.srk_booking_technician_workdays%rowtype;
  v_elapsed numeric(20,3);
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_technician FROM public.srk_technicians WHERE auth_user_id=v_uid AND account_status='active';
  SELECT * INTO w FROM public.srk_booking_technician_workdays WHERE id=p_workday_id AND technician_id=v_technician FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OWN_WORKDAY_REQUIRED' USING ERRCODE='42501'; END IF;
  PERFORM srk_private.srk_normalize_technician_workday_lunch(w.id);
  SELECT * INTO w FROM public.srk_booking_technician_workdays WHERE id=p_workday_id FOR UPDATE;
  IF w.status<>'running' THEN RAISE EXCEPTION 'RUNNING_WORKDAY_REQUIRED' USING ERRCODE='55000'; END IF;
  v_elapsed:=w.accumulated_work_seconds+
    greatest(extract(epoch FROM (clock_timestamp()-w.running_started_at)),0);
  UPDATE public.srk_booking_technician_workdays SET status='paused',
    accumulated_work_seconds=v_elapsed,running_started_at=NULL,updated_at=clock_timestamp()
  WHERE id=w.id;
  INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,actor_user_id,event_type,event_data)
  VALUES(w.id,w.booking_id,w.technician_id,v_uid,'paused',jsonb_build_object('elapsed_seconds',v_elapsed));
  RETURN jsonb_build_object('success',true,'status','paused','elapsed_seconds',v_elapsed);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_technician_resume_workday(p_workday_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_technician uuid; w public.srk_booking_technician_workdays%rowtype;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_technician FROM public.srk_technicians WHERE auth_user_id=v_uid AND account_status='active';
  SELECT * INTO w FROM public.srk_booking_technician_workdays WHERE id=p_workday_id AND technician_id=v_technician FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OWN_WORKDAY_REQUIRED' USING ERRCODE='42501'; END IF;
  PERFORM srk_private.srk_normalize_technician_workday_lunch(w.id);
  SELECT * INTO w FROM public.srk_booking_technician_workdays WHERE id=p_workday_id FOR UPDATE;
  IF w.status='lunch_paused' THEN
    RETURN jsonb_build_object('success',true,'status','lunch_paused','auto_resume_at',w.lunch_ends_at);
  END IF;
  IF w.status<>'paused' THEN RAISE EXCEPTION 'PAUSED_WORKDAY_REQUIRED' USING ERRCODE='55000'; END IF;
  IF w.accumulated_work_seconds>=14400 AND NOT w.lunch_break_taken THEN
    UPDATE public.srk_booking_technician_workdays SET status='lunch_paused',
      lunch_started_at=clock_timestamp(),lunch_ends_at=clock_timestamp()+interval '1 hour',
      accumulated_work_seconds=14400,updated_at=clock_timestamp()
    WHERE id=w.id;
    INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,actor_user_id,event_type,event_data)
    VALUES(w.id,w.booking_id,w.technician_id,v_uid,'lunch_auto_paused',
      jsonb_build_object('auto_resume_at',clock_timestamp()+interval '1 hour'));
    RETURN jsonb_build_object('success',true,'status','lunch_paused','auto_resume_at',clock_timestamp()+interval '1 hour');
  END IF;
  UPDATE public.srk_booking_technician_workdays SET status='running',
    running_started_at=clock_timestamp(),updated_at=clock_timestamp() WHERE id=w.id;
  INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,actor_user_id,event_type)
  VALUES(w.id,w.booking_id,w.technician_id,v_uid,'resumed');
  RETURN jsonb_build_object('success',true,'status','running');
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_technician_stop_workday(p_workday_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_technician uuid; w public.srk_booking_technician_workdays%rowtype;
  v_elapsed numeric(20,3); v_normal numeric(20,3); v_overtime numeric(20,3);
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_technician FROM public.srk_technicians WHERE auth_user_id=v_uid AND account_status='active';
  SELECT * INTO w FROM public.srk_booking_technician_workdays WHERE id=p_workday_id AND technician_id=v_technician FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OWN_WORKDAY_REQUIRED' USING ERRCODE='42501'; END IF;
  PERFORM srk_private.srk_normalize_technician_workday_lunch(w.id);
  SELECT * INTO w FROM public.srk_booking_technician_workdays WHERE id=p_workday_id FOR UPDATE;
  IF w.status='running' THEN
    v_elapsed:=w.accumulated_work_seconds+
      greatest(extract(epoch FROM (clock_timestamp()-w.running_started_at)),0);
  ELSIF w.status IN ('paused','lunch_paused') THEN
    v_elapsed:=w.accumulated_work_seconds;
  ELSE RAISE EXCEPTION 'ACTIVE_WORKDAY_REQUIRED' USING ERRCODE='55000';
  END IF;
  v_normal:=least(v_elapsed,28800);
  v_overtime:=greatest(v_elapsed-28800,0);
  UPDATE public.srk_booking_technician_workdays SET status='stopped',
    accumulated_work_seconds=v_elapsed,running_started_at=NULL,stopped_at=clock_timestamp(),
    normal_work_seconds=v_normal,overtime_work_seconds=v_overtime,updated_at=clock_timestamp()
  WHERE id=w.id;
  INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,actor_user_id,event_type,event_data)
  VALUES(w.id,w.booking_id,w.technician_id,v_uid,'day_stopped',
    jsonb_build_object('actual_work_seconds',v_elapsed,'normal_seconds',v_normal,'overtime_seconds',v_overtime));
  RETURN jsonb_build_object('success',true,'status','stopped','actual_work_seconds',v_elapsed,
    'normal_seconds',v_normal,'overtime_seconds',v_overtime);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_technician_get_workday(p_workday_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_technician uuid; w public.srk_booking_technician_workdays%rowtype;
  v_elapsed numeric(20,3);
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_technician FROM public.srk_technicians
  WHERE auth_user_id=v_uid AND account_status='active';
  SELECT * INTO w FROM public.srk_booking_technician_workdays
  WHERE id=p_workday_id AND technician_id=v_technician FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'OWN_WORKDAY_REQUIRED' USING ERRCODE='42501'; END IF;
  PERFORM srk_private.srk_normalize_technician_workday_lunch(w.id);
  SELECT * INTO w FROM public.srk_booking_technician_workdays WHERE id=p_workday_id;
  v_elapsed:=CASE
    WHEN w.status='running' THEN w.accumulated_work_seconds+
      greatest(extract(epoch FROM (clock_timestamp()-w.running_started_at)),0)
    WHEN w.status='lunch_paused' THEN 14400
    ELSE w.accumulated_work_seconds END;
  RETURN jsonb_build_object('workday_id',w.id,'booking_id',w.booking_id,
    'work_date',w.work_date,'status',w.status,'elapsed_work_seconds',v_elapsed,
    'lunch_ends_at',w.lunch_ends_at,'normal_work_seconds',w.normal_work_seconds,
    'overtime_work_seconds',w.overtime_work_seconds,
    'hourly_rate_paise_snapshot',w.technician_hourly_paise_snapshot);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_get_technician_workdays(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_result jsonb; v_workday_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'CUSTOMER_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.service_bookings WHERE id=p_booking_id AND customer_user_id=v_uid) THEN
    RAISE EXCEPTION 'OWN_CUSTOMER_BOOKING_REQUIRED' USING ERRCODE='42501';
  END IF;
  FOR v_workday_id IN SELECT w.id FROM public.srk_booking_technician_workdays w
    WHERE w.booking_id=p_booking_id AND w.status IN ('running','lunch_paused')
    ORDER BY w.id
  LOOP
    PERFORM srk_private.srk_normalize_technician_workday_lunch(v_workday_id);
  END LOOP;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'workday_id',w.id,'technician_id',w.technician_id,'work_date',w.work_date,
    'status',w.status,'start_requested_at',w.start_requested_at,
    'customer_approved_at',w.customer_approved_at,'accumulated_work_seconds',
      CASE WHEN w.status='running' THEN w.accumulated_work_seconds+
        greatest(extract(epoch FROM (clock_timestamp()-w.running_started_at)),0)
        WHEN w.status='lunch_paused' THEN 14400 ELSE w.accumulated_work_seconds END,
    'lunch_ends_at',w.lunch_ends_at,'normal_work_seconds',w.normal_work_seconds,
    'overtime_work_seconds',w.overtime_work_seconds
  ) ORDER BY w.work_date,w.technician_id), '[]'::jsonb)
  INTO v_result FROM public.srk_booking_technician_workdays w WHERE w.booking_id=p_booking_id;
  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_decide_workday(
  p_booking_id uuid,p_work_date date,p_decision text,p_replaced_technician_id uuid DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); b public.service_bookings%rowtype; v_w record;
  v_normal_amount bigint; v_overtime_amount bigint; v_total bigint; v_dispatch jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'CUSTOMER_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_decision NOT IN ('tomorrow','completed','replace_technician')
     OR (p_decision='replace_technician' AND p_replaced_technician_id IS NULL)
     OR (p_decision<>'replace_technician' AND p_replaced_technician_id IS NOT NULL) THEN
    RAISE EXCEPTION 'INVALID_WORKDAY_CUSTOMER_DECISION' USING ERRCODE='22023';
  END IF;
  SELECT * INTO b FROM public.service_bookings
  WHERE id=p_booking_id AND customer_user_id=v_uid FOR UPDATE;
  IF NOT FOUND OR b.srk_billing_model_snapshot<>'hourly' OR b.status<>'in_progress' THEN
    RAISE EXCEPTION 'CUSTOMER_ACTIVE_HOURLY_BOOKING_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF EXISTS(SELECT 1 FROM public.srk_booking_workday_customer_decisions
    WHERE booking_id=p_booking_id AND work_date=p_work_date) THEN
    RAISE EXCEPTION 'WORKDAY_DECISION_ALREADY_RECORDED' USING ERRCODE='23505';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.srk_booking_technician_workdays
    WHERE booking_id=p_booking_id AND work_date=p_work_date AND status='stopped') THEN
    RAISE EXCEPTION 'STOPPED_TECHNICIAN_WORKDAY_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF EXISTS(SELECT 1 FROM public.srk_booking_technician_assignments a
    WHERE a.booking_id=p_booking_id AND a.assignment_status IN ('accepted','active')
      AND NOT EXISTS(SELECT 1 FROM public.srk_booking_technician_workdays w
        WHERE w.booking_id=p_booking_id AND w.technician_id=a.technician_id
          AND w.work_date=p_work_date AND w.status='stopped')) THEN
    RAISE EXCEPTION 'ALL_ACTIVE_TECHNICIANS_MUST_STOP_THEIR_DAILY_WORK' USING ERRCODE='55000';
  END IF;

  FOR v_w IN SELECT * FROM public.srk_booking_technician_workdays
    WHERE booking_id=p_booking_id AND work_date=p_work_date AND status='stopped'
    ORDER BY technician_id FOR UPDATE
  LOOP
    v_normal_amount:=floor(v_w.technician_hourly_paise_snapshot*v_w.normal_work_seconds/3600+0.5)::bigint;
    v_overtime_amount:=floor(v_w.technician_hourly_paise_snapshot*v_w.overtime_work_seconds*1.5/3600+0.5)::bigint;
    v_total:=v_normal_amount+v_overtime_amount;
    INSERT INTO public.srk_booking_technician_labour_ledger(
      booking_id,workday_id,technician_id,work_date,technician_hourly_paise_snapshot,
      normal_work_seconds,overtime_work_seconds,normal_amount_paise,overtime_amount_paise,total_labour_paise
    ) VALUES(p_booking_id,v_w.id,v_w.technician_id,p_work_date,v_w.technician_hourly_paise_snapshot,
      v_w.normal_work_seconds,v_w.overtime_work_seconds,v_normal_amount,v_overtime_amount,v_total)
    ON CONFLICT(workday_id) DO NOTHING;
  END LOOP;

  INSERT INTO public.srk_booking_workday_customer_decisions(
    booking_id,work_date,customer_user_id,decision,replaced_technician_id
  ) VALUES(p_booking_id,p_work_date,v_uid,p_decision,p_replaced_technician_id);

  IF p_decision='tomorrow' THEN
    INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,actor_user_id,event_type)
    SELECT id,booking_id,technician_id,v_uid,'customer_tomorrow_accepted'
    FROM public.srk_booking_technician_workdays WHERE booking_id=p_booking_id AND work_date=p_work_date AND status='stopped';
    RETURN jsonb_build_object('success',true,'decision','tomorrow');
  ELSIF p_decision='replace_technician' THEN
    IF NOT EXISTS(SELECT 1 FROM public.srk_booking_technician_assignments
      WHERE booking_id=p_booking_id AND technician_id=p_replaced_technician_id AND assignment_status IN ('accepted','active')) THEN
      RAISE EXCEPTION 'REPLACE_TARGET_MUST_BE_CURRENTLY_ASSIGNED' USING ERRCODE='22023';
    END IF;
    UPDATE public.srk_booking_technician_assignments SET assignment_status='replaced'
    WHERE booking_id=p_booking_id AND technician_id=p_replaced_technician_id;
    UPDATE public.srk_technician_presence SET active_booking_id=NULL,is_online=false,updated_at=clock_timestamp()
    WHERE technician_id=p_replaced_technician_id AND active_booking_id=p_booking_id;
    UPDATE public.srk_technician_dispatch_requests d SET
      assigned_technician_count=(SELECT count(*)::smallint FROM public.srk_booking_technician_assignments a
        WHERE a.booking_id=p_booking_id AND a.assignment_status IN ('accepted','active','completed')),
      status='searching',current_offer_id=NULL,updated_at=clock_timestamp()
    WHERE d.booking_id=p_booking_id;
    SELECT public.srk_dispatch_issue_next_offer(p_booking_id) INTO v_dispatch;
    INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,actor_user_id,event_type,event_data)
    SELECT id,booking_id,technician_id,v_uid,'customer_technician_replaced',
      jsonb_build_object('replaced_technician_id',p_replaced_technician_id)
    FROM public.srk_booking_technician_workdays WHERE booking_id=p_booking_id AND work_date=p_work_date AND status='stopped';
    RETURN jsonb_build_object('success',true,'decision','replace_technician','dispatch',v_dispatch);
  ELSE
    UPDATE public.srk_booking_technician_assignments SET assignment_status='completed',completed_at=clock_timestamp()
    WHERE booking_id=p_booking_id AND assignment_status IN ('accepted','active');
    INSERT INTO srk_private.work_transition_authorizations(transaction_id,booking_id,target_status)
    VALUES(pg_catalog.txid_current(),p_booking_id,'completed') ON CONFLICT DO NOTHING;
    UPDATE public.service_bookings SET status='completed',
      completion_approval_status='approved',customer_completed_at=clock_timestamp()
    WHERE id=p_booking_id AND status='in_progress';
    DELETE FROM srk_private.work_transition_authorizations
    WHERE transaction_id=pg_catalog.txid_current() AND booking_id=p_booking_id AND target_status='completed';
    INSERT INTO public.srk_booking_technician_work_events(workday_id,booking_id,technician_id,actor_user_id,event_type)
    SELECT id,booking_id,technician_id,v_uid,'customer_completed'
    FROM public.srk_booking_technician_workdays WHERE booking_id=p_booking_id AND work_date=p_work_date AND status='stopped';
    RETURN jsonb_build_object('success',true,'decision','completed');
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_technician_request_workday_start(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_customer_respond_technician_workday_start(uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_technician_pause_workday(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_technician_resume_workday(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_technician_stop_workday(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_technician_get_workday(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_customer_get_technician_workdays(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_customer_decide_workday(uuid,date,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_request_workday_start(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_customer_respond_technician_workday_start(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_technician_pause_workday(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_technician_resume_workday(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_technician_stop_workday(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_technician_get_workday(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_technician_workdays(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_customer_decide_workday(uuid,date,text,uuid) TO authenticated;

COMMENT ON TABLE public.srk_booking_technician_workdays IS
  'One independently customer-approved daily timer per assigned canonical Technician. First four active hours precede an automatic one-hour lunch pause; timer resumes automatically after lunch. Daily first eight actual hours are normal and further time is 1.5x.';
COMMENT ON TABLE public.srk_booking_technician_labour_ledger IS
  'Immutable per-Technician daily labour ledger. Helper charges and final customer bill are separate integration steps.';


-- A replaced Technician who completed billable workdays still contributed to
-- the completed booking and must receive their own completion ordinal.
CREATE OR REPLACE FUNCTION public.srk_record_customer_confirmed_technician_completions()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_assignment record; v_ordinal bigint; v_online boolean;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed'
     OR NEW.completion_approval_status IS DISTINCT FROM 'approved'
     OR NEW.customer_completed_at IS NULL THEN RETURN NEW; END IF;
  IF OLD.status='completed' AND OLD.completion_approval_status='approved'
     AND OLD.customer_completed_at IS NOT NULL THEN RETURN NEW; END IF;
  v_online:=lower(btrim(COALESCE(NEW.payment_method,''))) LIKE '%razorpay%'
    OR lower(btrim(COALESCE(NEW.payment_method,''))) LIKE '%online%'
    OR lower(btrim(COALESCE(NEW.payment_method,''))) LIKE '%ऑनलाइन%';
  FOR v_assignment IN
    SELECT a.technician_id FROM public.srk_booking_technician_assignments a
    WHERE a.booking_id=NEW.id AND a.assignment_status<>'cancelled'
      AND (a.assignment_status<>'replaced' OR EXISTS(
        SELECT 1 FROM public.srk_booking_technician_labour_ledger l
        WHERE l.booking_id=NEW.id AND l.technician_id=a.technician_id
      ))
    ORDER BY a.technician_id
  LOOP
    IF EXISTS(SELECT 1 FROM public.srk_technician_completed_booking_events e
      WHERE e.technician_id=v_assignment.technician_id AND e.booking_id=NEW.id) THEN CONTINUE; END IF;
    INSERT INTO public.srk_technician_booking_counters(technician_id,completed_booking_count)
    VALUES(v_assignment.technician_id,0) ON CONFLICT(technician_id) DO NOTHING;
    UPDATE public.srk_technician_booking_counters
      SET completed_booking_count=completed_booking_count+1,updated_at=clock_timestamp()
      WHERE technician_id=v_assignment.technician_id
      RETURNING completed_booking_count INTO v_ordinal;
    IF mod(v_ordinal,3)=0 AND NOT v_online THEN
      RAISE EXCEPTION 'TECHNICIAN_EVERY_THIRD_COMPLETED_BOOKING_REQUIRES_ONLINE_PAYMENT'
        USING ERRCODE='23514';
    END IF;
    INSERT INTO public.srk_technician_completed_booking_events(
      technician_id,booking_id,completion_ordinal,customer_confirmed_at
    ) VALUES(v_assignment.technician_id,NEW.id,v_ordinal,NEW.customer_completed_at)
    ON CONFLICT(technician_id,booking_id) DO NOTHING;
    UPDATE public.srk_booking_technician_assignments
      SET assignment_status='completed',completed_at=NEW.customer_completed_at
      WHERE booking_id=NEW.id AND technician_id=v_assignment.technician_id
        AND assignment_status IN ('accepted','active');
  END LOOP;
  IF NOT EXISTS(SELECT 1 FROM public.srk_booking_technician_assignments a
    WHERE a.booking_id=NEW.id AND a.assignment_status<>'cancelled'
      AND (a.assignment_status<>'replaced' OR EXISTS(
        SELECT 1 FROM public.srk_booking_technician_labour_ledger l
        WHERE l.booking_id=NEW.id AND l.technician_id=a.technician_id
      ))) THEN
    RAISE EXCEPTION 'COMPLETED_BOOKING_REQUIRES_AT_LEAST_ONE_CONTRIBUTING_TECHNICIAN'
      USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_record_customer_confirmed_technician_completions()
  FROM PUBLIC,anon,authenticated;
