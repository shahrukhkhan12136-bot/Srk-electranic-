-- Replace the legacy-only Technician offer read with one shared legacy + Master projection.
-- Customer identity and work address remain hidden until the Master assignment is fully accepted.
DROP FUNCTION IF EXISTS public.srk_get_my_offer_details();
CREATE FUNCTION public.srk_get_my_offer_details()
RETURNS TABLE(
 offer_id uuid,offer_status text,match_level text,offer_created_at timestamptz,offer_expires_at timestamptz,
 booking_id uuid,service_type text,state text,district text,pincode text,work_details text,quoted_amount numeric,
 booking_status text,selected_category text,selected_rate_tier text,selected_duration_hours smallint,
 estimated_labour_paise bigint,work_start_approval_status text,completion_approval_status text,
 customer_name text,customer_phone text,address text,location_lat double precision,location_lng double precision,
 service_charge numeric,materials_amount numeric,quote_status text,quote_note text,
 offer_source text,srk_service_category_code text,srk_service_skill_code text,srk_service_code text,
 srk_rate_level_code text,srk_rate_version_snapshot text,srk_billing_model_snapshot text,
 srk_duration_minutes integer,srk_service_quantity integer,srk_required_technician_count smallint,
 srk_helper_included_snapshot boolean,srk_estimated_labour_paise bigint,
 workday_id uuid,workday_status text,workday_elapsed_seconds numeric,workday_lunch_ends_at timestamptz,
 workday_normal_seconds numeric,workday_overtime_seconds numeric
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
 SELECT o.id,o.status,o.match_level,o.created_at,o.expires_at,b.id,b.service_type,b.state,b.district,b.pincode,
  b.work_details,b.quoted_amount,b.status,b.selected_category,b.selected_rate_tier,b.selected_duration_hours,
  b.estimated_labour_paise,b.work_start_approval_status,b.completion_approval_status,
  CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
   ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
    'awaiting_work_start_approval','in_progress','completed','cancelled') THEN b.customer_name ELSE NULL END,
  CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
   ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
    'awaiting_work_start_approval','in_progress','completed','cancelled') THEN b.phone ELSE NULL END,
  CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
   ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
    'awaiting_work_start_approval','in_progress','completed','cancelled') THEN b.address ELSE NULL END,
  CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
   ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
    'awaiting_work_start_approval','in_progress','completed','cancelled') THEN b.location_lat ELSE NULL END,
  CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
   ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
    'awaiting_work_start_approval','in_progress','completed','cancelled') THEN b.location_lng ELSE NULL END,
  CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
   ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
    'awaiting_work_start_approval','in_progress','completed','cancelled') THEN b.service_charge ELSE NULL END,
  CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
   ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
    'awaiting_work_start_approval','in_progress','completed','cancelled') THEN b.materials_amount ELSE NULL END,
  CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
   ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
    'awaiting_work_start_approval','in_progress','completed','cancelled') THEN b.quote_status ELSE NULL END,
  CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
   ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected',
    'awaiting_work_start_approval','in_progress','completed','cancelled') THEN b.quote_note ELSE NULL END,
  'legacy',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
 FROM public.job_offers o
 JOIN public.electrician_profiles p ON p.id=o.electrician_id
 JOIN public.service_bookings b ON b.id=o.booking_id
 WHERE auth.uid() IS NOT NULL AND (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
  AND p.verification_status='approved' AND p.active=true
 UNION ALL
 SELECT o.id,o.status,o.match_level,o.offered_at,o.expires_at,b.id,b.service_type,b.state,b.district,b.pincode,
  b.work_details,b.quoted_amount,b.status,NULL::text,NULL::text,NULL::smallint,b.srk_estimated_labour_paise,
  b.work_start_approval_status,b.completion_approval_status,
  CASE WHEN b.status IN ('assigned','awaiting_work_start_approval','in_progress','completed','cancelled')
        AND a.assignment_status IN ('accepted','active','completed') THEN b.customer_name ELSE NULL END,
  CASE WHEN b.status IN ('assigned','awaiting_work_start_approval','in_progress','completed','cancelled')
        AND a.assignment_status IN ('accepted','active','completed') THEN b.phone ELSE NULL END,
  CASE WHEN b.status IN ('assigned','awaiting_work_start_approval','in_progress','completed','cancelled')
        AND a.assignment_status IN ('accepted','active','completed') THEN b.address ELSE NULL END,
  CASE WHEN b.status IN ('assigned','awaiting_work_start_approval','in_progress','completed','cancelled')
        AND a.assignment_status IN ('accepted','active','completed') THEN b.location_lat ELSE NULL END,
  CASE WHEN b.status IN ('assigned','awaiting_work_start_approval','in_progress','completed','cancelled')
        AND a.assignment_status IN ('accepted','active','completed') THEN b.location_lng ELSE NULL END,
  NULL::numeric,NULL::numeric,NULL::text,NULL::text,'master',b.srk_service_category_code,b.srk_service_skill_code,
  b.srk_service_code,b.srk_rate_level_code,b.srk_rate_version_snapshot,b.srk_billing_model_snapshot,
  b.srk_duration_minutes,b.srk_service_quantity,b.srk_required_technician_count,
  b.srk_helper_included_snapshot,b.srk_estimated_labour_paise,
  w.id,w.status,
  CASE WHEN w.status='running' THEN w.accumulated_work_seconds+
    greatest(extract(epoch FROM (clock_timestamp()-w.running_started_at)),0)
   WHEN w.status='lunch_paused' THEN 14400 ELSE w.accumulated_work_seconds END,
  w.lunch_ends_at,w.normal_work_seconds,w.overtime_work_seconds
 FROM public.srk_technician_dispatch_offers o
 JOIN public.srk_technicians t ON t.id=o.technician_id
 JOIN public.srk_technician_applications app ON app.technician_id=t.id AND app.status='approved'
 JOIN public.service_bookings b ON b.id=o.booking_id
 LEFT JOIN public.srk_booking_technician_assignments a
  ON a.booking_id=b.id AND a.technician_id=t.id
 LEFT JOIN LATERAL (
  SELECT wd.* FROM public.srk_booking_technician_workdays wd
  WHERE wd.booking_id=b.id AND wd.technician_id=t.id
  ORDER BY wd.work_date DESC,wd.id DESC LIMIT 1
 ) w ON true
 WHERE auth.uid() IS NOT NULL AND t.auth_user_id=auth.uid() AND t.account_status='active'
  AND (o.status='offered' OR a.assignment_status IN ('accepted','active','completed'))
 ORDER BY offer_created_at DESC
 LIMIT 100;
$function$;
REVOKE ALL ON FUNCTION public.srk_get_my_offer_details() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_offer_details() TO authenticated;
COMMENT ON FUNCTION public.srk_get_my_offer_details() IS
 'Shared Technician App offer feed. Combines legacy Electrician and category-neutral Master dispatch offers; reveals customer contact and address only after a full Master assignment.';
