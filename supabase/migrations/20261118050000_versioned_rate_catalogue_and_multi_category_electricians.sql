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
     WHERE i.tier_key=v_tier AND i.rate_version_id<>v_version
       AND v.status='published' AND v.effective_at<=now()
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
DECLARE v_profile public.electrician_profiles%rowtype; v_key text; v_existing text; v_rows integer:=0;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'MAIN_ADMIN_ONLY' USING ERRCODE='42501';
  END IF;
  IF p_electrician_profile_id IS NULL OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500
     OR p_category_keys IS NULL OR cardinality(p_category_keys)>4
     OR cardinality(p_category_keys)<>(SELECT count(DISTINCT category_key) FROM unnest(p_category_keys) AS u(category_key))
     OR EXISTS(SELECT 1 FROM unnest(p_category_keys) AS u(category_key) WHERE category_key NOT IN (
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
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows > 0 THEN
      INSERT INTO public.srk_electrician_rate_category_audit(
        electrician_profile_id,category_key,action,actor_id,reason
      ) VALUES(p_electrician_profile_id,v_key,'approved',auth.uid(),btrim(p_reason));
    END IF;
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
      'electrician_rate_paise',(i.customer_rate_paise-floor((i.customer_rate_paise::numeric*1500/10000)+0.5))::bigint
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
GRANT EXECUTE ON FUNCTION public.srk_get_current_customer_rate_catalogue() TO anon,authenticated,service_role;
GRANT SELECT ON TABLE public.srk_rate_catalogue_items TO service_role;
REVOKE ALL ON FUNCTION public.srk_admin_set_electrician_approved_categories(uuid,text[],text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_set_electrician_approved_categories(uuid,text[],text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_get_my_electrician_rate_list() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_electrician_rate_list() TO authenticated;



-- Preserve each existing single-category approval as one row in the new
-- multi-category relation. Historical profile columns/audit remain untouched.
INSERT INTO public.srk_electrician_approved_rate_categories(
  electrician_profile_id,category_key,approved_by,approved_at,is_active
)
SELECT p.id,p.approved_rate_tier,p.rate_tier_approved_by,
       coalesce(p.rate_tier_approved_at,now()),true
FROM public.electrician_profiles p
WHERE p.approved_rate_tier IS NOT NULL
  AND p.rate_tier_approved_by IS NOT NULL
  AND p.verification_status='approved'
ON CONFLICT(electrician_profile_id,category_key) DO NOTHING;

INSERT INTO public.srk_electrician_rate_category_audit(
  electrician_profile_id,category_key,action,actor_id,reason
)
SELECT p.id,p.approved_rate_tier,'approved',p.rate_tier_approved_by,
       'Legacy single-category approval copied to multi-category relation; legacy record preserved'
FROM public.electrician_profiles p
WHERE p.approved_rate_tier IS NOT NULL AND p.rate_tier_approved_by IS NOT NULL
  AND p.verification_status='approved'
  AND NOT EXISTS (
    SELECT 1 FROM public.srk_electrician_rate_category_audit a
    WHERE a.electrician_profile_id=p.id AND a.category_key=p.approved_rate_tier
      AND a.reason='Legacy single-category approval copied to multi-category relation; legacy record preserved'
  );

-- Keep the legacy audited-column guard, but permit activation when at least
-- one new Admin-approved category is present.
CREATE OR REPLACE FUNCTION public.srk_guard_electrician_rate_tier_activation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE v_authorized boolean:=false; v_has_multi_category boolean:=false;
BEGIN
  IF TG_OP='INSERT' THEN
    IF NEW.approved_rate_tier IS NOT NULL OR NEW.approved_rate_card_version IS NOT NULL
       OR NEW.rate_tier_approved_by IS NOT NULL OR NEW.rate_tier_approved_at IS NOT NULL THEN
      RAISE EXCEPTION 'Legacy rate tier fields must be assigned through audited Admin RPC' USING ERRCODE='42501';
    END IF;
  ELSIF NEW.approved_rate_tier IS DISTINCT FROM OLD.approved_rate_tier
     OR NEW.approved_rate_card_version IS DISTINCT FROM OLD.approved_rate_card_version
     OR NEW.rate_tier_approved_by IS DISTINCT FROM OLD.rate_tier_approved_by
     OR NEW.rate_tier_approved_at IS DISTINCT FROM OLD.rate_tier_approved_at THEN
    SELECT EXISTS(
      SELECT 1 FROM srk_private.electrician_rate_tier_authorizations a
      WHERE a.transaction_id=pg_catalog.txid_current()
        AND a.electrician_profile_id=NEW.id AND a.actor_id=auth.uid()
    ) INTO v_authorized;
    IF NOT v_authorized THEN RAISE EXCEPTION 'Legacy rate tier changes require audited Admin RPC' USING ERRCODE='42501'; END IF;
  END IF;
  SELECT EXISTS(
    SELECT 1 FROM public.srk_electrician_approved_rate_categories a
    WHERE a.electrician_profile_id=NEW.id AND a.is_active=true
  ) INTO v_has_multi_category;
  IF NEW.active IS TRUE AND NOT v_has_multi_category
     AND (NEW.approved_rate_tier IS NULL OR NEW.approved_rate_card_version IS NULL
       OR NEW.rate_tier_approved_by IS NULL OR NEW.rate_tier_approved_at IS NULL) THEN
    RAISE EXCEPTION 'Admin must approve at least one electrician rate category before activation' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$fn$;
REVOKE ALL ON FUNCTION public.srk_guard_electrician_rate_tier_activation() FROM PUBLIC,anon,authenticated;

-- Booking dispatch and job-offer authorization now consult the multi-category
-- Admin approval relation. Legacy approved_rate_tier columns remain untouched
-- for historical compatibility; they are no longer the authority for new offers.
CREATE OR REPLACE FUNCTION private.srk_offer_booking_to_eligible_electricians(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $fn$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_match_level text;
  v_eligible integer:=0;
  v_created integer:=0;
BEGIN
  IF p_booking_id IS NULL THEN RAISE EXCEPTION 'Booking ID required' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE='P0002'; END IF;
  IF v_booking.assigned_electrician_id IS NOT NULL OR v_booking.status NOT IN ('new','confirmed') THEN
    RETURN jsonb_build_object('success',false,'eligible_count',0,'offers_created',0);
  END IF;
  IF v_booking.selected_category IS NOT NULL AND
     (v_booking.selected_rate_tier IS NULL OR v_booking.selected_duration_hours IS NULL) THEN
    RETURN jsonb_build_object('success',false,'code','customer_selection_incomplete');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.electrician_profiles e
    WHERE e.active=true AND e.verification_status='approved'
      AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
      AND (v_booking.selected_rate_tier IS NULL OR EXISTS (
        SELECT 1 FROM public.srk_electrician_approved_rate_categories a
        WHERE a.electrician_profile_id=e.id AND a.category_key=v_booking.selected_rate_tier
          AND a.is_active=true
      ))
      AND e.pincode=v_booking.pincode AND lower(trim(e.state))=lower(trim(v_booking.state))
  ) THEN v_match_level:='pincode'; ELSE v_match_level:='district'; END IF;

  WITH eligible AS (
    SELECT e.id FROM public.electrician_profiles e
    WHERE e.active=true AND e.verification_status='approved'
      AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
      AND (v_booking.selected_rate_tier IS NULL OR EXISTS (
        SELECT 1 FROM public.srk_electrician_approved_rate_categories a
        WHERE a.electrician_profile_id=e.id AND a.category_key=v_booking.selected_rate_tier
          AND a.is_active=true
      ))
      AND lower(trim(e.state))=lower(trim(v_booking.state))
      AND ((v_match_level='pincode' AND e.pincode=v_booking.pincode)
        OR (v_match_level='district' AND lower(trim(e.district))=lower(trim(v_booking.district))))
  ), inserted AS (
    INSERT INTO public.job_offers(booking_id,electrician_id,status,match_level)
    SELECT p_booking_id,e.id,'offered',v_match_level FROM eligible e
    ON CONFLICT(booking_id,electrician_id) DO NOTHING RETURNING id
  )
  SELECT (SELECT count(*) FROM eligible),(SELECT count(*) FROM inserted)
    INTO v_eligible,v_created;

  IF v_eligible=0 THEN
    RETURN jsonb_build_object('success',false,'code','no_exact_rate_tier_match',
      'message','इस क्षेत्र में ग्राहक की चुनी श्रेणी के Admin-approved इलेक्ट्रिशियन उपलब्ध नहीं हैं।');
  END IF;
  RETURN jsonb_build_object('success',true,'match_level',v_match_level,
    'eligible_count',v_eligible,'offers_created',v_created);
END;
$fn$;
REVOKE ALL ON FUNCTION private.srk_offer_booking_to_eligible_electricians(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_guard_job_offer_selected_rate_tier()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $fn$
DECLARE v_selected_tier text;
BEGIN
  SELECT b.selected_rate_tier INTO v_selected_tier
  FROM public.service_bookings b WHERE b.id=NEW.booking_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found for job offer'; END IF;
  IF v_selected_tier IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.electrician_profiles e
    JOIN public.srk_electrician_approved_rate_categories a
      ON a.electrician_profile_id=e.id AND a.category_key=v_selected_tier AND a.is_active=true
    WHERE e.id=NEW.electrician_id AND e.active=true AND e.verification_status='approved'
      AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
  ) THEN
    RAISE EXCEPTION 'Electrician must have the selected Admin-approved category' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$fn$;
REVOKE ALL ON FUNCTION public.srk_guard_job_offer_selected_rate_tier() FROM PUBLIC,anon,authenticated;

COMMIT;
