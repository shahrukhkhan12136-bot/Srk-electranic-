-- Server-authoritative work timer and immutable labour-only bill.
-- New customer bookings do not use inspection quotations or quote approval.
-- This migration is source-only until separately approved for database rollout.

ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS work_timer_running boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS work_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS work_start_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS work_start_origin_status text,
  ADD COLUMN IF NOT EXISTS work_start_approval_status text NOT NULL DEFAULT 'not_requested',
  ADD COLUMN IF NOT EXISTS completion_approval_status text NOT NULL DEFAULT 'not_requested',
  ADD COLUMN IF NOT EXISTS completion_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS customer_completed_at timestamptz,
  ADD COLUMN IF NOT EXISTS work_timer_seconds bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS work_timer_elapsed_seconds numeric(24,6) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS labour_rate_tier_snapshot text,
  ADD COLUMN IF NOT EXISTS labour_rate8h_paise_snapshot bigint,
  ADD COLUMN IF NOT EXISTS labour_rate_card_version_snapshot text;

ALTER TABLE public.service_bookings
  DROP CONSTRAINT IF EXISTS service_bookings_work_timer_seconds_check;
ALTER TABLE public.service_bookings
  ALTER COLUMN work_timer_seconds TYPE bigint
  USING work_timer_seconds::bigint;

ALTER TABLE public.service_bookings
  DROP CONSTRAINT IF EXISTS service_bookings_status_check;
ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_status_check CHECK (status = ANY (ARRAY[
    'new','confirmed','assigned','inspection','awaiting_quote_approval',
    'quote_approved','quote_rejected','awaiting_work_start_approval',
    'in_progress','completed','cancelled'
  ]::text[]));

ALTER TABLE public.service_bookings
  DROP CONSTRAINT IF EXISTS service_bookings_assignment_status_requires_electrician;
ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_assignment_status_requires_electrician CHECK (
    status <> ALL (ARRAY[
      'assigned','inspection','awaiting_quote_approval','quote_approved',
      'quote_rejected','awaiting_work_start_approval','in_progress','completed'
    ]::text[]) OR assigned_electrician_id IS NOT NULL
  );

