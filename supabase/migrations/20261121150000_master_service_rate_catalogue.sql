-- SRK ELECTRONIC Master Service Catalogue and versioned labour rates.
-- Feature Branch source only. No production or TEST database application.
-- Historical bookings retain their legacy rate columns and immutable snapshots.

CREATE TABLE IF NOT EXISTS public.srk_service_offerings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_code text NOT NULL REFERENCES public.srk_service_categories(category_code) ON DELETE RESTRICT,
  skill_code text NOT NULL REFERENCES public.srk_service_skills(skill_code) ON DELETE RESTRICT,
  service_code text NOT NULL UNIQUE CHECK (service_code ~ '^[a-z][a-z0-9_]{1,79}$'),
  display_name text NOT NULL CHECK (length(btrim(display_name)) BETWEEN 2 AND 120),
  billing_model text NOT NULL CHECK (billing_model IN ('hourly','fixed_per_unit')),
  unit_label text NOT NULL DEFAULT 'काम' CHECK (length(btrim(unit_label)) BETWEEN 1 AND 40),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK ((category_code='electrician' AND skill_code IN ('residential_wiring','factory_wiring'))
      OR category_code<>'electrician')
);
CREATE INDEX IF NOT EXISTS srk_service_offerings_category_idx
  ON public.srk_service_offerings(category_code,skill_code,is_active);

CREATE TABLE IF NOT EXISTS public.srk_service_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_code text NOT NULL REFERENCES public.srk_service_offerings(service_code) ON DELETE RESTRICT,
  level_code text NOT NULL CHECK (level_code ~ '^[a-z][a-z0-9_]{1,79}$'),
  level_label text NOT NULL CHECK (length(btrim(level_label)) BETWEEN 2 AND 100),
  technician_hourly_paise bigint,
  helper_hourly_paise bigint NOT NULL DEFAULT 0,
  fixed_labour_paise bigint,
  rate_version text NOT NULL CHECK (length(btrim(rate_version)) BETWEEN 3 AND 100),
  status text NOT NULL DEFAULT 'pending_admin_configuration'
    CHECK (status IN ('pending_admin_configuration','active','retired')),
  effective_from timestamptz NOT NULL DEFAULT clock_timestamp(),
  effective_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  CHECK (effective_to IS NULL OR effective_to>effective_from),
  CHECK (technician_hourly_paise IS NULL OR technician_hourly_paise>=0),
  CHECK (helper_hourly_paise>=0),
  CHECK (fixed_labour_paise IS NULL OR fixed_labour_paise>0),
  UNIQUE(service_code,level_code,rate_version)
);
CREATE INDEX IF NOT EXISTS srk_service_rates_current_idx
  ON public.srk_service_rates(service_code,status,effective_from DESC)
  WHERE status='active';

