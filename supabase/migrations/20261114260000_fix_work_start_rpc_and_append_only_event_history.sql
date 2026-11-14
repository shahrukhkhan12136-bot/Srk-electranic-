-- Correct the customer start-approval RPC contract and harden work-event history.
-- Source-only migration; do not apply to production without separate approval.

CREATE OR REPLACE FUNCTION public.srk_customer_respond_work_start(
  p_booking_id uuid,
  p_response text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','srk_private','pg_temp'
AS $function$
DECLARE
  b public.service_bookings%ROWTYPE;
  p public.electrician_profiles%ROWTYPE;
  v_rate bigint;
  v_tier text;
  v_version text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL OR p_response IS NULL
     OR p_response NOT IN ('approved','rejected') THEN
    RAISE EXCEPTION 'Invalid work-start response' USING ERRCODE='22023';
  END IF;

  SELECT * INTO b
  FROM public.service_bookings
  WHERE id=p_booking_id AND customer_user_id=auth.uid()
  FOR UPDATE;

  IF NOT FOUND OR b.status<>'awaiting_work_start_approval'
     OR b.work_start_approval_status<>'pending' THEN
    RAISE EXCEPTION 'काम शुरू करने की कोई लंबित अनुमति नहीं है';
  END IF;

  INSERT INTO srk_private.work_timer_authorizations(transaction_id,booking_id,actor_id)
  VALUES(pg_catalog.txid_current(),p_booking_id,auth.uid());

  IF p_response='approved' THEN
    SELECT * INTO p
    FROM public.electrician_profiles
    WHERE id=b.assigned_electrician_id
      AND active=true
      AND verification_status='approved'
      AND approved_rate_tier=b.selected_rate_tier
      AND approved_rate_card_version IS NOT NULL
      AND rate_tier_approved_by IS NOT NULL
      AND rate_tier_approved_at IS NOT NULL
    FOR SHARE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'इलेक्ट्रिशियन की Admin-approved श्रेणी सत्यापित नहीं हो सकी';
    END IF;

    v_tier:=p.approved_rate_tier;
    v_version:=p.approved_rate_card_version;
    v_rate:=CASE v_tier
      WHEN 'electrical_assistant' THEN 89900
      WHEN 'skilled_electrician' THEN 119900
      WHEN 'expert_electrician' THEN 159900
      WHEN 'premium_electrician_specialist' THEN 199900
      ELSE NULL
    END;

    -- Preserve the published canonical tier key used by the rate card.
    IF v_tier='premium_electrician_specialist' THEN v_rate:=199900; END IF;
    IF v_rate IS NULL THEN
      RAISE EXCEPTION 'Unsupported approved rate tier';
    END IF;

    UPDATE public.service_bookings
    SET labour_rate_tier_snapshot=v_tier,
        labour_rate8h_paise_snapshot=v_rate,
        labour_rate_card_version_snapshot=v_version
    WHERE id=p_booking_id;

    INSERT INTO srk_private.work_transition_authorizations(
      transaction_id,booking_id,target_status
    ) VALUES(pg_catalog.txid_current(),p_booking_id,'in_progress');

    UPDATE public.service_bookings
    SET status='in_progress',
        work_start_approval_status='approved',
        work_started_at=clock_timestamp(),
        work_timer_running=true,
        work_start_origin_status=NULL
    WHERE id=p_booking_id;

    DELETE FROM srk_private.work_transition_authorizations
    WHERE transaction_id=pg_catalog.txid_current()
      AND booking_id=p_booking_id
      AND target_status='in_progress';
  ELSE
    UPDATE public.service_bookings
    SET status='assigned',
        work_start_approval_status='rejected',
        work_started_at=NULL,
        work_timer_running=false,
        work_start_origin_status=NULL
    WHERE id=p_booking_id;
  END IF;

  DELETE FROM srk_private.work_timer_authorizations
  WHERE transaction_id=pg_catalog.txid_current()
    AND booking_id=p_booking_id
    AND actor_id=auth.uid();

  RETURN jsonb_build_object('success',true,'response',p_response);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_customer_respond_work_start(uuid,text)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_respond_work_start(uuid,text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_reject_booking_work_event_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'Booking work history is append-only'
    USING ERRCODE='42501';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_reject_booking_work_event_mutation()
  FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS srk_booking_work_events_no_row_mutation
  ON public.srk_booking_work_events;
CREATE TRIGGER srk_booking_work_events_no_row_mutation
  BEFORE UPDATE OR DELETE ON public.srk_booking_work_events
  FOR EACH ROW
  EXECUTE FUNCTION public.srk_reject_booking_work_event_mutation();

DROP TRIGGER IF EXISTS srk_booking_work_events_no_truncate
  ON public.srk_booking_work_events;
CREATE TRIGGER srk_booking_work_events_no_truncate
  BEFORE TRUNCATE ON public.srk_booking_work_events
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.srk_reject_booking_work_event_mutation();
