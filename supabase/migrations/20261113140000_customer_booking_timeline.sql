-- SRK ELECTRONIC: expose a read-only, customer-owned booking status timeline.
-- The history table remains private to admins and service_role for direct table access.
-- Customers receive only status labels and timestamps for bookings they own.
CREATE OR REPLACE FUNCTION public.srk_get_customer_booking_timeline()
RETURNS TABLE (
  booking_id uuid,
  old_status text,
  new_status text,
  changed_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
  SELECT h.booking_id, h.old_status, h.new_status, h.changed_at
  FROM public.service_booking_status_history h
  INNER JOIN public.service_bookings b ON b.id = h.booking_id
  WHERE auth.uid() IS NOT NULL
    AND b.customer_user_id = auth.uid()
  ORDER BY h.changed_at ASC
  LIMIT 1000;
$function$;

REVOKE ALL ON FUNCTION public.srk_get_customer_booking_timeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_get_customer_booking_timeline() TO authenticated;
