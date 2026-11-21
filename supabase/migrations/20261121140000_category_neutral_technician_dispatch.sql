-- Category-neutral, GPS-aware sequential Technician dispatch.
-- Feature Branch only. Depends on the unified Technician identity and OTP-first onboarding migrations.
-- Does not alter the legacy electrician job_offers path or production data.

CREATE TABLE IF NOT EXISTS public.srk_technician_presence (
  technician_id uuid PRIMARY KEY REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  is_online boolean NOT NULL DEFAULT false,
  last_latitude double precision,
  last_longitude double precision,
  last_location_at timestamptz,
  active_booking_id uuid REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK ((last_latitude IS NULL) = (last_longitude IS NULL)),
  CHECK (last_latitude IS NULL OR last_latitude BETWEEN -90 AND 90),
  CHECK (last_longitude IS NULL OR last_longitude BETWEEN -180 AND 180),
  CHECK (is_online=false OR active_booking_id IS NULL)
);
CREATE INDEX IF NOT EXISTS srk_technician_presence_online_location_idx
  ON public.srk_technician_presence(is_online,last_location_at DESC)
  WHERE is_online=true;

CREATE TABLE IF NOT EXISTS public.srk_technician_dispatch_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL UNIQUE REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  category_code text NOT NULL REFERENCES public.srk_service_categories(category_code) ON DELETE RESTRICT,
  skill_code text NOT NULL REFERENCES public.srk_service_skills(skill_code) ON DELETE RESTRICT,
  required_technician_count smallint NOT NULL DEFAULT 1 CHECK (required_technician_count BETWEEN 1 AND 10),
  assigned_technician_count smallint NOT NULL DEFAULT 0 CHECK (assigned_technician_count BETWEEN 0 AND required_technician_count),
  offer_ttl_seconds smallint NOT NULL DEFAULT 60 CHECK (offer_ttl_seconds BETWEEN 15 AND 300),
  work_latitude double precision NOT NULL CHECK (work_latitude BETWEEN -90 AND 90),
  work_longitude double precision NOT NULL CHECK (work_longitude BETWEEN -180 AND 180),
  status text NOT NULL DEFAULT 'searching'
    CHECK (status IN ('searching','assigned','completed','cancelled','unavailable')),
  current_offer_id uuid,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS srk_technician_dispatch_queue_idx
  ON public.srk_technician_dispatch_requests(status,created_at)
  WHERE status='searching';

