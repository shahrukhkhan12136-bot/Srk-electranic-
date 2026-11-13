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

-- Preserve accumulated seconds from the previous timer implementation.
UPDATE public.service_bookings
SET work_timer_elapsed_seconds=work_timer_seconds::numeric
WHERE work_timer_seconds>0 AND work_timer_elapsed_seconds=0;

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
  platform_fee_rate numeric(5,2) NOT NULL DEFAULT 15.00 CHECK (platform_fee_rate=15.00),
  platform_fee_paise numeric(24,0) NOT NULL CHECK (platform_fee_paise>=0),
  platform_fee_amount numeric(18,2) NOT NULL CHECK (platform_fee_amount>=0),
  electrician_payable numeric(18,2) NOT NULL CHECK (electrician_payable>=0),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT srk_booking_labour_bill_amount_reconciles
    CHECK (labour_amount = labour_amount_paise / 100.0),
  CONSTRAINT srk_booking_labour_bill_platform_fee_reconciles
    CHECK (platform_fee_amount=platform_fee_paise/100.0
      AND labour_amount=platform_fee_amount+electrician_payable)
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
  IF TG_OP='INSERT' AND (
       NEW.work_timer_seconds<>0 OR NEW.work_timer_elapsed_seconds<>0
    OR NEW.work_timer_running IS TRUE OR NEW.work_started_at IS NOT NULL
    OR NEW.work_start_origin_status IS NOT NULL
    OR NEW.labour_rate_tier_snapshot IS NOT NULL
    OR NEW.labour_rate8h_paise_snapshot IS NOT NULL
    OR NEW.labour_rate_card_version_snapshot IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'New bookings cannot be inserted with pre-populated timer or rate snapshots'
      USING ERRCODE='42501';
  END IF;
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
  BEFORE INSERT OR UPDATE OF work_started_at,work_timer_running,work_timer_seconds,
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
  v_platform_fee_paise numeric;
  v_platform_fee numeric(18,2);
  v_electrician_payable numeric(18,2);
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
      -- Platform Fee is a separately approved 15% policy, never inferred from
      -- electrician_profiles/booking commission_rate.
      v_platform_fee_paise:=floor((v_amount_paise*15/100)+0.5);
      v_platform_fee:=round(v_platform_fee_paise/100,2);
      v_electrician_payable:=round(v_amount-v_platform_fee,2);

      INSERT INTO public.srk_booking_labour_bills(
        booking_id,customer_user_id,electrician_profile_id,
        customer_work_category,approved_rate_tier,rate_card_version,
        rate8h_paise,elapsed_seconds,billable_minutes,
        labour_amount_paise,labour_amount,platform_fee_rate,
        platform_fee_paise,platform_fee_amount,electrician_payable
      ) VALUES (
        p_booking_id,v_booking.customer_user_id,v_booking.assigned_electrician_id,
        v_booking.selected_category,v_booking.labour_rate_tier_snapshot,
        v_booking.labour_rate_card_version_snapshot,
        v_booking.labour_rate8h_paise_snapshot,v_booking.work_timer_elapsed_seconds,
        v_minutes::bigint,v_amount_paise,v_amount,15.00,
        v_platform_fee_paise,v_platform_fee,v_electrician_payable
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


-- The electrician offer API returns only fields needed for the assigned-work
-- lifecycle. It deliberately omits quote totals and all materials fields.
DROP FUNCTION IF EXISTS public.srk_get_my_offer_details();
CREATE FUNCTION public.srk_get_my_offer_details()
RETURNS TABLE(
  offer_id uuid,offer_status text,match_level text,offer_created_at timestamptz,
  booking_id uuid,service_type text,state text,district text,pincode text,
  preferred_date date,preferred_time time,work_details text,
  booking_status text,customer_name text,customer_phone text,address text,
  location_lat double precision,location_lng double precision,payment_method text,
  selected_category text,selected_duration_hours smallint,approved_rate_tier text,
  approved_skill_keys text[],work_timer_elapsed_seconds numeric,
  work_timer_running boolean,work_started_at timestamptz,
  work_start_approval_status text,completion_approval_status text,
  labour_rate_tier_snapshot text,payment_status text,amount_paid numeric,payment_verified_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
  SELECT o.id,o.status,o.match_level,o.created_at,b.id,b.service_type,b.state,b.district,b.pincode,
    b.preferred_date,b.preferred_time,b.work_details,b.status,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_work_start_approval','in_progress')
      THEN b.customer_name ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_work_start_approval','in_progress')
      THEN b.phone ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_work_start_approval','in_progress')
      THEN b.address ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_work_start_approval','in_progress')
      THEN b.location_lat ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_work_start_approval','in_progress')
      THEN b.location_lng ELSE NULL END,
    b.payment_method,b.selected_category,b.selected_duration_hours,
    p.approved_rate_tier,p.approved_skill_keys,
    b.work_timer_elapsed_seconds,b.work_timer_running,b.work_started_at,
    b.work_start_approval_status,b.completion_approval_status,
    b.labour_rate_tier_snapshot,b.payment_status,b.amount_paid,b.payment_verified_at
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



-- Narrow service-role payment lookup: payment adapters cannot select bill rows
-- directly through the Data API and cannot invent an amount from legacy quote fields.
CREATE OR REPLACE FUNCTION public.srk_service_get_labour_bill_for_payment(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_bill public.srk_booking_labour_bills%ROWTYPE;
BEGIN
  IF coalesce(auth.jwt()->>'role','')<>'service_role' THEN
    RAISE EXCEPTION 'Service role only' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_bill FROM public.srk_booking_labour_bills
  WHERE booking_id=p_booking_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN jsonb_build_object(
    'booking_id',v_bill.booking_id,
    'labour_amount_paise',v_bill.labour_amount_paise,
    'labour_amount',v_bill.labour_amount,
    'billable_minutes',v_bill.billable_minutes,
    'created_at',v_bill.created_at
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_service_get_labour_bill_for_payment(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_get_labour_bill_for_payment(uuid) TO service_role;



-- New categorized bookings settle only the immutable labour bill snapshot.
-- Legacy NULL-category bookings retain their audited quote-based compatibility path.
CREATE OR REPLACE FUNCTION public.srk_electrician_confirm_cash_payment(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_uid uuid:=auth.uid();
  v_booking public.service_bookings%ROWTYPE;
  v_bill public.srk_booking_labour_bills%ROWTYPE;
  v_reference text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT b.* INTO v_booking
  FROM public.service_bookings b
  JOIN public.electrician_profiles p ON p.id=b.assigned_electrician_id
  WHERE b.id=p_booking_id AND (p.user_id=v_uid OR p.auth_user_id=v_uid)
    AND p.verification_status='approved' AND p.active=true
  FOR UPDATE OF b;
  IF NOT FOUND THEN RAISE EXCEPTION 'Assigned booking not found' USING ERRCODE='42501'; END IF;
  IF v_booking.status<>'completed' THEN RAISE EXCEPTION 'Cash can only be confirmed after work is completed'; END IF;
  IF lower(coalesce(v_booking.payment_method,'')) NOT IN ('cash','नकद (cash)','नकद') THEN
    RAISE EXCEPTION 'This booking is not marked for cash payment';
  END IF;
  IF v_booking.payment_status='paid' THEN
    IF v_booking.selected_category IS NOT NULL THEN
      SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id;
      IF NOT FOUND OR round(coalesce(v_booking.amount_paid,0),2)<>v_bill.labour_amount THEN
        RAISE EXCEPTION 'Paid amount does not reconcile with final labour bill';
      END IF;
    END IF;
    RETURN jsonb_build_object('success',true,'already_paid',true);
  END IF;
  IF v_booking.payment_status NOT IN ('unpaid','pending') THEN
    RAISE EXCEPTION 'Payment state does not allow cash confirmation';
  END IF;

  IF v_booking.selected_category IS NOT NULL THEN
    IF v_booking.completion_approval_status<>'approved' THEN
      RAISE EXCEPTION 'Customer-approved completion is required';
    END IF;
    SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id;
    IF NOT FOUND OR v_bill.labour_amount<1 OR v_bill.labour_amount>10000000 THEN
      RAISE EXCEPTION 'Verified final labour bill is missing or invalid';
    END IF;
    IF EXISTS(SELECT 1 FROM public.srk_manual_payment_entries e WHERE e.booking_id=p_booking_id) THEN
      RAISE EXCEPTION 'A payment entry already exists; Admin reconciliation required';
    END IF;
    v_reference:='CASH-'||upper(left(replace(p_booking_id::text,'-',''),16));
    INSERT INTO public.srk_manual_payment_entries
      (booking_id,payment_method,amount,payment_reference,note,recorded_by)
    VALUES(p_booking_id,'cash',v_bill.labour_amount,v_reference,
      'Cash receipt confirmed by assigned electrician',v_uid);
    UPDATE public.service_bookings
    SET payment_status='paid',amount_paid=v_bill.labour_amount,
        payment_verified_at=clock_timestamp()
    WHERE id=p_booking_id;
    RETURN jsonb_build_object('success',true,'payment_method','cash',
      'amount_paid',v_bill.labour_amount,'labour_only',true);
  END IF;

  -- Legacy quote-based cash confirmation.
  IF v_booking.quote_status<>'approved' OR coalesce(v_booking.quoted_amount,0)<=0 THEN
    RAISE EXCEPTION 'Approved legacy quote required';
  END IF;
  UPDATE public.service_bookings
  SET payment_status='paid',amount_paid=v_booking.quoted_amount,payment_verified_at=clock_timestamp()
  WHERE id=p_booking_id;
  RETURN jsonb_build_object('success',true,'payment_method','cash','amount_paid',v_booking.quoted_amount);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_record_manual_payment(
  p_booking_id uuid,p_method text,p_reference text,p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_bill public.srk_booking_labour_bills%ROWTYPE;
  v_total numeric(12,2);
  v_method text:=lower(trim(coalesce(p_method,'')));
  v_reference text:=trim(coalesce(p_reference,''));
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL OR v_method NOT IN ('cash','upi','bank_transfer')
     OR length(v_reference) NOT BETWEEN 4 AND 120
     OR (p_note IS NOT NULL AND length(p_note)>250) THEN
    RAISE EXCEPTION 'Invalid manual payment details' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
  IF v_booking.status<>'completed' OR v_booking.assigned_electrician_id IS NULL THEN
    RAISE EXCEPTION 'Only completed assigned bookings can be marked paid';
  END IF;
  IF v_booking.payment_status IN ('paid','refunded') THEN
    RAISE EXCEPTION 'Booking already has a paid or refunded payment';
  END IF;
  IF v_booking.razorpay_order_id IS NOT NULL OR v_booking.razorpay_payment_id IS NOT NULL THEN
    RAISE EXCEPTION 'Razorpay-linked bookings must use verified Razorpay flow';
  END IF;
  IF EXISTS(SELECT 1 FROM public.srk_manual_payment_entries e WHERE e.booking_id=p_booking_id) THEN
    RAISE EXCEPTION 'A manual payment entry already exists for this booking';
  END IF;

  IF v_booking.selected_category IS NOT NULL THEN
    IF v_booking.completion_approval_status<>'approved' THEN
      RAISE EXCEPTION 'Customer-approved completion is required';
    END IF;
    SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Verified final labour bill is missing'; END IF;
    v_total:=v_bill.labour_amount;
  ELSE
    IF v_booking.quote_status<>'approved' OR v_booking.service_charge IS NULL
       OR v_booking.service_charge<0 OR v_booking.materials_amount<0 THEN
      RAISE EXCEPTION 'Approved legacy quote breakdown is invalid';
    END IF;
    v_total:=round(v_booking.service_charge+v_booking.materials_amount,2);
    IF round(coalesce(v_booking.quoted_amount,-1),2)<>v_total THEN
      RAISE EXCEPTION 'Legacy approved quote total does not reconcile';
    END IF;
  END IF;
  IF v_total<1 OR v_total>10000000 THEN RAISE EXCEPTION 'Payment amount outside supported range'; END IF;

  INSERT INTO public.srk_manual_payment_entries
    (booking_id,payment_method,amount,payment_reference,note,recorded_by)
  VALUES(p_booking_id,v_method,v_total,v_reference,nullif(trim(coalesce(p_note,'')),''),auth.uid());

  UPDATE public.service_bookings
  SET payment_method=CASE v_method WHEN 'cash' THEN 'Cash' WHEN 'upi' THEN 'UPI' ELSE 'Bank Transfer' END,
      payment_status='paid',amount_paid=v_total,payment_verified_at=clock_timestamp()
  WHERE id=p_booking_id;

  RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,
    'payment_method',v_method,'amount',v_total,'reference',v_reference,
    'labour_only',v_booking.selected_category IS NOT NULL);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_create_electrician_payable()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
DECLARE
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_total numeric(12,2);
  v_rate numeric(7,2);
  v_commission numeric(12,2);
  v_bill public.srk_booking_labour_bills%ROWTYPE;
BEGIN
  IF NEW.payment_status='paid' AND NEW.status='completed'
     AND NEW.assigned_electrician_id IS NOT NULL AND NEW.payment_verified_at IS NOT NULL
     AND (NEW.razorpay_payment_id IS NOT NULL OR EXISTS(
       SELECT 1 FROM public.srk_manual_payment_entries e
       WHERE e.booking_id=NEW.id AND e.amount=round(coalesce(NEW.amount_paid,0),2)
     )) THEN
    v_rate:=NEW.commission_rate;
    IF NEW.selected_category IS NOT NULL THEN
      IF NEW.completion_approval_status<>'approved' THEN
        RAISE EXCEPTION 'Customer-approved labour completion required for payout';
      END IF;
      SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=NEW.id;
      IF NOT FOUND OR round(coalesce(NEW.amount_paid,0),2)<>v_bill.labour_amount THEN
        RAISE EXCEPTION 'Verified payment does not match final labour bill; payout blocked';
      END IF;
      v_service:=v_bill.labour_amount;
      v_materials:=0;
      v_commission:=v_bill.platform_fee_amount;
    ELSIF NEW.quote_status='approved' THEN
      v_rate:=NEW.commission_rate;
      IF v_rate IS NULL OR v_rate<0 OR v_rate>100 THEN
        RAISE EXCEPTION 'Legacy commission rate must be between 0 and 100';
      END IF;
      v_service:=round(coalesce(NEW.service_charge,0),2);
      v_materials:=round(coalesce(NEW.materials_amount,0),2);
      v_total:=round(v_service+v_materials,2);
      IF round(coalesce(NEW.amount_paid,0),2)<>v_total THEN
        RAISE EXCEPTION 'Legacy verified payment does not match approved quote; payout ledger not created';
      END IF;
      v_commission:=round(v_service*v_rate/100,2);
    ELSE
      RETURN NEW;
    END IF;
    INSERT INTO public.srk_electrician_payouts(
      booking_id,electrician_profile_id,razorpay_payment_id,
      gross_service_amount,materials_amount,platform_commission,
      electrician_payable,payout_status
    ) VALUES(
      NEW.id,NEW.assigned_electrician_id,NEW.razorpay_payment_id,
      v_service,v_materials,v_commission,round(v_service+v_materials-v_commission,2),'pending'
    )
    ON CONFLICT(booking_id) DO UPDATE SET
      electrician_profile_id=excluded.electrician_profile_id,
      razorpay_payment_id=excluded.razorpay_payment_id,
      gross_service_amount=excluded.gross_service_amount,
      materials_amount=excluded.materials_amount,
      platform_commission=excluded.platform_commission,
      electrician_payable=excluded.electrician_payable,
      updated_at=clock_timestamp()
    WHERE public.srk_electrician_payouts.payout_status='pending';
  ELSIF NEW.payment_status='refunded' THEN
    UPDATE public.srk_electrician_payouts
    SET payout_status='refunded',updated_at=clock_timestamp()
    WHERE booking_id=NEW.id AND payout_status IN ('pending','blocked');
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_mark_electrician_payout_paid(
  p_payout_id uuid,p_method text,p_reference text,p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_row public.srk_electrician_payouts%ROWTYPE;
  v_booking public.service_bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  IF p_payout_id IS NULL OR p_method NOT IN ('upi','bank')
     OR p_reference IS NULL OR length(btrim(p_reference)) NOT BETWEEN 4 AND 120
     OR (p_note IS NOT NULL AND length(p_note)>250) THEN
    RAISE EXCEPTION 'Invalid payout settlement details' USING ERRCODE='22023';
  END IF;

  SELECT b.* INTO v_booking
  FROM public.service_bookings b
  JOIN public.srk_electrician_payouts p ON p.booking_id=b.id
  WHERE p.id=p_payout_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Payout booking not found'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=v_booking.id FOR UPDATE;
  SELECT * INTO v_row FROM public.srk_electrician_payouts WHERE id=p_payout_id FOR UPDATE;
  IF NOT FOUND OR v_row.booking_id IS DISTINCT FROM v_booking.id THEN
    RAISE EXCEPTION 'Payout record changed; refresh and retry';
  END IF;
  IF v_row.payout_status<>'pending' THEN RAISE EXCEPTION 'Only pending payouts can be marked paid'; END IF;

  IF v_booking.status<>'completed' OR v_booking.payment_status<>'paid'
     OR v_booking.payment_verified_at IS NULL
     OR v_booking.assigned_electrician_id IS DISTINCT FROM v_row.electrician_profile_id
     OR NOT (v_booking.razorpay_payment_id IS NOT NULL OR EXISTS(
       SELECT 1 FROM public.srk_manual_payment_entries e
       WHERE e.booking_id=v_booking.id AND round(coalesce(e.amount,0),2)=round(coalesce(v_booking.amount_paid,0),2)
     )) THEN
    RAISE EXCEPTION 'Booking payment proof or assignment does not reconcile';
  END IF;

  IF v_booking.selected_category IS NOT NULL THEN
    IF v_booking.completion_approval_status<>'approved'
       OR NOT EXISTS(SELECT 1 FROM public.srk_booking_labour_bills b
         WHERE b.booking_id=v_booking.id
           AND round(b.labour_amount,2)=round(coalesce(v_booking.amount_paid,0),2)
           AND round(b.labour_amount,2)=round(coalesce(v_row.gross_service_amount,0),2)
           AND coalesce(v_row.materials_amount,0)=0
           AND round(v_row.platform_commission,2)=round(b.platform_fee_amount,2)
           AND round(v_row.electrician_payable,2)=round(b.electrician_payable,2)
       ) THEN
      RAISE EXCEPTION 'Labour bill or payout ledger does not reconcile; settlement blocked';
    END IF;
  ELSE
    IF v_booking.quote_status<>'approved'
       OR round(coalesce(v_booking.amount_paid,0),2)<>round(coalesce(v_booking.service_charge,0)+coalesce(v_booking.materials_amount,0),2)
       OR round(coalesce(v_row.gross_service_amount,0),2)<>round(coalesce(v_booking.service_charge,0),2)
       OR round(coalesce(v_row.materials_amount,0),2)<>round(coalesce(v_booking.materials_amount,0),2)
       OR round(coalesce(v_row.platform_commission,0),2)<>round(coalesce(v_booking.service_charge,0)*v_booking.commission_rate/100,2)
       OR round(coalesce(v_row.electrician_payable,0),2)<>round(coalesce(v_booking.service_charge,0)+coalesce(v_booking.materials_amount,0)-round(coalesce(v_booking.service_charge,0)*v_booking.commission_rate/100,2),2) THEN
      RAISE EXCEPTION 'Legacy booking payment or payout ledger does not reconcile';
    END IF;
  END IF;

  UPDATE public.srk_electrician_payouts
  SET payout_status='paid',payout_method=p_method,payout_reference=btrim(p_reference),
      payout_note=nullif(btrim(p_note),''),paid_by=auth.uid(),
      paid_at=clock_timestamp(),updated_at=clock_timestamp()
  WHERE id=p_payout_id;
  RETURN jsonb_build_object('success',true,'payout_id',p_payout_id,'status','paid');
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_prepare_razorpay_refund(p_booking_id uuid,p_reason text)
RETURNS TABLE(
  refund_record_id uuid,booking_id uuid,payment_id text,amount_paise bigint,
  idempotency_key text,status text,previous_payout_note text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_refund public.srk_razorpay_refunds%ROWTYPE;
  v_payout public.srk_electrician_payouts%ROWTYPE;
  v_bill public.srk_booking_labour_bills%ROWTYPE;
  v_total numeric(12,2);
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 20 AND 250 THEN
    RAISE EXCEPTION 'Refund reason must be 20 to 250 characters';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
  IF v_booking.payment_status<>'paid' OR v_booking.payment_verified_at IS NULL
     OR v_booking.razorpay_payment_id IS NULL OR v_booking.amount_paid IS NULL OR v_booking.amount_paid<=0 THEN
    RAISE EXCEPTION 'Only verified Razorpay-paid bookings can be refunded';
  END IF;
  IF v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$' THEN
    RAISE EXCEPTION 'Invalid Razorpay payment ID';
  END IF;

  IF v_booking.selected_category IS NOT NULL THEN
    IF v_booking.completion_approval_status<>'approved' THEN
      RAISE EXCEPTION 'Customer-approved labour bill required for refund';
    END IF;
    SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id;
    IF NOT FOUND OR round(v_booking.amount_paid,2)<>v_bill.labour_amount THEN
      RAISE EXCEPTION 'Paid amount does not match final labour bill';
    END IF;
  ELSE
    IF v_booking.quote_status<>'approved' OR v_booking.quoted_amount IS NULL
       OR v_booking.service_charge IS NULL OR v_booking.materials_amount IS NULL
       OR round(v_booking.amount_paid,2)<>round(v_booking.quoted_amount,2)
       OR round(v_booking.amount_paid,2)<>round(v_booking.service_charge+v_booking.materials_amount,2) THEN
      RAISE EXCEPTION 'Paid amount does not match legacy approved quote';
    END IF;
  END IF;
  v_total:=round(v_booking.amount_paid,2);

  SELECT * INTO v_refund FROM public.srk_razorpay_refunds WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND THEN
    IF v_refund.status='failed' THEN RAISE EXCEPTION 'Previous Razorpay refund failed; reconcile before creating another request'; END IF;
    RETURN QUERY SELECT v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,
      v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
    RETURN;
  END IF;

  SELECT * INTO v_payout FROM public.srk_electrician_payouts WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND THEN
    IF v_payout.payout_status='paid' THEN
      RAISE EXCEPTION 'Electrician payout is already paid; recovery requires separate Admin reconciliation';
    END IF;
    IF v_payout.payout_status NOT IN ('pending','blocked') THEN
      RAISE EXCEPTION 'Electrician payout is not pending; reconcile payout before refund';
    END IF;
    UPDATE public.srk_electrician_payouts
    SET payout_status='blocked',payout_note='Razorpay refund pending',updated_at=clock_timestamp()
    WHERE id=v_payout.id;
  END IF;

  INSERT INTO public.srk_razorpay_refunds
    (booking_id,payment_id,amount,amount_paise,idempotency_key,status,reason,admin_user_id,previous_payout_note)
  VALUES(p_booking_id,v_booking.razorpay_payment_id,v_total,round(v_total*100)::bigint,
    replace(gen_random_uuid()::text,'-',''),'requested',btrim(p_reason),auth.uid(),v_payout.payout_note)
  RETURNING * INTO v_refund;
  RETURN QUERY SELECT v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,
    v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
END;
$function$;



-- Keep customer call contacts available during pending start approval, but never
-- expose the electrician phone after work completion through either RPC.
CREATE OR REPLACE FUNCTION private.srk_get_customer_call_contacts_impl()
RETURNS TABLE(booking_id uuid,booking_status text,electrician_name text,electrician_phone text)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT b.id,b.status,ep.display_name,ep.phone
  FROM public.service_bookings b
  JOIN public.electrician_profiles ep ON ep.id=b.assigned_electrician_id
  WHERE b.customer_user_id=v_uid AND b.assigned_electrician_id IS NOT NULL
    AND b.status IN ('assigned','inspection','awaiting_quote_approval','quote_approved',
      'quote_rejected','awaiting_work_start_approval','in_progress')
    AND ep.verification_status='approved' AND ep.active=true;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_get_my_booking_contacts()
RETURNS TABLE(booking_id uuid,electrician_phone text,booking_status text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
  SELECT b.id,ep.phone,b.status
  FROM public.service_bookings b
  JOIN public.electrician_profiles ep ON ep.id=b.assigned_electrician_id
  WHERE auth.uid() IS NOT NULL AND b.customer_user_id=auth.uid()
    AND b.assigned_electrician_id IS NOT NULL
    AND b.status IN ('assigned','inspection','awaiting_quote_approval','quote_approved',
      'quote_rejected','awaiting_work_start_approval','in_progress')
    AND ep.verification_status='approved' AND ep.active=true
  ORDER BY b.created_at DESC LIMIT 100;
$function$;
REVOKE ALL ON FUNCTION public.srk_customer_get_my_booking_contacts() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_my_booking_contacts() TO authenticated;



CREATE OR REPLACE FUNCTION public.srk_admin_get_labour_bill(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_bill public.srk_booking_labour_bills%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN jsonb_build_object(
    'booking_id',v_bill.booking_id,
    'customer_work_category',v_bill.customer_work_category,
    'approved_rate_tier',v_bill.approved_rate_tier,
    'rate_card_version',v_bill.rate_card_version,
    'rate8h_paise',v_bill.rate8h_paise,
    'elapsed_seconds',v_bill.elapsed_seconds,
    'billable_minutes',v_bill.billable_minutes,
    'labour_amount_paise',v_bill.labour_amount_paise,
    'labour_amount',v_bill.labour_amount,
    'created_at',v_bill.created_at
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_get_labour_bill(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_get_labour_bill(uuid) TO authenticated;



-- New categorized bookings use the separately approved Platform Fee policy.
-- The legacy commission_rate field is not used to infer the new-flow fee.
CREATE OR REPLACE FUNCTION public.srk_calculate_booking_commission()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
BEGIN
  IF NEW.amount_paid IS NOT NULL AND NEW.amount_paid<0 THEN
    RAISE EXCEPTION 'amount_paid cannot be negative';
  END IF;
  IF NEW.service_charge IS NOT NULL AND NEW.service_charge<0 THEN
    RAISE EXCEPTION 'service_charge cannot be negative';
  END IF;
  IF NEW.selected_category IS NOT NULL THEN
    NEW.commission_amount:=NULL;
    RETURN NEW;
  END IF;
  IF NEW.commission_rate IS NULL OR NEW.commission_rate<0 OR NEW.commission_rate>100 THEN
    RAISE EXCEPTION 'commission_rate must be between 0 and 100';
  END IF;
  IF NEW.status='completed' AND NEW.payment_status='paid'
     AND NEW.amount_paid IS NOT NULL AND NEW.service_charge IS NOT NULL THEN
    NEW.commission_amount:=round(NEW.service_charge*NEW.commission_rate/100,2);
  ELSE
    NEW.commission_amount:=NULL;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_get_my_earnings()
RETURNS TABLE(
  booking_id uuid,service_type text,booking_created_at timestamptz,
  booking_status text,payment_status text,amount_received numeric,
  commission_amount numeric,electrician_earning numeric
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
  SELECT b.id,b.service_type,b.created_at,b.status,b.payment_status,
    coalesce(b.amount_paid,0),
    CASE WHEN b.selected_category IS NOT NULL THEN coalesce(lb.platform_fee_amount,0)
      ELSE coalesce(b.commission_amount,0) END,
    CASE WHEN b.status='completed' AND b.payment_status='paid'
      THEN CASE WHEN b.selected_category IS NOT NULL THEN coalesce(lb.electrician_payable,0)
        ELSE greatest(coalesce(b.amount_paid,0)-coalesce(b.commission_amount,0),0) END
      ELSE 0 END
  FROM public.electrician_profiles p
  JOIN public.service_bookings b ON b.assigned_electrician_id=p.id
  LEFT JOIN public.srk_booking_labour_bills lb ON lb.booking_id=b.id
  WHERE (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved'
  ORDER BY b.created_at DESC LIMIT 200;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_commission_report()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  WITH paid_completed AS (
    SELECT b.assigned_electrician_id,
      coalesce(b.amount_paid,0)::numeric AS gross,
      CASE WHEN b.selected_category IS NOT NULL THEN coalesce(lb.platform_fee_amount,0)::numeric
        ELSE coalesce(b.commission_amount,0)::numeric END AS platform_fee
    FROM public.service_bookings b
    LEFT JOIN public.srk_booking_labour_bills lb ON lb.booking_id=b.id
    WHERE b.status='completed' AND b.payment_status='paid'
  ), totals AS (
    SELECT coalesce(sum(gross),0)::numeric AS collected,
      coalesce(sum(platform_fee),0)::numeric AS fee,
      coalesce(sum(gross-platform_fee),0)::numeric AS payable
    FROM paid_completed
  ), partners AS (
    SELECT p.id AS electrician_id,p.display_name,
      count(pc.*)::integer AS paid_completed_jobs,
      coalesce(sum(pc.gross),0)::numeric AS gross_received,
      coalesce(sum(pc.platform_fee),0)::numeric AS company_commission,
      coalesce(sum(pc.gross-pc.platform_fee),0)::numeric AS electrician_earning
    FROM public.electrician_profiles p
    LEFT JOIN paid_completed pc ON pc.assigned_electrician_id=p.id
    GROUP BY p.id,p.display_name
    ORDER BY p.display_name
  )
  SELECT jsonb_build_object(
    'total_collected',t.collected,
    'total_commission',t.fee,
    'total_platform_fee',t.fee,
    'total_electrician_payable',t.payable,
    'partners',coalesce((SELECT jsonb_agg(to_jsonb(partners)) FROM partners),'[]'::jsonb)
  ) INTO v_result FROM totals t;
  RETURN v_result;
END;
$function$;

