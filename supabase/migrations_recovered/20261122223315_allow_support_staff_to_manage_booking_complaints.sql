
CREATE OR REPLACE FUNCTION public.srk_admin_list_booking_complaints(p_limit integer DEFAULT 100)
RETURNS TABLE(id uuid, booking_id uuid, customer_name text, customer_phone text, service_type text, category text, description text, status text, admin_note text, created_at timestamp with time zone, updated_at timestamp with time zone, resolved_at timestamp with time zone, activity jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.srk_has_admin_permission('support.manage') THEN
    RAISE EXCEPTION 'Support permission required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT c.id,c.booking_id,b.customer_name,b.phone,b.service_type,
           c.category,c.description,c.status,c.admin_note,c.created_at,
           c.updated_at,c.resolved_at,
           COALESCE((
             SELECT jsonb_agg(jsonb_build_object(
               'actor_role',e.actor_role,'actor_user_id',e.actor_user_id,
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

CREATE OR REPLACE FUNCTION public.srk_admin_update_booking_complaint(
  p_complaint_id uuid, p_status text, p_admin_note text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_admin_id uuid := auth.uid();
  v_row public.srk_booking_complaints%rowtype;
  v_note text := NULLIF(btrim(p_admin_note),'');
BEGIN
  IF v_admin_id IS NULL OR NOT public.srk_has_admin_permission('support.manage') THEN
    RAISE EXCEPTION 'Support permission required' USING ERRCODE='42501';
  END IF;
  IF p_complaint_id IS NULL OR p_status NOT IN ('new','in_review','resolved','closed')
     OR (p_admin_note IS NOT NULL AND length(p_admin_note)>2000) THEN
    RAISE EXCEPTION 'Invalid complaint update';
  END IF;
  SELECT * INTO v_row FROM public.srk_booking_complaints
   WHERE id=p_complaint_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Complaint not found'; END IF;

  UPDATE public.srk_booking_complaints
     SET status=p_status, admin_note=COALESCE(v_note,admin_note),
         updated_at=pg_catalog.now(), updated_by=v_admin_id,
         resolved_at=CASE WHEN p_status IN ('resolved','closed') THEN COALESCE(resolved_at,pg_catalog.now()) ELSE NULL END,
         resolved_by=CASE WHEN p_status IN ('resolved','closed') THEN COALESCE(resolved_by,v_admin_id) ELSE NULL END
   WHERE id=p_complaint_id;

  INSERT INTO public.srk_booking_complaint_events
    (complaint_id,actor_user_id,actor_role,from_status,to_status,note)
  VALUES (p_complaint_id,v_admin_id,'admin',v_row.status,p_status,v_note);

  RETURN pg_catalog.jsonb_build_object('success',true,'complaint_id',p_complaint_id,'status',p_status);
END;
$function$;
