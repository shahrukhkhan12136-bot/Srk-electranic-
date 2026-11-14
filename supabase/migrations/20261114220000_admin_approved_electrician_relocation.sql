-- Admin-approved electrician relocation: exactly one active operating district per profile.
-- Existing KYC/application address remains unchanged; current operating area lives on electrician_profiles.

CREATE TABLE IF NOT EXISTS srk_private.srk_electrician_area_change_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  old_state text NOT NULL,
  old_district text NOT NULL,
  old_pincode text NOT NULL,
  requested_state text NOT NULL,
  requested_district text NOT NULL,
  requested_pincode text NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','cancelled')),
  admin_note text,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE srk_private.srk_electrician_area_change_requests ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX IF NOT EXISTS srk_electrician_one_pending_area_request
  ON srk_private.srk_electrician_area_change_requests(electrician_profile_id)
  WHERE status='pending';
CREATE INDEX IF NOT EXISTS srk_electrician_area_requests_status_created
  ON srk_private.srk_electrician_area_change_requests(status,created_at DESC);
REVOKE ALL ON TABLE srk_private.srk_electrician_area_change_requests FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_electrician_request_area_change(
  p_state text,p_district text,p_pincode text,p_reason text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid(); v_profile public.electrician_profiles%ROWTYPE;
 v_state text:=regexp_replace(btrim(coalesce(p_state,'')),'[[:space:]]+',' ','g');
 v_district text:=regexp_replace(btrim(coalesce(p_district,'')),'[[:space:]]+',' ','g');
 v_pin text:=btrim(coalesce(p_pincode,'')); v_reason text:=regexp_replace(btrim(coalesce(p_reason,'')),'[[:space:]]+',' ','g');
 v_id uuid;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 IF char_length(v_state)<2 OR char_length(v_state)>80 OR char_length(v_district)<2 OR char_length(v_district)>80
   OR v_pin !~ '^[0-9]{6}$' OR char_length(v_reason)<10 OR char_length(v_reason)>500 THEN
   RAISE EXCEPTION 'Valid state, district, six digit PIN and 10-500 character reason required' USING ERRCODE='22023';
 END IF;
 SELECT * INTO v_profile FROM public.electrician_profiles
  WHERE user_id=v_uid AND auth_user_id=v_uid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Linked electrician profile required' USING ERRCODE='42501'; END IF;
 IF v_profile.active IS DISTINCT FROM true OR v_profile.verification_status<>'approved' THEN
   RAISE EXCEPTION 'Only active, Admin-approved electricians can request relocation' USING ERRCODE='42501';
 END IF;
 IF lower(v_profile.state)=lower(v_state) AND lower(v_profile.district)=lower(v_district)
   AND v_profile.pincode=v_pin THEN
   RAISE EXCEPTION 'Requested operating area is already active' USING ERRCODE='22023';
 END IF;
 IF EXISTS(SELECT 1 FROM srk_private.srk_electrician_area_change_requests
   WHERE electrician_profile_id=v_profile.id AND status='pending') THEN
   RAISE EXCEPTION 'A relocation request is already pending' USING ERRCODE='55000';
 END IF;
 INSERT INTO srk_private.srk_electrician_area_change_requests(
  electrician_profile_id,actor_user_id,old_state,old_district,old_pincode,
  requested_state,requested_district,requested_pincode,reason)
 VALUES(v_profile.id,v_uid,v_profile.state,v_profile.district,v_profile.pincode,
  v_state,v_district,v_pin,v_reason) RETURNING id INTO v_id;
 RETURN jsonb_build_object('success',true,'request_id',v_id,'status','pending');
END;$function$;
REVOKE ALL ON FUNCTION public.srk_electrician_request_area_change(text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_request_area_change(text,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_electrician_list_my_area_requests()
RETURNS TABLE(id uuid,old_state text,old_district text,requested_state text,requested_district text,
 requested_pincode text,reason text,status text,admin_note text,created_at timestamptz,reviewed_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid(); v_profile_id uuid;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 SELECT id INTO v_profile_id FROM public.electrician_profiles WHERE user_id=v_uid AND auth_user_id=v_uid;
 IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Linked electrician profile required' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT r.id,r.old_state,r.old_district,r.requested_state,r.requested_district,
  r.requested_pincode,r.reason,r.status,r.admin_note,r.created_at,r.reviewed_at
 FROM srk_private.srk_electrician_area_change_requests r
 WHERE r.electrician_profile_id=v_profile_id ORDER BY r.created_at DESC LIMIT 20;
END;$function$;
REVOKE ALL ON FUNCTION public.srk_electrician_list_my_area_requests() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_list_my_area_requests() TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_list_electrician_area_requests(p_limit integer DEFAULT 100)
RETURNS TABLE(id uuid,electrician_profile_id uuid,electrician_name text,electrician_phone text,
 old_state text,old_district text,old_pincode text,requested_state text,requested_district text,
 requested_pincode text,reason text,status text,admin_note text,created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
  RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
 END IF;
 RETURN QUERY SELECT r.id,r.electrician_profile_id,e.display_name,e.phone,
  r.old_state,r.old_district,r.old_pincode,r.requested_state,r.requested_district,
  r.requested_pincode,r.reason,r.status,r.admin_note,r.created_at
 FROM srk_private.srk_electrician_area_change_requests r
 JOIN public.electrician_profiles e ON e.id=r.electrician_profile_id
 WHERE r.status='pending' ORDER BY r.created_at ASC LIMIT greatest(1,least(coalesce(p_limit,100),300));
END;$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_electrician_area_requests(integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_electrician_area_requests(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_review_electrician_area_request(
 p_request_id uuid,p_decision text,p_note text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid(); v_req srk_private.srk_electrician_area_change_requests%ROWTYPE;
 v_profile public.electrician_profiles%ROWTYPE; v_booking_id uuid; v_advanced integer:=0;
 v_note text:=nullif(regexp_replace(btrim(coalesce(p_note,'')),'[[:space:]]+',' ','g'),'');
BEGIN
 IF v_uid IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
 IF p_decision IS NULL OR p_decision NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Invalid decision' USING ERRCODE='22023'; END IF;
 IF v_note IS NOT NULL AND char_length(v_note)>1000 THEN RAISE EXCEPTION 'Admin note must be at most 1000 characters' USING ERRCODE='22023'; END IF;
 IF p_decision='rejected' AND (v_note IS NULL OR char_length(v_note)<5) THEN
  RAISE EXCEPTION 'Rejection reason must contain at least 5 characters' USING ERRCODE='22023';
 END IF;
 SELECT * INTO v_req FROM srk_private.srk_electrician_area_change_requests
  WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND OR v_req.status<>'pending' THEN RAISE EXCEPTION 'Pending request not found' USING ERRCODE='P0002'; END IF;
 SELECT * INTO v_profile FROM public.electrician_profiles WHERE id=v_req.electrician_profile_id FOR UPDATE;
 IF NOT FOUND OR v_profile.active IS DISTINCT FROM true OR v_profile.verification_status<>'approved' THEN
  RAISE EXCEPTION 'Electrician is no longer active and approved' USING ERRCODE='55000';
 END IF;
 IF p_decision='approved' THEN
  -- Preserve accepted assignments; close only unaccepted offers in the old area.
  UPDATE public.electrician_profiles SET state=v_req.requested_state,district=v_req.requested_district,
   pincode=v_req.requested_pincode,location_lat=NULL,location_lng=NULL
  WHERE id=v_profile.id;
  FOR v_booking_id IN
   UPDATE public.job_offers SET status='declined',responded_at=clock_timestamp()
   WHERE electrician_id=v_profile.id AND status='offered' RETURNING booking_id
  LOOP
   -- Reuse the existing Admin dispatch RPC; no separate dispatcher exists in this schema.
   IF EXISTS (
    SELECT 1 FROM public.service_bookings b
    WHERE b.id=v_booking_id AND b.assigned_electrician_id IS NULL
      AND b.status IN ('new','confirmed')
   ) THEN
    PERFORM public.srk_admin_offer_booking(v_booking_id);
    v_advanced:=v_advanced+1;
   END IF;
  END LOOP;
 END IF;
 UPDATE srk_private.srk_electrician_area_change_requests SET status=p_decision,
  admin_note=v_note,reviewed_by=v_uid,reviewed_at=clock_timestamp() WHERE id=v_req.id;
 RETURN jsonb_build_object('success',true,'status',p_decision,'closed_old_area_offers',v_advanced,
  'active_state',CASE WHEN p_decision='approved' THEN v_req.requested_state ELSE v_profile.state END,
  'active_district',CASE WHEN p_decision='approved' THEN v_req.requested_district ELSE v_profile.district END);
END;$function$;
REVOKE ALL ON FUNCTION public.srk_admin_review_electrician_area_request(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_electrician_area_request(uuid,text,text) TO authenticated;

COMMENT ON TABLE srk_private.srk_electrician_area_change_requests IS
 'Admin-approved relocation requests. Approval atomically replaces the single active operating area on electrician_profiles; historical application/KYC address is retained.';