CREATE TABLE IF NOT EXISTS public.srk_service_rate_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rate_id uuid NOT NULL REFERENCES public.srk_service_rates(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  action text NOT NULL CHECK (action IN ('created','activated','updated','retired')),
  before_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  after_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.srk_service_rate_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_service_offerings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_service_rates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_service_offerings,public.srk_service_rates,
  public.srk_service_rate_events FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE public.srk_service_offerings,public.srk_service_rates,
  public.srk_service_rate_events TO service_role;

CREATE OR REPLACE FUNCTION public.srk_guard_service_rate_history()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'SERVICE_RATE_HISTORY_CANNOT_BE_DELETED' USING ERRCODE='55000'; END IF;
  IF TG_OP='UPDATE' THEN
    IF OLD.status='retired' THEN RAISE EXCEPTION 'RETIRED_SERVICE_RATE_IS_IMMUTABLE' USING ERRCODE='55000'; END IF;
    IF NEW.service_code IS DISTINCT FROM OLD.service_code
       OR NEW.level_code IS DISTINCT FROM OLD.level_code
       OR NEW.rate_version IS DISTINCT FROM OLD.rate_version
       OR NEW.effective_from IS DISTINCT FROM OLD.effective_from THEN
      RAISE EXCEPTION 'RATE_IDENTITY_IS_IMMUTABLE_CREATE_A_NEW_VERSION' USING ERRCODE='55000';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_service_rate_history() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_guard_service_rate_history ON public.srk_service_rates;
CREATE TRIGGER srk_guard_service_rate_history
BEFORE UPDATE OR DELETE ON public.srk_service_rates
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_service_rate_history();

CREATE OR REPLACE FUNCTION public.srk_guard_service_rate_events_append_only()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'SERVICE_RATE_EVENTS_ARE_APPEND_ONLY' USING ERRCODE='55000'; END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_service_rate_events_append_only() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_service_rate_events_append_only ON public.srk_service_rate_events;
CREATE TRIGGER srk_service_rate_events_append_only
BEFORE UPDATE OR DELETE ON public.srk_service_rate_events
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_service_rate_events_append_only();

-- Existing skills become the initial service offerings. Admin may add more granular services later.
INSERT INTO public.srk_service_offerings(category_code,skill_code,service_code,display_name,billing_model,unit_label)
SELECT c.category_code,s.skill_code,s.skill_code,s.display_name,
  CASE WHEN s.skill_code IN ('motor_winding','cooler_motor_winding','cooler_repair') THEN 'fixed_per_unit' ELSE 'hourly' END,
  CASE WHEN s.skill_code IN ('motor_winding','cooler_motor_winding') THEN 'मोटर' WHEN s.skill_code='cooler_repair' THEN 'कूलर' ELSE 'घंटा' END
FROM public.srk_service_skills s
JOIN public.srk_service_categories c ON c.id=s.category_id
ON CONFLICT(service_code) DO NOTHING;

-- Plumber rates are explicitly confirmed. Conflicting category prices are deliberately not activated.
INSERT INTO public.srk_service_rates
(service_code,level_code,level_label,technician_hourly_paise,helper_hourly_paise,rate_version,status)
VALUES
('residential_plumbing','basic','Basic',10000,5000,'SRK-PLUMBER-2026-11-21-V1','active'),
('residential_plumbing','expert','Expert',15000,7500,'SRK-PLUMBER-2026-11-21-V1','active'),
('industrial_plumbing','master_industrial','Master / Industrial',22500,10000,'SRK-PLUMBER-2026-11-21-V1','active')
ON CONFLICT(service_code,level_code,rate_version) DO NOTHING;

-- Legacy electrician rate constraints were tied to the obsolete hard-coded card.
-- Keep the historical values on old bookings; new bookings use the canonical rate snapshot below.
ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS srk_service_code text,
  ADD COLUMN IF NOT EXISTS srk_rate_level_code text,
  ADD COLUMN IF NOT EXISTS srk_rate_level_label_snapshot text,
  ADD COLUMN IF NOT EXISTS srk_rate_version_snapshot text,
  ADD COLUMN IF NOT EXISTS srk_billing_model_snapshot text,
  ADD COLUMN IF NOT EXISTS srk_technician_hourly_paise_snapshot bigint,
  ADD COLUMN IF NOT EXISTS srk_helper_hourly_paise_snapshot bigint,
  ADD COLUMN IF NOT EXISTS srk_fixed_labour_paise_snapshot bigint,
  ADD COLUMN IF NOT EXISTS srk_estimated_labour_paise bigint,
  ADD COLUMN IF NOT EXISTS srk_duration_minutes integer;
DO $booking$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='service_bookings_srk_service_code_fk') THEN
    ALTER TABLE public.service_bookings ADD CONSTRAINT service_bookings_srk_service_code_fk
      FOREIGN KEY(srk_service_code) REFERENCES public.srk_service_offerings(service_code) ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='service_bookings_srk_duration_minutes_valid') THEN
    ALTER TABLE public.service_bookings ADD CONSTRAINT service_bookings_srk_duration_minutes_valid
      CHECK(srk_duration_minutes IS NULL OR srk_duration_minutes BETWEEN 1 AND 72000);
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='service_bookings_srk_rate_snapshot_complete') THEN
    ALTER TABLE public.service_bookings ADD CONSTRAINT service_bookings_srk_rate_snapshot_complete
      CHECK(
        (srk_service_code IS NULL AND srk_rate_level_code IS NULL AND srk_rate_version_snapshot IS NULL
          AND srk_billing_model_snapshot IS NULL AND srk_estimated_labour_paise IS NULL)
        OR
        (srk_service_code IS NOT NULL AND srk_rate_level_code IS NOT NULL
          AND srk_rate_level_label_snapshot IS NOT NULL AND srk_rate_version_snapshot IS NOT NULL
          AND srk_billing_model_snapshot IN ('hourly','fixed_per_unit')
          AND srk_estimated_labour_paise>0)
      );
  END IF;
END;
$booking$;

-- Retire only the old CHECK that recalculated every booking against the obsolete hard-coded card.
-- Existing historical estimate amounts and rate-card version columns remain untouched.
ALTER TABLE public.service_bookings DROP CONSTRAINT IF EXISTS service_bookings_estimate_matches_rate_card;

