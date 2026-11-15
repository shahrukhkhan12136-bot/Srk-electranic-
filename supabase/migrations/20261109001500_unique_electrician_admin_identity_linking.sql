-- Run after 20261109001000, which defines the legacy Admin approval function.
-- Replace legacy Admin approval's arbitrary LIMIT 1 phone claim with unique-only linking.
CREATE OR REPLACE FUNCTION public.srk_admin_review_application(p_application_id uuid, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $function$
DECLARE
  a public.electrician_applications%rowtype;
  v_phone text;
  v_auth_user_count integer;
  v_profile_count integer;
  v_auth_user_id uuid;
BEGIN
  IF NOT public.srk_is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  IF p_decision NOT IN ('approved','rejected','suspended') THEN RAISE EXCEPTION 'Invalid decision'; END IF;
  SELECT * INTO a FROM public.electrician_applications WHERE id=p_application_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Application not found'; END IF;
  UPDATE public.electrician_applications SET verification_status=p_decision WHERE id=p_application_id;
  IF p_decision='approved' THEN
    INSERT INTO public.electrician_profiles(application_id,display_name,phone,state,district,pincode,skills,active,verification_status)
    VALUES(a.id,a.full_name,a.phone,a.state,a.district,a.pincode,string_to_array(a.skills,','),false,'approved')
    ON CONFLICT(application_id) DO UPDATE SET display_name=excluded.display_name,phone=excluded.phone,
      state=excluded.state,district=excluded.district,pincode=excluded.pincode,skills=excluded.skills,
      verification_status='approved';
    v_phone:=right(regexp_replace(coalesce(a.phone,''),'[^0-9]','','g'),10);
    SELECT count(*) INTO v_auth_user_count FROM auth.users u
    WHERE u.phone_confirmed_at IS NOT NULL
      AND right(regexp_replace(coalesce(u.phone,''),'[^0-9]','','g'),10)=v_phone;
    IF v_auth_user_count=1 THEN
      SELECT u.id INTO v_auth_user_id FROM auth.users u
      WHERE u.phone_confirmed_at IS NOT NULL
        AND right(regexp_replace(coalesce(u.phone,''),'[^0-9]','','g'),10)=v_phone;
    END IF;
    SELECT count(*) INTO v_profile_count FROM public.electrician_profiles p
    WHERE p.verification_status='approved'
      AND right(regexp_replace(coalesce(p.phone,''),'[^0-9]','','g'),10)=v_phone;
    IF v_auth_user_count=1 AND v_profile_count=1 THEN
      UPDATE public.electrician_profiles p SET user_id=v_auth_user_id
      WHERE p.application_id=a.id AND p.user_id IS NULL AND p.auth_user_id IS NULL;
    END IF;
  ELSE
    UPDATE public.electrician_profiles SET active=false,verification_status=p_decision WHERE application_id=p_application_id;
  END IF;
  RETURN jsonb_build_object('success',true,'decision',p_decision);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_review_application(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_application(uuid,text) TO authenticated;
