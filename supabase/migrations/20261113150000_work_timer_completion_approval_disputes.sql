-- SRK ELECTRONIC 14.1.10: customer-controlled work start, server-side timer,
-- completion approval and admin resolution of work-completion disputes.
-- Existing approved quote amounts remain fixed; timer records duration only.
ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS work_start_approval_status text NOT NULL DEFAULT 'not_requested',
  ADD COLUMN IF NOT EXISTS work_start_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS work_timer_running boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS work_timer_seconds integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS completion_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS completion_approval_status text NOT NULL DEFAULT 'not_requested',
  ADD COLUMN IF NOT EXISTS customer_completed_at timestamptz;

ALTER TABLE public.service_bookings
  DROP CONSTRAINT IF EXISTS service_bookings_status_check;
ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_status_check CHECK (
    status = ANY (ARRAY[
      'new','confirmed','assigned','inspection','awaiting_quote_approval',
      'quote_approved','awaiting_work_start_approval','quote_rejected',
      'in_progress','completed','cancelled'
    ])
  );

ALTER TABLE public.service_bookings
  DROP CONSTRAINT IF EXISTS service_bookings_assignment_status_requires_electrician;
ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_assignment_status_requires_electrician CHECK (
    status <> ALL (ARRAY['assigned','inspection','awaiting_quote_approval','quote_approved',
      'awaiting_work_start_approval','quote_rejected','in_progress','completed'])
    OR assigned_electrician_id IS NOT NULL
  );

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_work_start_approval_check
    CHECK (work_start_approval_status IN ('not_requested','pending','approved','rejected')),
  ADD CONSTRAINT service_bookings_completion_approval_check
    CHECK (completion_approval_status IN ('not_requested','pending','approved','rejected','disputed','admin_approved','reopened')),
  ADD CONSTRAINT service_bookings_work_timer_seconds_check
    CHECK (work_timer_seconds BETWEEN 0 AND 604800);