CREATE TABLE IF NOT EXISTS srk_private.work_timer_authorizations (
  transaction_id bigint NOT NULL,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  PRIMARY KEY(transaction_id,booking_id)
);
REVOKE ALL ON TABLE srk_private.work_timer_authorizations FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS srk_private.work_transition_authorizations (
  transaction_id bigint NOT NULL,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE CASCADE,
  target_status text NOT NULL,
  PRIMARY KEY(transaction_id,booking_id,target_status)
);
REVOKE ALL ON TABLE srk_private.work_transition_authorizations FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS public.srk_booking_labour_bills (
  booking_id uuid PRIMARY KEY REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  customer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  customer_work_category text NOT NULL CHECK (customer_work_category IN (
    'home_wiring','electrical_repair','light_fan_fitting','home_repair','other'
  )),
  approved_rate_tier text NOT NULL CHECK (approved_rate_tier IN (
    'electrical_assistant','skilled_electrician','expert_electrician',
    'premium_electrical_specialist'
  )),
  rate_card_version text NOT NULL,
  rate8h_paise bigint NOT NULL CHECK (rate8h_paise IN (89900,119900,159900,199900)),
  elapsed_seconds numeric(24,6) NOT NULL CHECK (elapsed_seconds>0),
  billable_minutes bigint NOT NULL CHECK (billable_minutes>0),
  labour_amount_paise numeric(24,0) NOT NULL CHECK (labour_amount_paise>0),
  labour_amount numeric(18,2) NOT NULL CHECK (labour_amount>0),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (labour_amount=labour_amount_paise/100.0)
);
ALTER TABLE public.srk_booking_labour_bills ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_booking_labour_bills FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_guard_server_work_timer()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE v_authorized boolean;
BEGIN
  IF TG_OP='INSERT' AND (
    NEW.work_timer_running OR NEW.work_started_at IS NOT NULL
    OR NEW.work_timer_seconds<>0 OR NEW.work_timer_elapsed_seconds<>0
    OR NEW.labour_rate_tier_snapshot IS NOT NULL
    OR NEW.labour_rate8h_paise_snapshot IS NOT NULL
    OR NEW.labour_rate_card_version_snapshot IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'New bookings cannot contain client-supplied timer or rate snapshots'
      USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND (
    NEW.work_timer_running IS DISTINCT FROM OLD.work_timer_running
    OR NEW.work_started_at IS DISTINCT FROM OLD.work_started_at
    OR NEW.work_timer_seconds IS DISTINCT FROM OLD.work_timer_seconds
    OR NEW.work_timer_elapsed_seconds IS DISTINCT FROM OLD.work_timer_elapsed_seconds
    OR NEW.work_start_origin_status IS DISTINCT FROM OLD.work_start_origin_status
    OR NEW.labour_rate_tier_snapshot IS DISTINCT FROM OLD.labour_rate_tier_snapshot
    OR NEW.labour_rate8h_paise_snapshot IS DISTINCT FROM OLD.labour_rate8h_paise_snapshot
    OR NEW.labour_rate_card_version_snapshot IS DISTINCT FROM OLD.labour_rate_card_version_snapshot
  ) THEN
    SELECT EXISTS(SELECT 1 FROM srk_private.work_timer_authorizations a
      WHERE a.transaction_id=pg_catalog.txid_current()
        AND a.booking_id=NEW.id AND a.actor_id=auth.uid())
    INTO v_authorized;
    IF NOT v_authorized THEN
      RAISE EXCEPTION 'Timer and approved rate snapshots can only be changed by protected work RPCs'
        USING ERRCODE='42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_server_work_timer() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_guard_server_work_timer ON public.service_bookings;
CREATE TRIGGER srk_guard_server_work_timer
  BEFORE INSERT OR UPDATE OF work_timer_running,work_started_at,work_timer_seconds,
    work_timer_elapsed_seconds,work_start_origin_status,labour_rate_tier_snapshot,
    labour_rate8h_paise_snapshot,labour_rate_card_version_snapshot
  ON public.service_bookings FOR EACH ROW EXECUTE FUNCTION public.srk_guard_server_work_timer();

CREATE OR REPLACE FUNCTION public.srk_guard_immutable_booking_labour_bill()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE b public.service_bookings%ROWTYPE; v_minutes bigint; v_amount numeric(24,0);
BEGIN
  IF TG_OP<>'INSERT' THEN
    RAISE EXCEPTION 'Final labour bills are immutable' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM srk_private.work_timer_authorizations a
    WHERE a.transaction_id=pg_catalog.txid_current()
      AND a.booking_id=NEW.booking_id AND a.actor_id=auth.uid()) THEN
    RAISE EXCEPTION 'Bill creation requires an authorized completion workflow' USING ERRCODE='42501';
  END IF;
  SELECT * INTO b FROM public.service_bookings WHERE id=NEW.booking_id FOR UPDATE;
  IF NOT FOUND OR b.customer_user_id IS DISTINCT FROM NEW.customer_user_id
    OR b.assigned_electrician_id IS DISTINCT FROM NEW.electrician_profile_id
    OR b.status<>'in_progress' OR b.completion_approval_status<>'pending'
    OR b.completion_requested_at IS NULL OR b.work_timer_running
    OR b.work_started_at IS NOT NULL OR b.work_timer_elapsed_seconds<=0
    OR b.selected_category IS NULL OR b.labour_rate_tier_snapshot IS NULL
    OR b.labour_rate8h_paise_snapshot IS NULL OR b.labour_rate_card_version_snapshot IS NULL THEN
    RAISE EXCEPTION 'A stopped timer and customer-approved completion request are required';
  END IF;
  v_minutes:=ceil(b.work_timer_elapsed_seconds/60)::bigint;
  v_amount:=floor(b.labour_rate8h_paise_snapshot::numeric*v_minutes/480+0.5);
  IF NEW.customer_work_category IS DISTINCT FROM b.selected_category
    OR NEW.approved_rate_tier IS DISTINCT FROM b.labour_rate_tier_snapshot
    OR NEW.rate_card_version IS DISTINCT FROM b.labour_rate_card_version_snapshot
    OR NEW.rate8h_paise IS DISTINCT FROM b.labour_rate8h_paise_snapshot
    OR NEW.elapsed_seconds IS DISTINCT FROM b.work_timer_elapsed_seconds
    OR NEW.billable_minutes IS DISTINCT FROM v_minutes
    OR NEW.labour_amount_paise IS DISTINCT FROM v_amount
    OR NEW.labour_amount IS DISTINCT FROM (v_amount/100)::numeric(18,2) THEN
    RAISE EXCEPTION 'Labour bill does not match the server timer and approved rate snapshot';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_immutable_booking_labour_bill() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_guard_immutable_booking_labour_bill ON public.srk_booking_labour_bills;
