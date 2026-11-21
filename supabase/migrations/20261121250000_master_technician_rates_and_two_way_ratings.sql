-- SRK ELECTRONIC Master: Technician 85% rate lists + two-way booking ratings.
-- Feature Branch source only. Do not apply to Production or enable Master booking rollout.
-- Existing booking/rate/application history is preserved.

ALTER TABLE public.srk_technician_application_skills
  ADD COLUMN IF NOT EXISTS approved_level_code text
  CHECK (approved_level_code IS NULL OR approved_level_code ~ '^[a-z][a-z0-9_]{1,79}$');

CREATE OR REPLACE FUNCTION public.srk_admin_set_technician_skill_level(
  p_application_skill_id uuid,p_level_code text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_skill public.srk_technician_application_skills%rowtype; v_category_code text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_application_skill_id IS NULL OR p_level_code IS NULL
     OR p_level_code !~ '^[a-z][a-z0-9_]{1,79}$' THEN
    RAISE EXCEPTION 'INVALID_TECHNICIAN_SKILL_LEVEL' USING ERRCODE='22023';
  END IF;
  SELECT aps.* INTO v_skill
  FROM public.srk_technician_application_skills aps
  JOIN public.srk_technician_applications a ON a.id=aps.application_id
  WHERE aps.id=p_application_skill_id AND aps.review_status='approved'
    AND a.status='approved'
  FOR UPDATE OF aps;
  IF NOT FOUND THEN RAISE EXCEPTION 'APPROVED_TECHNICIAN_SKILL_REQUIRED' USING ERRCODE='55000'; END IF;
  SELECT c.category_code INTO v_category_code
  FROM public.srk_service_skills s
  JOIN public.srk_service_categories c ON c.id=s.category_id
  WHERE s.id=v_skill.skill_id;
  IF NOT EXISTS (
    SELECT 1 FROM public.srk_service_offerings o
    JOIN public.srk_service_rates r ON r.service_code=o.service_code
    WHERE o.category_code=v_category_code
      AND o.skill_code=(SELECT skill_code FROM public.srk_service_skills WHERE id=v_skill.skill_id)
      AND r.level_code=p_level_code AND r.status='active'
      AND r.effective_from<=clock_timestamp()
      AND (r.effective_to IS NULL OR r.effective_to>clock_timestamp())
  ) THEN RAISE EXCEPTION 'ACTIVE_RATE_FOR_VERIFIED_SKILL_LEVEL_REQUIRED' USING ERRCODE='55000'; END IF;
  UPDATE public.srk_technician_application_skills
  SET approved_level_code=p_level_code
  WHERE id=v_skill.id;
  INSERT INTO public.srk_technician_application_events
    (application_id,technician_id,actor_user_id,actor_role,event_type,note,snapshot)
  SELECT v_skill.application_id,a.technician_id,auth.uid(),'admin','skill_reviewed',
    'Verified skill level assigned',
    jsonb_build_object('application_skill_id',v_skill.id,'approved_level_code',p_level_code)
  FROM public.srk_technician_applications a WHERE a.id=v_skill.application_id;
  RETURN jsonb_build_object('success',true,'application_skill_id',v_skill.id,'approved_level_code',p_level_code);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_set_technician_skill_level(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_set_technician_skill_level(uuid,text) TO authenticated;

-- Technician's own list: only Admin-approved categories/skills and the exact level assigned to this Technician.
CREATE OR REPLACE FUNCTION public.srk_technician_list_my_85_percent_rates()
RETURNS TABLE(
  technician_id uuid,category_code text,category_name text,skill_code text,skill_name text,
  service_code text,service_name text,billing_model text,level_code text,level_label text,
  technician_8h_paise bigint,helper_8h_paise bigint,combined_8h_paise bigint,
  technician_share_85_paise bigint,helper_share_85_paise bigint,total_share_85_paise bigint,
  fixed_customer_rate_paise bigint,fixed_share_85_paise bigint,rate_version text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_tid uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT t.id INTO v_tid FROM public.srk_technicians t
  WHERE t.auth_user_id=v_uid AND t.account_status='active';
  IF v_tid IS NULL THEN RAISE EXCEPTION 'ACTIVE_TECHNICIAN_REQUIRED' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT v_tid,c.category_code,c.display_name,s.skill_code,s.display_name,
    o.service_code,o.display_name,o.billing_model,r.level_code,r.level_label,
    CASE WHEN o.billing_model='hourly' THEN r.technician_hourly_paise*8 ELSE NULL END,
    CASE WHEN o.billing_model='hourly' THEN r.helper_hourly_paise*8 ELSE NULL END,
    CASE WHEN o.billing_model='hourly' THEN (r.technician_hourly_paise+r.helper_hourly_paise)*8 ELSE NULL END,
    CASE WHEN o.billing_model='hourly' THEN floor(r.technician_hourly_paise::numeric*8*0.85)::bigint ELSE NULL END,
    CASE WHEN o.billing_model='hourly' THEN floor(r.helper_hourly_paise::numeric*8*0.85)::bigint ELSE NULL END,
    CASE WHEN o.billing_model='hourly' THEN floor((r.technician_hourly_paise+r.helper_hourly_paise)::numeric*8*0.85)::bigint ELSE NULL END,
    r.fixed_labour_paise,
    CASE WHEN o.billing_model='fixed_per_unit' THEN floor(r.fixed_labour_paise::numeric*0.85)::bigint ELSE NULL END,
    r.rate_version
  FROM public.srk_technician_applications a
  JOIN public.srk_technician_application_skills aps
    ON aps.application_id=a.id AND aps.review_status='approved' AND aps.approved_level_code IS NOT NULL
  JOIN public.srk_service_skills s ON s.id=aps.skill_id AND s.is_active
  JOIN public.srk_service_categories c ON c.id=s.category_id AND c.is_active
  JOIN public.srk_service_offerings o ON o.category_code=c.category_code AND o.skill_code=s.skill_code AND o.is_active
  JOIN public.srk_service_rates r ON r.service_code=o.service_code
    AND r.level_code=aps.approved_level_code AND r.status='active'
    AND r.effective_from<=clock_timestamp() AND (r.effective_to IS NULL OR r.effective_to>clock_timestamp())
  WHERE a.technician_id=v_tid AND a.status='approved'
  ORDER BY c.sort_order,c.category_code,s.skill_code,o.display_name;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_list_my_85_percent_rates() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_list_my_85_percent_rates() TO authenticated;

-- Reference list for every category/skill/level. It is informational only and grants no job eligibility.
CREATE OR REPLACE FUNCTION public.srk_technician_list_all_85_percent_rates()
RETURNS TABLE(
  category_code text,category_name text,skill_code text,skill_name text,
  service_code text,service_name text,billing_model text,level_code text,level_label text,
  technician_8h_paise bigint,helper_8h_paise bigint,combined_8h_paise bigint,
  total_share_85_paise bigint,fixed_customer_rate_paise bigint,fixed_share_85_paise bigint,
  rate_version text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT c.category_code,c.display_name,s.skill_code,s.display_name,
    o.service_code,o.display_name,o.billing_model,r.level_code,r.level_label,
    CASE WHEN o.billing_model='hourly' THEN r.technician_hourly_paise*8 END,
    CASE WHEN o.billing_model='hourly' THEN r.helper_hourly_paise*8 END,
    CASE WHEN o.billing_model='hourly' THEN (r.technician_hourly_paise+r.helper_hourly_paise)*8 END,
    CASE WHEN o.billing_model='hourly' THEN floor((r.technician_hourly_paise+r.helper_hourly_paise)::numeric*8*0.85)::bigint END,
    r.fixed_labour_paise,
    CASE WHEN o.billing_model='fixed_per_unit' THEN floor(r.fixed_labour_paise::numeric*0.85)::bigint END,
    r.rate_version
  FROM public.srk_service_categories c
  JOIN public.srk_service_skills s ON s.category_id=c.id AND s.is_active
  JOIN public.srk_service_offerings o ON o.category_code=c.category_code AND o.skill_code=s.skill_code AND o.is_active
  JOIN public.srk_service_rates r ON r.service_code=o.service_code
  WHERE c.is_active AND r.status='active' AND r.effective_from<=clock_timestamp()
    AND (r.effective_to IS NULL OR r.effective_to>clock_timestamp())
  ORDER BY c.sort_order,c.category_code,s.skill_code,o.display_name,r.level_label;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_list_all_85_percent_rates() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_list_all_85_percent_rates() TO authenticated;

CREATE TABLE IF NOT EXISTS public.srk_master_booking_ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  reviewer_role text NOT NULL CHECK(reviewer_role IN ('customer','technician')),
  reviewer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  reviewer_technician_id uuid REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  target_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  target_technician_id uuid REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  stars smallint NOT NULL CHECK(stars BETWEEN 1 AND 5),
  review_text text CHECK(review_text IS NULL OR length(btrim(review_text))<=1000),
  moderation_status text NOT NULL DEFAULT 'published' CHECK(moderation_status IN ('published','hidden')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  moderated_at timestamptz,
  moderated_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  moderation_reason text CHECK(moderation_reason IS NULL OR length(btrim(moderation_reason)) BETWEEN 5 AND 1000),
  CHECK(
    (reviewer_role='customer' AND reviewer_technician_id IS NULL
      AND target_user_id IS NULL AND target_technician_id IS NOT NULL)
    OR
    (reviewer_role='technician' AND reviewer_technician_id IS NOT NULL
      AND target_user_id IS NOT NULL AND target_technician_id IS NULL)
  ),
  CHECK((moderation_status='published' AND moderated_at IS NULL AND moderated_by IS NULL AND moderation_reason IS NULL)
     OR (moderation_status='hidden' AND moderated_at IS NOT NULL AND moderated_by IS NOT NULL AND moderation_reason IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS srk_master_customer_rating_per_technician_booking_uidx
  ON public.srk_master_booking_ratings(booking_id,target_technician_id)
  WHERE reviewer_role='customer';
CREATE UNIQUE INDEX IF NOT EXISTS srk_master_technician_rating_per_booking_uidx
  ON public.srk_master_booking_ratings(booking_id,reviewer_technician_id)
  WHERE reviewer_role='technician';
CREATE INDEX IF NOT EXISTS srk_master_booking_ratings_target_technician_idx
  ON public.srk_master_booking_ratings(target_technician_id,created_at DESC)
  WHERE moderation_status='published';
CREATE INDEX IF NOT EXISTS srk_master_booking_ratings_target_customer_idx
  ON public.srk_master_booking_ratings(target_user_id,created_at DESC)
  WHERE moderation_status='published';

ALTER TABLE public.srk_master_booking_ratings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_master_booking_ratings FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.srk_master_booking_ratings TO service_role;

CREATE OR REPLACE FUNCTION public.srk_customer_rate_master_technician(
  p_booking_id uuid,p_technician_id uuid,p_stars smallint,p_review_text text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_rating_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'CUSTOMER_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_booking_id IS NULL OR p_technician_id IS NULL OR p_stars NOT BETWEEN 1 AND 5
    OR (p_review_text IS NOT NULL AND length(btrim(p_review_text))>1000) THEN
    RAISE EXCEPTION 'INVALID_RATING' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM public.service_bookings b
    JOIN public.srk_booking_technician_assignments a ON a.booking_id=b.id
    WHERE b.id=p_booking_id AND b.customer_user_id=v_uid AND b.status='completed'
      AND b.completion_approval_status='approved' AND b.customer_completed_at IS NOT NULL
      AND a.technician_id=p_technician_id AND a.assignment_status='completed'
  ) THEN RAISE EXCEPTION 'COMPLETED_BOOKING_PARTICIPATION_REQUIRED' USING ERRCODE='42501'; END IF;
  INSERT INTO public.srk_master_booking_ratings(
    booking_id,reviewer_role,reviewer_user_id,target_technician_id,stars,review_text
  ) VALUES(p_booking_id,'customer',v_uid,p_technician_id,p_stars,nullif(btrim(coalesce(p_review_text,'')),''))
  RETURNING id INTO v_rating_id;
  RETURN v_rating_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_customer_rate_master_technician(uuid,uuid,smallint,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_rate_master_technician(uuid,uuid,smallint,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_rate_master_customer(
  p_booking_id uuid,p_stars smallint,p_review_text text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_tid uuid; v_customer_uid uuid; v_rating_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_tid FROM public.srk_technicians WHERE auth_user_id=v_uid AND account_status='active';
  IF v_tid IS NULL THEN RAISE EXCEPTION 'ACTIVE_TECHNICIAN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_booking_id IS NULL OR p_stars NOT BETWEEN 1 AND 5
    OR (p_review_text IS NOT NULL AND length(btrim(p_review_text))>1000) THEN
    RAISE EXCEPTION 'INVALID_RATING' USING ERRCODE='22023';
  END IF;
  SELECT b.customer_user_id INTO v_customer_uid
  FROM public.service_bookings b
  JOIN public.srk_booking_technician_assignments a ON a.booking_id=b.id
  WHERE b.id=p_booking_id AND a.technician_id=v_tid AND a.assignment_status='completed'
    AND b.status='completed' AND b.completion_approval_status='approved'
    AND b.customer_completed_at IS NOT NULL;
  IF v_customer_uid IS NULL THEN RAISE EXCEPTION 'COMPLETED_BOOKING_PARTICIPATION_REQUIRED' USING ERRCODE='42501'; END IF;
  INSERT INTO public.srk_master_booking_ratings(
    booking_id,reviewer_role,reviewer_user_id,reviewer_technician_id,target_user_id,stars,review_text
  ) VALUES(p_booking_id,'technician',v_uid,v_tid,v_customer_uid,p_stars,
    nullif(btrim(coalesce(p_review_text,'')),''))
  RETURNING id INTO v_rating_id;
  RETURN v_rating_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_rate_master_customer(uuid,smallint,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_rate_master_customer(uuid,smallint,text) TO authenticated;

CREATE TABLE IF NOT EXISTS public.srk_master_rating_moderation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rating_id uuid NOT NULL REFERENCES public.srk_master_booking_ratings(id) ON DELETE RESTRICT,
  admin_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  action text NOT NULL CHECK(action IN ('hide','restore')),
  reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 5 AND 1000),
  before_status text NOT NULL CHECK(before_status IN ('published','hidden')),
  after_status text NOT NULL CHECK(after_status IN ('published','hidden')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.srk_master_rating_moderation_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_master_rating_moderation_events FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.srk_guard_master_rating_moderation_events_append_only()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  RAISE EXCEPTION 'RATING_MODERATION_HISTORY_IS_APPEND_ONLY' USING ERRCODE='55000';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_master_rating_moderation_events_append_only() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_rating_moderation_events_append_only ON public.srk_master_rating_moderation_events;
CREATE TRIGGER srk_master_rating_moderation_events_append_only
BEFORE UPDATE OR DELETE ON public.srk_master_rating_moderation_events
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_rating_moderation_events_append_only();
GRANT ALL ON public.srk_master_rating_moderation_events TO service_role;

CREATE OR REPLACE FUNCTION public.srk_admin_moderate_master_rating(
  p_rating_id uuid,p_action text,p_reason text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_rating public.srk_master_booking_ratings%rowtype; v_after text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_rating_id IS NULL OR p_action NOT IN ('hide','restore')
    OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 1000 THEN
    RAISE EXCEPTION 'INVALID_RATING_MODERATION' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_rating FROM public.srk_master_booking_ratings WHERE id=p_rating_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RATING_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  v_after:=CASE WHEN p_action='hide' THEN 'hidden' ELSE 'published' END;
  IF v_rating.moderation_status=v_after THEN RAISE EXCEPTION 'RATING_ALREADY_IN_TARGET_STATE'; END IF;
  UPDATE public.srk_master_booking_ratings
  SET moderation_status=v_after,
      moderated_at=CASE WHEN v_after='hidden' THEN clock_timestamp() ELSE NULL END,
      moderated_by=CASE WHEN v_after='hidden' THEN auth.uid() ELSE NULL END,
      moderation_reason=CASE WHEN v_after='hidden' THEN btrim(p_reason) ELSE NULL END
  WHERE id=p_rating_id;
  INSERT INTO public.srk_master_rating_moderation_events(
    rating_id,admin_user_id,action,reason,before_status,after_status
  ) VALUES(p_rating_id,auth.uid(),p_action,btrim(p_reason),v_rating.moderation_status,v_after);
  RETURN jsonb_build_object('success',true,'rating_id',p_rating_id,'moderation_status',v_after);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_moderate_master_rating(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_moderate_master_rating(uuid,text,text) TO authenticated;

COMMENT ON TABLE public.srk_master_booking_ratings IS
  'One customer-to-Technician rating per assigned Technician and one Technician-to-customer rating per completed booking; no ratings for cancelled or incomplete bookings.';
COMMENT ON FUNCTION public.srk_technician_list_my_85_percent_rates() IS
  'Technician sees only rates for their Admin-approved category/skill and assigned level; shows 85 percent share only.';
COMMENT ON FUNCTION public.srk_technician_list_all_85_percent_rates() IS
  'Informational 85 percent reference rate list across all active categories and skills; it does not grant booking eligibility.';
