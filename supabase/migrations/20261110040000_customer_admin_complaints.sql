-- Customer complaint intake and Admin-only complaint management.
CREATE TABLE IF NOT EXISTS public.srk_booking_complaints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  customer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  category text NOT NULL CHECK (category IN ('service_quality','electrician_behavior','billing_payment','delay_no_show','safety','other')),
  description text NOT NULL CHECK (length(btrim(description)) BETWEEN 20 AND 2000),
  status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','in_review','resolved','closed')),
  admin_note text CHECK (admin_note IS NULL OR length(admin_note) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  updated_by uuid REFERENCES auth.users(id),
  resolved_by uuid REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS public.srk_booking_complaint_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id uuid NOT NULL REFERENCES public.srk_booking_complaints(id) ON DELETE CASCADE,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  actor_role text NOT NULL CHECK (actor_role IN ('customer','admin')),
  from_status text CHECK (from_status IS NULL OR from_status IN ('new','in_review','resolved','closed')),
  to_status text NOT NULL CHECK (to_status IN ('new','in_review','resolved','closed')),
  note text CHECK (note IS NULL OR length(note) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS srk_booking_complaint_events_complaint_idx
  ON public.srk_booking_complaint_events (complaint_id, created_at ASC);
ALTER TABLE public.srk_booking_complaint_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_booking_complaint_events FROM PUBLIC, anon, authenticated;

CREATE INDEX IF NOT EXISTS srk_booking_complaints_created_idx
  ON public.srk_booking_complaints (created_at DESC);
CREATE INDEX IF NOT EXISTS srk_booking_complaints_booking_idx
  ON public.srk_booking_complaints (booking_id, created_at DESC);
CREATE INDEX IF NOT EXISTS srk_booking_complaints_status_idx
  ON public.srk_booking_complaints (status, created_at DESC);

ALTER TABLE public.srk_booking_complaints ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_booking_complaints FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.srk_customer_create_booking_complaint(
  p_booking_id uuid,
  p_category text,
  p_description text
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
       WHERE c.customer_user_id=v_customer_id
         AND c.created_at >= pg_catalog.now() - interval '24 hours') >= 10 THEN
    RAISE EXCEPTION 'Daily complaint limit reached';
  END IF;

  INSERT INTO public.srk_booking_complaints
    (booking_id,customer_user_id,category,description)
  VALUES
    (p_booking_id,v_customer_id,p_category,btrim(p_description))
  RETURNING id INTO v_complaint_id;

  INSERT INTO public.srk_booking_complaint_events
    (complaint_id,actor_user_id,actor_role,from_status,to_status,note)
  VALUES (v_complaint_id,v_customer_id,'customer',NULL,'new','ग्राहक ने शिकायत दर्ज की');

  RETURN v_complaint_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_list_booking_complaints()
RETURNS TABLE (
  id uuid,
  booking_id uuid,
  category text,
  description text,
  status text,
  admin_note text,
  created_at timestamptz,
  updated_at timestamptz,
  resolved_at timestamptz,
  activity jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Customer login required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT c.id,c.booking_id,c.category,c.description,c.status,c.admin_note,
           c.created_at,c.updated_at,c.resolved_at,
           COALESCE((SELECT jsonb_agg(jsonb_build_object(
             'actor_role',e.actor_role,'from_status',e.from_status,'to_status',e.to_status,
             'note',e.note,'created_at',e.created_at) ORDER BY e.created_at ASC)
             FROM public.srk_booking_complaint_events e WHERE e.complaint_id=c.id),'[]'::jsonb)
      FROM public.srk_booking_complaints c
     WHERE c.customer_user_id=auth.uid()
     ORDER BY c.created_at DESC
     LIMIT 100;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_list_booking_complaints(p_limit integer DEFAULT 100)
RETURNS TABLE (
  id uuid,
  booking_id uuid,
  customer_name text,
  customer_phone text,
  service_type text,
  category text,
  description text,
  status text,
  admin_note text,
  created_at timestamptz,
  updated_at timestamptz,
  resolved_at timestamptz,
  activity jsonb
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
           COALESCE((SELECT jsonb_agg(jsonb_build_object(
             'actor_role',e.actor_role,'from_status',e.from_status,'to_status',e.to_status,
             'note',e.note,'created_at',e.created_at) ORDER BY e.created_at ASC)
             FROM public.srk_booking_complaint_events e WHERE e.complaint_id=c.id),'[]'::jsonb)
      FROM public.srk_booking_complaints c
      JOIN public.service_bookings b ON b.id=c.booking_id
     ORDER BY c.created_at DESC
     LIMIT GREATEST(1,LEAST(COALESCE(p_limit,100),300));
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_update_booking_complaint(
  p_complaint_id uuid,
  p_status text,
  p_admin_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_admin_id uuid := auth.uid();
  v_row public.srk_booking_complaints%rowtype;
  v_note text := NULLIF(btrim(p_admin_note),'');
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501';
  END IF;
  IF p_complaint_id IS NULL OR p_status NOT IN ('new','in_review','resolved','closed')
     OR (p_admin_note IS NOT NULL AND length(p_admin_note)>2000) THEN
    RAISE EXCEPTION 'Invalid complaint update';
  END IF;
  SELECT * INTO v_row
    FROM public.srk_booking_complaints
   WHERE id=p_complaint_id
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Complaint not found'; END IF;

  UPDATE public.srk_booking_complaints
     SET status=p_status,
         admin_note=COALESCE(v_note,admin_note),
         updated_at=pg_catalog.now(),
         updated_by=v_admin_id,
         resolved_at=CASE WHEN p_status IN ('resolved','closed') THEN COALESCE(resolved_at,pg_catalog.now()) ELSE NULL END,
         resolved_by=CASE WHEN p_status IN ('resolved','closed') THEN COALESCE(resolved_by,v_admin_id) ELSE NULL END
   WHERE id=p_complaint_id;

  INSERT INTO public.srk_booking_complaint_events
    (complaint_id,actor_user_id,actor_role,from_status,to_status,note)
  VALUES (p_complaint_id,v_admin_id,'admin',v_row.status,p_status,v_note);

  RETURN pg_catalog.jsonb_build_object('success',true,'complaint_id',p_complaint_id,'status',p_status);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_customer_create_booking_complaint(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_create_booking_complaint(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_customer_list_booking_complaints() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_list_booking_complaints() TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_list_booking_complaints(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_booking_complaints(integer) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_update_booking_complaint(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_update_booking_complaint(uuid,text,text) TO authenticated;
