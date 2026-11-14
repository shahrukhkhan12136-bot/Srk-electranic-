-- Consent-based, assignment-scoped live electrician location sharing.
-- Coordinates are written only after the electrician explicitly starts sharing.
-- Customer reads are limited to the owning booking and fresh active tracking sessions.

CREATE TABLE IF NOT EXISTS public.srk_booking_live_locations (
  booking_id uuid PRIMARY KEY REFERENCES public.service_bookings(id) ON DELETE CASCADE,
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  is_active boolean NOT NULL DEFAULT false,
  latitude double precision,
  longitude double precision,
  accuracy_meters numeric(9,2),
  updated_at timestamptz,
  started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  stopped_at timestamptz,
  CONSTRAINT srk_booking_live_locations_latitude_check
    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT srk_booking_live_locations_longitude_check
    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  CONSTRAINT srk_booking_live_locations_accuracy_check
    CHECK (accuracy_meters IS NULL OR accuracy_meters BETWEEN 0 AND 150),
  CONSTRAINT srk_booking_live_locations_active_payload_check
    CHECK (NOT is_active OR (latitude IS NOT NULL AND longitude IS NOT NULL
      AND accuracy_meters IS NOT NULL AND updated_at IS NOT NULL AND stopped_at IS NULL))
);
ALTER TABLE public.srk_booking_live_locations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_booking_live_locations FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.srk_booking_live_locations IS
  'Private, short-lived live GPS for an assigned booking; never stores electrician base/home coordinates.';

