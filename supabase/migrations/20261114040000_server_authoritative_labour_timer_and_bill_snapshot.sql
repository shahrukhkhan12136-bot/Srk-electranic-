-- Server-authoritative, resumable labour timer and immutable final labour bill.
-- New categorized bookings use the Admin-approved commercial rate tier captured
-- at the first customer-approved work start. Legacy NULL-category bookings keep
-- their existing quote workflow until their payment dependencies are migrated.

ALTER TABLE public.service_bookings
  DROP CONSTRAINT IF EXISTS service_bookings_work_timer_seconds_check;

ALTER TABLE public.service_bookings
  ALTER COLUMN work_timer_seconds TYPE bigint
  USING work_timer_seconds::bigint;

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_work_timer_seconds_nonnegative
  CHECK (work_timer_seconds >= 0);

ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS work_timer_elapsed_seconds numeric(24,6) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS work_start_origin_status text,
  ADD COLUMN IF NOT EXISTS labour_rate_tier_snapshot text,
  ADD COLUMN IF NOT EXISTS labour_rate8h_paise_snapshot bigint,
  ADD COLUMN IF NOT EXISTS labour_rate_card_version_snapshot text;

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_work_timer_elapsed_nonnegative
  CHECK (work_timer_elapsed_seconds >= 0);

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_labour_rate_snapshot_valid
  CHECK (
    (labour_rate_tier_snapshot IS NULL AND labour_rate8h_paise_snapshot IS NULL
      AND labour_rate_card_version_snapshot IS NULL)
    OR
    (labour_rate_tier_snapshot IN (
       'electrical_assistant','skilled_electrician','expert_electrician',
       'premium_electrical_specialist'
     )
     AND labour_rate8h_paise_snapshot IN (89900,119900,159900,199900)
     AND labour_rate_card_version_snapshot IS NOT NULL)
  );

COMMENT ON COLUMN public.service_bookings.work_timer_elapsed_seconds IS
  'Exact accumulated server-recorded elapsed seconds across approved work sessions; no daily or 7-day cap.';
COMMENT ON COLUMN public.service_bookings.work_start_origin_status IS
  'Booking status to restore if the customer rejects a pending work-start request.';
COMMENT ON COLUMN public.service_bookings.labour_rate_tier_snapshot IS
  'Commercial rate tier copied from the assigned electrician at first customer-approved start; immutable for this booking.';
COMMENT ON COLUMN public.service_bookings.labour_rate8h_paise_snapshot IS
  'Eight-hour labour rate snapshot in integer paise; never inferred from customer work category.';

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
  elapsed_seconds numeric(24,6) NOT NULL CHECK (elapsed_seconds > 0),
  billable_minutes bigint NOT NULL CHECK (billable_minutes > 0),
  labour_amount_paise numeric(24,0) NOT NULL CHECK (labour_amount_paise > 0),
  labour_amount numeric(18,2) NOT NULL CHECK (labour_amount > 0),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT srk_booking_labour_bill_amount_reconciles
    CHECK (labour_amount = labour_amount_paise / 100.0)
);

CREATE INDEX IF NOT EXISTS srk_booking_labour_bills_customer_created_idx
  ON public.srk_booking_labour_bills(customer_user_id,created_at DESC);
CREATE INDEX IF NOT EXISTS srk_booking_labour_bills_electrician_created_idx
  ON public.srk_booking_labour_bills(electrician_profile_id,created_at DESC);

ALTER TABLE public.srk_booking_labour_bills ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_booking_labour_bills FROM PUBLIC,anon,authenticated;


