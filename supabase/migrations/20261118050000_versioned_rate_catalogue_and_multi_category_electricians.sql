-- Multi-category electrician approvals + immutable published commercial rate catalogue.
-- SOURCE ONLY. Do not apply to Production without explicit approval.
BEGIN;

CREATE TABLE IF NOT EXISTS public.srk_rate_catalogue_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'published' CHECK (status='published'),
  currency text NOT NULL DEFAULT 'INR' CHECK (currency='INR'),
  base_duration_hours smallint NOT NULL DEFAULT 8 CHECK (base_duration_hours=8),
  effective_at timestamptz NOT NULL,
  previous_version_id uuid REFERENCES public.srk_rate_catalogue_versions(id) ON DELETE RESTRICT,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  published_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  published_at timestamptz NOT NULL DEFAULT now(),
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 5 AND 500)
);
CREATE UNIQUE INDEX IF NOT EXISTS srk_rate_catalogue_published_effective_uidx
  ON public.srk_rate_catalogue_versions(effective_at);
CREATE INDEX IF NOT EXISTS srk_rate_catalogue_active_lookup_idx
  ON public.srk_rate_catalogue_versions(effective_at DESC) WHERE status='published';

CREATE TABLE IF NOT EXISTS public.srk_rate_catalogue_items (
  rate_version_id uuid NOT NULL REFERENCES public.srk_rate_catalogue_versions(id) ON DELETE RESTRICT,
  tier_key text NOT NULL CHECK (tier_key IN (
    'electrical_assistant','skilled_electrician','expert_electrician','premium_electrical_specialist'
  )),
  customer_rate_paise bigint NOT NULL CHECK (customer_rate_paise > 0),
  PRIMARY KEY(rate_version_id,tier_key)
);

