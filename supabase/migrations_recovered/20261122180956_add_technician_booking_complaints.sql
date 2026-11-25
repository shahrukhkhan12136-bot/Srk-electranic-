
ALTER TABLE public.srk_booking_complaints
  ALTER COLUMN customer_user_id DROP NOT NULL,
  ADD COLUMN reporter_role text NOT NULL DEFAULT 'customer',
  ADD COLUMN reported_by_user_id uuid;

UPDATE public.srk_booking_complaints
   SET reported_by_user_id = customer_user_id,
       reporter_role = 'customer'
 WHERE reported_by_user_id IS NULL;

ALTER TABLE public.srk_booking_complaints
  ALTER COLUMN reported_by_user_id SET NOT NULL,
  ADD CONSTRAINT srk_booking_complaints_reporter_role_check
    CHECK (reporter_role IN ('customer','technician')),
  ADD CONSTRAINT srk_booking_complaints_reported_by_user_id_fkey
    FOREIGN KEY (reported_by_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS srk_booking_complaints_reporter_recent_idx
  ON public.srk_booking_complaints (reported_by_user_id, reporter_role, created_at DESC);

ALTER TABLE public.srk_booking_complaint_events
  DROP CONSTRAINT srk_booking_complaint_events_actor_role_check,
  ADD CONSTRAINT srk_booking_complaint_events_actor_role_check
    CHECK (actor_role IN ('customer','technician','admin'));

CREATE OR REPLACE FUNCTION public.srk_customer_create_booking_complaint(
  p_booking_id uuid, p_category text, p_description text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_customer_id uuid := auth.uid();
  v_complaint_id uuid;
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Customer login required' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL
     OR p_category NOT IN ('service_quality','electrician_behavior','billing_payment','delay_no_show','safety','other')
     OR p_description IS NULL
     OR length(btrim(p_description)) NOT BETWEEN 20 AND 2000 THEN
    RAISE EXCEPTION 'Valid booking, category and 20-2000 character description are required';
  END IF;

  PERFORM 1
    FROM public.service_bookings b
   WHERE b.id=p_booking_id AND b.customer_user_id=v_customer_id
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found for this customer' USING ERRCODE='42501';
  END IF;

  IF (SELECT count(*) FROM public.srk_booking_complaints c
       WHERE c.reported_by_user_id=v_customer_id
         AND c.reporter_role='customer'
         AND c.created_at >= pg_catalog.now() - interval '24 hours') >= 10 THEN
    RAISE EXCEPTION 'Daily complaint limit reached';
  END IF;

  INSERT INTO public.srk_booking_complaints
    (booking_id,customer_user_id,reporter_role,reported_by_user_id,category,description)
  VALUES
    (p_booking_id,v_customer_id,'customer',v_customer_id,p_category,btrim(p_description))
  RETURNING id INTO v_complaint_id;

  INSERT INTO public.srk_booking_complaint_events
    (complaint_id,actor_user_id,actor_role,from_status,to_status,note)
  VALUES (v_complaint_id,v_customer_id,'customer',NULL,'new','ग्राहक ने शिकायत दर्ज की');

  RETURN v_complaint_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_technician_create_booking_complaint(
  p_booking_id uuid, p_category text, p_description text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_technician_user_id uuid := auth.uid();
  v_profile_id uuid;
  v_complaint_id uuid;
BEGIN
  IF v_technician_user_id IS NULL THEN
    RAISE EXCEPTION 'Technician login required' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL
     OR p_category NOT IN ('service_quality','electrician_behavior','billing_payment','delay_no_show','safety','other')
     OR p_description IS NULL
     OR length(btrim(p_description)) NOT BETWEEN 20 AND 2000 THEN
    RAISE EXCEPTION 'Valid booking, category and 20-2000 character description are required';
  END IF;

  SELECT p.id INTO v_profile_id
    FROM public.electrician_profiles p
   WHERE (p.user_id=v_technician_user_id OR p.auth_user_id=v_technician_user_id)
     AND p.verification_status='approved'
     AND p.active=true
   LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Approved active technician required' USING ERRCODE='42501';
  END IF;

  PERFORM 1
    FROM public.service_bookings b
   WHERE b.id=p_booking_id
     AND b.assigned_electrician_id=v_profile_id
   FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking is not assigned to this technician' USING ERRCODE='42501';
  END IF;

  IF (SELECT count(*) FROM public.srk_booking_complaints c
       WHERE c.reported_by_user_id=v_technician_user_id
         AND c.reporter_role='technician'
         AND c.created_at >= pg_catalog.now() - interval '24 hours') >= 10 THEN
    RAISE EXCEPTION 'Daily complaint limit reached';
  END IF;

  INSERT INTO public.srk_booking_complaints
    (booking_id,customer_user_id,reporter_role,reported_by_user_id,category,description)
  VALUES
    (p_booking_id,NULL,'technician',v_technician_user_id,p_category,btrim(p_description))
  RETURNING id INTO v_complaint_id;

  INSERT INTO public.srk_booking_complaint_events
    (complaint_id,actor_user_id,actor_role,from_status,to_status,note)
  VALUES (v_complaint_id,v_technician_user_id,'technician',NULL,'new','Technician ने शिकायत दर्ज की');

  RETURN v_complaint_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_technician_list_booking_complaints()
RETURNS TABLE(
  id uuid, booking_id uuid, category text, description text, status text,
  admin_note text, created_at timestamptz, updated_at timestamptz,
  resolved_at timestamptz, activity jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Technician login required' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
    SELECT c.id,c.booking_id,c.category,c.description,c.status,c.admin_note,
           c.created_at,c.updated_at,c.resolved_at,
           COALESCE((
             SELECT jsonb_agg(jsonb_build_object(
               'actor_role',e.actor_role,'from_status',e.from_status,'to_status',e.to_status,
               'note',e.note,'created_at',e.created_at
             ) ORDER BY e.created_at ASC)
             FROM public.srk_booking_complaint_events e
             WHERE e.complaint_id=c.id
           ),'[]'::jsonb)
      FROM public.srk_booking_complaints c
     WHERE c.reported_by_user_id=auth.uid()
       AND c.reporter_role='technician'
     ORDER BY c.created_at DESC
     LIMIT 100;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_list_booking_complaints(p_limit integer DEFAULT 100)
RETURNS TABLE(
  id uuid, booking_id uuid, customer_name text, customer_phone text,
  service_type text, category text, description text, status text,
  admin_note text, created_at timestamptz, updated_at timestamptz,
  resolved_at timestamptz, activity jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
    SELECT c.id,c.booking_id,b.customer_name,b.phone,b.service_type,
           c.category,c.description,c.status,c.admin_note,c.created_at,
           c.updated_at,c.resolved_at,
           COALESCE((
             SELECT jsonb_agg(jsonb_build_object(
               'actor_role',e.actor_role,
               'actor_user_id',e.actor_user_id,
               'from_status',e.from_status,'to_status',e.to_status,
               'note',e.note,'created_at',e.created_at
             ) ORDER BY e.created_at ASC)
             FROM public.srk_booking_complaint_events e
             WHERE e.complaint_id=c.id
           ),'[]'::jsonb)
      FROM public.srk_booking_complaints c
      JOIN public.service_bookings b ON b.id=c.booking_id
     ORDER BY c.created_at DESC
     LIMIT GREATEST(1,LEAST(COALESCE(p_limit,100),300));
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_technician_create_booking_complaint(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_create_booking_complaint(uuid,text,text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.srk_technician_list_booking_complaints() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_list_booking_complaints() TO authenticated, service_role;