CREATE OR REPLACE FUNCTION public.srk_electrician_start_live_location(
  p_booking_id uuid, p_latitude double precision, p_longitude double precision,
  p_accuracy_meters numeric
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid(); v_profile public.electrician_profiles%ROWTYPE;
        v_booking public.service_bookings%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Electrician login required' USING ERRCODE='42501'; END IF;
  IF p_booking_id IS NULL OR p_latitude IS NULL OR p_longitude IS NULL
     OR p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180
     OR p_accuracy_meters IS NULL OR p_accuracy_meters NOT BETWEEN 0 AND 150 THEN
    RAISE EXCEPTION 'Valid GPS coordinates with accuracy of 150 metres or better are required' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_profile FROM public.electrician_profiles
    WHERE user_id=v_uid AND auth_user_id=v_uid AND active=true
      AND verification_status='approved' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Approved active electrician profile required' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings
    WHERE id=p_booking_id AND assigned_electrician_id=v_profile.id
      AND status='assigned' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Live location is available only for your currently assigned booking while travelling' USING ERRCODE='42501'; END IF;
  INSERT INTO public.srk_booking_live_locations
    (booking_id,electrician_profile_id,is_active,latitude,longitude,accuracy_meters,updated_at,started_at,stopped_at)
  VALUES(p_booking_id,v_profile.id,true,p_latitude,p_longitude,p_accuracy_meters,
         clock_timestamp(),clock_timestamp(),NULL)
  ON CONFLICT (booking_id) DO UPDATE
    SET electrician_profile_id=EXCLUDED.electrician_profile_id,
        is_active=true,latitude=EXCLUDED.latitude,longitude=EXCLUDED.longitude,
        accuracy_meters=EXCLUDED.accuracy_meters,updated_at=clock_timestamp(),
        started_at=CASE WHEN srk_booking_live_locations.electrician_profile_id IS DISTINCT FROM EXCLUDED.electrician_profile_id
          THEN clock_timestamp() ELSE srk_booking_live_locations.started_at END,
        stopped_at=NULL
    WHERE srk_booking_live_locations.stopped_at IS NULL
       OR srk_booking_live_locations.electrician_profile_id IS DISTINCT FROM EXCLUDED.electrician_profile_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Location sharing has already been stopped for this booking' USING ERRCODE='55000'; END IF;
  RETURN jsonb_build_object('success',true,'is_active',true,'updated_at',clock_timestamp());
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_electrician_update_live_location(
  p_booking_id uuid, p_latitude double precision, p_longitude double precision,
  p_accuracy_meters numeric
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid(); v_profile_id uuid; v_status text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Electrician login required' USING ERRCODE='42501'; END IF;
  IF p_booking_id IS NULL OR p_latitude IS NULL OR p_longitude IS NULL
     OR p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180
     OR p_accuracy_meters IS NULL OR p_accuracy_meters NOT BETWEEN 0 AND 150 THEN
    RAISE EXCEPTION 'GPS accuracy must be 150 metres or better' USING ERRCODE='22023';
  END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
    WHERE user_id=v_uid AND auth_user_id=v_uid AND active=true AND verification_status='approved';
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Approved active electrician profile required' USING ERRCODE='42501'; END IF;
  SELECT status INTO v_status FROM public.service_bookings
    WHERE id=p_booking_id AND assigned_electrician_id=v_profile_id;
  IF NOT FOUND OR v_status<>'assigned' THEN
    RAISE EXCEPTION 'This booking is no longer in the travel stage' USING ERRCODE='55000';
  END IF;
  UPDATE public.srk_booking_live_locations
    SET latitude=p_latitude,longitude=p_longitude,accuracy_meters=p_accuracy_meters,
        updated_at=clock_timestamp()
    WHERE booking_id=p_booking_id AND electrician_profile_id=v_profile_id
      AND is_active=true AND stopped_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Start live location sharing first' USING ERRCODE='55000'; END IF;
  RETURN jsonb_build_object('success',true,'updated_at',clock_timestamp());
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_electrician_stop_live_location(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid(); v_profile_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Electrician login required' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
    WHERE user_id=v_uid AND auth_user_id=v_uid;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Linked electrician profile required' USING ERRCODE='42501'; END IF;
  UPDATE public.srk_booking_live_locations
    SET is_active=false,latitude=NULL,longitude=NULL,accuracy_meters=NULL,
        updated_at=clock_timestamp(),stopped_at=COALESCE(stopped_at,clock_timestamp())
    WHERE booking_id=p_booking_id AND electrician_profile_id=v_profile_id;
  RETURN jsonb_build_object('success',true,'is_active',false);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_electrician_get_my_live_location_status(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid(); v_profile_id uuid; v_row public.srk_booking_live_locations%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Electrician login required' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
    WHERE user_id=v_uid AND auth_user_id=v_uid;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Linked electrician profile required' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_row FROM public.srk_booking_live_locations
    WHERE booking_id=p_booking_id AND electrician_profile_id=v_profile_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('is_active',false,'can_start',true); END IF;
  RETURN jsonb_build_object('is_active',v_row.is_active,'can_start',v_row.stopped_at IS NULL,
    'updated_at',v_row.updated_at);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_get_live_electrician_location(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid(); v_row public.srk_booking_live_locations%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Customer login required' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.service_bookings b
    WHERE b.id=p_booking_id AND b.customer_user_id=v_uid
      AND b.assigned_electrician_id IS NOT NULL AND b.status='assigned') THEN
    RAISE EXCEPTION 'Live location is not available for this booking' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_row FROM public.srk_booking_live_locations
    WHERE booking_id=p_booking_id AND is_active=true;
  IF NOT FOUND OR v_row.updated_at < clock_timestamp()-interval '90 seconds' THEN
    RETURN jsonb_build_object('is_active',false,'code','location_unavailable_or_stale');
  END IF;
  RETURN jsonb_build_object('is_active',true,'latitude',v_row.latitude,
    'longitude',v_row.longitude,'accuracy_meters',v_row.accuracy_meters,
    'updated_at',v_row.updated_at);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_stop_live_location_on_booking_transition()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status
     OR NEW.assigned_electrician_id IS DISTINCT FROM OLD.assigned_electrician_id THEN
    IF NEW.status<>'assigned' OR NEW.assigned_electrician_id IS NULL
       OR NEW.assigned_electrician_id IS DISTINCT FROM OLD.assigned_electrician_id THEN
      UPDATE public.srk_booking_live_locations
        SET is_active=false,latitude=NULL,longitude=NULL,accuracy_meters=NULL,
            updated_at=clock_timestamp(),stopped_at=COALESCE(stopped_at,clock_timestamp())
        WHERE booking_id=NEW.id AND is_active=true;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS srk_stop_live_location_on_booking_transition ON public.service_bookings;
CREATE TRIGGER srk_stop_live_location_on_booking_transition
AFTER UPDATE OF status,assigned_electrician_id ON public.service_bookings
FOR EACH ROW EXECUTE FUNCTION public.srk_stop_live_location_on_booking_transition();

REVOKE ALL ON FUNCTION public.srk_electrician_start_live_location(uuid,double precision,double precision,numeric) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_electrician_update_live_location(uuid,double precision,double precision,numeric) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_electrician_stop_live_location(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_electrician_get_my_live_location_status(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_customer_get_live_electrician_location(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_start_live_location(uuid,double precision,double precision,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_electrician_update_live_location(uuid,double precision,double precision,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_electrician_stop_live_location(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_electrician_get_my_live_location_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_live_electrician_location(uuid) TO authenticated;
