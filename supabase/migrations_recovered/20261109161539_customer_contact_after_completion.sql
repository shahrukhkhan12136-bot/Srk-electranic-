-- SRK ELECTRONIC: keep reciprocal phone visibility after a booking is completed.
-- Apply only after Supabase migration history has been reconciled and this
-- function replacement has been reviewed in the target project.
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
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  RETURN QUERY
  SELECT b.id, b.status, ep.display_name, ep.phone
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
      'in_progress',
      'completed'
    );
END;
$function$;
