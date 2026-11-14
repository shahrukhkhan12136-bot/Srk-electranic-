-- Sequential, nearest-first electrician offers for customer-selected commercial tiers.
-- One live offer per booking. Decline/timeout advances to the next eligible electrician.

ALTER TABLE public.job_offers ADD COLUMN IF NOT EXISTS expires_at timestamptz;

CREATE TABLE IF NOT EXISTS srk_private.srk_booking_offer_dispatch (
  booking_id uuid PRIMARY KEY REFERENCES public.service_bookings(id) ON DELETE CASCADE,
  match_level text NOT NULL CHECK (match_level IN ('pincode','district')),
  next_sequence integer NOT NULL DEFAULT 1 CHECK (next_sequence > 0),
  dispatch_status text NOT NULL DEFAULT 'active'
    CHECK (dispatch_status IN ('active','accepted','exhausted','cancelled')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE IF NOT EXISTS srk_private.srk_booking_offer_candidates (
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE CASCADE,
  sequence_no integer NOT NULL CHECK (sequence_no > 0),
  electrician_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  distance_meters numeric(14,2),
  match_level text NOT NULL CHECK (match_level IN ('pincode','district')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (booking_id,sequence_no),
  UNIQUE (booking_id,electrician_id)
);
REVOKE ALL ON TABLE srk_private.srk_booking_offer_dispatch,
  srk_private.srk_booking_offer_candidates FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS job_offers_live_expiry_idx
  ON public.job_offers(expires_at) WHERE status='offered';

CREATE OR REPLACE FUNCTION private.srk_dispatch_next_booking_offer(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_dispatch srk_private.srk_booking_offer_dispatch%ROWTYPE;
  v_candidate srk_private.srk_booking_offer_candidates%ROWTYPE;
  v_offer_id uuid;
BEGIN
  SELECT * INTO v_booking FROM public.service_bookings
    WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE='P0002'; END IF;
  IF v_booking.assigned_electrician_id IS NOT NULL
     OR v_booking.status NOT IN ('new','confirmed') THEN
    UPDATE srk_private.srk_booking_offer_dispatch
      SET dispatch_status='cancelled',updated_at=clock_timestamp()
      WHERE booking_id=p_booking_id AND dispatch_status='active';
    RETURN jsonb_build_object('success',false,'code','booking_not_offerable');
  END IF;

  SELECT * INTO v_dispatch FROM srk_private.srk_booking_offer_dispatch
    WHERE booking_id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_dispatch.dispatch_status<>'active' THEN
    RETURN jsonb_build_object('success',false,'code','dispatch_not_active');
  END IF;
  IF EXISTS(SELECT 1 FROM public.job_offers
    WHERE booking_id=p_booking_id AND status='offered'
      AND expires_at>clock_timestamp()) THEN
    RETURN jsonb_build_object('success',true,'code','offer_already_live');
  END IF;

  LOOP
    SELECT * INTO v_candidate FROM srk_private.srk_booking_offer_candidates
      WHERE booking_id=p_booking_id AND sequence_no=v_dispatch.next_sequence;
    IF NOT FOUND THEN
      UPDATE srk_private.srk_booking_offer_dispatch
        SET dispatch_status='exhausted',updated_at=clock_timestamp()
        WHERE booking_id=p_booking_id;
      RETURN jsonb_build_object('success',false,'code','no_more_eligible_electricians',
        'message','इस श्रेणी में अभी कोई और उपलब्ध, स्वीकृत इलेक्ट्रिशियन नहीं है। आपकी चुनी हुई श्रेणी नहीं बदली गई।');
    END IF;

    UPDATE srk_private.srk_booking_offer_dispatch
      SET next_sequence=next_sequence+1,updated_at=clock_timestamp()
      WHERE booking_id=p_booking_id RETURNING * INTO v_dispatch;

    IF EXISTS(SELECT 1 FROM public.electrician_profiles e
      WHERE e.id=v_candidate.electrician_id AND e.active=true
        AND e.verification_status='approved' AND e.auth_user_id IS NOT NULL
        AND e.user_id=e.auth_user_id
        AND (v_booking.selected_rate_tier IS NULL OR (
          e.approved_rate_tier=v_booking.selected_rate_tier
          AND e.approved_rate_card_version IS NOT NULL
          AND e.rate_tier_approved_by IS NOT NULL
          AND e.rate_tier_approved_at IS NOT NULL
        )))
      AND NOT EXISTS(SELECT 1 FROM public.job_offers o
        WHERE o.booking_id=p_booking_id AND o.electrician_id=v_candidate.electrician_id) THEN
      INSERT INTO public.job_offers(booking_id,electrician_id,status,match_level,expires_at)
      VALUES(p_booking_id,v_candidate.electrician_id,'offered',
        v_candidate.match_level,clock_timestamp()+interval '3 minutes')
      RETURNING id INTO v_offer_id;
      RETURN jsonb_build_object('success',true,'code','offer_dispatched',
        'offer_id',v_offer_id,'electrician_id',v_candidate.electrician_id,
        'sequence_no',v_candidate.sequence_no,'match_level',v_candidate.match_level,
        'distance_meters',v_candidate.distance_meters,
        'expires_at',clock_timestamp()+interval '3 minutes');
    END IF;
  END LOOP;
END;
$function$;
REVOKE ALL ON FUNCTION private.srk_dispatch_next_booking_offer(uuid)
  FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.srk_offer_booking_to_eligible_electricians(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_match_level text;
  v_has_pincode boolean;
  v_candidate_count integer;
  v_result jsonb;
BEGIN
  IF p_booking_id IS NULL THEN RAISE EXCEPTION 'Booking ID required' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings
    WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE='P0002'; END IF;
  IF v_booking.assigned_electrician_id IS NOT NULL
     OR v_booking.status NOT IN ('new','confirmed') THEN
    RETURN jsonb_build_object('success',false,'code','booking_not_offerable');
  END IF;
  IF v_booking.selected_category IS NOT NULL
     AND (v_booking.selected_rate_tier IS NULL
       OR v_booking.selected_duration_hours IS NULL
       OR v_booking.estimated_labour_paise IS NULL
       OR v_booking.estimate_rate_card_version IS NULL) THEN
    RETURN jsonb_build_object('success',false,'code','customer_selection_incomplete');
  END IF;
  IF EXISTS(SELECT 1 FROM srk_private.srk_booking_offer_dispatch
    WHERE booking_id=p_booking_id) THEN
    RETURN private.srk_dispatch_next_booking_offer(p_booking_id);
  END IF;

  SELECT EXISTS(SELECT 1 FROM public.electrician_profiles e
    WHERE e.active=true AND e.verification_status='approved'
      AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
      AND (v_booking.selected_rate_tier IS NULL OR (
        e.approved_rate_tier=v_booking.selected_rate_tier
        AND e.approved_rate_card_version IS NOT NULL
        AND e.rate_tier_approved_by IS NOT NULL
        AND e.rate_tier_approved_at IS NOT NULL))
      AND e.pincode=v_booking.pincode
      AND lower(trim(e.state))=lower(trim(v_booking.state)))
    INTO v_has_pincode;
  v_match_level:=CASE WHEN v_has_pincode THEN 'pincode' ELSE 'district' END;

  INSERT INTO srk_private.srk_booking_offer_candidates(
    booking_id,sequence_no,electrician_id,distance_meters,match_level
  )
  SELECT p_booking_id,
    row_number() OVER(ORDER BY
      CASE WHEN v_booking.location_lat IS NOT NULL AND v_booking.location_lng IS NOT NULL
             AND e.location_lat IS NOT NULL AND e.location_lng IS NOT NULL
        THEN 0 ELSE 1 END,
      CASE WHEN v_booking.location_lat IS NOT NULL AND v_booking.location_lng IS NOT NULL
             AND e.location_lat IS NOT NULL AND e.location_lng IS NOT NULL
        THEN 2*6371000*asin(sqrt(least(1,
          power(sin(radians(e.location_lat-v_booking.location_lat)/2),2)
          +cos(radians(v_booking.location_lat))*cos(radians(e.location_lat))
           *power(sin(radians(e.location_lng-v_booking.location_lng)/2),2)
        ))) ELSE NULL END NULLS LAST,
      e.created_at ASC,e.id ASC)::integer,
    e.id,
    CASE WHEN v_booking.location_lat IS NOT NULL AND v_booking.location_lng IS NOT NULL
           AND e.location_lat IS NOT NULL AND e.location_lng IS NOT NULL
      THEN 2*6371000*asin(sqrt(least(1,
        power(sin(radians(e.location_lat-v_booking.location_lat)/2),2)
        +cos(radians(v_booking.location_lat))*cos(radians(e.location_lat))
         *power(sin(radians(e.location_lng-v_booking.location_lng)/2),2)
      ))) ELSE NULL END,
    v_match_level
  FROM public.electrician_profiles e
  WHERE e.active=true AND e.verification_status='approved'
    AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
    AND (v_booking.selected_rate_tier IS NULL OR (
      e.approved_rate_tier=v_booking.selected_rate_tier
      AND e.approved_rate_card_version IS NOT NULL
      AND e.rate_tier_approved_by IS NOT NULL
      AND e.rate_tier_approved_at IS NOT NULL))
    AND lower(trim(e.state))=lower(trim(v_booking.state))
    AND ((v_match_level='pincode' AND e.pincode=v_booking.pincode)
      OR (v_match_level='district' AND lower(trim(e.district))=lower(trim(v_booking.district))));

  GET DIAGNOSTICS v_candidate_count=ROW_COUNT;
  IF v_candidate_count=0 THEN
    RETURN jsonb_build_object('success',false,'code','no_exact_rate_tier_match',
      'message','इस PIN/जिले में आपकी चुनी हुई इलेक्ट्रिशियन श्रेणी का कोई Active और Admin-approved पार्टनर उपलब्ध नहीं है। श्रेणी अपने-आप नहीं बदली जाएगी।',
      'match_level',v_match_level,'eligible_count',0,'offers_created',0);
  END IF;

  INSERT INTO srk_private.srk_booking_offer_dispatch(booking_id,match_level,next_sequence,dispatch_status)
    VALUES(p_booking_id,v_match_level,1,'active');
  v_result:=private.srk_dispatch_next_booking_offer(p_booking_id);
  RETURN v_result||jsonb_build_object('match_level',v_match_level,
    'eligible_count',v_candidate_count,'dispatch_mode','sequential_nearest_first');
END;
$function$;
REVOKE ALL ON FUNCTION private.srk_offer_booking_to_eligible_electricians(uuid)
  FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.broadcast_booking_job()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  PERFORM private.srk_offer_booking_to_eligible_electricians(NEW.id);
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.broadcast_booking_job() FROM PUBLIC,anon,authenticated;
-- Ensure exactly one AFTER INSERT trigger invokes the sequential dispatcher.
DO $trigger$
DECLARE v_trigger record;
BEGIN
  FOR v_trigger IN
    SELECT tgname FROM pg_trigger
    WHERE tgrelid='public.service_bookings'::regclass
      AND NOT tgisinternal
      AND tgfoid='public.broadcast_booking_job()'::regprocedure
  LOOP
    EXECUTE format('DROP TRIGGER %I ON public.service_bookings',v_trigger.tgname);
  END LOOP;
END;
$trigger$;
CREATE TRIGGER broadcast_new_booking
  AFTER INSERT ON public.service_bookings
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_booking_job();


CREATE OR REPLACE FUNCTION public.srk_respond_to_offer(p_offer_id uuid,p_response text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_booking_id uuid;
  v_electrician_id uuid;
  v_offer_status text;
  v_expires_at timestamptz;
  v_next jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_response NOT IN ('accepted','declined') THEN RAISE EXCEPTION 'Invalid response' USING ERRCODE='22023'; END IF;

  SELECT o.booking_id,o.electrician_id,o.status,o.expires_at
    INTO v_booking_id,v_electrician_id,v_offer_status,v_expires_at
  FROM public.job_offers o
  JOIN public.electrician_profiles e ON e.id=o.electrician_id
  WHERE o.id=p_offer_id AND e.user_id=auth.uid() AND e.auth_user_id=auth.uid()
    AND e.verification_status='approved' AND e.active=true
  FOR UPDATE OF o;
  IF v_booking_id IS NULL THEN RAISE EXCEPTION 'Offer not found or electrician is not active' USING ERRCODE='P0002'; END IF;
  IF v_offer_status<>'offered' THEN RAISE EXCEPTION 'Offer already answered or expired' USING ERRCODE='55000'; END IF;

  PERFORM 1 FROM public.service_bookings WHERE id=v_booking_id FOR UPDATE;
  IF v_expires_at IS NOT NULL AND v_expires_at<=clock_timestamp() THEN
    UPDATE public.job_offers SET status='expired',responded_at=clock_timestamp()
      WHERE id=p_offer_id AND status='offered';
    v_next:=private.srk_dispatch_next_booking_offer(v_booking_id);
    RETURN jsonb_build_object('success',false,'code','offer_expired','next_offer',v_next);
  END IF;

  IF p_response='accepted' THEN
    UPDATE public.service_bookings SET assigned_electrician_id=v_electrician_id,status='assigned'
      WHERE id=v_booking_id AND assigned_electrician_id IS NULL AND status IN ('new','confirmed');
    IF NOT FOUND THEN RAISE EXCEPTION 'This job has already been assigned' USING ERRCODE='55000'; END IF;
    UPDATE public.job_offers SET status='accepted',responded_at=clock_timestamp() WHERE id=p_offer_id;
    UPDATE public.job_offers SET status='cancelled',responded_at=clock_timestamp()
      WHERE booking_id=v_booking_id AND id<>p_offer_id AND status='offered';
    UPDATE srk_private.srk_booking_offer_dispatch SET dispatch_status='accepted',updated_at=clock_timestamp()
      WHERE booking_id=v_booking_id;
    RETURN jsonb_build_object('success',true,'status','accepted');
  END IF;

  UPDATE public.job_offers SET status='declined',responded_at=clock_timestamp() WHERE id=p_offer_id;
  v_next:=private.srk_dispatch_next_booking_offer(v_booking_id);
  RETURN jsonb_build_object('success',true,'status','declined','next_offer',v_next);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_respond_to_offer(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_respond_to_offer(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_expire_and_advance_booking_offers()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_offer record; v_count integer:=0;
BEGIN
  FOR v_offer IN
    SELECT o.id,o.booking_id FROM public.job_offers o
    JOIN srk_private.srk_booking_offer_dispatch d ON d.booking_id=o.booking_id
    WHERE o.status='offered' AND o.expires_at<=clock_timestamp()
      AND d.dispatch_status='active'
    ORDER BY o.expires_at FOR UPDATE OF o SKIP LOCKED
  LOOP
    UPDATE public.job_offers SET status='expired',responded_at=clock_timestamp()
      WHERE id=v_offer.id AND status='offered';
    IF FOUND THEN
      PERFORM private.srk_dispatch_next_booking_offer(v_offer.booking_id);
      v_count:=v_count+1;
    END IF;
  END LOOP;
  RETURN v_count;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_expire_and_advance_booking_offers()
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_expire_and_advance_booking_offers() TO service_role;

-- Netlify scheduled worker invokes this service-role-only RPC every minute.
COMMENT ON FUNCTION private.srk_offer_booking_to_eligible_electricians(uuid) IS
  'One offer at a time, nearest-first where both parties have coordinates; exact customer-selected rate tier only.';
COMMENT ON COLUMN public.job_offers.expires_at IS
  'Server-set response deadline for the single active sequential electrician offer.';