CREATE OR REPLACE FUNCTION public.srk_customer_get_service_rate(
  p_service_code text,p_level_code text
)
RETURNS TABLE(
  category_code text,skill_code text,service_code text,service_name text,
  billing_model text,unit_label text,level_code text,level_label text,
  technician_hourly_paise bigint,helper_hourly_paise bigint,fixed_labour_paise bigint,
  rate_version text,effective_from timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT o.category_code,o.skill_code,o.service_code,o.display_name,o.billing_model,o.unit_label,
    r.level_code,r.level_label,r.technician_hourly_paise,r.helper_hourly_paise,r.fixed_labour_paise,
    r.rate_version,r.effective_from
  FROM public.srk_service_offerings o
  JOIN public.srk_service_rates r ON r.service_code=o.service_code
  WHERE o.service_code=p_service_code AND r.level_code=p_level_code
    AND o.is_active AND r.status='active'
    AND r.effective_from<=clock_timestamp()
    AND (r.effective_to IS NULL OR r.effective_to>clock_timestamp())
    AND ((o.billing_model='hourly' AND r.technician_hourly_paise IS NOT NULL
           AND r.technician_hourly_paise+r.helper_hourly_paise>0 AND r.fixed_labour_paise IS NULL)
      OR (o.billing_model='fixed_per_unit' AND r.fixed_labour_paise IS NOT NULL
           AND r.technician_hourly_paise IS NULL AND r.helper_hourly_paise=0))
  ORDER BY r.effective_from DESC
  LIMIT 1;
$function$;
REVOKE ALL ON FUNCTION public.srk_customer_get_service_rate(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_service_rate(text,text) TO service_role;

CREATE OR REPLACE FUNCTION public.srk_customer_list_active_service_rates()
RETURNS TABLE(
  category_code text,skill_code text,service_code text,service_name text,
  billing_model text,unit_label text,level_code text,level_label text,
  technician_hourly_paise bigint,helper_hourly_paise bigint,fixed_labour_paise bigint,
  rate_version text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT o.category_code,o.skill_code,o.service_code,o.display_name,o.billing_model,o.unit_label,
    r.level_code,r.level_label,r.technician_hourly_paise,r.helper_hourly_paise,r.fixed_labour_paise,r.rate_version
  FROM public.srk_service_offerings o
  JOIN public.srk_service_categories c ON c.category_code=o.category_code AND c.is_active
  JOIN public.srk_service_skills s ON s.skill_code=o.skill_code AND s.is_active
  JOIN public.srk_service_rates r ON r.service_code=o.service_code
  WHERE o.is_active AND r.status='active' AND r.effective_from<=clock_timestamp()
    AND (r.effective_to IS NULL OR r.effective_to>clock_timestamp())
  ORDER BY c.sort_order,o.display_name,r.level_label;
$function$;
REVOKE ALL ON FUNCTION public.srk_customer_list_active_service_rates() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_list_active_service_rates() TO anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.srk_admin_upsert_service_offering(
  p_category_code text,p_skill_code text,p_service_code text,p_display_name text,
  p_billing_model text,p_unit_label text,p_is_active boolean DEFAULT true
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_id uuid; v_before jsonb:='{}'::jsonb; v_after jsonb; v_action text:='created';
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_category_code IS NULL OR p_skill_code IS NULL OR p_service_code !~ '^[a-z][a-z0-9_]{1,79}$'
    OR p_display_name IS NULL OR length(btrim(p_display_name)) NOT BETWEEN 2 AND 120
    OR p_billing_model NOT IN ('hourly','fixed_per_unit') OR p_unit_label IS NULL
    OR length(btrim(p_unit_label)) NOT BETWEEN 1 AND 40 OR p_is_active IS NULL THEN
    RAISE EXCEPTION 'INVALID_SERVICE_OFFERING' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.srk_service_categories c JOIN public.srk_service_skills s
    ON s.category_id=c.id WHERE c.category_code=p_category_code AND s.skill_code=p_skill_code
    AND c.is_active AND s.is_active) THEN RAISE EXCEPTION 'ACTIVE_CATEGORY_SKILL_PAIR_REQUIRED' USING ERRCODE='22023'; END IF;
  SELECT id,to_jsonb(o) INTO v_id,v_before FROM public.srk_service_offerings o
    WHERE service_code=p_service_code FOR UPDATE;
  IF v_id IS NOT NULL THEN v_action:='updated'; END IF;
  INSERT INTO public.srk_service_offerings(category_code,skill_code,service_code,display_name,billing_model,unit_label,is_active,created_by,updated_at)
  VALUES(p_category_code,p_skill_code,p_service_code,btrim(p_display_name),p_billing_model,btrim(p_unit_label),p_is_active,auth.uid(),clock_timestamp())
  ON CONFLICT(service_code) DO UPDATE SET category_code=EXCLUDED.category_code,skill_code=EXCLUDED.skill_code,
    display_name=EXCLUDED.display_name,billing_model=EXCLUDED.billing_model,unit_label=EXCLUDED.unit_label,
    is_active=EXCLUDED.is_active,updated_at=clock_timestamp()
  RETURNING id,to_jsonb(srk_service_offerings) INTO v_id,v_after;
  INSERT INTO public.srk_service_catalogue_events(actor_user_id,object_type,object_id,action,before_data,after_data)
  VALUES(auth.uid(),'skill',v_id,v_action,v_before,v_after);
  RETURN v_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_upsert_service_offering(text,text,text,text,text,text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_upsert_service_offering(text,text,text,text,text,text,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_upsert_service_rate(
  p_service_code text,p_level_code text,p_level_label text,
  p_technician_hourly_paise bigint,p_helper_hourly_paise bigint,
  p_fixed_labour_paise bigint,p_rate_version text,
  p_status text DEFAULT 'pending_admin_configuration',
  p_effective_from timestamptz DEFAULT clock_timestamp(),p_effective_to timestamptz DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_id uuid; v_before jsonb:='{}'::jsonb; v_after jsonb; v_action text:='created'; v_model text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_service_code IS NULL OR p_level_code !~ '^[a-z][a-z0-9_]{1,79}$'
    OR p_level_label IS NULL OR length(btrim(p_level_label)) NOT BETWEEN 2 AND 100
    OR p_rate_version IS NULL OR length(btrim(p_rate_version)) NOT BETWEEN 3 AND 100
    OR p_status NOT IN ('pending_admin_configuration','active')
    OR p_effective_from IS NULL OR (p_effective_to IS NOT NULL AND p_effective_to<=p_effective_from)
    OR coalesce(p_helper_hourly_paise,0)<0
    OR (p_technician_hourly_paise IS NOT NULL AND p_technician_hourly_paise<0)
    OR (p_fixed_labour_paise IS NOT NULL AND p_fixed_labour_paise<=0) THEN
    RAISE EXCEPTION 'INVALID_SERVICE_RATE' USING ERRCODE='22023';
  END IF;
  SELECT billing_model INTO v_model FROM public.srk_service_offerings
    WHERE service_code=p_service_code AND is_active FOR SHARE;
  IF v_model IS NULL THEN RAISE EXCEPTION 'ACTIVE_SERVICE_OFFERING_REQUIRED' USING ERRCODE='22023'; END IF;
  IF (v_model='hourly' AND (p_technician_hourly_paise IS NULL OR p_technician_hourly_paise+p_helper_hourly_paise<=0 OR p_fixed_labour_paise IS NOT NULL))
    OR (v_model='fixed_per_unit' AND (p_fixed_labour_paise IS NULL OR p_technician_hourly_paise IS NOT NULL OR coalesce(p_helper_hourly_paise,0)<>0)) THEN
    RAISE EXCEPTION 'RATE_FIELDS_DO_NOT_MATCH_BILLING_MODEL' USING ERRCODE='22023';
  END IF;
  SELECT id,to_jsonb(r) INTO v_id,v_before FROM public.srk_service_rates r
    WHERE service_code=p_service_code AND level_code=p_level_code AND rate_version=p_rate_version FOR UPDATE;
  IF v_id IS NOT NULL THEN v_action:=CASE WHEN p_status='active' THEN 'activated' ELSE 'updated' END; END IF;
  INSERT INTO public.srk_service_rates(service_code,level_code,level_label,technician_hourly_paise,helper_hourly_paise,fixed_labour_paise,rate_version,status,effective_from,effective_to,created_by)
  VALUES(p_service_code,p_level_code,btrim(p_level_label),p_technician_hourly_paise,coalesce(p_helper_hourly_paise,0),p_fixed_labour_paise,btrim(p_rate_version),p_status,p_effective_from,p_effective_to,auth.uid())
  ON CONFLICT(service_code,level_code,rate_version) DO UPDATE SET level_label=EXCLUDED.level_label,
    technician_hourly_paise=EXCLUDED.technician_hourly_paise,helper_hourly_paise=EXCLUDED.helper_hourly_paise,
    fixed_labour_paise=EXCLUDED.fixed_labour_paise,status=EXCLUDED.status,
    effective_from=EXCLUDED.effective_from,effective_to=EXCLUDED.effective_to
  RETURNING id,to_jsonb(srk_service_rates) INTO v_id,v_after;
  INSERT INTO public.srk_service_rate_events(rate_id,actor_user_id,action,before_data,after_data)
  VALUES(v_id,auth.uid(),v_action,v_before,v_after);
  RETURN v_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_upsert_service_rate(text,text,text,text,bigint,bigint,bigint,text,text,timestamptz,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_upsert_service_rate(text,text,text,bigint,bigint,bigint,text,text,timestamptz,timestamptz) TO authenticated;

-- Keep legacy booking history but prevent direct client writes to the new commercial snapshot.
COMMENT ON TABLE public.srk_service_rates IS 'Versioned Admin-controlled labour rate catalogue. New bookings snapshot the active rate; historical booking snapshots never change.';
