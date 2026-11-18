-- Main Admin read model for the versioned Rate Catalogue and multi-category approvals.
-- Source-only migration; do not apply to any database without explicit approval.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_admin_list_electrician_rate_categories()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path=''
AS $fn$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'MAIN_ADMIN_ONLY' USING ERRCODE='42501';
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'electrician_profile_id',p.id,
    'display_name',coalesce(to_jsonb(p)->>'display_name',to_jsonb(p)->>'name','Electrician'),
    'phone',coalesce(to_jsonb(p)->>'phone',to_jsonb(p)->>'mobile',''),
    'verification_status',p.verification_status,
    'active_categories',coalesce((
      SELECT jsonb_agg(a.category_key ORDER BY a.category_key)
      FROM public.srk_electrician_approved_rate_categories a
      WHERE a.electrician_profile_id=p.id AND a.is_active=true
    ),'[]'::jsonb)
  ) ORDER BY coalesce(to_jsonb(p)->>'display_name',to_jsonb(p)->>'name',''),p.id),'[]'::jsonb)
  INTO v_result
  FROM public.electrician_profiles p
  WHERE p.verification_status='approved';

  RETURN v_result;
END;
$fn$;

REVOKE ALL ON FUNCTION public.srk_admin_list_electrician_rate_categories() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_electrician_rate_categories() TO authenticated;

COMMIT;
