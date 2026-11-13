-- Canonical requested category and Admin-approved electrician commercial rate tier.
-- Source-only until separately approved for production application.

ALTER TABLE public.electrician_applications
  ADD COLUMN IF NOT EXISTS requested_category text;

ALTER TABLE public.electrician_applications
  ADD CONSTRAINT electrician_applications_requested_category_check
  CHECK (requested_category IS NULL OR requested_category IN (
    'electrical_assistant',
    'skilled_electrician',
    'expert_electrician',
    'premium_electrical_specialist'
  ));

ALTER TABLE public.electrician_profiles
  ADD COLUMN IF NOT EXISTS approved_rate_tier text,
  ADD COLUMN IF NOT EXISTS approved_rate_card_version text,
  ADD COLUMN IF NOT EXISTS rate_tier_approved_by uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS rate_tier_approved_at timestamptz;

ALTER TABLE public.electrician_profiles
  ADD CONSTRAINT electrician_profiles_approved_rate_tier_check
  CHECK (approved_rate_tier IS NULL OR approved_rate_tier IN (
    'electrical_assistant',
    'skilled_electrician',
    'expert_electrician',
    'premium_electrical_specialist'
  ));

ALTER TABLE public.electrician_profiles
  ADD CONSTRAINT electrician_profiles_rate_tier_approval_pair_check
  CHECK (
    (approved_rate_tier IS NULL AND approved_rate_card_version IS NULL
      AND rate_tier_approved_by IS NULL AND rate_tier_approved_at IS NULL)
    OR
    (approved_rate_tier IS NOT NULL AND approved_rate_card_version IS NOT NULL
      AND rate_tier_approved_by IS NOT NULL AND rate_tier_approved_at IS NOT NULL)
  );

CREATE TABLE IF NOT EXISTS public.srk_electrician_rate_tier_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  application_id uuid REFERENCES public.electrician_applications(id) ON DELETE RESTRICT,
  previous_rate_tier text,
  new_rate_tier text NOT NULL CHECK (new_rate_tier IN (
    'electrical_assistant',
    'skilled_electrician',
    'expert_electrician',
    'premium_electrical_specialist'
  )),
  rate_card_version text NOT NULL,
  changed_by uuid NOT NULL REFERENCES auth.users(id),
  changed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.srk_electrician_rate_tier_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_electrician_rate_tier_audit FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.srk_electrician_rate_tier_audit TO authenticated;
CREATE POLICY srk_electrician_rate_tier_audit_admin_select
  ON public.srk_electrician_rate_tier_audit
  FOR SELECT TO authenticated
  USING ((SELECT public.is_srk_admin()));

CREATE OR REPLACE FUNCTION public.srk_admin_set_electrician_rate_tier(
  p_electrician_profile_id uuid,
  p_rate_tier text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_profile public.electrician_profiles%ROWTYPE;
  v_previous text;
  v_version constant text := 'SRK-CUSTOMER-LABOUR-2026-11-13-V1';
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin only' USING ERRCODE = '42501';
  END IF;
  IF p_electrician_profile_id IS NULL OR p_rate_tier NOT IN (
    'electrical_assistant',
    'skilled_electrician',
    'expert_electrician',
    'premium_electrical_specialist'
  ) THEN
    RAISE EXCEPTION 'Invalid electrician profile or rate tier' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_profile
  FROM public.electrician_profiles
  WHERE id = p_electrician_profile_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Electrician profile not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_profile.verification_status <> 'approved' THEN
    RAISE EXCEPTION 'Electrician KYC must be approved before assigning a rate tier' USING ERRCODE = '23514';
  END IF;

  v_previous := v_profile.approved_rate_tier;

  UPDATE public.electrician_profiles
  SET approved_rate_tier = p_rate_tier,
      approved_rate_card_version = v_version,
      rate_tier_approved_by = auth.uid(),
      rate_tier_approved_at = now()
  WHERE id = p_electrician_profile_id;

  INSERT INTO public.srk_electrician_rate_tier_audit (
    electrician_profile_id, application_id, previous_rate_tier,
    new_rate_tier, rate_card_version, changed_by
  ) VALUES (
    v_profile.id, v_profile.application_id, v_previous,
    p_rate_tier, v_version, auth.uid()
  );

  RETURN jsonb_build_object(
    'success', true,
    'electrician_profile_id', v_profile.id,
    'approved_rate_tier', p_rate_tier,
    'rate_card_version', v_version
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_set_electrician_rate_tier(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_set_electrician_rate_tier(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_guard_electrician_rate_tier_activation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  IF NEW.active IS TRUE AND (
    NEW.approved_rate_tier IS NULL
    OR NEW.approved_rate_card_version IS NULL
    OR NEW.rate_tier_approved_by IS NULL
    OR NEW.rate_tier_approved_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Admin must approve an electrician rate tier before activation'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS srk_guard_electrician_rate_tier_activation
  ON public.electrician_profiles;
CREATE TRIGGER srk_guard_electrician_rate_tier_activation
  BEFORE INSERT OR UPDATE OF active ON public.electrician_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.srk_guard_electrician_rate_tier_activation();

COMMENT ON COLUMN public.electrician_applications.requested_category IS
  'Applicant-selected requested category; not an approved commercial tier.';
COMMENT ON COLUMN public.electrician_profiles.approved_rate_tier IS
  'Admin-approved commercial rate tier; never infer from skills or applicant request.';
