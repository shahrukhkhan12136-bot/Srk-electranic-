-- Customer-selected work category, commercial rate tier and server estimate.
-- Source migration only. Not applied to production.
CREATE SCHEMA IF NOT EXISTS srk_private;
ALTER TABLE public.service_bookings ADD COLUMN IF NOT EXISTS selected_category text, ADD COLUMN IF NOT EXISTS selected_duration_hours smallint, ADD COLUMN IF NOT EXISTS selected_rate_tier text, ADD COLUMN IF NOT EXISTS estimated_labour_paise bigint, ADD COLUMN IF NOT EXISTS estimate_rate_card_version text;
ALTER TABLE public.electrician_applications ADD COLUMN IF NOT EXISTS requested_category text;
ALTER TABLE public.electrician_profiles ADD COLUMN IF NOT EXISTS approved_rate_tier text, ADD COLUMN IF NOT EXISTS approved_rate_card_version text, ADD COLUMN IF NOT EXISTS rate_tier_approved_by uuid REFERENCES auth.users(id), ADD COLUMN IF NOT EXISTS rate_tier_approved_at timestamptz;

DO $constraints$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='service_bookings_selected_category_valid') THEN ALTER TABLE public.service_bookings ADD CONSTRAINT service_bookings_selected_category_valid CHECK(selected_category IS NULL OR selected_category IN ('home_wiring','electrical_repair','light_fan_fitting','home_repair','other')); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='service_bookings_selected_duration_hours_valid') THEN ALTER TABLE public.service_bookings ADD CONSTRAINT service_bookings_selected_duration_hours_valid CHECK(selected_duration_hours IS NULL OR selected_duration_hours BETWEEN 1 AND 8); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='service_bookings_category_duration_pair') THEN ALTER TABLE public.service_bookings ADD CONSTRAINT service_bookings_category_duration_pair CHECK((selected_category IS NULL)=(selected_duration_hours IS NULL)); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='service_bookings_selected_rate_tier_valid') THEN ALTER TABLE public.service_bookings ADD CONSTRAINT service_bookings_selected_rate_tier_valid CHECK(selected_rate_tier IS NULL OR selected_rate_tier IN ('electrical_assistant','skilled_electrician','expert_electrician','premium_electrical_specialist')); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='service_bookings_estimate_snapshot_complete') THEN ALTER TABLE public.service_bookings ADD CONSTRAINT service_bookings_estimate_snapshot_complete CHECK((selected_rate_tier IS NULL AND estimated_labour_paise IS NULL AND estimate_rate_card_version IS NULL) OR (selected_rate_tier IS NOT NULL AND estimated_labour_paise>0 AND estimate_rate_card_version IS NOT NULL AND selected_category IS NOT NULL AND selected_duration_hours BETWEEN 1 AND 8)); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='service_bookings_estimate_matches_rate_card') THEN ALTER TABLE public.service_bookings ADD CONSTRAINT service_bookings_estimate_matches_rate_card CHECK(selected_rate_tier IS NULL OR estimated_labour_paise=floor((CASE selected_rate_tier WHEN 'electrical_assistant' THEN 89900 WHEN 'skilled_electrician' THEN 119900 WHEN 'expert_electrician' THEN 159900 WHEN 'premium_electrical_specialist' THEN 199900 END)::numeric*selected_duration_hours/8+0.5)::bigint); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='electrician_applications_requested_category_check') THEN ALTER TABLE public.electrician_applications ADD CONSTRAINT electrician_applications_requested_category_check CHECK(requested_category IS NULL OR requested_category IN ('electrical_assistant','skilled_electrician','expert_electrician','premium_electrical_specialist')); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='electrician_profiles_approved_rate_tier_check') THEN ALTER TABLE public.electrician_profiles ADD CONSTRAINT electrician_profiles_approved_rate_tier_check CHECK(approved_rate_tier IS NULL OR approved_rate_tier IN ('electrical_assistant','skilled_electrician','expert_electrician','premium_electrical_specialist')); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='electrician_profiles_rate_tier_approval_pair_check') THEN ALTER TABLE public.electrician_profiles ADD CONSTRAINT electrician_profiles_rate_tier_approval_pair_check CHECK((approved_rate_tier IS NULL AND approved_rate_card_version IS NULL AND rate_tier_approved_by IS NULL AND rate_tier_approved_at IS NULL) OR (approved_rate_tier IS NOT NULL AND approved_rate_card_version IS NOT NULL AND rate_tier_approved_by IS NOT NULL AND rate_tier_approved_at IS NOT NULL)); END IF;
END;
$constraints$;

