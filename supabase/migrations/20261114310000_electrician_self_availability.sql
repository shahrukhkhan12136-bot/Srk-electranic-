-- Electrician-controlled availability, separate from Admin-controlled activation.
ALTER TABLE public.electrician_profiles
  ADD COLUMN IF NOT EXISTS available_for_work boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.electrician_profiles.available_for_work IS
  'Electrician-controlled job availability; active remains Admin-controlled approval/activation.';

CREATE TABLE IF NOT EXISTS public.srk_electrician_availability_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  available_for_work boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.srk_electrician_availability_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_electrician_availability_events FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.srk_electrician_set_availability(p_available boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_uid uuid:=auth.uid();
  v_profile public.electrician_profiles%ROWTYPE;
  v_booking_id uuid;
  v_advanced integer:=0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Electrician login required' USING ERRCODE='42501'; END IF;
  IF p_available IS NULL THEN RAISE EXCEPTION 'Availability value required' USING ERRCODE='22023'; END IF;

  SELECT * INTO v_profile
  FROM public.electrician_profiles
  WHERE user_id=v_uid AND auth_user_id=v_uid
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Linked electrician profile required' USING ERRCODE='42501'; END IF;
  IF v_profile.active IS DISTINCT FROM true OR v_profile.verification_status<>'approved' THEN
    RAISE EXCEPTION 'Only Admin-approved active electricians can change availability' USING ERRCODE='42501';
  END IF;

  UPDATE public.electrician_profiles
  SET available_for_work=p_available
  WHERE id=v_profile.id AND available_for_work IS DISTINCT FROM p_available;

  IF v_profile.available_for_work IS DISTINCT FROM p_available THEN
    INSERT INTO public.srk_electrician_availability_events
      (electrician_profile_id,actor_user_id,available_for_work)
    VALUES(v_profile.id,v_uid,p_available);
  END IF;

  IF NOT p_available THEN
    -- Close this electrician's unaccepted offers and immediately advance each
    -- affected sequential dispatch queue. Accepted assignments are untouched.
    FOR v_booking_id IN
      UPDATE public.job_offers
      SET status='declined',responded_at=clock_timestamp()
      WHERE electrician_id=v_profile.id AND status='offered'
      RETURNING booking_id
    LOOP
      PERFORM private.srk_dispatch_next_booking_offer(v_booking_id);
      v_advanced:=v_advanced+1;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'success',true,
    'available_for_work',p_available,
    'closed_offers_advanced',v_advanced
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_electrician_set_availability(boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_set_availability(boolean) TO authenticated;
