-- Structured, Admin-verified electrician skills and configurable customer-category matching.
-- Free-text application/profile skills remain descriptive only and are never used for eligibility.
ALTER TABLE public.electrician_applications
  ADD COLUMN IF NOT EXISTS requested_skill_keys text[] NOT NULL DEFAULT '{}';
ALTER TABLE public.electrician_profiles
  ADD COLUMN IF NOT EXISTS requested_skill_keys text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS approved_skill_keys text[] NOT NULL DEFAULT '{}';

CREATE TABLE IF NOT EXISTS public.srk_electrician_skill_catalog (
  skill_key text PRIMARY KEY,
  name_hi text NOT NULL,
  name_en text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  sort_order smallint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT srk_electrician_skill_catalog_key_check
    CHECK (skill_key ~ '^[a-z][a-z0-9_]{2,59}$')
);
INSERT INTO public.srk_electrician_skill_catalog(skill_key,name_hi,name_en,sort_order) VALUES
 ('house_wiring','घर की वायरिंग','House wiring',10),
 ('electrical_fault_diagnosis','बिजली की खराबी जाँचना','Electrical fault diagnosis',20),
 ('mcb_distribution_board','MCB / डिस्ट्रीब्यूशन बोर्ड','MCB / distribution board',30),
 ('light_installation','लाइट लगाना / बदलना','Light installation',40),
 ('fan_installation','पंखा लगाना / बदलना','Fan installation',50),
 ('inverter_ups','इन्वर्टर / UPS','Inverter / UPS',60),
 ('earthing','अर्थिंग','Earthing',70),
 ('appliance_repair','इलेक्ट्रिकल उपकरण मरम्मत','Electrical appliance repair',80),
 ('pump_motor','पंप / मोटर','Pump / motor',90),
 ('other_electrical_work','अन्य इलेक्ट्रिकल काम','Other electrical work',100)
ON CONFLICT(skill_key) DO UPDATE SET name_hi=excluded.name_hi,name_en=excluded.name_en,sort_order=excluded.sort_order;

CREATE TABLE IF NOT EXISTS public.srk_customer_category_skill_rules (
  category_key text NOT NULL CHECK (category_key IN
    ('home_wiring','electrical_repair','light_fan_fitting','home_repair','other')),
  skill_key text NOT NULL REFERENCES public.srk_electrician_skill_catalog(skill_key) ON DELETE RESTRICT,
  changed_by uuid NOT NULL REFERENCES auth.users(id),
  changed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(category_key,skill_key)
);
CREATE TABLE IF NOT EXISTS public.srk_customer_category_skill_rule_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_key text NOT NULL CHECK (category_key IN
    ('home_wiring','electrical_repair','light_fan_fitting','home_repair','other')),
  previous_skill_keys text[] NOT NULL DEFAULT '{}',
  new_skill_keys text[] NOT NULL DEFAULT '{}',
  changed_by uuid NOT NULL REFERENCES auth.users(id),
  changed_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.srk_electrician_skill_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  previous_skill_keys text[] NOT NULL DEFAULT '{}',
  new_skill_keys text[] NOT NULL DEFAULT '{}',
  changed_by uuid NOT NULL REFERENCES auth.users(id),
  changed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.srk_electrician_skill_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_customer_category_skill_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_customer_category_skill_rule_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_electrician_skill_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_electrician_skill_catalog,public.srk_customer_category_skill_rules,
  public.srk_customer_category_skill_rule_audit,public.srk_electrician_skill_audit
  FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.srk_electrician_skill_catalog,public.srk_customer_category_skill_rules,
  public.srk_customer_category_skill_rule_audit,public.srk_electrician_skill_audit TO authenticated;
CREATE POLICY srk_skill_catalog_admin_select ON public.srk_electrician_skill_catalog
  FOR SELECT TO authenticated USING ((SELECT public.is_srk_admin()));
CREATE POLICY srk_category_skill_rules_admin_select ON public.srk_customer_category_skill_rules
  FOR SELECT TO authenticated USING ((SELECT public.is_srk_admin()));