-- Only the server-side workflow RPCs may change timer state or the first-start
-- commercial rate snapshot. Admin direct table edits cannot forge elapsed time.
CREATE TABLE IF NOT EXISTS srk_private.work_timer_authorizations (
  transaction_id bigint NOT NULL,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  PRIMARY KEY(transaction_id,booking_id)
);
REVOKE ALL ON TABLE srk_private.work_timer_authorizations FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_guard_server_work_timer()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE v_authorized boolean;
BEGIN
  IF TG_OP='UPDATE' AND (
       NEW.work_started_at IS DISTINCT FROM OLD.work_started_at
    OR NEW.work_timer_running IS DISTINCT FROM OLD.work_timer_running
    OR NEW.work_timer_seconds IS DISTINCT FROM OLD.work_timer_seconds
    OR NEW.work_timer_elapsed_seconds IS DISTINCT FROM OLD.work_timer_elapsed_seconds
    OR NEW.work_start_origin_status IS DISTINCT FROM OLD.work_start_origin_status
    OR NEW.labour_rate_tier_snapshot IS DISTINCT FROM OLD.labour_rate_tier_snapshot
    OR NEW.labour_rate8h_paise_snapshot IS DISTINCT FROM OLD.labour_rate8h_paise_snapshot
    OR NEW.labour_rate_card_version_snapshot IS DISTINCT FROM OLD.labour_rate_card_version_snapshot
  ) THEN
    SELECT EXISTS(
      SELECT 1 FROM srk_private.work_timer_authorizations a
      WHERE a.transaction_id=pg_catalog.txid_current()
        AND a.booking_id=NEW.id
        AND a.actor_id=auth.uid()
    ) INTO v_authorized;
    IF NOT v_authorized THEN
      RAISE EXCEPTION 'Timer and rate snapshots can only be changed by the authorized server workflow'
        USING ERRCODE='42501';
    END IF;
  END IF;

  IF NEW.labour_rate_tier_snapshot IS NOT NULL AND (
    (NEW.labour_rate_tier_snapshot='electrical_assistant' AND NEW.labour_rate8h_paise_snapshot<>89900)
    OR (NEW.labour_rate_tier_snapshot='skilled_electrician' AND NEW.labour_rate8h_paise_snapshot<>119900)
    OR (NEW.labour_rate_tier_snapshot='expert_electrician' AND NEW.labour_rate8h_paise_snapshot<>159900)
    OR (NEW.labour_rate_tier_snapshot='premium_electrical_specialist' AND NEW.labour_rate8h_paise_snapshot<>199900)
  ) THEN
    RAISE EXCEPTION 'Rate tier and eight-hour rate do not match';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_server_work_timer() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_guard_server_work_timer ON public.service_bookings;
CREATE TRIGGER srk_guard_server_work_timer
  BEFORE UPDATE OF work_started_at,work_timer_running,work_timer_seconds,
    work_timer_elapsed_seconds,work_start_origin_status,
    labour_rate_tier_snapshot,labour_rate8h_paise_snapshot,
    labour_rate_card_version_snapshot
  ON public.service_bookings
  FOR EACH ROW EXECUTE FUNCTION public.srk_guard_server_work_timer();

