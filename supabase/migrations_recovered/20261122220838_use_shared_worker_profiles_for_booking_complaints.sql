
CREATE OR REPLACE FUNCTION public.srk_technician_create_booking_complaint(
  p_booking_id uuid,
  p_category text,
  p_description text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_worker_id uuid;
  v_complaint_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Worker login required' USING ERRCODE='42501';
  END IF;

  IF p_booking_id IS NULL
     OR p_category NOT IN ('service_quality','electrician_behavior','billing_payment','delay_no_show','safety','other')
     OR p_description IS NULL
     OR length(btrim(p_description)) NOT BETWEEN 20 AND 2000 THEN
    RAISE EXCEPTION 'Valid booking, category and 20-2000 character description are required';
  END IF;

  SELECT wp.id INTO v_worker_id
  FROM public.srk_worker_profiles wp
  WHERE wp.user_id=v_user_id
  LIMIT 1;

  IF v_worker_id IS NULL THEN
    RAISE EXCEPTION 'Worker profile required' USING ERRCODE='42501';
  END IF;

  PERFORM 1
  FROM public.srk_booking_workers bw
  WHERE bw.booking_id=p_booking_id
    AND bw.worker_id=v_worker_id
    AND bw.assignment_status IN ('accepted','assigned','completed','released')
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking is not assigned to this worker' USING ERRCODE='42501';
  END IF;

  IF (
    SELECT count(*)
    FROM public.srk_booking_complaints c
    WHERE c.reported_by_user_id=v_user_id
      AND c.reporter_role='technician'
      AND c.created_at >= pg_catalog.now() - interval '24 hours'
  ) >= 10 THEN
    RAISE EXCEPTION 'Daily complaint limit reached';
  END IF;

  INSERT INTO public.srk_booking_complaints
    (booking_id,customer_user_id,reporter_role,reported_by_user_id,category,description)
  VALUES
    (p_booking_id,NULL,'technician',v_user_id,p_category,btrim(p_description))
  RETURNING id INTO v_complaint_id;

  INSERT INTO public.srk_booking_complaint_events
    (complaint_id,actor_user_id,actor_role,from_status,to_status,note)
  VALUES
    (v_complaint_id,v_user_id,'technician',NULL,'new','Worker ने शिकायत दर्ज की');

  RETURN v_complaint_id;
END;
$function$;
