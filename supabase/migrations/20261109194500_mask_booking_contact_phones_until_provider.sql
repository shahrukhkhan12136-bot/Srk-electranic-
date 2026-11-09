-- Keep both parties' real phone numbers out of booking contact RPC results
-- until the OTP-verified masked-calling provider is enabled and tested.
-- Existing function signatures and grants are preserved.

CREATE OR REPLACE FUNCTION private.srk_get_customer_call_contacts_impl()
RETURNS TABLE(
  booking_id uuid,
  booking_status text,
  electrician_name text,
  electrician_phone text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.status,
    ep.display_name,
    NULL::text AS electrician_phone
  FROM public.service_bookings b
  JOIN public.electrician_profiles ep
    ON ep.id = b.assigned_electrician_id
  WHERE b.customer_user_id = v_uid
    AND b.assigned_electrician_id IS NOT NULL
    AND b.status IN (
      'assigned',
      'inspection',
      'awaiting_quote_approval',
      'quote_approved',
      'in_progress'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_get_my_offer_details()
RETURNS TABLE(
  offer_id uuid,
  offer_status text,
  match_level text,
  offer_created_at timestamp with time zone,
  booking_id uuid,
  service_type text,
  state text,
  district text,
  pincode text,
  preferred_date date,
  preferred_time time without time zone,
  work_details text,
  quoted_amount numeric,
  booking_status text,
  customer_name text,
  customer_phone text,
  address text,
  location_lat double precision,
  location_lng double precision,
  service_charge numeric,
  materials_amount numeric,
  quote_status text,
  quote_note text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
  SELECT
    o.id,
    o.status,
    o.match_level,
    o.created_at,
    b.id,
    b.service_type,
    b.state,
    b.district,
    b.pincode,
    b.preferred_date,
    b.preferred_time,
    b.work_details,
    b.quoted_amount,
    b.status,
    CASE WHEN b.assigned_electrician_id = p.id THEN b.customer_name ELSE NULL END,
    NULL::text AS customer_phone,
    CASE WHEN b.assigned_electrician_id = p.id THEN b.address ELSE NULL END,
    CASE WHEN b.assigned_electrician_id = p.id THEN b.location_lat ELSE NULL END,
    CASE WHEN b.assigned_electrician_id = p.id THEN b.location_lng ELSE NULL END,
    CASE WHEN b.assigned_electrician_id = p.id THEN b.service_charge ELSE NULL END,
    CASE WHEN b.assigned_electrician_id = p.id THEN b.materials_amount ELSE NULL END,
    CASE WHEN b.assigned_electrician_id = p.id THEN b.quote_status ELSE NULL END,
    CASE WHEN b.assigned_electrician_id = p.id THEN b.quote_note ELSE NULL END
  FROM public.job_offers o
  JOIN public.electrician_profiles p ON p.id = o.electrician_id
  JOIN public.service_bookings b ON b.id = o.booking_id
  WHERE p.user_id = auth.uid()
    AND p.verification_status = 'approved'
    AND p.active = true
  ORDER BY o.created_at DESC
  LIMIT 100;
$function$;