CREATE TABLE IF NOT EXISTS public.srk_technician_dispatch_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispatch_request_id uuid NOT NULL REFERENCES public.srk_technician_dispatch_requests(id) ON DELETE RESTRICT,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  category_code_snapshot text NOT NULL,
  skill_code_snapshot text NOT NULL,
  match_level text NOT NULL DEFAULT 'nearby_30km' CHECK (match_level IN ('nearby_30km','manual_admin')),
  distance_km numeric(8,3),
  status text NOT NULL DEFAULT 'offered'
    CHECK (status IN ('offered','accepted','declined','expired','cancelled','replaced')),
  offered_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  responded_at timestamptz,
  UNIQUE(dispatch_request_id,technician_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS srk_technician_dispatch_one_live_offer_per_booking_uidx
  ON public.srk_technician_dispatch_offers(dispatch_request_id) WHERE status='offered';
CREATE UNIQUE INDEX IF NOT EXISTS srk_technician_dispatch_one_live_offer_per_technician_uidx
  ON public.srk_technician_dispatch_offers(technician_id) WHERE status='offered';
CREATE INDEX IF NOT EXISTS srk_technician_dispatch_offers_booking_idx
  ON public.srk_technician_dispatch_offers(booking_id,offered_at DESC);
CREATE INDEX IF NOT EXISTS srk_technician_dispatch_offers_technician_idx
  ON public.srk_technician_dispatch_offers(technician_id,status,offered_at DESC);

ALTER TABLE public.srk_technician_dispatch_requests
  ADD CONSTRAINT srk_technician_dispatch_current_offer_fk
  FOREIGN KEY(current_offer_id) REFERENCES public.srk_technician_dispatch_offers(id)
  ON DELETE RESTRICT;

CREATE TABLE IF NOT EXISTS public.srk_technician_dispatch_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispatch_request_id uuid NOT NULL REFERENCES public.srk_technician_dispatch_requests(id) ON DELETE RESTRICT,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  technician_id uuid REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  offer_id uuid REFERENCES public.srk_technician_dispatch_offers(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_type text NOT NULL CHECK (event_type IN (
    'dispatch_created','offer_sent','offer_accepted','offer_declined','offer_expired',
    'technician_assigned','dispatch_unavailable','dispatch_cancelled','technician_released'
  )),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS srk_technician_dispatch_events_recent_idx
  ON public.srk_technician_dispatch_events(dispatch_request_id,created_at DESC,id DESC);

ALTER TABLE public.srk_technician_presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_dispatch_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_dispatch_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_dispatch_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_technician_presence,public.srk_technician_dispatch_requests,
  public.srk_technician_dispatch_offers,public.srk_technician_dispatch_events
FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE public.srk_technician_presence,public.srk_technician_dispatch_requests,
  public.srk_technician_dispatch_offers,public.srk_technician_dispatch_events TO service_role;

CREATE OR REPLACE FUNCTION public.srk_guard_technician_dispatch_events_append_only()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  RAISE EXCEPTION 'TECHNICIAN_DISPATCH_HISTORY_IS_APPEND_ONLY' USING ERRCODE='55000';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_technician_dispatch_events_append_only() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_technician_dispatch_events_append_only ON public.srk_technician_dispatch_events;
CREATE TRIGGER srk_technician_dispatch_events_append_only
BEFORE UPDATE OR DELETE ON public.srk_technician_dispatch_events
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_technician_dispatch_events_append_only();

-- Technicians can share GPS only while online or while an accepted booking is active.
-- If a GPS fix is unavailable, the last fix and its original timestamp are retained.
CREATE OR REPLACE FUNCTION public.srk_technician_set_presence(
  p_is_online boolean,p_latitude double precision DEFAULT NULL,p_longitude double precision DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_technician_id uuid; v_active_booking uuid;
  v_lat double precision; v_lng double precision; v_location_at timestamptz;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_is_online IS NULL OR ((p_latitude IS NULL)<>(p_longitude IS NULL))
     OR (p_latitude IS NOT NULL AND (p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180)) THEN
    RAISE EXCEPTION 'INVALID_TECHNICIAN_PRESENCE' USING ERRCODE='22023';
  END IF;
  SELECT t.id INTO v_technician_id FROM public.srk_technicians t
  WHERE t.auth_user_id=v_uid AND t.account_status='active' AND t.verified_phone IS NOT NULL;
  IF v_technician_id IS NULL THEN RAISE EXCEPTION 'APPROVED_TECHNICIAN_ACCOUNT_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_is_online AND NOT EXISTS (
    SELECT 1 FROM public.srk_technician_applications a
    JOIN public.srk_technician_application_skills aps ON aps.application_id=a.id
    JOIN public.srk_service_skills s ON s.id=aps.skill_id AND s.is_active
    JOIN public.srk_service_categories c ON c.id=s.category_id AND c.is_active
    WHERE a.technician_id=v_technician_id AND a.status='approved' AND aps.review_status='approved'
  ) THEN RAISE EXCEPTION 'APPROVED_CATEGORY_SKILL_REQUIRED_TO_GO_ONLINE' USING ERRCODE='42501'; END IF;

  INSERT INTO public.srk_technician_presence(technician_id,is_online,last_latitude,last_longitude,last_location_at)
  VALUES(v_technician_id,false,p_latitude,p_longitude,
    CASE WHEN p_latitude IS NOT NULL THEN clock_timestamp() ELSE NULL END)
  ON CONFLICT(technician_id) DO NOTHING;

  SELECT active_booking_id,last_latitude,last_longitude,last_location_at
    INTO v_active_booking,v_lat,v_lng,v_location_at
  FROM public.srk_technician_presence WHERE technician_id=v_technician_id FOR UPDATE;

  IF p_is_online AND v_active_booking IS NOT NULL THEN
    RAISE EXCEPTION 'ACTIVE_BOOKING_MUST_FINISH_BEFORE_ONLINE_STATUS' USING ERRCODE='55000';
  END IF;
  IF p_is_online AND p_latitude IS NULL
     AND (v_location_at IS NULL OR v_location_at<clock_timestamp()-interval '5 minutes') THEN
    RAISE EXCEPTION 'FRESH_GPS_LOCATION_REQUIRED_TO_GO_ONLINE' USING ERRCODE='22023';
  END IF;
  UPDATE public.srk_technician_presence SET
    is_online=p_is_online,
    last_latitude=COALESCE(p_latitude,v_lat),
    last_longitude=COALESCE(p_longitude,v_lng),
    last_location_at=CASE WHEN p_latitude IS NOT NULL THEN clock_timestamp() ELSE v_location_at END,
    updated_at=clock_timestamp()
  WHERE technician_id=v_technician_id;
  RETURN jsonb_build_object('success',true,'is_online',p_is_online,
    'active_booking_id',v_active_booking,'last_location_at',
    CASE WHEN p_latitude IS NOT NULL THEN clock_timestamp() ELSE v_location_at END);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_set_presence(boolean,double precision,double precision) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_set_presence(boolean,double precision,double precision) TO authenticated;

-- Trusted server only: called after a booking is persisted with its canonical service category/skill.
CREATE OR REPLACE FUNCTION public.srk_dispatch_create_for_booking(
  p_booking_id uuid,p_category_code text,p_skill_code text,
  p_required_technician_count smallint DEFAULT 1,p_offer_ttl_seconds smallint DEFAULT 60
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_lat double precision; v_lng double precision; v_id uuid;
BEGIN
  IF p_booking_id IS NULL OR p_category_code IS NULL OR p_skill_code IS NULL
     OR p_required_technician_count NOT BETWEEN 1 AND 10
     OR p_offer_ttl_seconds NOT BETWEEN 15 AND 300 THEN
    RAISE EXCEPTION 'INVALID_TECHNICIAN_DISPATCH_REQUEST' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.srk_service_skills s
    JOIN public.srk_service_categories c ON c.id=s.category_id
    WHERE s.skill_code=p_skill_code AND c.category_code=p_category_code
      AND s.is_active AND c.is_active
  ) THEN RAISE EXCEPTION 'ACTIVE_CATEGORY_SKILL_PAIR_REQUIRED' USING ERRCODE='22023'; END IF;
  SELECT b.location_lat,b.location_lng INTO v_lat,v_lng
  FROM public.service_bookings b
  WHERE b.id=p_booking_id AND b.status NOT IN ('cancelled','completed');
  IF NOT FOUND OR v_lat IS NULL OR v_lng IS NULL THEN
    RAISE EXCEPTION 'BOOKING_WITH_VALID_GPS_LOCATION_REQUIRED_FOR_AUTO_DISPATCH' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.srk_technician_dispatch_requests
    (booking_id,category_code,skill_code,required_technician_count,offer_ttl_seconds,work_latitude,work_longitude)
  VALUES(p_booking_id,p_category_code,p_skill_code,p_required_technician_count,p_offer_ttl_seconds,v_lat,v_lng)
  ON CONFLICT(booking_id) DO NOTHING
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN
    SELECT id INTO v_id FROM public.srk_technician_dispatch_requests WHERE booking_id=p_booking_id;
  ELSE
    INSERT INTO public.srk_technician_dispatch_events(dispatch_request_id,booking_id,event_type,details)
    VALUES(v_id,p_booking_id,'dispatch_created',jsonb_build_object('category_code',p_category_code,
      'skill_code',p_skill_code,'required_technician_count',p_required_technician_count,
      'offer_ttl_seconds',p_offer_ttl_seconds));
  END IF;
  RETURN jsonb_build_object('success',true,'dispatch_request_id',v_id,'status','searching');
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_dispatch_create_for_booking(uuid,text,text,smallint,smallint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_dispatch_create_for_booking(uuid,text,text,smallint,smallint) TO service_role;

-- Trusted server worker: expire the previous sequential offer, then issue the next nearest eligible offer.
CREATE OR REPLACE FUNCTION public.srk_dispatch_issue_next_offer(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_req public.srk_technician_dispatch_requests%rowtype;
  v_offer_id uuid; v_technician_id uuid; v_distance numeric; v_match_level text;
BEGIN
  SELECT * INTO v_req FROM public.srk_technician_dispatch_requests
  WHERE booking_id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'TECHNICIAN_DISPATCH_REQUEST_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  IF v_req.status IN ('cancelled','completed','assigned','unavailable') THEN
    RETURN jsonb_build_object('success',true,'status',v_req.status);
  END IF;

  UPDATE public.srk_technician_dispatch_offers
    SET status='expired',responded_at=clock_timestamp()
  WHERE dispatch_request_id=v_req.id AND status='offered' AND expires_at<=clock_timestamp();
  IF FOUND THEN
    INSERT INTO public.srk_technician_dispatch_events(dispatch_request_id,booking_id,technician_id,offer_id,event_type)
    SELECT v_req.id,p_booking_id,o.technician_id,o.id,'offer_expired'
    FROM public.srk_technician_dispatch_offers o
    WHERE o.dispatch_request_id=v_req.id AND o.status='expired'
      AND o.responded_at>=clock_timestamp()-interval '2 seconds';
  END IF;

  SELECT o.id INTO v_offer_id FROM public.srk_technician_dispatch_offers o
  WHERE o.dispatch_request_id=v_req.id AND o.status='offered' AND o.expires_at>clock_timestamp()
  LIMIT 1;
  IF v_offer_id IS NOT NULL THEN
    RETURN jsonb_build_object('success',true,'status','offer_active','offer_id',v_offer_id);
  END IF;

  SELECT count(*)::smallint INTO v_req.assigned_technician_count
  FROM public.srk_booking_technician_assignments a
  WHERE a.booking_id=p_booking_id AND a.assignment_status IN ('accepted','active','completed');
  UPDATE public.srk_technician_dispatch_requests SET assigned_technician_count=v_req.assigned_technician_count,
    status=CASE WHEN v_req.assigned_technician_count>=required_technician_count THEN 'assigned' ELSE 'searching' END,
    current_offer_id=NULL,updated_at=clock_timestamp()
  WHERE id=v_req.id RETURNING * INTO v_req;
  IF v_req.status='assigned' THEN RETURN jsonb_build_object('success',true,'status','assigned'); END IF;

  SELECT candidate.technician_id,candidate.distance_km
    INTO v_technician_id,v_distance
  FROM (
    SELECT t.id AS technician_id,
      (6371.0*2*asin(sqrt(
        power(sin(radians(p.last_latitude-v_req.work_latitude)/2),2)
        +cos(radians(v_req.work_latitude))*cos(radians(p.last_latitude))
         *power(sin(radians(p.last_longitude-v_req.work_longitude)/2),2)
      )))::numeric(8,3) AS distance_km
    FROM public.srk_technician_presence p
    JOIN public.srk_technicians t ON t.id=p.technician_id AND t.account_status='active'
    JOIN public.srk_technician_applications a ON a.technician_id=t.id AND a.status='approved'
    JOIN public.srk_technician_application_skills aps ON aps.application_id=a.id AND aps.review_status='approved'
    JOIN public.srk_service_skills s ON s.id=aps.skill_id AND s.skill_code=v_req.skill_code AND s.is_active
    JOIN public.srk_service_categories c ON c.id=s.category_id AND c.category_code=v_req.category_code AND c.is_active
    JOIN public.srk_technician_application_categories ac ON ac.application_id=a.id AND ac.category_id=c.id
    WHERE p.is_online=true AND p.active_booking_id IS NULL
      AND p.last_latitude IS NOT NULL AND p.last_longitude IS NOT NULL
      AND p.last_location_at>=clock_timestamp()-interval '5 minutes'
      AND NOT EXISTS (SELECT 1 FROM public.srk_technician_dispatch_offers old
        WHERE old.dispatch_request_id=v_req.id AND old.technician_id=t.id)
      AND NOT EXISTS (SELECT 1 FROM public.srk_technician_dispatch_offers live
        WHERE live.technician_id=t.id AND live.status='offered' AND live.expires_at>clock_timestamp())
      AND NOT EXISTS (SELECT 1 FROM public.srk_booking_technician_assignments assigned
        WHERE assigned.booking_id=p_booking_id AND assigned.technician_id=t.id)
  ) candidate
  WHERE candidate.distance_km<=30
  ORDER BY candidate.distance_km,candidate.technician_id
  LIMIT 1
  FOR UPDATE OF candidate;

  IF v_technician_id IS NULL THEN
    UPDATE public.srk_technician_dispatch_requests SET status='unavailable',
      current_offer_id=NULL,updated_at=clock_timestamp() WHERE id=v_req.id;
    INSERT INTO public.srk_technician_dispatch_events(dispatch_request_id,booking_id,event_type,details)
    VALUES(v_req.id,p_booking_id,'dispatch_unavailable',jsonb_build_object('radius_km',30,'skill_code',v_req.skill_code));
    RETURN jsonb_build_object('success',true,'status','unavailable','radius_km',30);
  END IF;

  INSERT INTO public.srk_technician_dispatch_offers
    (dispatch_request_id,booking_id,technician_id,category_code_snapshot,skill_code_snapshot,
      match_level,distance_km,expires_at)
  VALUES(v_req.id,p_booking_id,v_technician_id,v_req.category_code,v_req.skill_code,
    'nearby_30km',v_distance,clock_timestamp()+make_interval(secs=>v_req.offer_ttl_seconds))
  RETURNING id INTO v_offer_id;
  UPDATE public.srk_technician_dispatch_requests SET current_offer_id=v_offer_id,
    status='searching',updated_at=clock_timestamp() WHERE id=v_req.id;
  INSERT INTO public.srk_technician_dispatch_events(dispatch_request_id,booking_id,technician_id,offer_id,event_type,details)
  VALUES(v_req.id,p_booking_id,v_technician_id,v_offer_id,'offer_sent',
    jsonb_build_object('distance_km',v_distance,'expires_at',clock_timestamp()+make_interval(secs=>v_req.offer_ttl_seconds)));
  RETURN jsonb_build_object('success',true,'status','offer_sent','offer_id',v_offer_id,
    'technician_id',v_technician_id,'distance_km',v_distance);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_dispatch_issue_next_offer(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_dispatch_issue_next_offer(uuid) TO service_role;

-- Technician accepts or declines only their own live offer. Decline immediately advances the queue.
CREATE OR REPLACE FUNCTION public.srk_technician_respond_to_dispatch_offer(p_offer_id uuid,p_response text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_offer public.srk_technician_dispatch_offers%rowtype;
  v_technician_id uuid; v_req public.srk_technician_dispatch_requests%rowtype; v_next jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_offer_id IS NULL OR p_response NOT IN ('accepted','declined') THEN
    RAISE EXCEPTION 'INVALID_TECHNICIAN_OFFER_RESPONSE' USING ERRCODE='22023';
  END IF;
  SELECT id INTO v_technician_id FROM public.srk_technicians
  WHERE auth_user_id=v_uid AND account_status='active';
  IF v_technician_id IS NULL THEN RAISE EXCEPTION 'APPROVED_TECHNICIAN_ACCOUNT_REQUIRED' USING ERRCODE='42501'; END IF;

  SELECT * INTO v_offer FROM public.srk_technician_dispatch_offers
  WHERE id=p_offer_id AND technician_id=v_technician_id FOR UPDATE;
  IF NOT FOUND OR v_offer.status<>'offered' THEN
    RAISE EXCEPTION 'OWN_ACTIVE_TECHNICIAN_OFFER_REQUIRED' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_req FROM public.srk_technician_dispatch_requests
  WHERE id=v_offer.dispatch_request_id FOR UPDATE;
  IF v_offer.expires_at<=clock_timestamp() THEN
    UPDATE public.srk_technician_dispatch_offers SET status='expired',responded_at=clock_timestamp() WHERE id=v_offer.id;
    INSERT INTO public.srk_technician_dispatch_events(dispatch_request_id,booking_id,technician_id,offer_id,event_type)
    VALUES(v_req.id,v_offer.booking_id,v_technician_id,v_offer.id,'offer_expired');
    v_next:=public.srk_dispatch_issue_next_offer(v_offer.booking_id);
    RETURN jsonb_build_object('success',false,'error','OFFER_EXPIRED','next',v_next);
  END IF;
  IF v_req.status<>'searching' OR v_req.current_offer_id IS DISTINCT FROM v_offer.id THEN
    RAISE EXCEPTION 'DISPATCH_OFFER_NO_LONGER_CURRENT' USING ERRCODE='55000';
  END IF;

  IF p_response='declined' THEN
    UPDATE public.srk_technician_dispatch_offers SET status='declined',responded_at=clock_timestamp() WHERE id=v_offer.id;
    INSERT INTO public.srk_technician_dispatch_events(dispatch_request_id,booking_id,technician_id,offer_id,actor_user_id,event_type)
    VALUES(v_req.id,v_offer.booking_id,v_technician_id,v_offer.id,v_uid,'offer_declined');
    v_next:=public.srk_dispatch_issue_next_offer(v_offer.booking_id);
    RETURN jsonb_build_object('success',true,'status','declined','next',v_next);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.srk_technician_presence p
    WHERE p.technician_id=v_technician_id AND p.is_online AND p.active_booking_id IS NULL
      AND p.last_location_at>=clock_timestamp()-interval '5 minutes') THEN
    RAISE EXCEPTION 'TECHNICIAN_MUST_BE_ONLINE_WITH_FRESH_GPS_TO_ACCEPT' USING ERRCODE='55000';
  END IF;
  UPDATE public.srk_technician_dispatch_offers SET status='accepted',responded_at=clock_timestamp() WHERE id=v_offer.id;
  INSERT INTO public.srk_booking_technician_assignments
    (booking_id,technician_id,service_category_snapshot,assignment_status,assigned_at,accepted_at)
  VALUES(v_offer.booking_id,v_technician_id,v_offer.category_code_snapshot,'accepted',clock_timestamp(),clock_timestamp())
  ON CONFLICT(booking_id,technician_id) DO UPDATE SET
    assignment_status='accepted',accepted_at=EXCLUDED.accepted_at
  WHERE public.srk_booking_technician_assignments.assignment_status IN ('cancelled','replaced');
  IF NOT FOUND THEN
    RAISE EXCEPTION 'TECHNICIAN_ALREADY_ASSIGNED_TO_BOOKING' USING ERRCODE='23505';
  END IF;
  UPDATE public.srk_technician_presence SET is_online=false,active_booking_id=v_offer.booking_id,
    updated_at=clock_timestamp() WHERE technician_id=v_technician_id;
  INSERT INTO public.srk_technician_dispatch_events(dispatch_request_id,booking_id,technician_id,offer_id,actor_user_id,event_type)
  VALUES(v_req.id,v_offer.booking_id,v_technician_id,v_offer.id,v_uid,'offer_accepted');
  SELECT count(*)::smallint INTO v_req.assigned_technician_count
  FROM public.srk_booking_technician_assignments a
  WHERE a.booking_id=v_offer.booking_id AND a.assignment_status IN ('accepted','active','completed');
  UPDATE public.srk_technician_dispatch_requests SET assigned_technician_count=v_req.assigned_technician_count,
    status=CASE WHEN v_req.assigned_technician_count>=required_technician_count THEN 'assigned' ELSE 'searching' END,
    current_offer_id=NULL,updated_at=clock_timestamp() WHERE id=v_req.id;
  INSERT INTO public.srk_technician_dispatch_events(dispatch_request_id,booking_id,technician_id,event_type,details)
  VALUES(v_req.id,v_offer.booking_id,v_technician_id,'technician_assigned',
    jsonb_build_object('assigned_count',v_req.assigned_technician_count));
  IF v_req.assigned_technician_count< v_req.required_technician_count THEN
    v_next:=public.srk_dispatch_issue_next_offer(v_offer.booking_id);
  END IF;
  RETURN jsonb_build_object('success',true,'status',
    CASE WHEN v_req.assigned_technician_count>=v_req.required_technician_count THEN 'assigned' ELSE 'partially_assigned' END,
    'assigned_technician_count',v_req.assigned_technician_count,'next',v_next);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_respond_to_dispatch_offer(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_respond_to_dispatch_offer(uuid,text) TO authenticated;

-- Release GPS/presence after a booking reaches a terminal state. Keep the last fix and its timestamp as history.
CREATE OR REPLACE FUNCTION public.srk_release_technician_presence_after_booking_terminal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_assignment record;
BEGIN
  IF NEW.status NOT IN ('completed','cancelled') OR OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;
  UPDATE public.srk_technician_dispatch_offers SET status='cancelled',responded_at=clock_timestamp()
  WHERE booking_id=NEW.id AND status='offered';
  UPDATE public.srk_technician_dispatch_requests SET status=CASE WHEN NEW.status='completed' THEN 'completed' ELSE 'cancelled' END,
    updated_at=clock_timestamp() WHERE booking_id=NEW.id;
  FOR v_assignment IN
    SELECT technician_id FROM public.srk_booking_technician_assignments
    WHERE booking_id=NEW.id AND assignment_status IN ('accepted','active','completed')
  LOOP
    UPDATE public.srk_technician_presence SET is_online=false,active_booking_id=NULL,updated_at=clock_timestamp()
    WHERE technician_id=v_assignment.technician_id AND active_booking_id=NEW.id;
    INSERT INTO public.srk_technician_dispatch_events(dispatch_request_id,booking_id,technician_id,event_type)
    SELECT d.id,NEW.id,v_assignment.technician_id,'technician_released'
    FROM public.srk_technician_dispatch_requests d WHERE d.booking_id=NEW.id;
  END LOOP;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_release_technician_presence_after_booking_terminal() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_release_technician_presence_after_booking_terminal ON public.service_bookings;
CREATE TRIGGER srk_release_technician_presence_after_booking_terminal
AFTER UPDATE OF status ON public.service_bookings
FOR EACH ROW EXECUTE FUNCTION public.srk_release_technician_presence_after_booking_terminal();

-- Read-only view for the signed-in Technician's own current offers.
CREATE OR REPLACE FUNCTION public.srk_technician_get_my_dispatch_offers()
RETURNS TABLE(offer_id uuid,booking_id uuid,category_code text,skill_code text,
  match_level text,distance_km numeric,offered_at timestamptz,expires_at timestamptz,status text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT o.id,o.booking_id,o.category_code_snapshot,o.skill_code_snapshot,
    o.match_level,o.distance_km,o.offered_at,o.expires_at,o.status
  FROM public.srk_technician_dispatch_offers o
  JOIN public.srk_technicians t ON t.id=o.technician_id
  WHERE t.auth_user_id=auth.uid()
    AND t.account_status='active'
    AND o.status IN ('offered','accepted')
  ORDER BY o.offered_at DESC
  LIMIT 100;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_get_my_dispatch_offers() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_get_my_dispatch_offers() TO authenticated;
