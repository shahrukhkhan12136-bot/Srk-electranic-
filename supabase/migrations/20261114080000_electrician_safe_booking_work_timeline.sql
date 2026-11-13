-- Electrician-safe read-only access to the immutable booking work-event timeline.
-- Exposes only events for bookings assigned to the authenticated electrician profile.

CREATE OR REPLACE FUNCTION public.srk_electrician_get_my_booking_work_timeline()
RETURNS TABLE(
  booking_id uuid,
  event_id bigint,
  event_type text,
  actor_role text,
  old_status text,
  new_status text,
  occurred_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT e.booking_id,e.id,e.event_type,e.actor_role,e.old_status,e.new_status,e.occurred_at
  FROM public.srk_booking_work_events e
  JOIN public.service_bookings b ON b.id=e.booking_id
  WHERE EXISTS (
    SELECT 1
    FROM public.electrician_profiles ep
    WHERE ep.id=b.assigned_electrician_id
      AND (ep.user_id=auth.uid() OR ep.auth_user_id=auth.uid())
  )
  ORDER BY e.booking_id,e.occurred_at,e.id;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_electrician_get_my_booking_work_timeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_get_my_booking_work_timeline() TO authenticated;

COMMENT ON FUNCTION public.srk_electrician_get_my_booking_work_timeline() IS
  'Returns only minimal immutable work-event timeline rows for bookings assigned to the authenticated electrician profile; excludes actor IDs and private event details.';