CREATE POLICY srk_category_skill_audit_admin_select ON public.srk_customer_category_skill_rule_audit
  FOR SELECT TO authenticated USING ((SELECT public.is_srk_admin()));
CREATE POLICY srk_electrician_skill_audit_admin_select ON public.srk_electrician_skill_audit
  FOR SELECT TO authenticated USING ((SELECT public.is_srk_admin()));

CREATE TABLE IF NOT EXISTS srk_private.electrician_skill_authorizations (
  transaction_id bigint NOT NULL,
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  PRIMARY KEY(transaction_id,electrician_profile_id)
);
REVOKE ALL ON srk_private.electrician_skill_authorizations FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_validate_electrician_requested_skills()
RETURNS trigger LANGUAGE plpgsql SET search_path=''
AS $function$
DECLARE v_allowed text[];
BEGIN
  IF NEW.requested_skill_keys IS NULL OR cardinality(NEW.requested_skill_keys)>20
     OR array_position(NEW.requested_skill_keys,NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'Invalid requested skill list' USING ERRCODE='22023';
  END IF;
  SELECT coalesce(array_agg(skill_key),'{}'::text[]) INTO v_allowed
  FROM public.srk_electrician_skill_catalog WHERE active=true;
  IF NOT (NEW.requested_skill_keys <@ v_allowed) THEN
    RAISE EXCEPTION 'Unknown or inactive requested skill' USING ERRCODE='22023';
  END IF;
  NEW.requested_skill_keys := ARRAY(SELECT DISTINCT x FROM unnest(NEW.requested_skill_keys) x ORDER BY x);
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS srk_validate_application_requested_skills ON public.electrician_applications;
CREATE TRIGGER srk_validate_application_requested_skills
  BEFORE INSERT OR UPDATE OF requested_skill_keys ON public.electrician_applications
  FOR EACH ROW EXECUTE FUNCTION public.srk_validate_electrician_requested_skills();

CREATE OR REPLACE FUNCTION public.srk_guard_electrician_approved_skills()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
BEGIN
  IF TG_OP='INSERT' AND cardinality(coalesce(NEW.approved_skill_keys,'{}'::text[]))>0 THEN
    RAISE EXCEPTION 'Approved skills must be assigned through the Admin approval RPC' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND NEW.approved_skill_keys IS DISTINCT FROM OLD.approved_skill_keys THEN
    IF NOT EXISTS (
      SELECT 1 FROM srk_private.electrician_skill_authorizations a
      WHERE a.transaction_id=txid_current()
        AND a.electrician_profile_id=NEW.id
        AND a.actor_id=auth.uid()
    ) THEN
      RAISE EXCEPTION 'Approved skills require Admin approval RPC' USING ERRCODE='42501';
    END IF;
    DELETE FROM srk_private.electrician_skill_authorizations
    WHERE transaction_id=txid_current()
      AND electrician_profile_id=NEW.id AND actor_id=auth.uid();
  END IF;
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS srk_guard_electrician_approved_skills ON public.electrician_profiles;
CREATE TRIGGER srk_guard_electrician_approved_skills
  BEFORE INSERT OR UPDATE OF approved_skill_keys ON public.electrician_profiles
  FOR EACH ROW EXECUTE FUNCTION public.srk_guard_electrician_approved_skills();

CREATE OR REPLACE FUNCTION public.srk_admin_set_electrician_skills(
  p_electrician_profile_id uuid,p_skill_keys text[]
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE v_profile public.electrician_profiles%ROWTYPE; v_new text[]; v_old text[];
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';
  END IF;
  IF p_electrician_profile_id IS NULL OR p_skill_keys IS NULL
     OR cardinality(p_skill_keys)>20 OR array_position(p_skill_keys,NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'Invalid profile or skill list' USING ERRCODE='22023';
  END IF;
  v_new := ARRAY(SELECT DISTINCT x FROM unnest(p_skill_keys) x ORDER BY x);
  SELECT * INTO v_profile FROM public.electrician_profiles
    WHERE id=p_electrician_profile_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Electrician profile not found' USING ERRCODE='P0002'; END IF;
  IF v_profile.verification_status<>'approved' THEN
    RAISE EXCEPTION 'KYC must be approved before skill verification' USING ERRCODE='23514';
  END IF;
  IF NOT (v_new <@ v_profile.requested_skill_keys) THEN
    RAISE EXCEPTION 'Only skills declared in the application can be approved' USING ERRCODE='23514';
  END IF;
  IF EXISTS(SELECT 1 FROM unnest(v_new) x LEFT JOIN public.srk_electrician_skill_catalog c
      ON c.skill_key=x AND c.active=true WHERE c.skill_key IS NULL) THEN
    RAISE EXCEPTION 'Unknown or inactive skill' USING ERRCODE='22023';
  END IF;
  v_old:=v_profile.approved_skill_keys;
  INSERT INTO srk_private.electrician_skill_authorizations(transaction_id,electrician_profile_id,actor_id)
    VALUES(txid_current(),v_profile.id,auth.uid());
  UPDATE public.electrician_profiles SET approved_skill_keys=v_new WHERE id=v_profile.id;
  INSERT INTO public.srk_electrician_skill_audit(electrician_profile_id,previous_skill_keys,new_skill_keys,changed_by)
    VALUES(v_profile.id,v_old,v_new,auth.uid());
  RETURN jsonb_build_object('success',true,'approved_skill_keys',to_jsonb(v_new));
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_set_electrician_skills(uuid,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_set_electrician_skills(uuid,text[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_set_category_skill_rules(p_category_key text,p_skill_keys text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE v_old text[]; v_new text[];
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin only' USING ERRCODE='42501';
  END IF;
  IF p_category_key IS NULL OR p_category_key NOT IN
    ('home_wiring','electrical_repair','light_fan_fitting','home_repair','other')
    OR p_skill_keys IS NULL OR cardinality(p_skill_keys)>20
    OR array_position(p_skill_keys,NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'Invalid category or skill list' USING ERRCODE='22023';
  END IF;
  v_new:=ARRAY(SELECT DISTINCT x FROM unnest(p_skill_keys) x ORDER BY x);
  IF EXISTS(SELECT 1 FROM unnest(v_new) x LEFT JOIN public.srk_electrician_skill_catalog c
      ON c.skill_key=x AND c.active=true WHERE c.skill_key IS NULL) THEN
    RAISE EXCEPTION 'Unknown or inactive skill' USING ERRCODE='22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_category_key,0));
  SELECT coalesce(array_agg(skill_key ORDER BY skill_key),'{}'::text[]) INTO v_old
    FROM public.srk_customer_category_skill_rules WHERE category_key=p_category_key;
  DELETE FROM public.srk_customer_category_skill_rules WHERE category_key=p_category_key;
  INSERT INTO public.srk_customer_category_skill_rules(category_key,skill_key,changed_by)
    SELECT p_category_key,x,auth.uid() FROM unnest(v_new) x;
  INSERT INTO public.srk_customer_category_skill_rule_audit(category_key,previous_skill_keys,new_skill_keys,changed_by)
    VALUES(p_category_key,v_old,v_new,auth.uid());
  RETURN jsonb_build_object('success',true,'category_key',p_category_key,'skill_keys',to_jsonb(v_new));
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_set_category_skill_rules(text,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_set_category_skill_rules(text,text[]) TO authenticated;

-- Carry applicant-declared structured skills into the profile, but approve none automatically.
CREATE OR REPLACE FUNCTION public.srk_admin_review_application(p_application_id uuid,p_decision text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE a public.electrician_applications%ROWTYPE; linked_user uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  IF p_application_id IS NULL OR p_decision IS NULL OR p_decision NOT IN ('approved','rejected','suspended') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;
  SELECT * INTO a FROM public.electrician_applications WHERE id=p_application_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Application not found'; END IF;
  IF p_decision='approved' THEN
    SELECT u.id INTO linked_user FROM auth.users u
      WHERE u.phone_confirmed_at IS NOT NULL
        AND right(regexp_replace(coalesce(u.phone,''),'[^0-9]','','g'),10)=a.phone
      ORDER BY u.created_at DESC LIMIT 1;
    IF linked_user IS NULL THEN
      RAISE EXCEPTION 'Electrician must verify this application phone by OTP before approval';
    END IF;
  END IF;
  UPDATE public.electrician_applications SET verification_status=p_decision,active=false WHERE id=p_application_id;
  IF p_decision='approved' THEN
    INSERT INTO public.electrician_profiles
      (application_id,display_name,phone,state,district,pincode,skills,requested_skill_keys,approved_skill_keys,
       active,verification_status,user_id,auth_user_id,location_lat,location_lng)
    VALUES
      (p_application_id,a.full_name,a.phone,a.state,a.district,a.pincode,
       CASE WHEN nullif(trim(a.skills),'') IS NULL THEN ARRAY[]::text[] ELSE string_to_array(a.skills,',') END,
       a.requested_skill_keys,ARRAY[]::text[],false,'approved',linked_user,linked_user,a.location_lat,a.location_lng)
    ON CONFLICT(application_id) DO UPDATE SET
      display_name=excluded.display_name,phone=excluded.phone,state=excluded.state,district=excluded.district,
      pincode=excluded.pincode,skills=excluded.skills,requested_skill_keys=excluded.requested_skill_keys,
      verification_status='approved',active=false,user_id=excluded.user_id,auth_user_id=excluded.auth_user_id,
      location_lat=excluded.location_lat,location_lng=excluded.location_lng;
  ELSE
    UPDATE public.electrician_profiles SET active=false,verification_status=p_decision WHERE application_id=p_application_id;
  END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_review_application(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_application(uuid,text) TO authenticated;

-- Replace matching: category-specific jobs require at least one Admin-verified mapped skill.
CREATE OR REPLACE FUNCTION public.srk_admin_offer_booking(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_match_level text;
  v_eligible integer:=0;
  v_created integer:=0;
  v_has_rules boolean:=false;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL THEN RAISE EXCEPTION 'Booking ID required' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE='P0002'; END IF;
  IF v_booking.assigned_electrician_id IS NOT NULL THEN RAISE EXCEPTION 'Booking already has an assigned electrician'; END IF;
  IF v_booking.status NOT IN ('new','confirmed') THEN RAISE EXCEPTION 'Only new or confirmed bookings can be offered'; END IF;

  IF v_booking.selected_category IS NOT NULL THEN
    SELECT EXISTS(SELECT 1 FROM public.srk_customer_category_skill_rules r
      WHERE r.category_key=v_booking.selected_category) INTO v_has_rules;
    IF NOT v_has_rules THEN
      RETURN jsonb_build_object('success',false,'code','category_skill_mapping_missing',
        'message','इस काम की Category के लिए Admin ने अभी verified skill matching सेट नहीं की है। पहले Admin Panel में skill mapping सेट करें।',
        'match_level',null,'eligible_count',0,'offers_created',0);
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.electrician_profiles e
    WHERE e.active=true AND e.verification_status='approved'
      AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
      AND e.approved_rate_tier IS NOT NULL AND e.approved_rate_card_version IS NOT NULL
      AND e.rate_tier_approved_by IS NOT NULL AND e.rate_tier_approved_at IS NOT NULL
      AND e.pincode=v_booking.pincode AND lower(trim(e.state))=lower(trim(v_booking.state))
      AND (v_booking.selected_category IS NULL OR EXISTS(
        SELECT 1 FROM public.srk_customer_category_skill_rules r
        WHERE r.category_key=v_booking.selected_category
          AND r.skill_key=ANY(e.approved_skill_keys)))
  ) THEN v_match_level:='pincode'; ELSE v_match_level:='district'; END IF;

  WITH eligible AS (
    SELECT e.id FROM public.electrician_profiles e
    WHERE e.active=true AND e.verification_status='approved'
      AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
      AND e.approved_rate_tier IS NOT NULL AND e.approved_rate_card_version IS NOT NULL
      AND e.rate_tier_approved_by IS NOT NULL AND e.rate_tier_approved_at IS NOT NULL
      AND lower(trim(e.state))=lower(trim(v_booking.state))
      AND ((v_match_level='pincode' AND e.pincode=v_booking.pincode)
        OR (v_match_level='district' AND lower(trim(e.district))=lower(trim(v_booking.district))))
      AND (v_booking.selected_category IS NULL OR EXISTS(
        SELECT 1 FROM public.srk_customer_category_skill_rules r
        WHERE r.category_key=v_booking.selected_category
          AND r.skill_key=ANY(e.approved_skill_keys)))
  ), inserted AS (
    INSERT INTO public.job_offers(booking_id,electrician_id,status,match_level)
    SELECT p_booking_id,e.id,'offered',v_match_level FROM eligible e
    ON CONFLICT(booking_id,electrician_id) DO NOTHING RETURNING id
  )
  SELECT (SELECT count(*) FROM eligible),(SELECT count(*) FROM inserted) INTO v_eligible,v_created;

  IF v_eligible=0 THEN
    RETURN jsonb_build_object('success',false,'code','no_verified_skill_match',
      'message','इस PIN/जिले में आवश्यक verified skill और Admin-approved rate tier वाला Active इलेक्ट्रिशियन उपलब्ध नहीं है।',
      'match_level',v_match_level,'eligible_count',0,'offers_created',0);
  END IF;
  RETURN jsonb_build_object('success',true,
    'message',CASE WHEN v_match_level='pincode'
      THEN 'उसी PIN के verified-skill और rate-tier-approved इलेक्ट्रिशियनों को ऑफर भेजे गए।'
      ELSE 'PIN पर योग्य पार्टनर नहीं मिला; जिले के verified-skill और rate-tier-approved पार्टनर को ऑफर भेजे गए।' END,
    'match_level',v_match_level,'eligible_count',v_eligible,'offers_created',v_created);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_offer_booking(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_offer_booking(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.srk_get_my_offer_details();
CREATE FUNCTION public.srk_get_my_offer_details()
RETURNS TABLE(
  offer_id uuid,offer_status text,match_level text,offer_created_at timestamptz,
  booking_id uuid,service_type text,state text,district text,pincode text,
  preferred_date date,preferred_time time,work_details text,quoted_amount numeric,
  booking_status text,customer_name text,customer_phone text,address text,
  location_lat double precision,location_lng double precision,
  service_charge numeric,materials_amount numeric,quote_status text,quote_note text,
  selected_category text,selected_duration_hours smallint,approved_rate_tier text,
  approved_skill_keys text[]
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
  SELECT o.id,o.status,o.match_level,o.created_at,b.id,b.service_type,b.state,b.district,b.pincode,
    b.preferred_date,b.preferred_time,b.work_details,b.quoted_amount,b.status,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.customer_name ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.phone ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.address ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.location_lat ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.location_lng ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.service_charge ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.materials_amount ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.quote_status ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.quote_note ELSE NULL END,
    b.selected_category,b.selected_duration_hours,p.approved_rate_tier,p.approved_skill_keys
  FROM public.job_offers o
  JOIN public.electrician_profiles p ON p.id=o.electrician_id
  JOIN public.service_bookings b ON b.id=o.booking_id
  WHERE auth.uid() IS NOT NULL AND (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved' AND p.active=true
    AND p.approved_rate_tier IS NOT NULL AND p.approved_rate_card_version IS NOT NULL
    AND p.rate_tier_approved_by IS NOT NULL AND p.rate_tier_approved_at IS NOT NULL
  ORDER BY o.created_at DESC LIMIT 100;
$function$;
REVOKE ALL ON FUNCTION public.srk_get_my_offer_details() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_offer_details() TO authenticated;

COMMENT ON TABLE public.srk_customer_category_skill_rules IS
  'Admin-configured mapping: a customer work category can be offered only to electricians with at least one matching Admin-verified skill. Empty mapping fails closed.';


CREATE OR REPLACE FUNCTION public.srk_admin_get_category_skill_rules()
RETURNS TABLE(category_key text,skill_key text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
  SELECT r.category_key,r.skill_key
  FROM public.srk_customer_category_skill_rules r
  WHERE auth.uid() IS NOT NULL AND public.is_srk_admin()
  ORDER BY r.category_key,r.skill_key;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_get_category_skill_rules() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_get_category_skill_rules() TO authenticated;