CREATE TABLE IF NOT EXISTS public.srk_electrician_rate_tier_audit(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,application_id uuid REFERENCES public.electrician_applications(id) ON DELETE RESTRICT,previous_rate_tier text,new_rate_tier text NOT NULL CHECK(new_rate_tier IN ('electrical_assistant','skilled_electrician','expert_electrician','premium_electrical_specialist')),rate_card_version text NOT NULL,changed_by uuid NOT NULL REFERENCES auth.users(id),changed_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.srk_electrician_rate_tier_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_electrician_rate_tier_audit FROM PUBLIC,anon,authenticated;
GRANT SELECT ON TABLE public.srk_electrician_rate_tier_audit TO authenticated;
DROP POLICY IF EXISTS srk_electrician_rate_tier_audit_admin_select ON public.srk_electrician_rate_tier_audit;
CREATE POLICY srk_electrician_rate_tier_audit_admin_select ON public.srk_electrician_rate_tier_audit FOR SELECT TO authenticated USING((SELECT public.is_srk_admin()));

CREATE TABLE IF NOT EXISTS srk_private.electrician_rate_tier_authorizations(transaction_id bigint NOT NULL,electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE CASCADE,actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,PRIMARY KEY(transaction_id,electrician_profile_id));
REVOKE ALL ON TABLE srk_private.electrician_rate_tier_authorizations FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_guard_electrician_rate_tier_activation() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_authorized boolean:=false;
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.approved_rate_tier IS NOT NULL OR NEW.approved_rate_card_version IS NOT NULL OR NEW.rate_tier_approved_by IS NOT NULL OR NEW.rate_tier_approved_at IS NOT NULL THEN RAISE EXCEPTION 'Rate tier must be assigned through the audited Admin RPC' USING ERRCODE='42501'; END IF;
 ELSIF NEW.approved_rate_tier IS DISTINCT FROM OLD.approved_rate_tier OR NEW.approved_rate_card_version IS DISTINCT FROM OLD.approved_rate_card_version OR NEW.rate_tier_approved_by IS DISTINCT FROM OLD.rate_tier_approved_by OR NEW.rate_tier_approved_at IS DISTINCT FROM OLD.rate_tier_approved_at THEN
  SELECT EXISTS(SELECT 1 FROM srk_private.electrician_rate_tier_authorizations a WHERE a.transaction_id=pg_catalog.txid_current() AND a.electrician_profile_id=NEW.id AND a.actor_id=auth.uid()) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Rate tier changes require the audited Admin RPC' USING ERRCODE='42501'; END IF;
 END IF;
 IF NEW.active IS TRUE AND (NEW.approved_rate_tier IS NULL OR NEW.approved_rate_card_version IS NULL OR NEW.rate_tier_approved_by IS NULL OR NEW.rate_tier_approved_at IS NULL) THEN RAISE EXCEPTION 'Admin must approve an electrician rate tier before activation' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;$function$;
REVOKE ALL ON FUNCTION public.srk_guard_electrician_rate_tier_activation() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_guard_electrician_rate_tier_activation ON public.electrician_profiles;
CREATE TRIGGER srk_guard_electrician_rate_tier_activation BEFORE INSERT OR UPDATE OF active,approved_rate_tier,approved_rate_card_version,rate_tier_approved_by,rate_tier_approved_at ON public.electrician_profiles FOR EACH ROW EXECUTE FUNCTION public.srk_guard_electrician_rate_tier_activation();

CREATE OR REPLACE FUNCTION public.srk_admin_set_electrician_rate_tier(p_electrician_profile_id uuid,p_rate_tier text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_profile public.electrician_profiles%ROWTYPE; v_previous text; v_version constant text:='SRK-CUSTOMER-LABOUR-2026-11-13-V1';
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'Admin only' USING ERRCODE='42501'; END IF;
 IF p_electrician_profile_id IS NULL OR p_rate_tier IS NULL OR p_rate_tier NOT IN ('electrical_assistant','skilled_electrician','expert_electrician','premium_electrical_specialist') THEN RAISE EXCEPTION 'Invalid electrician profile or rate tier' USING ERRCODE='22023'; END IF;
 SELECT * INTO v_profile FROM public.electrician_profiles WHERE id=p_electrician_profile_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Electrician profile not found' USING ERRCODE='P0002'; END IF;
 IF v_profile.verification_status<>'approved' THEN RAISE EXCEPTION 'Electrician KYC must be approved before assigning a rate tier' USING ERRCODE='23514'; END IF;
 v_previous:=v_profile.approved_rate_tier;
 INSERT INTO srk_private.electrician_rate_tier_authorizations(transaction_id,electrician_profile_id,actor_id) VALUES(pg_catalog.txid_current(),v_profile.id,auth.uid());
 UPDATE public.electrician_profiles SET approved_rate_tier=p_rate_tier,approved_rate_card_version=v_version,rate_tier_approved_by=auth.uid(),rate_tier_approved_at=now() WHERE id=p_electrician_profile_id;
 DELETE FROM srk_private.electrician_rate_tier_authorizations WHERE transaction_id=pg_catalog.txid_current() AND electrician_profile_id=v_profile.id AND actor_id=auth.uid();
 INSERT INTO public.srk_electrician_rate_tier_audit(electrician_profile_id,application_id,previous_rate_tier,new_rate_tier,rate_card_version,changed_by) VALUES(v_profile.id,v_profile.application_id,v_previous,p_rate_tier,v_version,auth.uid());
 RETURN jsonb_build_object('success',true,'electrician_profile_id',v_profile.id,'approved_rate_tier',p_rate_tier,'rate_card_version',v_version);
END;$function$;
REVOKE ALL ON FUNCTION public.srk_admin_set_electrician_rate_tier(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_set_electrician_rate_tier(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION private.srk_offer_booking_to_eligible_electricians(p_booking_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog','public','auth','pg_temp' AS $function$
DECLARE v_booking public.service_bookings%ROWTYPE; v_match_level text; v_eligible integer:=0; v_created integer:=0;
BEGIN
 IF p_booking_id IS NULL THEN RAISE EXCEPTION 'Booking ID required' USING ERRCODE='22023'; END IF;
 SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE='P0002'; END IF;
 IF v_booking.assigned_electrician_id IS NOT NULL OR v_booking.status NOT IN ('new','confirmed') THEN RETURN jsonb_build_object('success',false,'eligible_count',0,'offers_created',0); END IF;
 IF v_booking.selected_category IS NOT NULL AND (v_booking.selected_rate_tier IS NULL OR v_booking.selected_duration_hours IS NULL) THEN RETURN jsonb_build_object('success',false,'code','customer_selection_incomplete','message','ग्राहक की काम की श्रेणी, इलेक्ट्रिशियन श्रेणी और अवधि पूरी नहीं है।'); END IF;
 IF EXISTS(SELECT 1 FROM public.electrician_profiles e WHERE e.active=true AND e.verification_status='approved' AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id AND e.approved_rate_tier IS NOT NULL AND e.approved_rate_card_version IS NOT NULL AND e.rate_tier_approved_by IS NOT NULL AND e.rate_tier_approved_at IS NOT NULL AND (v_booking.selected_rate_tier IS NULL OR e.approved_rate_tier=v_booking.selected_rate_tier) AND e.pincode=v_booking.pincode AND lower(trim(e.state))=lower(trim(v_booking.state))) THEN v_match_level:='pincode'; ELSE v_match_level:='district'; END IF;
 WITH eligible AS (SELECT e.id FROM public.electrician_profiles e WHERE e.active=true AND e.verification_status='approved' AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id AND e.approved_rate_tier IS NOT NULL AND e.approved_rate_card_version IS NOT NULL AND e.rate_tier_approved_by IS NOT NULL AND e.rate_tier_approved_at IS NOT NULL AND (v_booking.selected_rate_tier IS NULL OR e.approved_rate_tier=v_booking.selected_rate_tier) AND lower(trim(e.state))=lower(trim(v_booking.state)) AND ((v_match_level='pincode' AND e.pincode=v_booking.pincode) OR (v_match_level='district' AND lower(trim(e.district))=lower(trim(v_booking.district))))), inserted AS (INSERT INTO public.job_offers(booking_id,electrician_id,status,match_level) SELECT p_booking_id,e.id,'offered',v_match_level FROM eligible e ON CONFLICT(booking_id,electrician_id) DO NOTHING RETURNING id) SELECT (SELECT count(*) FROM eligible),(SELECT count(*) FROM inserted) INTO v_eligible,v_created;
 IF v_eligible=0 THEN RETURN jsonb_build_object('success',false,'code','no_exact_rate_tier_match','message','इस PIN/जिले में ग्राहक की चुनी हुई इलेक्ट्रिशियन श्रेणी का कोई Active और Admin-approved पार्टनर उपलब्ध नहीं है। श्रेणी अपने-आप नहीं बदली जाएगी।','match_level',v_match_level,'eligible_count',0,'offers_created',0); END IF;
 RETURN jsonb_build_object('success',true,'message',CASE WHEN v_match_level='pincode' THEN 'ग्राहक की चुनी हुई श्रेणी के उसी PIN के approved इलेक्ट्रिशियनों को ऑफर भेजे गए।' ELSE 'उसी PIN पर चुनी श्रेणी का पार्टनर नहीं मिला; उसी जिले में चुनी श्रेणी के approved पार्टनर को ऑफर भेजे गए।' END,'match_level',v_match_level,'eligible_count',v_eligible,'offers_created',v_created);
END;$function$;
REVOKE ALL ON FUNCTION private.srk_offer_booking_to_eligible_electricians(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.broadcast_booking_job() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog','public','auth','pg_temp' AS $function$
BEGIN PERFORM private.srk_offer_booking_to_eligible_electricians(NEW.id); RETURN NEW; END;$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_offer_booking(p_booking_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog','public','auth','pg_temp' AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501'; END IF;
 RETURN private.srk_offer_booking_to_eligible_electricians(p_booking_id);
END;$function$;
REVOKE ALL ON FUNCTION public.srk_admin_offer_booking(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_offer_booking(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_guard_job_offer_selected_rate_tier() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog','public','pg_temp' AS $function$
DECLARE v_selected_tier text; v_electrician_tier text;
BEGIN
 SELECT b.selected_rate_tier INTO v_selected_tier FROM public.service_bookings b WHERE b.id=NEW.booking_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found for job offer'; END IF;
 IF v_selected_tier IS NOT NULL THEN
  SELECT e.approved_rate_tier INTO v_electrician_tier FROM public.electrician_profiles e WHERE e.id=NEW.electrician_id AND e.active=true AND e.verification_status='approved' AND e.approved_rate_card_version IS NOT NULL AND e.rate_tier_approved_by IS NOT NULL AND e.rate_tier_approved_at IS NOT NULL;
  IF NOT FOUND OR v_electrician_tier IS DISTINCT FROM v_selected_tier THEN RAISE EXCEPTION 'Electrician rate tier must exactly match the customer-selected tier' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END;$function$;
REVOKE ALL ON FUNCTION public.srk_guard_job_offer_selected_rate_tier() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_guard_job_offer_selected_rate_tier ON public.job_offers;
CREATE TRIGGER srk_guard_job_offer_selected_rate_tier BEFORE INSERT OR UPDATE OF booking_id,electrician_id ON public.job_offers FOR EACH ROW EXECUTE FUNCTION public.srk_guard_job_offer_selected_rate_tier();

COMMENT ON FUNCTION private.srk_offer_booking_to_eligible_electricians(uuid) IS 'Exact commercial rate-tier matching for new customer-selected bookings; no automatic tier downgrade or upgrade.';
