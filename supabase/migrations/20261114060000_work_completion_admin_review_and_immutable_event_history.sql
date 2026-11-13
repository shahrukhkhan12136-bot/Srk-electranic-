-- Add immutable work-event history and an Admin review path for stopped completion requests.
-- This is additive: it does not alter production or execute against a live database.

ALTER TABLE public.srk_booking_labour_bills
  ADD COLUMN IF NOT EXISTS completion_requested_at timestamptz;

UPDATE public.srk_booking_labour_bills lb
SET completion_requested_at = COALESCE(b.completion_requested_at, lb.created_at)
FROM public.service_bookings b
WHERE b.id = lb.booking_id
  AND lb.completion_requested_at IS NULL;

ALTER TABLE public.srk_booking_labour_bills
  ALTER COLUMN completion_requested_at SET NOT NULL;

COMMENT ON COLUMN public.srk_booking_labour_bills.completion_requested_at IS
  'Server timestamp when electrician first submitted the completion request used for this immutable bill; Admin review time never replaces it.';

CREATE TABLE IF NOT EXISTS public.srk_booking_work_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  actor_id uuid,
  event_type text NOT NULL CHECK (event_type IN (
    'booking_created',
    'work_start_requested',
    'work_start_approved',
    'work_start_rejected',
    'work_timer_started',
    'work_completion_requested',
    'work_completion_rejected',
    'work_completion_disputed',
    'work_completion_customer_approved',
    'work_completion_admin_approved',
    'booking_work_state_changed'
  )),
  old_status text,
  new_status text,
  old_timer_running boolean,
  new_timer_running boolean,
  old_work_started_at timestamptz,
  new_work_started_at timestamptz,
  old_elapsed_seconds numeric(24,6),
  new_elapsed_seconds numeric(24,6),
  old_start_approval_status text,
  new_start_approval_status text,
  old_completion_approval_status text,
  new_completion_approval_status text,
  completion_requested_at timestamptz,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS srk_booking_work_events_booking_time_idx
  ON public.srk_booking_work_events(booking_id, occurred_at, id);

ALTER TABLE public.srk_booking_work_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_booking_work_events FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.srk_guard_immutable_booking_work_event()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'Booking work-event history is append-only'
    USING ERRCODE='42501';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_immutable_booking_work_event() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS srk_guard_immutable_booking_work_event ON public.srk_booking_work_events;
CREATE TRIGGER srk_guard_immutable_booking_work_event
  BEFORE UPDATE OR DELETE ON public.srk_booking_work_events
  FOR EACH ROW EXECUTE FUNCTION public.srk_guard_immutable_booking_work_event();

-- Private, transaction-scoped details let privileged RPCs enrich the single
-- trigger-generated event without allowing clients to write audit history.
CREATE TABLE IF NOT EXISTS srk_private.work_event_details_authorizations (
  transaction_id bigint NOT NULL,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL,
  event_type text NOT NULL,
  details jsonb NOT NULL,
  PRIMARY KEY (transaction_id, booking_id)
);
REVOKE ALL ON TABLE srk_private.work_event_details_authorizations FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.srk_capture_booking_work_event()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_event_type text;
  v_actor uuid := auth.uid();
  v_details jsonb := '{}'::jsonb;
