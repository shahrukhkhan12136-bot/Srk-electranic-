-- Retire live legacy quotation RPCs and remove quotation projections from electrician offers.
-- Historical booking rows and paid financial evidence are intentionally preserved.
-- Feature-branch source only: never apply to Production without explicit owner approval.

REVOKE ALL ON FUNCTION public.srk_submit_booking_quote(uuid,numeric,numeric,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.srk_customer_respond_booking_quote(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.srk_update_booking_work_status(uuid,text) FROM PUBLIC, anon, authenticated;

DROP FUNCTION IF EXISTS public.srk_submit_booking_quote(uuid,numeric,numeric,text);
DROP FUNCTION IF EXISTS public.srk_customer_respond_booking_quote(uuid,text);
DROP FUNCTION IF EXISTS public.srk_update_booking_work_status(uuid,text);

DROP FUNCTION IF EXISTS public.srk_get_my_offer_details();
CREATE FUNCTION public.srk_get_my_offer_details()
RETURNS TABLE(
  offer_id uuid,offer_status text,match_level text,offer_created_at timestamptz,
  booking_id uuid,service_type text,state text,district text,pincode text,
  preferred_date date,preferred_time time,work_details text,
  booking_status text,customer_name text,customer_phone text,address text,
  location_lat double precision,location_lng double precision,
  selected_category text,selected_duration_hours smallint,selected_rate_tier text,
  work_start_approval_status text,completion_approval_status text,
  completion_requested_at timestamptz,work_timer_elapsed_seconds numeric,
  work_started_at timestamptz,work_timer_running boolean
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
  SELECT o.id,o.status,o.match_level,o.created_at,b.id,b.service_type,b.state,b.district,b.pincode,
    b.preferred_date,b.preferred_time,b.work_details,b.status,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.customer_name ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.phone ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.address ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.location_lat ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.location_lng ELSE NULL END,
    b.selected_category,b.selected_duration_hours,b.selected_rate_tier,
    b.work_start_approval_status,b.completion_approval_status,b.completion_requested_at,
    b.work_timer_elapsed_seconds,b.work_started_at,b.work_timer_running
  FROM public.job_offers o
  JOIN public.electrician_profiles p ON p.id=o.electrician_id
  JOIN public.service_bookings b ON b.id=o.booking_id
  WHERE (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved' AND p.active=true
  ORDER BY o.created_at DESC LIMIT 100;
$function$;
REVOKE ALL ON FUNCTION public.srk_get_my_offer_details() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_offer_details() TO authenticated;
COMMENT ON FUNCTION public.srk_get_my_offer_details() IS
'Returns active electrician offer and server-timed booking fields only; legacy quotation projections are retired. Historical booking/payment records remain preserved.';
