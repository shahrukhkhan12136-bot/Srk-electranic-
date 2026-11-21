-- Complete shared Technician application read, customer workday decisions, and Admin dispatch visibility.
DROP FUNCTION IF EXISTS public.srk_technician_get_my_applications();
CREATE FUNCTION public.srk_technician_get_my_applications()
RETURNS TABLE(application_id uuid,technician_id uuid,full_name text,address text,district text,state text,pincode text,
 experience_years integer,about text,status text,rejection_reason text,submitted_at timestamptz,
 categories jsonb,skills jsonb,kyc jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid();v_technician_id uuid;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501';END IF;
 SELECT t.id INTO v_technician_id FROM public.srk_technicians t WHERE t.auth_user_id=v_uid;
 IF v_technician_id IS NULL THEN RETURN;END IF;
 RETURN QUERY
 SELECT a.id,a.technician_id,a.full_name,a.address,a.district,a.state,a.pincode,a.experience_years,a.about,
  a.status,a.rejection_reason,a.submitted_at,
  COALESCE((SELECT jsonb_agg(jsonb_build_object('code',c.category_code,'name',c.display_name)
   ORDER BY c.sort_order,c.category_code)
   FROM public.srk_technician_application_categories ac
   JOIN public.srk_service_categories c ON c.id=ac.category_id WHERE ac.application_id=a.id),'[]'::jsonb),
  COALESCE((SELECT jsonb_agg(jsonb_build_object('application_skill_id',aps.id,'code',s.skill_code,
   'name',s.display_name,'review_status',aps.review_status,'admin_note',aps.admin_note)
   ORDER BY s.skill_code)
   FROM public.srk_technician_application_skills aps
   JOIN public.srk_service_skills s ON s.id=aps.skill_id WHERE aps.application_id=a.id),'[]'::jsonb),
  COALESCE((SELECT jsonb_agg(jsonb_build_object('id',d.id,'document_type',d.document_type,
   'file_name',d.file_name,'review_status',d.review_status,'admin_note',d.admin_note,
   'uploaded_at',d.uploaded_at,'reviewed_at',d.reviewed_at)
   ORDER BY d.uploaded_at DESC)
   FROM public.srk_technician_kyc_documents d WHERE d.application_id=a.id),'[]'::jsonb)
 FROM public.srk_technician_applications a WHERE a.technician_id=v_technician_id
 ORDER BY a.submitted_at DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_get_my_applications() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_get_my_applications() TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_customer_get_technician_workdays(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid();v_result jsonb;v_workday_id uuid;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'CUSTOMER_LOGIN_REQUIRED' USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.service_bookings WHERE id=p_booking_id AND customer_user_id=v_uid) THEN
  RAISE EXCEPTION 'OWN_CUSTOMER_BOOKING_REQUIRED' USING ERRCODE='42501';
 END IF;
 FOR v_workday_id IN SELECT w.id FROM public.srk_booking_technician_workdays w
  WHERE w.booking_id=p_booking_id AND w.status IN ('running','lunch_paused') ORDER BY w.id
 LOOP PERFORM srk_private.srk_normalize_technician_workday_lunch(v_workday_id);END LOOP;
 SELECT COALESCE(jsonb_agg(jsonb_build_object(
  'workday_id',w.id,'technician_id',w.technician_id,'work_date',w.work_date,
  'status',w.status,'start_requested_at',w.start_requested_at,'customer_approved_at',w.customer_approved_at,
  'accumulated_work_seconds',CASE WHEN w.status='running' THEN w.accumulated_work_seconds+
    greatest(extract(epoch FROM (clock_timestamp()-w.running_started_at)),0)
    WHEN w.status='lunch_paused' THEN 14400 ELSE w.accumulated_work_seconds END,
  'lunch_ends_at',w.lunch_ends_at,'normal_work_seconds',w.normal_work_seconds,
  'overtime_work_seconds',w.overtime_work_seconds,
  'customer_decision',(SELECT d.decision FROM public.srk_booking_workday_customer_decisions d
    WHERE d.booking_id=w.booking_id AND d.work_date=w.work_date)
 ) ORDER BY w.work_date,w.technician_id),'[]'::jsonb)
 INTO v_result FROM public.srk_booking_technician_workdays w WHERE w.booking_id=p_booking_id;
 RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_customer_get_technician_workdays(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_technician_workdays(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_get_my_presence()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_tid uuid;v_result jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501';END IF;
 SELECT t.id INTO v_tid FROM public.srk_technicians t
 WHERE t.auth_user_id=auth.uid() AND t.account_status='active';
 IF v_tid IS NULL THEN RAISE EXCEPTION 'ACTIVE_TECHNICIAN_REQUIRED' USING ERRCODE='42501';END IF;
 SELECT jsonb_build_object('is_online',COALESCE(p.is_online,false),
  'active_booking_id',p.active_booking_id,'last_location_at',p.last_location_at)
 INTO v_result FROM public.srk_technician_presence p WHERE p.technician_id=v_tid;
 RETURN COALESCE(v_result,jsonb_build_object('is_online',false,'active_booking_id',NULL,'last_location_at',NULL));
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_get_my_presence() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_get_my_presence() TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_list_master_dispatch_queue(p_limit integer DEFAULT 200)
RETURNS TABLE(
 booking_id uuid,category_code text,skill_code text,service_code text,rate_level_code text,
 booking_status text,dispatch_status text,required_technician_count smallint,assigned_technician_count smallint,
 current_offer_technician_id uuid,current_offer_expires_at timestamptz,latest_event_type text,created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'INVALID_LIMIT' USING ERRCODE='22023';END IF;
 RETURN QUERY
 SELECT d.booking_id,d.category_code,d.skill_code,b.srk_service_code,b.srk_rate_level_code,
  b.status,d.status,d.required_technician_count,d.assigned_technician_count,
  o.technician_id,o.expires_at,e.event_type,d.created_at
 FROM public.srk_technician_dispatch_requests d
 JOIN public.service_bookings b ON b.id=d.booking_id
 LEFT JOIN public.srk_technician_dispatch_offers o ON o.id=d.current_offer_id
 LEFT JOIN LATERAL(SELECT ev.event_type FROM public.srk_technician_dispatch_events ev
  WHERE ev.dispatch_request_id=d.id ORDER BY ev.created_at DESC,ev.id DESC LIMIT 1)e ON true
 ORDER BY d.created_at DESC LIMIT p_limit;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_master_dispatch_queue(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_master_dispatch_queue(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_retry_master_dispatch(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE d public.srk_technician_dispatch_requests%rowtype;b public.service_bookings%rowtype;v_result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';END IF;
 IF p_booking_id IS NULL THEN RAISE EXCEPTION 'BOOKING_ID_REQUIRED' USING ERRCODE='22023';END IF;
 SELECT * INTO b FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND OR b.srk_service_category_code IS NULL OR b.status IN ('cancelled','completed') THEN
  RAISE EXCEPTION 'ACTIVE_MASTER_BOOKING_REQUIRED' USING ERRCODE='55000';
 END IF;
 SELECT * INTO d FROM public.srk_technician_dispatch_requests WHERE booking_id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'MASTER_DISPATCH_REQUEST_NOT_FOUND' USING ERRCODE='P0002';END IF;
 IF d.assigned_technician_count>=d.required_technician_count THEN
  RETURN jsonb_build_object('success',true,'status','assigned','assigned_technician_count',d.assigned_technician_count);
 END IF;
 UPDATE public.srk_technician_dispatch_requests SET status='searching',
  current_offer_id=CASE WHEN EXISTS(SELECT 1 FROM public.srk_technician_dispatch_offers o
    WHERE o.dispatch_request_id=d.id AND o.status='offered' AND o.expires_at>clock_timestamp())
    THEN d.current_offer_id ELSE NULL END,updated_at=clock_timestamp()
 WHERE id=d.id;
 v_result:=public.srk_dispatch_issue_next_offer(p_booking_id);
 RETURN jsonb_build_object('success',true,'dispatch',v_result);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_retry_master_dispatch(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_retry_master_dispatch(uuid) TO authenticated;
