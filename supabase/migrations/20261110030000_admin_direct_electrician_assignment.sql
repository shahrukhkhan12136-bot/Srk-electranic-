-- Admin-only direct electrician assignment. Assignment is serialized on the booking row.
CREATE OR REPLACE FUNCTION public.srk_admin_assign_electrician(
  p_booking_id uuid,
  p_electrician_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%rowtype;
  v_electrician public.electrician_profiles%rowtype;
  v_match_level text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL OR p_electrician_id IS NULL THEN
    RAISE EXCEPTION 'Booking and electrician are required';
  END IF;

  SELECT * INTO v_booking
  FROM public.service_bookings
  WHERE id=p_booking_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
  IF v_booking.assigned_electrician_id IS NOT NULL THEN
    RAISE EXCEPTION 'Booking already has an assigned electrician';
  END IF;
  IF v_booking.status NOT IN ('new','confirmed') THEN
    RAISE EXCEPTION 'Only new or confirmed bookings can be assigned';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.electrician_profiles e
    WHERE e.active=true AND e.verification_status='approved'
      AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
      AND e.pincode=v_booking.pincode
      AND lower(pg_catalog.btrim(e.state))=lower(pg_catalog.btrim(v_booking.state))
  ) THEN
    v_match_level := 'pincode';
  ELSE
    v_match_level := 'district';
  END IF;

  SELECT * INTO v_electrician
  FROM public.electrician_profiles
  WHERE id=p_electrician_id
  FOR SHARE;
  IF NOT FOUND OR v_electrician.active IS DISTINCT FROM true
     OR v_electrician.verification_status IS DISTINCT FROM 'approved'
     OR v_electrician.auth_user_id IS NULL
     OR v_electrician.user_id IS DISTINCT FROM v_electrician.auth_user_id THEN
    RAISE EXCEPTION 'Electrician must be active, approved, and OTP-linked';
  END IF;
  IF lower(pg_catalog.btrim(v_electrician.state)) <> lower(pg_catalog.btrim(v_booking.state))
     OR NOT (
       (v_match_level='pincode' AND v_electrician.pincode=v_booking.pincode)
       OR (v_match_level='district' AND lower(pg_catalog.btrim(v_electrician.district))=lower(pg_catalog.btrim(v_booking.district)))
     ) THEN
    RAISE EXCEPTION 'Electrician must match same PIN first, or district fallback when no same-PIN electrician is eligible';
  END IF;

  UPDATE public.service_bookings
  SET assigned_electrician_id=p_electrician_id, status='assigned'
  WHERE id=p_booking_id
    AND assigned_electrician_id IS NULL
    AND status IN ('new','confirmed');
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking assignment conflict'; END IF;

  UPDATE public.job_offers
  SET status='expired', responded_at=COALESCE(responded_at,pg_catalog.now())
  WHERE booking_id=p_booking_id AND status IN ('offered','accepted');

  RETURN pg_catalog.jsonb_build_object(
    'success',true,'booking_id',p_booking_id,'electrician_id',p_electrician_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_assign_electrician(uuid,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.srk_admin_assign_electrician(uuid,uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_assign_electrician(uuid,uuid) TO authenticated;
