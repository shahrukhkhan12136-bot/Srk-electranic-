CREATE TABLE IF NOT EXISTS public.srk_electrician_profile_name_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  old_display_name text NOT NULL,
  new_display_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.srk_electrician_profile_name_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_electrician_profile_name_events FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.srk_electrician_update_my_display_name(p_display_name text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_profile public.electrician_profiles%ROWTYPE;
  v_name text := regexp_replace(btrim(coalesce(p_display_name,'')), '\s+', ' ', 'g');
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  IF char_length(v_name) < 2 OR char_length(v_name) > 80
     OR v_name !~ '^[[:alpha:][:digit:][:space:].''-]+$' THEN
    RAISE EXCEPTION 'Name must be 2-80 characters and contain only letters, numbers, spaces, dot, apostrophe or hyphen'
      USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_profile
  FROM public.electrician_profiles
  WHERE user_id=v_uid AND auth_user_id=v_uid
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Electrician profile not found' USING ERRCODE='42501';
  END IF;
  IF v_profile.display_name IS DISTINCT FROM v_name THEN
    UPDATE public.electrician_profiles SET display_name=v_name WHERE id=v_profile.id;
    INSERT INTO public.srk_electrician_profile_name_events
      (electrician_profile_id,actor_user_id,old_display_name,new_display_name)
    VALUES (v_profile.id,v_uid,v_profile.display_name,v_name);
  END IF;
  RETURN v_name;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_electrician_update_my_display_name(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_update_my_display_name(text) TO authenticated;