CREATE TABLE IF NOT EXISTS public.srk_rate_catalogue_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rate_version_id uuid NOT NULL REFERENCES public.srk_rate_catalogue_versions(id) ON DELETE RESTRICT,
  tier_key text NOT NULL,
  old_customer_rate_paise bigint,
  new_customer_rate_paise bigint NOT NULL,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.srk_electrician_approved_rate_categories (
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  category_key text NOT NULL CHECK (category_key IN (
    'electrical_assistant','skilled_electrician','expert_electrician','premium_electrical_specialist'
  )),
  approved_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  approved_at timestamptz NOT NULL DEFAULT now(),
  is_active boolean NOT NULL DEFAULT true,
  revoked_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  revoked_at timestamptz,
  PRIMARY KEY(electrician_profile_id,category_key),
  CHECK ((is_active AND revoked_at IS NULL AND revoked_by IS NULL)
      OR (NOT is_active AND revoked_at IS NOT NULL AND revoked_by IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS srk_electrician_active_rate_categories_idx
  ON public.srk_electrician_approved_rate_categories(electrician_profile_id,category_key)
  WHERE is_active=true;

CREATE TABLE IF NOT EXISTS public.srk_electrician_rate_category_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  category_key text NOT NULL,
  action text NOT NULL CHECK(action IN ('approved','revoked')),
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.srk_rate_catalogue_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_rate_catalogue_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_rate_catalogue_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_electrician_approved_rate_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_electrician_rate_category_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_rate_catalogue_versions,public.srk_rate_catalogue_items,
  public.srk_rate_catalogue_audit,public.srk_electrician_approved_rate_categories,
  public.srk_electrician_rate_category_audit FROM PUBLIC,anon,authenticated;

-- Published rows and audit history are immutable. Only SECURITY DEFINER RPCs insert.
CREATE OR REPLACE FUNCTION public.srk_reject_rate_catalogue_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
BEGIN
  RAISE EXCEPTION 'PUBLISHED_RATE_CATALOGUE_IS_IMMUTABLE' USING ERRCODE='42501';
END;
$fn$;
REVOKE ALL ON FUNCTION public.srk_reject_rate_catalogue_mutation() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_rate_catalogue_versions_immutable ON public.srk_rate_catalogue_versions;
CREATE TRIGGER srk_rate_catalogue_versions_immutable BEFORE UPDATE OR DELETE ON public.srk_rate_catalogue_versions
FOR EACH ROW EXECUTE FUNCTION public.srk_reject_rate_catalogue_mutation();
DROP TRIGGER IF EXISTS srk_rate_catalogue_items_immutable ON public.srk_rate_catalogue_items;
CREATE TRIGGER srk_rate_catalogue_items_immutable BEFORE UPDATE OR DELETE ON public.srk_rate_catalogue_items
FOR EACH ROW EXECUTE FUNCTION public.srk_reject_rate_catalogue_mutation();
DROP TRIGGER IF EXISTS srk_rate_catalogue_audit_immutable ON public.srk_rate_catalogue_audit;
CREATE TRIGGER srk_rate_catalogue_audit_immutable BEFORE UPDATE OR DELETE ON public.srk_rate_catalogue_audit
FOR EACH ROW EXECUTE FUNCTION public.srk_reject_rate_catalogue_mutation();
DROP TRIGGER IF EXISTS srk_electrician_rate_category_audit_immutable ON public.srk_electrician_rate_category_audit;
CREATE TRIGGER srk_electrician_rate_category_audit_immutable BEFORE UPDATE OR DELETE ON public.srk_electrician_rate_category_audit
FOR EACH ROW EXECUTE FUNCTION public.srk_reject_rate_catalogue_mutation();

CREATE OR REPLACE FUNCTION public.srk_admin_publish_rate_catalogue(
  p_rates jsonb,
  p_effective_at timestamptz,
  p_expected_current_version_id uuid,
  p_reason text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE
  v_actor uuid:=auth.uid();
  v_current uuid;
  v_version uuid:=gen_random_uuid();
  v_keys text[];
  v_tier text;
  v_amount bigint;
  v_old bigint;
BEGIN
  IF v_actor IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'MAIN_ADMIN_ONLY' USING ERRCODE='42501';
  END IF;
  IF p_effective_at IS NULL OR p_effective_at < now() - interval '1 minute'
     OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500 THEN
    RAISE EXCEPTION 'INVALID_EFFECTIVE_TIME_OR_REASON' USING ERRCODE='22023';
  END IF;
  IF jsonb_typeof(p_rates) <> 'object' THEN RAISE EXCEPTION 'RATE_MAP_OBJECT_REQUIRED'; END IF;
  SELECT array_agg(key ORDER BY key) INTO v_keys FROM jsonb_object_keys(p_rates) AS x(key);
  IF v_keys IS DISTINCT FROM ARRAY[
    'electrical_assistant','expert_electrician','premium_electrical_specialist','skilled_electrician'
  ]::text[] THEN RAISE EXCEPTION 'EXACTLY_FOUR_RATE_TIERS_REQUIRED'; END IF;
  FOR v_tier IN SELECT unnest(v_keys) LOOP
    IF (p_rates->>v_tier) !~ '^[0-9]+$' THEN RAISE EXCEPTION 'RATE_MUST_BE_INTEGER_PAISE: %',v_tier; END IF;
    v_amount:=(p_rates->>v_tier)::bigint;
    IF v_amount<1 OR v_amount>9000000000000000 THEN RAISE EXCEPTION 'RATE_OUT_OF_RANGE: %',v_tier; END IF;
  END LOOP;

  PERFORM pg_advisory_xact_lock(hashtextextended('srk-rate-catalogue-publish',0));
  SELECT id INTO v_current FROM public.srk_rate_catalogue_versions
   WHERE status='published' AND effective_at<=now()
   ORDER BY effective_at DESC,id DESC LIMIT 1;
  IF v_current IS DISTINCT FROM p_expected_current_version_id THEN
    RAISE EXCEPTION 'RATE_CATALOGUE_VERSION_CONFLICT' USING ERRCODE='40001';
  END IF;

  INSERT INTO public.srk_rate_catalogue_versions(
    id,status,effective_at,previous_version_id,created_by,published_by,reason
  ) VALUES(v_version,'published',p_effective_at,v_current,v_actor,v_actor,btrim(p_reason));

  FOR v_tier IN SELECT unnest(v_keys) LOOP
    v_amount:=(p_rates->>v_tier)::bigint;
    INSERT INTO public.srk_rate_catalogue_items(rate_version_id,tier_key,customer_rate_paise)
      VALUES(v_version,v_tier,v_amount);
    SELECT customer_rate_paise INTO v_old
      FROM public.srk_rate_catalogue_items i
      JOIN public.srk_rate_catalogue_versions v ON v.id=i.rate_version_id
     WHERE i.tier_key=v_tier AND v.status='published' AND v.effective_at<=now()
     ORDER BY v.effective_at DESC LIMIT 1;
    INSERT INTO public.srk_rate_catalogue_audit(
      rate_version_id,tier_key,old_customer_rate_paise,new_customer_rate_paise,actor_id,reason
    ) VALUES(v_version,v_tier,v_old,v_amount,v_actor,btrim(p_reason));
  END LOOP;
  RETURN jsonb_build_object('success',true,'rate_version_id',v_version,'effective_at',p_effective_at);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.srk_get_current_customer_rate_catalogue()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE v_id uuid; v_effective timestamptz; v_rates jsonb;
BEGIN
  SELECT id,effective_at INTO v_id,v_effective
    FROM public.srk_rate_catalogue_versions
   WHERE status='published' AND effective_at<=now()
   ORDER BY effective_at DESC,id DESC LIMIT 1;
  IF v_id IS NULL THEN RETURN NULL; END IF;
  SELECT jsonb_object_agg(tier_key,customer_rate_paise ORDER BY tier_key)
    INTO v_rates FROM public.srk_rate_catalogue_items WHERE rate_version_id=v_id;
  IF (SELECT count(*) FROM public.srk_rate_catalogue_items WHERE rate_version_id=v_id)<>4 THEN
    RAISE EXCEPTION 'PUBLISHED_RATE_VERSION_INCOMPLETE';
  END IF;
  RETURN jsonb_build_object('rate_version_id',v_id,'effective_at',v_effective,
    'currency','INR','base_duration_hours',8,'rates',v_rates);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.srk_admin_set_electrician_approved_categories(
  p_electrician_profile_id uuid,
  p_category_keys text[],
  p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE v_profile public.electrician_profiles%rowtype; v_key text; v_existing text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'MAIN_ADMIN_ONLY' USING ERRCODE='42501';
  END IF;
  IF p_electrician_profile_id IS NULL OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500
     OR p_category_keys IS NULL OR cardinality(p_category_keys)>4
     OR cardinality(p_category_keys)<>(SELECT count(DISTINCT x) FROM unnest(p_category_keys) x)
     OR EXISTS(SELECT 1 FROM unnest(p_category_keys) x WHERE x NOT IN (
       'electrical_assistant','skilled_electrician','expert_electrician','premium_electrical_specialist'
     )) THEN RAISE EXCEPTION 'INVALID_CATEGORY_APPROVAL_REQUEST' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_profile FROM public.electrician_profiles
   WHERE id=p_electrician_profile_id FOR UPDATE;
  IF NOT FOUND OR v_profile.verification_status<>'approved' THEN
    RAISE EXCEPTION 'APPROVED_ELECTRICIAN_PROFILE_REQUIRED';
  END IF;

  FOR v_existing IN
    SELECT category_key FROM public.srk_electrician_approved_rate_categories
     WHERE electrician_profile_id=p_electrician_profile_id AND is_active=true
       AND NOT (category_key=ANY(p_category_keys))
     FOR UPDATE
  LOOP
    UPDATE public.srk_electrician_approved_rate_categories
       SET is_active=false,revoked_by=auth.uid(),revoked_at=now()
     WHERE electrician_profile_id=p_electrician_profile_id AND category_key=v_existing;
    INSERT INTO public.srk_electrician_rate_category_audit(
      electrician_profile_id,category_key,action,actor_id,reason
    ) VALUES(p_electrician_profile_id,v_existing,'revoked',auth.uid(),btrim(p_reason));
  END LOOP;

  FOREACH v_key IN ARRAY p_category_keys LOOP
    INSERT INTO public.srk_electrician_approved_rate_categories(
      electrician_profile_id,category_key,approved_by,approved_at,is_active,revoked_by,revoked_at
    ) VALUES(p_electrician_profile_id,v_key,auth.uid(),now(),true,NULL,NULL)
    ON CONFLICT(electrician_profile_id,category_key) DO UPDATE SET
      approved_by=EXCLUDED.approved_by,approved_at=EXCLUDED.approved_at,
      is_active=true,revoked_by=NULL,revoked_at=NULL
    WHERE public.srk_electrician_approved_rate_categories.is_active=false;
    INSERT INTO public.srk_electrician_rate_category_audit(
      electrician_profile_id,category_key,action,actor_id,reason
    ) VALUES(p_electrician_profile_id,v_key,'approved',auth.uid(),btrim(p_reason));
  END LOOP;
  RETURN jsonb_build_object('success',true,'electrician_profile_id',p_electrician_profile_id,
    'approved_categories',to_jsonb(p_category_keys));
END;
$fn$;

CREATE OR REPLACE FUNCTION public.srk_get_my_electrician_rate_list()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE v_profile_id uuid; v_catalogue jsonb; v_items jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
   WHERE auth_user_id=auth.uid() AND user_id=auth.uid()
     AND verification_status='approved' LIMIT 1;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'APPROVED_ELECTRICIAN_PROFILE_REQUIRED' USING ERRCODE='42501'; END IF;
  v_catalogue:=public.srk_get_current_customer_rate_catalogue();
  IF v_catalogue IS NULL THEN RAISE EXCEPTION 'NO_ACTIVE_RATE_CATALOGUE'; END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'category_key',a.category_key,
      'customer_facing_label',CASE a.category_key
        WHEN 'electrical_assistant' THEN 'Electrical Assistant'
        WHEN 'skilled_electrician' THEN 'Skilled Electrician'
        WHEN 'expert_electrician' THEN 'Expert Electrician'
        WHEN 'premium_electrical_specialist' THEN 'Premium Electrical Specialist' END,
      'duration_hours',8,
      'electrician_rate_paise',floor((i.customer_rate_paise::numeric*8500/10000)+0.5)::bigint
    ) ORDER BY a.category_key),'[]'::jsonb)
    INTO v_items
    FROM public.srk_electrician_approved_rate_categories a
    JOIN public.srk_rate_catalogue_items i
      ON i.rate_version_id=(v_catalogue->>'rate_version_id')::uuid
     AND i.tier_key=a.category_key
   WHERE a.electrician_profile_id=v_profile_id AND a.is_active=true;
  RETURN jsonb_build_object('rate_version_id',v_catalogue->'rate_version_id',
    'effective_at',v_catalogue->'effective_at','currency','INR','items',v_items);
END;
$fn$;

REVOKE ALL ON FUNCTION public.srk_admin_publish_rate_catalogue(jsonb,timestamptz,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_publish_rate_catalogue(jsonb,timestamptz,uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_get_current_customer_rate_catalogue() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.srk_get_current_customer_rate_catalogue() TO anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_set_electrician_approved_categories(uuid,text[],text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_set_electrician_approved_categories(uuid,text[],text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_get_my_electrician_rate_list() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_electrician_rate_list() TO authenticated;

COMMIT;