CREATE OR REPLACE FUNCTION public.srk_electrician_request_work_start(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_profile_id uuid; v_booking public.service_bookings%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
   WHERE (user_id=auth.uid() OR auth_user_id=auth.uid())
     AND verification_status='approved' AND active=true
   ORDER BY created_at DESC LIMIT 1;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Approved active electrician required' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=p_booking_id AND assigned_electrician_id=v_profile_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Assigned booking not found' USING ERRCODE='42501'; END IF;
  IF v_booking.status<>'quote_approved' OR v_booking.quote_status<>'approved' THEN
    RAISE EXCEPTION 'Customer-approved quote is required before requesting work start';
  END IF;
  IF v_booking.work_start_approval_status NOT IN ('not_requested','rejected') THEN
    RAISE EXCEPTION 'Work start approval is already pending or granted';
  END IF;
  UPDATE public.service_bookings SET
    status='awaiting_work_start_approval',
    work_start_approval_status='pending',
    work_start_requested_at=pg_catalog.now(),
    work_timer_running=false
  WHERE id=p_booking_id;
  RETURN pg_catalog.jsonb_build_object('success',true,'status','awaiting_work_start_approval');
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_respond_work_start(p_booking_id uuid,p_response text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_booking public.service_bookings%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_response NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Invalid response'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=p_booking_id AND customer_user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Customer booking not found' USING ERRCODE='42501'; END IF;
  IF v_booking.status<>'awaiting_work_start_approval' OR v_booking.work_start_approval_status<>'pending' THEN
    RAISE EXCEPTION 'No work-start request is waiting for approval';
  END IF;
  UPDATE public.service_bookings SET
    work_start_approval_status=p_response,
    status=CASE WHEN p_response='approved' THEN 'in_progress' ELSE 'quote_approved' END,
    work_started_at=CASE WHEN p_response='approved' THEN pg_catalog.now() ELSE NULL END,
    work_timer_running=(p_response='approved'),
    work_timer_seconds=0
  WHERE id=p_booking_id;
  RETURN pg_catalog.jsonb_build_object('success',true,'response',p_response);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_electrician_request_work_completion(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_profile_id uuid; v_booking public.service_bookings%rowtype; v_seconds integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
   WHERE (user_id=auth.uid() OR auth_user_id=auth.uid())
     AND verification_status='approved' AND active=true
   ORDER BY created_at DESC LIMIT 1;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Approved active electrician required' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=p_booking_id AND assigned_electrician_id=v_profile_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Assigned booking not found' USING ERRCODE='42501'; END IF;
  IF v_booking.status<>'in_progress' OR NOT v_booking.work_timer_running OR v_booking.work_started_at IS NULL THEN
    RAISE EXCEPTION 'No running work timer exists';
  END IF;
  v_seconds:=LEAST(604800,v_booking.work_timer_seconds+
    GREATEST(0,FLOOR(EXTRACT(EPOCH FROM (pg_catalog.now()-v_booking.work_started_at)))::integer));
  UPDATE public.service_bookings SET
    work_timer_seconds=v_seconds,
    work_timer_running=false,
    completion_requested_at=pg_catalog.now(),
    completion_approval_status='pending'
  WHERE id=p_booking_id;
  RETURN pg_catalog.jsonb_build_object('success',true,'completion_status','pending','work_seconds',v_seconds);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_respond_work_completion(p_booking_id uuid,p_response text,p_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_booking public.service_bookings%rowtype; v_note text:=NULLIF(pg_catalog.btrim(p_note),'');
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_response IS NULL OR p_response NOT IN ('approved','rejected','disputed') OR (p_note IS NOT NULL AND pg_catalog.length(p_note)>1000) THEN
    RAISE EXCEPTION 'Invalid completion response';
  END IF;
  IF p_response='disputed' AND (v_note IS NULL OR pg_catalog.length(v_note)<20) THEN
    RAISE EXCEPTION 'विवाद का कारण कम से कम 20 अक्षरों में लिखें';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=p_booking_id AND customer_user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Customer booking not found' USING ERRCODE='42501'; END IF;
  IF v_booking.status<>'in_progress' OR v_booking.completion_approval_status<>'pending'
     OR v_booking.completion_requested_at IS NULL THEN
    RAISE EXCEPTION 'No completion request is waiting for your response';
  END IF;
  IF p_response='approved' THEN
    UPDATE public.service_bookings SET status='completed',
      completion_approval_status='approved',customer_completed_at=pg_catalog.now(),
      work_timer_running=false
    WHERE id=p_booking_id;
  ELSIF p_response='rejected' THEN
    UPDATE public.service_bookings SET completion_approval_status='rejected',
      completion_requested_at=NULL,work_started_at=pg_catalog.now(),
      work_timer_running=true
    WHERE id=p_booking_id;
  ELSE
    INSERT INTO public.srk_booking_complaints
      (booking_id,customer_user_id,category,description)
    VALUES (p_booking_id,auth.uid(),'service_quality','काम पूरा होने पर विवाद: '||v_note);
    UPDATE public.service_bookings SET completion_approval_status='disputed',
      work_timer_running=false
    WHERE id=p_booking_id;
  END IF;
  RETURN pg_catalog.jsonb_build_object('success',true,'response',p_response);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_resolve_work_dispute(
  p_booking_id uuid,p_resolution text,p_admin_note text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_booking public.service_bookings%rowtype; v_admin_id uuid:=auth.uid(); v_complaint public.srk_booking_complaints%rowtype;
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501';
  END IF;
  IF p_resolution IS NULL OR p_resolution NOT IN ('approve_completion','reopen_work')
     OR p_admin_note IS NULL OR pg_catalog.length(pg_catalog.btrim(p_admin_note))<10
     OR pg_catalog.length(p_admin_note)>2000 THEN RAISE EXCEPTION 'Valid resolution and admin note required'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.completion_approval_status<>'disputed' THEN
    RAISE EXCEPTION 'No disputed completion exists for this booking';
  END IF;
  SELECT * INTO v_complaint FROM public.srk_booking_complaints
   WHERE booking_id=p_booking_id AND category='service_quality'
     AND description LIKE 'काम पूरा होने पर विवाद:%'
     AND status IN ('new','in_review')
   ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Open work-completion dispute record not found'; END IF;
  IF p_resolution='approve_completion' THEN
    UPDATE public.service_bookings SET status='completed',
      completion_approval_status='admin_approved',customer_completed_at=pg_catalog.now(),
      work_timer_running=false
    WHERE id=p_booking_id;
  ELSE
    UPDATE public.service_bookings SET status='in_progress',
      completion_approval_status='reopened',completion_requested_at=NULL,
      work_started_at=pg_catalog.now(),work_timer_running=true
    WHERE id=p_booking_id;
  END IF;
  UPDATE public.srk_booking_complaints SET status='resolved',admin_note=p_admin_note,
    updated_at=pg_catalog.now(),updated_by=v_admin_id,resolved_at=pg_catalog.now(),resolved_by=v_admin_id
  WHERE id=v_complaint.id;
  INSERT INTO public.srk_booking_complaint_events
    (complaint_id,actor_user_id,actor_role,from_status,to_status,note)
  VALUES (v_complaint.id,v_admin_id,'admin',v_complaint.status,'resolved',p_admin_note);
  RETURN pg_catalog.jsonb_build_object('success',true,'resolution',p_resolution);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_update_booking_work_status(p_booking_id uuid,p_status text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_profile_id uuid; v_booking public.service_bookings%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_status<>'inspection' THEN RAISE EXCEPTION 'काम शुरू और पूरा करने के लिए ग्राहक की मंजूरी जरूरी है'; END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
   WHERE (user_id=auth.uid() OR auth_user_id=auth.uid())
     AND verification_status='approved' AND active=true
   ORDER BY created_at DESC LIMIT 1;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Approved active electrician required' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=p_booking_id AND assigned_electrician_id=v_profile_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Assigned booking not found' USING ERRCODE='42501'; END IF;
  IF p_status='inspection' AND v_booking.status='assigned' THEN
    UPDATE public.service_bookings SET status='inspection' WHERE id=p_booking_id;
  ELSE RAISE EXCEPTION 'Invalid booking status transition'; END IF;
  RETURN pg_catalog.jsonb_build_object('success',true,'status',p_status);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_electrician_request_work_start(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_customer_respond_work_start(uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_electrician_request_work_completion(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_customer_respond_work_completion(uuid,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_admin_resolve_work_dispute(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_request_work_start(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_customer_respond_work_start(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_electrician_request_work_completion(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_customer_respond_work_completion(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_admin_resolve_work_dispute(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_update_booking_work_status(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_update_booking_work_status(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_electrician_get_work_control(p_booking_id uuid)
RETURNS TABLE(
  booking_id uuid,status text,work_start_approval_status text,
  completion_approval_status text,work_started_at timestamptz,
  work_timer_seconds integer,work_timer_running boolean,completion_requested_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_profile_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
   WHERE (user_id=auth.uid() OR auth_user_id=auth.uid())
     AND verification_status='approved' AND active=true
   ORDER BY created_at DESC LIMIT 1;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Approved active electrician required' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT b.id,b.status,b.work_start_approval_status,b.completion_approval_status,
    b.work_started_at,b.work_timer_seconds,b.work_timer_running,b.completion_requested_at
  FROM public.service_bookings b
  WHERE b.id=p_booking_id AND b.assigned_electrician_id=v_profile_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_list_work_disputes(p_limit integer DEFAULT 100)
RETURNS TABLE(
  booking_id uuid,complaint_id uuid,customer_name text,customer_phone text,
  service_type text,description text,work_timer_seconds integer,completion_requested_at timestamptz,
  complaint_status text,created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT b.id,c.id,b.customer_name,b.phone,b.service_type,c.description,
    b.work_timer_seconds,b.completion_requested_at,c.status,c.created_at
  FROM public.service_bookings b
  JOIN public.srk_booking_complaints c ON c.booking_id=b.id
  WHERE b.completion_approval_status='disputed'
    AND c.category='service_quality'
    AND c.description LIKE 'काम पूरा होने पर विवाद:%'
    AND c.status IN ('new','in_review')
  ORDER BY c.created_at DESC
  LIMIT GREATEST(1,LEAST(COALESCE(p_limit,100),300));
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_electrician_get_work_control(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_get_work_control(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_list_work_disputes(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_work_disputes(integer) TO authenticated;
