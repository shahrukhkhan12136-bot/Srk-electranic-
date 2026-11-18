-- Prevent authenticated electrician accounts from reading the public gross customer catalogue.
-- Keep customer booking access and expose electrician net rates through the dedicated RPC only.
-- SOURCE ONLY: do not apply to Production without explicit approval.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_get_current_customer_rate_catalogue()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path=''
AS $fn$
DECLARE
  v_id uuid;
  v_effective timestamptz;
  v_rates jsonb;
BEGIN
  IF auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.electrician_profiles ep
    WHERE ep.user_id=auth.uid() OR ep.auth_user_id=auth.uid()
  ) THEN
    RAISE EXCEPTION 'ELECTRICIAN_CUSTOMER_RATE_CATALOGUE_FORBIDDEN'
      USING ERRCODE='42501';
  END IF;

  SELECT id,effective_at INTO v_id,v_effective
  FROM public.srk_rate_catalogue_versions
  WHERE status='published' AND effective_at<=now()
  ORDER BY effective_at DESC,id DESC
  LIMIT 1;

  IF v_id IS NULL THEN RETURN NULL; END IF;

  SELECT jsonb_object_agg(tier_key,customer_rate_paise ORDER BY tier_key)
  INTO v_rates
  FROM public.srk_rate_catalogue_items
  WHERE rate_version_id=v_id;

  IF (SELECT count(*) FROM public.srk_rate_catalogue_items WHERE rate_version_id=v_id)<>4 THEN
    RAISE EXCEPTION 'PUBLISHED_RATE_VERSION_INCOMPLETE';
  END IF;

  RETURN jsonb_build_object(
    'rate_version_id',v_id,
    'effective_at',v_effective,
    'currency','INR',
    'base_duration_hours',8,
    'rates',v_rates
  );
END;
$fn$;

-- The electrician's own Rate List must not call the customer-gross RPC.
-- Resolve the published version directly and return only the canonical 85% net.
CREATE OR REPLACE FUNCTION public.srk_get_my_electrician_rate_list()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path=''
AS $fn$
DECLARE
  v_profile_id uuid;
  v_rate_version_id uuid;
  v_effective timestamptz;
  v_items jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='42501';
  END IF;

  SELECT id INTO v_profile_id
  FROM public.electrician_profiles
  WHERE auth_user_id=auth.uid()
    AND user_id=auth.uid()
    AND verification_status='approved'
    AND active=true
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'APPROVED_ELECTRICIAN_PROFILE_REQUIRED' USING ERRCODE='42501';
  END IF;

  SELECT id,effective_at INTO v_rate_version_id,v_effective
  FROM public.srk_rate_catalogue_versions
  WHERE status='published' AND effective_at<=now()
  ORDER BY effective_at DESC,id DESC
  LIMIT 1;

  IF v_rate_version_id IS NULL THEN
    RAISE EXCEPTION 'NO_ACTIVE_RATE_CATALOGUE';
  END IF;

  IF (SELECT count(*) FROM public.srk_rate_catalogue_items
      WHERE rate_version_id=v_rate_version_id)<>4 THEN
    RAISE EXCEPTION 'PUBLISHED_RATE_VERSION_INCOMPLETE';
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'category_key',a.category_key,
    'customer_facing_label',CASE a.category_key
      WHEN 'electrical_assistant' THEN 'Electrical Assistant'
      WHEN 'skilled_electrician' THEN 'Skilled Electrician'
      WHEN 'expert_electrician' THEN 'Expert Electrician'
      WHEN 'premium_electrical_specialist' THEN 'Premium Electrical Specialist'
    END,
    'duration_hours',8,
    'electrician_rate_paise',
      i.customer_rate_paise-floor((i.customer_rate_paise::numeric*1500/10000)+0.5)::bigint
  ) ORDER BY a.category_key),'[]'::jsonb)
  INTO v_items
  FROM public.srk_electrician_approved_rate_categories a
  JOIN public.srk_rate_catalogue_items i
    ON i.rate_version_id=v_rate_version_id
   AND i.tier_key=a.category_key
  WHERE a.electrician_profile_id=v_profile_id
    AND a.is_active=true;

  RETURN jsonb_build_object(
    'rate_version_id',v_rate_version_id,
    'effective_at',v_effective,
    'currency','INR',
    'items',v_items
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.srk_get_current_customer_rate_catalogue() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.srk_get_current_customer_rate_catalogue() TO anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.srk_get_my_electrician_rate_list() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_electrician_rate_list() TO authenticated;

COMMIT;
