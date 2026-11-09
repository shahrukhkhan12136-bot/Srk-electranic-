-- Tighten input checks on the validated Admin booking RPC.
CREATE OR REPLACE FUNCTION public.srk_admin_update_booking(
  p_booking_id uuid, p_status text, p_address text, p_district text, p_state text, p_pincode text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE v_booking public.service_bookings%rowtype;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'Admin permission required'; END IF;
  IF p_booking_id IS NULL THEN RAISE EXCEPTION 'Booking ID required'; END IF;
  IF p_address IS NULL OR length(pg_catalog.btrim(p_address))=0 OR length(p_address)>300
     OR p_district IS NULL OR length(pg_catalog.btrim(p_district))=0 OR length(p_district)>80
     OR p_state IS NULL OR length(pg_catalog.btrim(p_state))=0 OR length(p_state)>80
     OR p_pincode IS NULL OR p_pincode !~ '^[0-9]{6}$' THEN RAISE EXCEPTION 'Valid address, district, state and six-digit PIN required'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
  IF p_status IS NOT NULL THEN
    IF p_status NOT IN ('new','confirmed','assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed','cancelled') THEN RAISE EXCEPTION 'Invalid booking status'; END IF;
    IF v_booking.status='new' AND p_status NOT IN ('new','confirmed','cancelled') THEN RAISE EXCEPTION 'New booking can only remain new, be confirmed, or cancelled';
    ELSIF v_booking.status='confirmed' AND p_status NOT IN ('confirmed','cancelled') THEN RAISE EXCEPTION 'Confirmed booking can only remain confirmed or be cancelled';
    ELSIF v_booking.status NOT IN ('new','confirmed') AND p_status NOT IN (v_booking.status,'cancelled') THEN RAISE EXCEPTION 'Admin cannot skip booking workflow stages'; END IF;
    IF p_status='assigned' AND v_booking.assigned_electrician_id IS NULL THEN RAISE EXCEPTION 'Electrician assignment required'; END IF;
    IF p_status='cancelled' AND v_booking.payment_status='paid' THEN RAISE EXCEPTION 'Paid booking requires the verified refund workflow before cancellation'; END IF;
  END IF;
  UPDATE public.service_bookings SET status=COALESCE(p_status,status),address=pg_catalog.btrim(p_address),
    district=pg_catalog.btrim(p_district),state=pg_catalog.btrim(p_state),pincode=p_pincode WHERE id=p_booking_id;
  RETURN pg_catalog.jsonb_build_object('success',true);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_update_booking(uuid,text,text,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.srk_admin_update_booking(uuid,text,text,text,text,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_update_booking(uuid,text,text,text,text,text) TO authenticated;