BEGIN
  IF TG_OP='INSERT' THEN
    v_event_type := 'booking_created';
    INSERT INTO public.srk_booking_work_events(
      booking_id, actor_id, event_type, new_status, new_timer_running,
      new_work_started_at, new_elapsed_seconds, new_start_approval_status,
      new_completion_approval_status, completion_requested_at
    ) VALUES (
      NEW.id, v_actor, v_event_type, NEW.status, NEW.work_timer_running,
      NEW.work_started_at, COALESCE(NEW.work_timer_elapsed_seconds,0),
      NEW.work_start_approval_status, NEW.completion_approval_status,
      NEW.completion_requested_at
    );
    RETURN NEW;
  END IF;

  IF OLD.status IS NOT DISTINCT FROM NEW.status
     AND OLD.work_timer_running IS NOT DISTINCT FROM NEW.work_timer_running
     AND OLD.work_started_at IS NOT DISTINCT FROM NEW.work_started_at
     AND OLD.work_timer_elapsed_seconds IS NOT DISTINCT FROM NEW.work_timer_elapsed_seconds
     AND OLD.work_start_approval_status IS NOT DISTINCT FROM NEW.work_start_approval_status
     AND OLD.completion_approval_status IS NOT DISTINCT FROM NEW.completion_approval_status
     AND OLD.completion_requested_at IS NOT DISTINCT FROM NEW.completion_requested_at THEN
    RETURN NEW;
  END IF;

  v_event_type := CASE
    WHEN OLD.work_start_approval_status IS DISTINCT FROM NEW.work_start_approval_status
      AND NEW.work_start_approval_status='pending' THEN 'work_start_requested'
    WHEN OLD.work_start_approval_status IS DISTINCT FROM NEW.work_start_approval_status
      AND NEW.work_start_approval_status='approved' THEN 'work_start_approved'
    WHEN OLD.work_start_approval_status IS DISTINCT FROM NEW.work_start_approval_status
      AND NEW.work_start_approval_status='rejected' THEN 'work_start_rejected'
    WHEN OLD.completion_requested_at IS DISTINCT FROM NEW.completion_requested_at
      AND NEW.completion_requested_at IS NOT NULL THEN 'work_completion_requested'
    WHEN OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status
      AND NEW.completion_approval_status='rejected' THEN 'work_completion_rejected'
    WHEN OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status
      AND NEW.completion_approval_status='disputed' THEN 'work_completion_disputed'
    WHEN OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status
      AND NEW.completion_approval_status='approved'
      AND public.is_srk_admin() THEN 'work_completion_admin_approved'
    WHEN OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status
      AND NEW.completion_approval_status='approved' THEN 'work_completion_customer_approved'
    WHEN OLD.work_timer_running IS DISTINCT FROM NEW.work_timer_running
      AND NEW.work_timer_running IS TRUE THEN 'work_timer_started'
    ELSE 'booking_work_state_changed'
  END;

  IF v_event_type='work_completion_admin_approved' THEN
    SELECT a.details INTO v_details
    FROM srk_private.work_event_details_authorizations a
    WHERE a.transaction_id=pg_catalog.txid_current()
      AND a.booking_id=NEW.id AND a.actor_id=v_actor
      AND a.event_type=v_event_type;
    v_details := COALESCE(v_details,'{}'::jsonb);
  END IF;

  INSERT INTO public.srk_booking_work_events(
    booking_id, actor_id, event_type,
    old_status, new_status,
    old_timer_running, new_timer_running,
    old_work_started_at, new_work_started_at,
    old_elapsed_seconds, new_elapsed_seconds,
    old_start_approval_status, new_start_approval_status,
    old_completion_approval_status, new_completion_approval_status,
    completion_requested_at, details
  ) VALUES (
    NEW.id, v_actor, v_event_type,
    OLD.status, NEW.status,
    OLD.work_timer_running, NEW.work_timer_running,
    OLD.work_started_at, NEW.work_started_at,
    OLD.work_timer_elapsed_seconds, NEW.work_timer_elapsed_seconds,
    OLD.work_start_approval_status, NEW.work_start_approval_status,
    OLD.completion_approval_status, NEW.completion_approval_status,
    NEW.completion_requested_at, v_details
  );
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_capture_booking_work_event() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS srk_capture_booking_work_event ON public.service_bookings;
CREATE TRIGGER srk_capture_booking_work_event
  AFTER INSERT OR UPDATE ON public.service_bookings
  FOR EACH ROW EXECUTE FUNCTION public.srk_capture_booking_work_event();

-- Permit the protected bill INSERT trigger to validate Admin-reviewed completion.
-- The locked booking must still be in_progress with a stopped timer and an
-- original server completion-request timestamp; the Admin cannot supply time.
CREATE OR REPLACE FUNCTION public.srk_guard_immutable_booking_labour_bill()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_minutes bigint;
  v_labour_paise numeric(24,0);
  v_fee_paise numeric(24,0);
