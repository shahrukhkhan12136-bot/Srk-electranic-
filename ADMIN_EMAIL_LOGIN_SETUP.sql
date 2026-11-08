-- SRK ELECTRONIC: Admin access patch for the EXISTING project
-- Run once in Supabase SQL Editor while signed in as project owner.
-- This uses the existing srk_admin_users row created for your Auth user.

-- Ensure the admin allow-list table is protected.
ALTER TABLE public.srk_admin_users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS srk_admin_users_self_read ON public.srk_admin_users;
CREATE POLICY srk_admin_users_self_read ON public.srk_admin_users
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Admin check used by the website after email/password login.
CREATE OR REPLACE FUNCTION public.is_srk_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, auth AS $$
  SELECT EXISTS (SELECT 1 FROM public.srk_admin_users WHERE user_id = auth.uid());
$$;
REVOKE ALL ON FUNCTION public.is_srk_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_srk_admin() TO authenticated;

-- Admin-only read/update access to the operational tables.
ALTER TABLE public.service_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.electrician_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.electrician_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS srk_admin_read_bookings ON public.service_bookings;
CREATE POLICY srk_admin_read_bookings ON public.service_bookings
  FOR SELECT TO authenticated USING (public.is_srk_admin());
DROP POLICY IF EXISTS srk_admin_update_bookings ON public.service_bookings;
CREATE POLICY srk_admin_update_bookings ON public.service_bookings
  FOR UPDATE TO authenticated USING (public.is_srk_admin()) WITH CHECK (public.is_srk_admin());

DROP POLICY IF EXISTS srk_admin_read_applications ON public.electrician_applications;
CREATE POLICY srk_admin_read_applications ON public.electrician_applications
  FOR SELECT TO authenticated USING (public.is_srk_admin());
DROP POLICY IF EXISTS srk_admin_update_applications ON public.electrician_applications;
CREATE POLICY srk_admin_update_applications ON public.electrician_applications
  FOR UPDATE TO authenticated USING (public.is_srk_admin()) WITH CHECK (public.is_srk_admin());

DROP POLICY IF EXISTS srk_admin_manage_profiles ON public.electrician_profiles;
CREATE POLICY srk_admin_manage_profiles ON public.electrician_profiles
  FOR ALL TO authenticated USING (public.is_srk_admin()) WITH CHECK (public.is_srk_admin());
DROP POLICY IF EXISTS srk_admin_read_offers ON public.job_offers;
CREATE POLICY srk_admin_read_offers ON public.job_offers
  FOR SELECT TO authenticated USING (public.is_srk_admin());

-- Admin-only application review RPC; creates an inactive profile on approval.
CREATE OR REPLACE FUNCTION public.srk_admin_review_application(p_application_id uuid, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE a public.electrician_applications%rowtype;
BEGIN
  IF NOT public.is_srk_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  IF p_decision NOT IN ('approved','rejected','suspended') THEN RAISE EXCEPTION 'Invalid decision'; END IF;
  SELECT * INTO a FROM public.electrician_applications WHERE id=p_application_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Application not found'; END IF;
  UPDATE public.electrician_applications SET verification_status=p_decision WHERE id=p_application_id;
  IF p_decision='approved' THEN
    INSERT INTO public.electrician_profiles(application_id,display_name,phone,state,district,pincode,skills,active,verification_status)
    VALUES(a.id,a.full_name,a.phone,a.state,a.district,a.pincode,string_to_array(coalesce(a.skills,''),','),false,'approved')
    ON CONFLICT (application_id) DO UPDATE SET display_name=EXCLUDED.display_name, phone=EXCLUDED.phone,
      state=EXCLUDED.state, district=EXCLUDED.district, pincode=EXCLUDED.pincode, skills=EXCLUDED.skills,
      verification_status='approved', active=false;
    UPDATE public.electrician_profiles p
       SET user_id = (SELECT u.id FROM auth.users u
         WHERE u.phone_confirmed_at IS NOT NULL
           AND right(regexp_replace(coalesce(u.phone,''), '[^0-9]', '', 'g'), 10) = a.phone
         ORDER BY u.created_at DESC LIMIT 1)
     WHERE p.application_id = a.id AND p.user_id IS NULL;
  ELSE
    UPDATE public.electrician_profiles SET active=false, verification_status=p_decision WHERE application_id=p_application_id;
  END IF;
  RETURN jsonb_build_object('success',true,'decision',p_decision);
END; $$;
REVOKE ALL ON FUNCTION public.srk_admin_review_application(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_application(uuid,text) TO authenticated;

-- Verify the allow-list entry exists (SQL Editor may show false for auth.uid();
-- this query checks the actual stored row directly).
SELECT user_id, created_at FROM public.srk_admin_users ORDER BY created_at DESC;
