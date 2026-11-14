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
      WHEN 'premium_electrical_specialist' THEN 199900
      ELSE NULL
    END;

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


-- These two functions are redefined by the immediately preceding work-timer migrations;
-- harden their final definitions here, after those replacements have run.
alter function public.srk_customer_respond_work_start(uuid,text) set search_path = '';
alter function public.srk_customer_respond_work_completion(uuid,text,text) set search_path = '';

-- Customer-safe work timeline. Expose only event label, actor role and time;
-- never return old_state/new_state JSON or internal event payloads.
create or replace function public.srk_customer_get_my_booking_work_timeline(
  p_booking_id uuid
)
returns table(event_type text,actor_role text,occurred_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid:=auth.uid();
begin
  if v_uid is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000';
  end if;
  if p_booking_id is null or not exists(
    select 1 from public.service_bookings b
     where b.id=p_booking_id and b.customer_user_id=v_uid
  ) then
    raise exception 'BOOKING_NOT_AVAILABLE' using errcode='42501';
  end if;

  return query
    select
      case
        when e.event_type='work_completion_approved'
             and exists(select 1 from public.srk_admin_users a where a.user_id=e.actor_user_id)
          then 'work_completion_admin_approved'
        when e.event_type='work_completion_approved'
             and e.actor_user_id=v_uid
          then 'work_completion_customer_approved'
        else e.event_type
      end::text,
      case
        when e.actor_user_id=v_uid then 'customer'
        when exists(select 1 from public.srk_admin_users a where a.user_id=e.actor_user_id) then 'admin'
        when exists(select 1 from public.electrician_profiles p
          where p.auth_user_id=e.actor_user_id or p.user_id=e.actor_user_id) then 'electrician'
        else 'system'
      end::text,
      e.created_at
    from public.srk_booking_work_events e
   where e.booking_id=p_booking_id
   order by e.created_at asc,e.id asc
   limit 200;
end;
$function$;

revoke all on function public.srk_customer_get_my_booking_work_timeline(uuid) from public,anon;
grant execute on function public.srk_customer_get_my_booking_work_timeline(uuid) to authenticated;

comment on function public.srk_customer_get_my_booking_work_timeline(uuid) is
  'Returns customer-owned work event labels, actor roles and timestamps only; excludes private event snapshots.';