BEGIN
  IF TG_OP<>'INSERT' THEN
    RAISE EXCEPTION 'Final labour bill snapshots are immutable'
      USING ERRCODE='42501';
  END IF;

  IF NOT EXISTS(
    SELECT 1 FROM srk_private.work_timer_authorizations a
    WHERE a.transaction_id=pg_catalog.txid_current()
      AND a.booking_id=NEW.booking_id AND a.actor_id=auth.uid()
  ) THEN
    RAISE EXCEPTION 'Final labour bill can only be created by an authorized completion workflow'
      USING ERRCODE='42501';
  END IF;

  SELECT * INTO v_booking FROM public.service_bookings
  WHERE id=NEW.booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking for final labour bill not found'; END IF;

  IF v_booking.selected_category IS NULL
     OR v_booking.customer_user_id IS DISTINCT FROM NEW.customer_user_id
     OR v_booking.assigned_electrician_id IS DISTINCT FROM NEW.electrician_profile_id
     OR v_booking.status<>'in_progress'
     OR v_booking.completion_approval_status NOT IN ('pending','disputed')
     OR v_booking.completion_requested_at IS NULL
     OR v_booking.work_timer_running IS TRUE
     OR v_booking.work_started_at IS NOT NULL
     OR v_booking.work_timer_elapsed_seconds<=0
     OR v_booking.labour_rate_tier_snapshot IS NULL
     OR v_booking.labour_rate8h_paise_snapshot IS NULL
     OR v_booking.labour_rate_card_version_snapshot IS NULL THEN
    RAISE EXCEPTION 'A stopped timer and pending/disputed completion request are required';
  END IF;

  v_minutes:=ceil(v_booking.work_timer_elapsed_seconds/60)::bigint;
  v_labour_paise:=floor(v_booking.labour_rate8h_paise_snapshot::numeric*v_minutes/480+0.5);
  v_fee_paise:=floor(v_labour_paise*15/100+0.5);

  IF NEW.customer_work_category IS DISTINCT FROM v_booking.selected_category
     OR NEW.approved_rate_tier IS DISTINCT FROM v_booking.labour_rate_tier_snapshot
     OR NEW.rate_card_version IS DISTINCT FROM v_booking.labour_rate_card_version_snapshot
     OR NEW.rate8h_paise IS DISTINCT FROM v_booking.labour_rate8h_paise_snapshot
     OR NEW.elapsed_seconds IS DISTINCT FROM v_booking.work_timer_elapsed_seconds
     OR NEW.completion_requested_at IS DISTINCT FROM v_booking.completion_requested_at
     OR NEW.billable_minutes IS DISTINCT FROM v_minutes
     OR NEW.labour_amount_paise IS DISTINCT FROM v_labour_paise
     OR NEW.labour_amount IS DISTINCT FROM (v_labour_paise/100)::numeric(18,2)
     OR NEW.platform_fee_rate IS DISTINCT FROM 15.00::numeric
     OR NEW.platform_fee_policy_version IS DISTINCT FROM 'SRK-PLATFORM-FEE-15-2026-11-13-V1'
     OR NEW.platform_fee_paise IS DISTINCT FROM v_fee_paise
     OR NEW.platform_fee_amount IS DISTINCT FROM (v_fee_paise/100)::numeric(18,2)
     OR NEW.electrician_payable IS DISTINCT FROM ((v_labour_paise-v_fee_paise)/100)::numeric(18,2) THEN
    RAISE EXCEPTION 'Final labour bill does not reconcile with server timer, completion timestamp and approved rate snapshot';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_immutable_booking_labour_bill() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_approve_work_completion(
  p_booking_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_minutes bigint;
  v_labour_paise numeric(24,0);
  v_labour numeric(18,2);
  v_fee_paise numeric(24,0);
  v_fee numeric(18,2);
  v_electrician_payable numeric(18,2);
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL OR p_reason IS NULL
     OR length(btrim(p_reason)) NOT BETWEEN 20 AND 1000 THEN
    RAISE EXCEPTION 'Admin approval reason must be 20 to 1000 characters'
      USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_booking FROM public.service_bookings
  WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;

  IF v_booking.selected_category IS NULL
     OR v_booking.status<>'in_progress'
     OR v_booking.completion_approval_status NOT IN ('pending','disputed')
     OR v_booking.completion_requested_at IS NULL
     OR v_booking.work_timer_running IS TRUE
     OR v_booking.work_started_at IS NOT NULL
     OR v_booking.work_timer_elapsed_seconds<=0
     OR v_booking.labour_rate_tier_snapshot IS NULL
     OR v_booking.labour_rate8h_paise_snapshot IS NULL
     OR v_booking.labour_rate_card_version_snapshot IS NULL THEN
    RAISE EXCEPTION 'Only a stopped, pending/disputed new-flow completion can be approved';
  END IF;

  IF EXISTS(SELECT 1 FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id) THEN
    RAISE EXCEPTION 'A final labour bill already exists; Admin reconciliation required';
  END IF;

  v_minutes:=ceil(v_booking.work_timer_elapsed_seconds/60)::bigint;
  v_labour_paise:=floor(v_booking.labour_rate8h_paise_snapshot::numeric*v_minutes/480+0.5);
  v_fee_paise:=floor(v_labour_paise*15/100+0.5);
  IF v_minutes<1 OR v_labour_paise<1 OR v_labour_paise>999999999999999999 THEN
    RAISE EXCEPTION 'Final labour amount is outside the supported range';
  END IF;
  v_labour:=round(v_labour_paise/100,2);
  v_fee:=round(v_fee_paise/100,2);
  v_electrician_payable:=round(v_labour-v_fee,2);

  INSERT INTO srk_private.work_timer_authorizations(transaction_id,booking_id,actor_id)
  VALUES (pg_catalog.txid_current(),p_booking_id,auth.uid());

  INSERT INTO public.srk_booking_labour_bills(
    booking_id,customer_user_id,electrician_profile_id,
    customer_work_category,approved_rate_tier,rate_card_version,
    rate8h_paise,elapsed_seconds,completion_requested_at,billable_minutes,
    labour_amount_paise,labour_amount,platform_fee_rate,
    platform_fee_paise,platform_fee_amount,electrician_payable
  ) VALUES (
    p_booking_id,v_booking.customer_user_id,v_booking.assigned_electrician_id,
    v_booking.selected_category,v_booking.labour_rate_tier_snapshot,
    v_booking.labour_rate_card_version_snapshot,
    v_booking.labour_rate8h_paise_snapshot,v_booking.work_timer_elapsed_seconds,
    v_booking.completion_requested_at,v_minutes,
    v_labour_paise,v_labour,15.00,v_fee_paise,v_fee,v_electrician_payable
  );

  INSERT INTO srk_private.work_transition_authorizations(transaction_id,booking_id,target_status)
  VALUES (pg_catalog.txid_current(),p_booking_id,'completed');

  INSERT INTO srk_private.work_event_details_authorizations(
    transaction_id,booking_id,actor_id,event_type,details
  ) VALUES (
    pg_catalog.txid_current(),p_booking_id,auth.uid(),'work_completion_admin_approved',
    jsonb_build_object('reason',btrim(p_reason),'billable_minutes',v_minutes,
      'labour_amount',v_labour,'platform_fee_amount',v_fee,
      'electrician_payable',v_electrician_payable)
  );

  UPDATE public.service_bookings
  SET status='completed',
      service_charge=v_labour,
      completion_approval_status='approved',
      customer_completed_at=clock_timestamp(),
      work_timer_running=false,
      work_started_at=NULL
  WHERE id=p_booking_id;

  DELETE FROM srk_private.work_event_details_authorizations
  WHERE transaction_id=pg_catalog.txid_current() AND booking_id=p_booking_id;
  DELETE FROM srk_private.work_transition_authorizations
  WHERE transaction_id=pg_catalog.txid_current()
    AND booking_id=p_booking_id AND target_status='completed';
  DELETE FROM srk_private.work_timer_authorizations
  WHERE transaction_id=pg_catalog.txid_current()
    AND booking_id=p_booking_id AND actor_id=auth.uid();

  RETURN jsonb_build_object(
    'success',true,'booking_id',p_booking_id,'status','completed',
    'completion_approval_status','approved','admin_approved',true,
    'completion_requested_at',v_booking.completion_requested_at,
    'billable_minutes',v_minutes,'labour_amount',v_labour,
    'platform_fee_amount',v_fee,'electrician_payable',v_electrician_payable
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_approve_work_completion(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_approve_work_completion(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_get_booking_work_events(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_events jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.service_bookings WHERE id=p_booking_id) THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id',e.id,'event_type',e.event_type,'actor_id',e.actor_id,
    'old_status',e.old_status,'new_status',e.new_status,
    'old_timer_running',e.old_timer_running,'new_timer_running',e.new_timer_running,
    'old_work_started_at',e.old_work_started_at,'new_work_started_at',e.new_work_started_at,
    'old_elapsed_seconds',e.old_elapsed_seconds,'new_elapsed_seconds',e.new_elapsed_seconds,
    'old_start_approval_status',e.old_start_approval_status,
    'new_start_approval_status',e.new_start_approval_status,
    'old_completion_approval_status',e.old_completion_approval_status,
    'new_completion_approval_status',e.new_completion_approval_status,
    'completion_requested_at',e.completion_requested_at,
    'details',e.details,'occurred_at',e.occurred_at
  ) ORDER BY e.occurred_at,e.id),'[]'::jsonb)
  INTO v_events
  FROM public.srk_booking_work_events e
  WHERE e.booking_id=p_booking_id;
  RETURN v_events;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_get_booking_work_events(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_get_booking_work_events(uuid) TO authenticated;


-- Keep the customer approval path compatible with the immutable bill's
-- original completion-request timestamp (not the later approval timestamp).
CREATE OR REPLACE FUNCTION public.srk_customer_respond_work_completion(
  p_booking_id uuid,p_response text,p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
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
      v_platform_fee_paise:=floor((v_amount_paise*15/100)+0.5);
      v_platform_fee:=round(v_platform_fee_paise/100,2);
      v_electrician_payable:=round(v_amount-v_platform_fee,2);

      INSERT INTO public.srk_booking_labour_bills(
        booking_id,customer_user_id,electrician_profile_id,
        customer_work_category,approved_rate_tier,rate_card_version,
        rate8h_paise,elapsed_seconds,completion_requested_at,billable_minutes,
        labour_amount_paise,labour_amount,platform_fee_rate,
        platform_fee_paise,platform_fee_amount,electrician_payable
      ) VALUES (
        p_booking_id,v_booking.customer_user_id,v_booking.assigned_electrician_id,
        v_booking.selected_category,v_booking.labour_rate_tier_snapshot,
        v_booking.labour_rate_card_version_snapshot,
        v_booking.labour_rate8h_paise_snapshot,v_booking.work_timer_elapsed_seconds,
        v_booking.completion_requested_at,v_minutes::bigint,
        v_amount_paise,v_amount,15.00,
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
REVOKE ALL ON FUNCTION public.srk_customer_respond_work_completion(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_respond_work_completion(uuid,text,text) TO authenticated;


-- Expose the original completion-request timestamp in all role-scoped bill
-- read RPCs so the customer, assigned electrician, and Admin see the same
-- immutable timing evidence alongside the final actual-duration calculation.
CREATE OR REPLACE FUNCTION public.srk_customer_get_labour_bill(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_bill public.srk_booking_labour_bills%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_bill FROM public.srk_booking_labour_bills
  WHERE booking_id=p_booking_id AND customer_user_id=auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Final labour bill not found' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object(
    'booking_id',v_bill.booking_id,'category',v_bill.customer_work_category,
    'rate_tier',v_bill.approved_rate_tier,'rate_card_version',v_bill.rate_card_version,
    'rate8h_paise',v_bill.rate8h_paise,'elapsed_seconds',v_bill.elapsed_seconds,
    'completion_requested_at',v_bill.completion_requested_at,
    'billable_minutes',v_bill.billable_minutes,'labour_amount_paise',v_bill.labour_amount_paise,
    'labour_amount',v_bill.labour_amount,'created_at',v_bill.created_at,
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
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT p.id INTO v_profile_id FROM public.electrician_profiles p
  WHERE (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
  ORDER BY p.created_at DESC LIMIT 1;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Electrician profile not found' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_bill FROM public.srk_booking_labour_bills
  WHERE booking_id=p_booking_id AND electrician_profile_id=v_profile_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Final labour bill not found' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object(
    'booking_id',v_bill.booking_id,'category',v_bill.customer_work_category,
    'rate_tier',v_bill.approved_rate_tier,'rate_card_version',v_bill.rate_card_version,
    'rate8h_paise',v_bill.rate8h_paise,'elapsed_seconds',v_bill.elapsed_seconds,
    'completion_requested_at',v_bill.completion_requested_at,
    'billable_minutes',v_bill.billable_minutes,'labour_amount_paise',v_bill.labour_amount_paise,
    'labour_amount',v_bill.labour_amount,'electrician_payable',v_bill.electrician_payable,
    'created_at',v_bill.created_at,'document_type','final_labour_bill'
  );
END;
$function$;

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
    'booking_id',v_bill.booking_id,'customer_work_category',v_bill.customer_work_category,
    'approved_rate_tier',v_bill.approved_rate_tier,'rate_card_version',v_bill.rate_card_version,
    'rate8h_paise',v_bill.rate8h_paise,'elapsed_seconds',v_bill.elapsed_seconds,
    'completion_requested_at',v_bill.completion_requested_at,
    'billable_minutes',v_bill.billable_minutes,'labour_amount_paise',v_bill.labour_amount_paise,
    'labour_amount',v_bill.labour_amount,'platform_fee_rate',v_bill.platform_fee_rate,
    'platform_fee_policy_version',v_bill.platform_fee_policy_version,
    'platform_fee_amount',v_bill.platform_fee_amount,'electrician_payable',v_bill.electrician_payable,
    'created_at',v_bill.created_at
  );
END;
$function$;