CREATE OR REPLACE FUNCTION public.srk_electrician_request_work_start(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_profile_id uuid;
  v_booking public.service_bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;

  SELECT p.id INTO v_profile_id
  FROM public.electrician_profiles p
  WHERE (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved' AND p.active=true
  ORDER BY p.created_at DESC LIMIT 1;
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Approved active electrician required' USING ERRCODE='42501';
  END IF;

  SELECT * INTO v_booking FROM public.service_bookings
  WHERE id=p_booking_id AND assigned_electrician_id=v_profile_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Assigned booking not found' USING ERRCODE='42501';
  END IF;

  IF v_booking.selected_category IS NOT NULL THEN
    IF v_booking.status NOT IN ('assigned','inspection') THEN
      RAISE EXCEPTION 'नई बुकिंग में काम शुरू करने के लिए assigned/inspection स्थिति जरूरी है';
    END IF;
  ELSIF v_booking.status<>'quote_approved' OR v_booking.quote_status<>'approved' THEN
    RAISE EXCEPTION 'पुरानी बुकिंग में ग्राहक-मंजूर quote जरूरी है';
  END IF;

  IF v_booking.work_timer_running OR v_booking.work_start_approval_status NOT IN ('not_requested','rejected') THEN
    RAISE EXCEPTION 'Work start approval is already pending or timer is running';
  END IF;

  INSERT INTO srk_private.work_timer_authorizations(transaction_id,booking_id,actor_id)
  VALUES (pg_catalog.txid_current(),p_booking_id,auth.uid());
  UPDATE public.service_bookings
  SET status='awaiting_work_start_approval',
      work_start_origin_status=v_booking.status,
      work_start_approval_status='pending',
      work_start_requested_at=clock_timestamp(),
      work_started_at=NULL,
      work_timer_running=false
  WHERE id=p_booking_id;
  DELETE FROM srk_private.work_timer_authorizations
  WHERE transaction_id=pg_catalog.txid_current() AND booking_id=p_booking_id AND actor_id=auth.uid();

  RETURN jsonb_build_object('success',true,'status','awaiting_work_start_approval');
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_respond_work_start(
  p_booking_id uuid,p_response text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_profile public.electrician_profiles%ROWTYPE;
  v_rate bigint;
  v_tier text;
  v_version text;
  v_return_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  IF p_response NOT IN ('approved','rejected') OR p_response IS NULL THEN
    RAISE EXCEPTION 'Invalid response' USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_booking FROM public.service_bookings
  WHERE id=p_booking_id AND customer_user_id=auth.uid()
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer booking not found' USING ERRCODE='42501';
  END IF;
  IF v_booking.status<>'awaiting_work_start_approval'
     OR v_booking.work_start_approval_status<>'pending' THEN
    RAISE EXCEPTION 'No work-start request is waiting for approval';
  END IF;

  INSERT INTO srk_private.work_timer_authorizations(transaction_id,booking_id,actor_id)
  VALUES (pg_catalog.txid_current(),p_booking_id,auth.uid());

  INSERT INTO srk_private.work_timer_authorizations(transaction_id,booking_id,actor_id)
  VALUES (pg_catalog.txid_current(),p_booking_id,auth.uid());

  IF p_response='approved' THEN
    IF v_booking.selected_category IS NOT NULL
       AND v_booking.labour_rate8h_paise_snapshot IS NULL THEN
      SELECT * INTO v_profile FROM public.electrician_profiles p
      WHERE p.id=v_booking.assigned_electrician_id
        AND p.active=true AND p.verification_status='approved'
        AND p.auth_user_id IS NOT NULL AND p.user_id=p.auth_user_id
        AND p.approved_rate_tier IS NOT NULL
        AND p.approved_rate_card_version IS NOT NULL
        AND p.rate_tier_approved_by IS NOT NULL
        AND p.rate_tier_approved_at IS NOT NULL
      FOR SHARE;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'काम शुरू करने से पहले Electrician का Admin-approved rate tier जरूरी है';
      END IF;

      v_tier:=v_profile.approved_rate_tier;
      v_version:=v_profile.approved_rate_card_version;
      v_rate:=CASE v_tier
        WHEN 'electrical_assistant' THEN 89900
        WHEN 'skilled_electrician' THEN 119900
        WHEN 'expert_electrician' THEN 159900
        WHEN 'premium_electrical_specialist' THEN 199900
        ELSE NULL END;
      IF v_rate IS NULL THEN
        RAISE EXCEPTION 'Approved rate tier is not supported';
      END IF;

      UPDATE public.service_bookings
      SET labour_rate_tier_snapshot=v_tier,
          labour_rate8h_paise_snapshot=v_rate,
          labour_rate_card_version_snapshot=v_version
      WHERE id=p_booking_id;
    END IF;

    INSERT INTO srk_private.work_transition_authorizations(transaction_id,booking_id,target_status)
    VALUES (pg_catalog.txid_current(),p_booking_id,'in_progress');

    UPDATE public.service_bookings
    SET work_start_approval_status='approved',
        status='in_progress',
        work_started_at=clock_timestamp(),
        work_timer_running=true,
        work_start_origin_status=NULL
    WHERE id=p_booking_id;

    DELETE FROM srk_private.work_transition_authorizations
    WHERE transaction_id=pg_catalog.txid_current()
      AND booking_id=p_booking_id AND target_status='in_progress';
  ELSE
    v_return_status:=CASE
      WHEN v_booking.work_start_origin_status IN ('assigned','inspection','quote_approved')
        THEN v_booking.work_start_origin_status
      WHEN v_booking.selected_category IS NOT NULL THEN 'inspection'
      ELSE 'quote_approved' END;

    UPDATE public.service_bookings
    SET status=v_return_status,
        work_start_approval_status='rejected',
        work_started_at=NULL,
        work_timer_running=false,
        work_start_origin_status=NULL
    WHERE id=p_booking_id;
  END IF;

  DELETE FROM srk_private.work_timer_authorizations
  WHERE transaction_id=pg_catalog.txid_current() AND booking_id=p_booking_id AND actor_id=auth.uid();

  RETURN jsonb_build_object('success',true,'response',p_response);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_electrician_request_work_completion(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_profile_id uuid;
  v_booking public.service_bookings%ROWTYPE;
  v_elapsed numeric(24,6);
  v_whole_seconds numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  SELECT p.id INTO v_profile_id FROM public.electrician_profiles p
  WHERE (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved' AND p.active=true
  ORDER BY p.created_at DESC LIMIT 1;
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Approved active electrician required' USING ERRCODE='42501';
  END IF;

  SELECT * INTO v_booking FROM public.service_bookings
  WHERE id=p_booking_id AND assigned_electrician_id=v_profile_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Assigned booking not found' USING ERRCODE='42501';
  END IF;
  IF v_booking.status<>'in_progress' OR NOT v_booking.work_timer_running
     OR v_booking.work_started_at IS NULL THEN
    RAISE EXCEPTION 'No running work timer exists';
  END IF;

  v_elapsed:=v_booking.work_timer_elapsed_seconds
    + GREATEST(0,EXTRACT(EPOCH FROM (clock_timestamp()-v_booking.work_started_at)));
  v_whole_seconds:=floor(v_elapsed);
  IF v_whole_seconds>9223372036854775807 THEN
    RAISE EXCEPTION 'Accumulated timer exceeds supported whole-second storage';
  END IF;

  INSERT INTO srk_private.work_timer_authorizations(transaction_id,booking_id,actor_id)
  VALUES (pg_catalog.txid_current(),p_booking_id,auth.uid());
  UPDATE public.service_bookings
  SET work_timer_elapsed_seconds=v_elapsed,
      work_timer_seconds=v_whole_seconds::bigint,
      work_timer_running=false,
      work_started_at=NULL,
      completion_requested_at=clock_timestamp(),
      completion_approval_status='pending'
  WHERE id=p_booking_id;
  DELETE FROM srk_private.work_timer_authorizations
  WHERE transaction_id=pg_catalog.txid_current() AND booking_id=p_booking_id AND actor_id=auth.uid();

  RETURN jsonb_build_object(
    'success',true,'completion_status','pending',
    'elapsed_seconds',v_elapsed,
    'billable_minutes',CASE WHEN v_elapsed>0 THEN ceil(v_elapsed/60) ELSE 0 END
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_respond_work_completion(
  p_booking_id uuid,p_response text,p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_note text:=NULLIF(btrim(p_note),'');
  v_minutes numeric;
  v_amount_paise numeric;
  v_amount numeric(18,2);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  IF p_response NOT IN ('approved','rejected','disputed') OR p_response IS NULL
     OR (p_note IS NOT NULL AND length(p_note)>1000) THEN
    RAISE EXCEPTION 'Invalid completion response' USING ERRCODE='22023';
  END IF;
  IF p_response='disputed' AND (v_note IS NULL OR length(v_note)<20) THEN
    RAISE EXCEPTION 'विवाद का कारण कम से कम 20 अक्षरों में लिखें';
  END IF;

  SELECT * INTO v_booking FROM public.service_bookings
  WHERE id=p_booking_id AND customer_user_id=auth.uid()
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer booking not found' USING ERRCODE='42501';
  END IF;
  IF v_booking.status<>'in_progress' OR v_booking.completion_approval_status<>'pending'
     OR v_booking.completion_requested_at IS NULL OR v_booking.work_timer_running THEN
    RAISE EXCEPTION 'No stopped completion request is waiting for your response';
  END IF;

  INSERT INTO srk_private.work_timer_authorizations(transaction_id,booking_id,actor_id)
  VALUES (pg_catalog.txid_current(),p_booking_id,auth.uid());

  IF p_response='approved' THEN
    IF v_booking.selected_category IS NOT NULL THEN
      IF v_booking.labour_rate8h_paise_snapshot IS NULL
         OR v_booking.labour_rate_tier_snapshot IS NULL
         OR v_booking.labour_rate_card_version_snapshot IS NULL
         OR v_booking.work_timer_elapsed_seconds<=0 THEN
        RAISE EXCEPTION 'Final labour bill cannot be calculated; Admin review required';
      END IF;

      v_minutes:=ceil(v_booking.work_timer_elapsed_seconds/60);
      v_amount_paise:=floor(
        (v_booking.labour_rate8h_paise_snapshot::numeric*v_minutes/480)+0.5
      );
      IF v_minutes<1 OR v_amount_paise<1 OR v_amount_paise>999999999999999999 THEN
        RAISE EXCEPTION 'Final labour amount is outside the supported range';
      END IF;
      v_amount:=round(v_amount_paise/100,2);

      INSERT INTO public.srk_booking_labour_bills(
        booking_id,customer_user_id,electrician_profile_id,
        customer_work_category,approved_rate_tier,rate_card_version,
        rate8h_paise,elapsed_seconds,billable_minutes,
        labour_amount_paise,labour_amount
      ) VALUES (
        p_booking_id,v_booking.customer_user_id,v_booking.assigned_electrician_id,
        v_booking.selected_category,v_booking.labour_rate_tier_snapshot,
        v_booking.labour_rate_card_version_snapshot,
        v_booking.labour_rate8h_paise_snapshot,v_booking.work_timer_elapsed_seconds,
        v_minutes::bigint,v_amount_paise,v_amount
      );

     END IF;

    INSERT INTO srk_private.work_transition_authorizations(transaction_id,booking_id,target_status)
    VALUES (pg_catalog.txid_current(),p_booking_id,'completed');

    UPDATE public.service_bookings
    SET status='completed',
        service_charge=CASE WHEN v_booking.selected_category IS NOT NULL THEN v_amount ELSE service_charge END,
        completion_approval_status='approved',
        customer_completed_at=clock_timestamp(),
        work_timer_running=false,
        work_started_at=NULL
    WHERE id=p_booking_id;

    DELETE FROM srk_private.work_transition_authorizations
    WHERE transaction_id=pg_catalog.txid_current()
      AND booking_id=p_booking_id AND target_status='completed';
  ELSIF p_response='rejected' THEN
    UPDATE public.service_bookings
    SET completion_approval_status='rejected',
        completion_requested_at=NULL,
        work_started_at=clock_timestamp(),
        work_timer_running=true
    WHERE id=p_booking_id;
  ELSE
    INSERT INTO public.srk_booking_complaints(booking_id,customer_user_id,category,description)
    VALUES (p_booking_id,auth.uid(),'service_quality','काम पूरा होने पर विवाद: '||v_note);
    UPDATE public.service_bookings
    SET completion_approval_status='disputed',
        work_timer_running=false,
        work_started_at=NULL
    WHERE id=p_booking_id;
  END IF;

  DELETE FROM srk_private.work_timer_authorizations
  WHERE transaction_id=pg_catalog.txid_current() AND booking_id=p_booking_id AND actor_id=auth.uid();

  RETURN jsonb_build_object(
    'success',true,'response',p_response,
    'bill_created',p_response='approved' AND v_booking.selected_category IS NOT NULL
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_get_labour_bill(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_bill public.srk_booking_labour_bills%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_bill FROM public.srk_booking_labour_bills
  WHERE booking_id=p_booking_id AND customer_user_id=auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Final labour bill not found' USING ERRCODE='42501';
  END IF;
  RETURN jsonb_build_object(
    'booking_id',v_bill.booking_id,
    'category',v_bill.customer_work_category,
    'rate_tier',v_bill.approved_rate_tier,
    'rate_card_version',v_bill.rate_card_version,
    'rate8h_paise',v_bill.rate8h_paise,
    'elapsed_seconds',v_bill.elapsed_seconds,
    'billable_minutes',v_bill.billable_minutes,
    'labour_amount_paise',v_bill.labour_amount_paise,
    'labour_amount',v_bill.labour_amount,
    'created_at',v_bill.created_at,
    'document_type','final_labour_bill'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_electrician_get_labour_bill(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_bill public.srk_booking_labour_bills%ROWTYPE; v_profile_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  SELECT p.id INTO v_profile_id FROM public.electrician_profiles p
  WHERE (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
  ORDER BY p.created_at DESC LIMIT 1;
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Electrician profile not found' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_bill FROM public.srk_booking_labour_bills
  WHERE booking_id=p_booking_id AND electrician_profile_id=v_profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Final labour bill not found' USING ERRCODE='42501';
  END IF;
  RETURN jsonb_build_object(
    'booking_id',v_bill.booking_id,
    'category',v_bill.customer_work_category,
    'rate_tier',v_bill.approved_rate_tier,
    'rate_card_version',v_bill.rate_card_version,
    'rate8h_paise',v_bill.rate8h_paise,
    'elapsed_seconds',v_bill.elapsed_seconds,
    'billable_minutes',v_bill.billable_minutes,
    'labour_amount_paise',v_bill.labour_amount_paise,
    'labour_amount',v_bill.labour_amount,
    'created_at',v_bill.created_at,
    'document_type','final_labour_bill'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_electrician_request_work_start(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_customer_respond_work_start(uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_electrician_request_work_completion(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_customer_respond_work_completion(uuid,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_customer_get_labour_bill(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_electrician_get_labour_bill(uuid) FROM PUBLIC,anon;

GRANT EXECUTE ON FUNCTION public.srk_electrician_request_work_start(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_customer_respond_work_start(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_electrician_request_work_completion(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_customer_respond_work_completion(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_labour_bill(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_electrician_get_labour_bill(uuid) TO authenticated;
