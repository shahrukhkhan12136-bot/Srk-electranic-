-- Re-check the candidate's current operating area at dispatch time.
-- This prevents an old queued candidate snapshot from receiving work after relocation.
CREATE OR REPLACE FUNCTION private.srk_dispatch_next_booking_offer(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
 v_booking public.service_bookings%ROWTYPE;
 v_dispatch srk_private.srk_booking_offer_dispatch%ROWTYPE;
 v_candidate srk_private.srk_booking_offer_candidates%ROWTYPE;
 v_electrician public.electrician_profiles%ROWTYPE;
 v_distance numeric(14,2);
 v_match_level text;
 v_offer_id uuid;
BEGIN
 SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE='P0002'; END IF;
 IF v_booking.assigned_electrician_id IS NOT NULL OR v_booking.status NOT IN ('new','confirmed') THEN
  UPDATE srk_private.srk_booking_offer_dispatch SET dispatch_status='cancelled',updated_at=clock_timestamp()
   WHERE booking_id=p_booking_id AND dispatch_status='active';
  RETURN jsonb_build_object('success',false,'code','booking_not_offerable');
 END IF;
 SELECT * INTO v_dispatch FROM srk_private.srk_booking_offer_dispatch WHERE booking_id=p_booking_id FOR UPDATE;
 IF NOT FOUND OR v_dispatch.dispatch_status<>'active' THEN
  RETURN jsonb_build_object('success',false,'code','dispatch_not_active');
 END IF;
 IF EXISTS(SELECT 1 FROM public.job_offers WHERE booking_id=p_booking_id AND status='offered'
   AND expires_at>clock_timestamp()) THEN
  RETURN jsonb_build_object('success',true,'code','offer_already_live');
 END IF;
 LOOP
  SELECT * INTO v_candidate FROM srk_private.srk_booking_offer_candidates
   WHERE booking_id=p_booking_id AND sequence_no=v_dispatch.next_sequence;
  IF NOT FOUND THEN
   UPDATE srk_private.srk_booking_offer_dispatch SET dispatch_status='exhausted',updated_at=clock_timestamp()
    WHERE booking_id=p_booking_id;
   RETURN jsonb_build_object('success',false,'code','no_more_eligible_electricians',
    'message','इस क्षेत्र में अभी कोई और उपलब्ध, स्वीकृत इलेक्ट्रिशियन नहीं है।');
  END IF;
  UPDATE srk_private.srk_booking_offer_dispatch SET next_sequence=next_sequence+1,updated_at=clock_timestamp()
   WHERE booking_id=p_booking_id RETURNING * INTO v_dispatch;
  SELECT * INTO v_electrician FROM public.electrician_profiles e
   WHERE e.id=v_candidate.electrician_id AND e.active=true AND e.available_for_work=true
    AND e.verification_status='approved' AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
    AND lower(trim(e.state))=lower(trim(v_booking.state))
    AND lower(trim(e.district))=lower(trim(v_booking.district))
    AND (v_booking.selected_rate_tier IS NULL OR (
      e.approved_rate_tier=v_booking.selected_rate_tier AND e.approved_rate_card_version IS NOT NULL
      AND e.rate_tier_approved_by IS NOT NULL AND e.rate_tier_approved_at IS NOT NULL));
  IF FOUND AND NOT EXISTS(SELECT 1 FROM public.job_offers o
    WHERE o.booking_id=p_booking_id AND o.electrician_id=v_candidate.electrician_id) THEN
   -- Recompute match label and distance from the electrician's CURRENT area/location.
   -- Relocation clears stale coordinates; never expose the old snapshot distance.
   v_match_level:=CASE WHEN v_electrician.pincode=v_booking.pincode THEN 'pincode' ELSE 'district' END;
   v_distance:=NULL;
   IF v_booking.location_lat IS NOT NULL AND v_booking.location_lng IS NOT NULL
      AND v_electrician.location_lat IS NOT NULL AND v_electrician.location_lng IS NOT NULL THEN
     v_distance:=2*6371000*asin(sqrt(least(1,
       power(sin(radians(v_electrician.location_lat-v_booking.location_lat)/2),2)
       +cos(radians(v_booking.location_lat))*cos(radians(v_electrician.location_lat))
        *power(sin(radians(v_electrician.location_lng-v_booking.location_lng)/2),2)
     )));
   END IF;
   INSERT INTO public.job_offers(booking_id,electrician_id,status,match_level,expires_at)
    VALUES(p_booking_id,v_candidate.electrician_id,'offered',v_match_level,clock_timestamp()+interval '3 minutes')
    RETURNING id INTO v_offer_id;
   RETURN jsonb_build_object('success',true,'code','offer_dispatched','offer_id',v_offer_id,
    'electrician_id',v_candidate.electrician_id,'sequence_no',v_candidate.sequence_no,
    'match_level',v_match_level,'distance_meters',v_distance,
    'expires_at',clock_timestamp()+interval '3 minutes');
  END IF;
 END LOOP;
END;$function$;
REVOKE ALL ON FUNCTION private.srk_dispatch_next_booking_offer(uuid) FROM PUBLIC,anon,authenticated;
