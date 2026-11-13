DROP FUNCTION IF EXISTS public.srk_get_my_offer_details();
CREATE FUNCTION public.srk_get_my_offer_details()
RETURNS TABLE(offer_id uuid, offer_status text, match_level text, offer_created_at timestamptz, booking_id uuid, service_type text, state text, district text, pincode text, preferred_date date, preferred_time time, work_details text, quoted_amount numeric, booking_status text, customer_name text, customer_phone text, address text, location_lat double precision, location_lng double precision)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog','public','auth','pg_temp' AS $function$
 SELECT o.id,o.status,o.match_level,o.created_at,b.id,b.service_type,b.state,b.district,b.pincode,b.preferred_date,b.preferred_time,b.work_details,b.quoted_amount,b.status,
 CASE WHEN b.assigned_electrician_id=p.id AND b.status IN ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed') THEN b.customer_name ELSE NULL END,
 CASE WHEN b.assigned_electrician_id=p.id AND b.status IN ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed') THEN b.phone ELSE NULL END,
 CASE WHEN b.assigned_electrician_id=p.id AND b.status IN ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed') THEN b.address ELSE NULL END,
 CASE WHEN b.assigned_electrician_id=p.id AND b.status IN ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed') THEN b.location_lat ELSE NULL END,
 CASE WHEN b.assigned_electrician_id=p.id AND b.status IN ('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed') THEN b.location_lng ELSE NULL END
 FROM public.job_offers o JOIN public.electrician_profiles p ON p.id=o.electrician_id JOIN public.service_bookings b ON b.id=o.booking_id
 WHERE p.user_id=auth.uid() AND p.verification_status='approved' AND p.active=true ORDER BY o.created_at DESC LIMIT 100;
$function$;
REVOKE ALL ON FUNCTION public.srk_get_my_offer_details() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_offer_details() TO authenticated;