CREATE TRIGGER srk_guard_immutable_booking_labour_bill
  BEFORE INSERT OR UPDATE OR DELETE ON public.srk_booking_labour_bills
  FOR EACH ROW EXECUTE FUNCTION public.srk_guard_immutable_booking_labour_bill();

CREATE OR REPLACE FUNCTION public.srk_electrician_request_work_start(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE v_profile uuid; b public.service_bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT p.id INTO v_profile FROM public.electrician_profiles p
  WHERE (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved' AND p.active=true
  ORDER BY p.created_at DESC LIMIT 1;
  IF v_profile IS NULL THEN RAISE EXCEPTION 'Approved active electrician required' USING ERRCODE='42501'; END IF;
  SELECT * INTO b FROM public.service_bookings
  WHERE id=p_booking_id AND assigned_electrician_id=v_profile FOR UPDATE;
  IF NOT FOUND OR b.selected_category IS NULL THEN RAISE EXCEPTION 'New assigned customer booking not found' USING ERRCODE='42501'; END IF;
  IF b.status<>'assigned' OR b.work_timer_running OR b.work_start_approval_status NOT IN ('not_requested','rejected') THEN
    RAISE EXCEPTION 'इस बुकिंग में अभी काम शुरू करने का अनुरोध उपलब्ध नहीं है';
  END IF;
  INSERT INTO srk_private.work_timer_authorizations VALUES(pg_catalog.txid_current(),p_booking_id,auth.uid());
  UPDATE public.service_bookings SET status='awaiting_work_start_approval',
    work_start_origin_status='assigned',work_start_approval_status='pending',
    work_start_requested_at=clock_timestamp(),work_started_at=NULL,work_timer_running=false
  WHERE id=p_booking_id;
  DELETE FROM srk_private.work_timer_authorizations WHERE transaction_id=pg_catalog.txid_current() AND booking_id=p_booking_id AND actor_id=auth.uid();
  RETURN jsonb_build_object('success',true,'status','awaiting_work_start_approval');
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_respond_work_start(p_booking_id uuid,p_response text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE b public.service_bookings%ROWTYPE; p public.electrician_profiles%ROWTYPE;
  v_rate bigint; v_tier text; v_version text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_response NOT IN ('approved','rejected','disputed') OR p_response IS NULL OR (p_note IS NOT NULL AND length(p_note)>1000) THEN RAISE EXCEPTION 'Invalid response' USING ERRCODE='22023'; END IF;
  IF p_response='disputed' AND (v_note IS NULL OR length(v_note)<20) THEN RAISE EXCEPTION 'विवाद का कारण कम से कम 20 अक्षरों में लिखें'; END IF;
  SELECT * INTO b FROM public.service_bookings WHERE id=p_booking_id AND customer_user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR b.status<>'awaiting_work_start_approval' OR b.work_start_approval_status<>'pending' THEN
    RAISE EXCEPTION 'काम शुरू करने की कोई लंबित अनुमति नहीं है';
  END IF;
  INSERT INTO srk_private.work_timer_authorizations VALUES(pg_catalog.txid_current(),p_booking_id,auth.uid());
  IF p_response='approved' THEN
    SELECT * INTO p FROM public.electrician_profiles
    WHERE id=b.assigned_electrician_id AND active=true AND verification_status='approved'
      AND approved_rate_tier=b.selected_rate_tier
      AND approved_rate_card_version IS NOT NULL AND rate_tier_approved_by IS NOT NULL
      AND rate_tier_approved_at IS NOT NULL FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'इलेक्ट्रिशियन की Admin-approved श्रेणी सत्यापित नहीं हो सकी'; END IF;
    v_tier:=p.approved_rate_tier; v_version:=p.approved_rate_card_version;
    v_rate:=CASE v_tier WHEN 'electrical_assistant' THEN 89900
      WHEN 'skilled_electrician' THEN 119900 WHEN 'expert_electrician' THEN 159900
      WHEN 'premium_electrical_specialist' THEN 199900 ELSE NULL END;
    IF v_rate IS NULL THEN RAISE EXCEPTION 'Unsupported approved rate tier'; END IF;
    UPDATE public.service_bookings SET labour_rate_tier_snapshot=v_tier,
      labour_rate8h_paise_snapshot=v_rate,labour_rate_card_version_snapshot=v_version
    WHERE id=p_booking_id;
    INSERT INTO srk_private.work_transition_authorizations VALUES(pg_catalog.txid_current(),p_booking_id,'in_progress');
    UPDATE public.service_bookings SET status='in_progress',work_start_approval_status='approved',
      work_started_at=clock_timestamp(),work_timer_running=true,work_start_origin_status=NULL
    WHERE id=p_booking_id;
    DELETE FROM srk_private.work_transition_authorizations WHERE transaction_id=pg_catalog.txid_current()
      AND booking_id=p_booking_id AND target_status='in_progress';
  ELSE
    UPDATE public.service_bookings SET status='assigned',work_start_approval_status='rejected',
      work_started_at=NULL,work_timer_running=false,work_start_origin_status=NULL
    WHERE id=p_booking_id;
  END IF;
  DELETE FROM srk_private.work_timer_authorizations WHERE transaction_id=pg_catalog.txid_current()
    AND booking_id=p_booking_id AND actor_id=auth.uid();
  RETURN jsonb_build_object('success',true,'response',p_response);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_electrician_request_work_completion(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE v_profile uuid; b public.service_bookings%ROWTYPE; v_elapsed numeric(24,6);
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT p.id INTO v_profile FROM public.electrician_profiles p
  WHERE (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved' AND p.active=true ORDER BY p.created_at DESC LIMIT 1;
  IF v_profile IS NULL THEN RAISE EXCEPTION 'Approved active electrician required' USING ERRCODE='42501'; END IF;
  SELECT * INTO b FROM public.service_bookings
  WHERE id=p_booking_id AND assigned_electrician_id=v_profile FOR UPDATE;
  IF NOT FOUND OR b.status<>'in_progress' OR NOT b.work_timer_running OR b.work_started_at IS NULL THEN
    RAISE EXCEPTION 'चलता हुआ काम नहीं मिला';
  END IF;
  v_elapsed:=b.work_timer_elapsed_seconds+greatest(extract(epoch FROM (clock_timestamp()-b.work_started_at)),0);
  INSERT INTO srk_private.work_timer_authorizations VALUES(pg_catalog.txid_current(),p_booking_id,auth.uid());
  UPDATE public.service_bookings SET work_timer_elapsed_seconds=v_elapsed,
    work_timer_seconds=ceil(v_elapsed)::bigint,work_timer_running=false,work_started_at=NULL,
    completion_approval_status='pending',completion_requested_at=clock_timestamp()
  WHERE id=p_booking_id;
  DELETE FROM srk_private.work_timer_authorizations WHERE transaction_id=pg_catalog.txid_current()
    AND booking_id=p_booking_id AND actor_id=auth.uid();
  RETURN jsonb_build_object('success',true,'status','awaiting_customer_completion_approval',
    'elapsed_seconds',v_elapsed,'billable_minutes',ceil(v_elapsed/60)::bigint);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_respond_work_completion(p_booking_id uuid,p_response text,p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE b public.service_bookings%ROWTYPE; v_minutes bigint; v_paise numeric(24,0); v_amount numeric(18,2); v_note text:=NULLIF(btrim(p_note),'');
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_response NOT IN ('approved','rejected','disputed') OR p_response IS NULL OR (p_note IS NOT NULL AND length(p_note)>1000) THEN RAISE EXCEPTION 'Invalid response' USING ERRCODE='22023'; END IF;
  IF p_response='disputed' AND (v_note IS NULL OR length(v_note)<20) THEN RAISE EXCEPTION 'विवाद का कारण कम से कम 20 अक्षरों में लिखें'; END IF;
  SELECT * INTO b FROM public.service_bookings WHERE id=p_booking_id AND customer_user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR b.status<>'in_progress' OR b.completion_approval_status<>'pending'
    OR b.completion_requested_at IS NULL OR b.work_timer_running THEN
    RAISE EXCEPTION 'काम पूरा करने की कोई लंबित पुष्टि नहीं है';
  END IF;
  INSERT INTO srk_private.work_timer_authorizations VALUES(pg_catalog.txid_current(),p_booking_id,auth.uid());
  IF p_response='approved' THEN
    v_minutes:=ceil(b.work_timer_elapsed_seconds/60)::bigint;
    v_paise:=floor(b.labour_rate8h_paise_snapshot::numeric*v_minutes/480+0.5);
    IF v_minutes<1 OR v_paise<1 THEN RAISE EXCEPTION 'Final labour amount cannot be calculated'; END IF;
    v_amount:=round(v_paise/100,2);
    INSERT INTO public.srk_booking_labour_bills(
      booking_id,customer_user_id,electrician_profile_id,customer_work_category,
      approved_rate_tier,rate_card_version,rate8h_paise,elapsed_seconds,billable_minutes,
      labour_amount_paise,labour_amount
    ) VALUES(p_booking_id,b.customer_user_id,b.assigned_electrician_id,b.selected_category,
      b.labour_rate_tier_snapshot,b.labour_rate_card_version_snapshot,b.labour_rate8h_paise_snapshot,
      b.work_timer_elapsed_seconds,v_minutes,v_paise,v_amount);
    INSERT INTO srk_private.work_transition_authorizations VALUES(pg_catalog.txid_current(),p_booking_id,'completed');
    UPDATE public.service_bookings SET status='completed',service_charge=v_amount,
      completion_approval_status='approved',customer_completed_at=clock_timestamp()
    WHERE id=p_booking_id;
    DELETE FROM srk_private.work_transition_authorizations WHERE transaction_id=pg_catalog.txid_current()
      AND booking_id=p_booking_id AND target_status='completed';
  ELSIF p_response='rejected' THEN
    UPDATE public.service_bookings SET completion_approval_status='rejected',
      completion_requested_at=NULL,work_started_at=clock_timestamp(),work_timer_running=true
    WHERE id=p_booking_id;
  ELSE
    INSERT INTO public.srk_booking_complaints(booking_id,customer_user_id,category,description)
    VALUES(p_booking_id,auth.uid(),'service_quality','काम पूरा होने पर विवाद: '||v_note);
    UPDATE public.service_bookings SET completion_approval_status='disputed',
      work_timer_running=false,work_started_at=NULL
    WHERE id=p_booking_id;
  END IF;
  DELETE FROM srk_private.work_timer_authorizations WHERE transaction_id=pg_catalog.txid_current()
    AND booking_id=p_booking_id AND actor_id=auth.uid();
  RETURN jsonb_build_object('success',true,'response',p_response,
    'bill_created',p_response='approved','labour_amount',CASE WHEN p_response='approved' THEN v_amount ELSE NULL END);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_get_labour_bill(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE b public.srk_booking_labour_bills%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT * INTO b FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id AND customer_user_id=auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Final labour bill not found' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object('booking_id',b.booking_id,'category',b.customer_work_category,
    'rate_tier',b.approved_rate_tier,'rate_card_version',b.rate_card_version,
    'rate8h_paise',b.rate8h_paise,'elapsed_seconds',b.elapsed_seconds,
    'billable_minutes',b.billable_minutes,'labour_amount_paise',b.labour_amount_paise,
    'labour_amount',b.labour_amount,'created_at',b.created_at);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_electrician_get_labour_bill(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE b public.srk_booking_labour_bills%ROWTYPE; v_profile uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT p.id INTO v_profile FROM public.electrician_profiles p
  WHERE p.user_id=auth.uid() OR p.auth_user_id=auth.uid() ORDER BY p.created_at DESC LIMIT 1;
  SELECT * INTO b FROM public.srk_booking_labour_bills
  WHERE booking_id=p_booking_id AND electrician_profile_id=v_profile;
  IF NOT FOUND THEN RAISE EXCEPTION 'Final labour bill not found' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object('booking_id',b.booking_id,'category',b.customer_work_category,
    'rate_tier',b.approved_rate_tier,'rate_card_version',b.rate_card_version,
    'rate8h_paise',b.rate8h_paise,'elapsed_seconds',b.elapsed_seconds,
    'billable_minutes',b.billable_minutes,'labour_amount_paise',b.labour_amount_paise,
    'labour_amount',b.labour_amount,'created_at',b.created_at);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_electrician_request_work_start(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_request_work_start(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_customer_respond_work_start(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_respond_work_start(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_electrician_request_work_completion(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_request_work_completion(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_customer_respond_work_completion(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_respond_work_completion(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_customer_get_labour_bill(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_labour_bill(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_electrician_get_labour_bill(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_get_labour_bill(uuid) TO authenticated;

COMMENT ON FUNCTION public.srk_customer_respond_work_completion(uuid,text) IS
'Customer approves/rejects server-timed completion. Final bill contains labour only; materials are excluded. No separate quotation approval is used.';

-- Extend the electrician's assigned-offer view with the timer fields needed by the portal.
DROP FUNCTION IF EXISTS public.srk_get_my_offer_details();
CREATE FUNCTION public.srk_get_my_offer_details()
RETURNS TABLE(
  offer_id uuid,offer_status text,match_level text,offer_created_at timestamptz,
  booking_id uuid,service_type text,state text,district text,pincode text,
  preferred_date date,preferred_time time,work_details text,quoted_amount numeric,
  booking_status text,customer_name text,customer_phone text,address text,
  location_lat double precision,location_lng double precision,service_charge numeric,
  materials_amount numeric,quote_status text,quote_note text,
  selected_category text,selected_duration_hours smallint,selected_rate_tier text,
  work_start_approval_status text,completion_approval_status text,
  completion_requested_at timestamptz,work_timer_elapsed_seconds numeric,
  work_started_at timestamptz,work_timer_running boolean
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
  SELECT o.id,o.status,o.match_level,o.created_at,b.id,b.service_type,b.state,b.district,b.pincode,
    b.preferred_date,b.preferred_time,b.work_details,b.quoted_amount,b.status,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.customer_name ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.phone ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.address ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.location_lat ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.location_lng ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.service_charge ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.materials_amount ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.quote_status ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id THEN b.quote_note ELSE NULL END,
    b.selected_category,b.selected_duration_hours,b.selected_rate_tier,
    b.work_start_approval_status,b.completion_approval_status,b.completion_requested_at,
    b.work_timer_elapsed_seconds,b.work_started_at,b.work_timer_running
  FROM public.job_offers o
  JOIN public.electrician_profiles p ON p.id=o.electrician_id
  JOIN public.service_bookings b ON b.id=o.booking_id
  WHERE (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved' AND p.active=true
  ORDER BY o.created_at DESC LIMIT 100;
$function$;
REVOKE ALL ON FUNCTION public.srk_get_my_offer_details() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_offer_details() TO authenticated;


-- Legacy quotation RPCs remain usable only for historical rows without a
-- customer-selected work category. New bookings must use the server timer.
CREATE OR REPLACE FUNCTION public.srk_submit_booking_quote(
  p_booking_id uuid,p_service_charge numeric,p_materials_amount numeric,p_quote_note text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_profile_id uuid; v_booking public.service_bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_booking_id IS NULL OR p_service_charge IS NULL OR p_service_charge<=0
    OR p_materials_amount IS NULL OR p_materials_amount<0
    OR p_service_charge>10000000 OR p_materials_amount>10000000 THEN
    RAISE EXCEPTION 'Invalid quote amounts' USING ERRCODE='22023';
  END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
  WHERE (user_id=auth.uid() OR auth_user_id=auth.uid())
    AND verification_status='approved' AND active=true
  ORDER BY created_at DESC LIMIT 1;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Approved active electrician required' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings
  WHERE id=p_booking_id AND assigned_electrician_id=v_profile_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Assigned booking not found' USING ERRCODE='42501'; END IF;
  IF v_booking.selected_category IS NOT NULL THEN
    RAISE EXCEPTION 'नई बुकिंग में अलग कोटेशन नहीं है; ग्राहक द्वारा चुनी दर और सर्वर टाइमर लागू हैं';
  END IF;
  IF v_booking.status NOT IN ('assigned','inspection','quote_rejected') THEN
    RAISE EXCEPTION 'Booking is not ready for a legacy quote';
  END IF;
  UPDATE public.service_bookings SET service_charge=round(p_service_charge,2),
    materials_amount=round(p_materials_amount,2),
    quoted_amount=round(p_service_charge+p_materials_amount,2),
    quote_note=left(coalesce(p_quote_note,''),1000),quote_status='pending',
    quote_submitted_at=clock_timestamp(),quote_responded_at=NULL,status='awaiting_quote_approval'
  WHERE id=p_booking_id;
  RETURN jsonb_build_object('success',true,'total',round(p_service_charge+p_materials_amount,2),'quote_status','pending');
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_respond_booking_quote(p_booking_id uuid,p_response text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_booking public.service_bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_response NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Invalid quote response' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings
  WHERE id=p_booking_id AND customer_user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Customer booking not found' USING ERRCODE='42501'; END IF;
  IF v_booking.selected_category IS NOT NULL THEN
    RAISE EXCEPTION 'नई बुकिंग में कोटेशन मंजूरी लागू नहीं है';
  END IF;
  IF v_booking.status<>'awaiting_quote_approval' OR v_booking.quote_status<>'pending' THEN
    RAISE EXCEPTION 'No legacy quote is waiting for approval';
  END IF;
  UPDATE public.service_bookings SET quote_status=p_response,quote_responded_at=clock_timestamp(),
    status=CASE WHEN p_response='approved' THEN 'quote_approved' ELSE 'quote_rejected' END
  WHERE id=p_booking_id;
  RETURN jsonb_build_object('success',true,'quote_status',p_response);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_update_booking_work_status(p_booking_id uuid,p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_profile_id uuid; v_booking public.service_bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_status NOT IN ('inspection','in_progress','completed') THEN RAISE EXCEPTION 'Invalid work status' USING ERRCODE='22023'; END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
  WHERE (user_id=auth.uid() OR auth_user_id=auth.uid())
    AND verification_status='approved' AND active=true
  ORDER BY created_at DESC LIMIT 1;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Approved active electrician required' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings
  WHERE id=p_booking_id AND assigned_electrician_id=v_profile_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Assigned booking not found' USING ERRCODE='42501'; END IF;
  IF v_booking.selected_category IS NOT NULL THEN
    RAISE EXCEPTION 'नई बुकिंग का Status केवल Customer-approved server timer workflow बदल सकता है' USING ERRCODE='42501';
  END IF;
  IF p_status='inspection' AND v_booking.status='assigned' THEN
    UPDATE public.service_bookings SET status='inspection' WHERE id=p_booking_id;
  ELSIF p_status='in_progress' AND v_booking.status='quote_approved' AND v_booking.quote_status='approved' THEN
    UPDATE public.service_bookings SET status='in_progress',work_started_at=clock_timestamp() WHERE id=p_booking_id;
  ELSIF p_status='completed' AND v_booking.status='in_progress' THEN
    UPDATE public.service_bookings SET status='completed' WHERE id=p_booking_id;
  ELSE
    RAISE EXCEPTION 'Invalid legacy booking status transition';
  END IF;
  RETURN jsonb_build_object('success',true,'status',p_status);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_submit_booking_quote(uuid,numeric,numeric,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_submit_booking_quote(uuid,numeric,numeric,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_customer_respond_booking_quote(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_respond_booking_quote(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_update_booking_work_status(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_update_booking_work_status(uuid,text) TO authenticated;
