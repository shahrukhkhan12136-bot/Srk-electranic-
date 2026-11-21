-- Fencing tokens prevent a worker whose lease expired from overwriting
-- the result of a newer worker that reclaimed the same outbox/device row.
DO $preflight$
BEGIN
  IF to_regclass('srk_private.srk_push_delivery_outbox') IS NULL
     OR to_regclass('srk_private.srk_push_subscription_deliveries') IS NULL THEN
    RAISE EXCEPTION 'Lease fencing prerequisites missing';
  END IF;
END;
$preflight$;

DROP FUNCTION IF EXISTS public.srk_finish_push_delivery_outbox(uuid,boolean,text);
CREATE FUNCTION public.srk_finish_push_delivery_outbox(
  p_outbox_id uuid,p_attempt_count integer,p_success boolean,p_error text DEFAULT NULL
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','srk_private','pg_temp'
AS $function$
DECLARE v_row srk_private.srk_push_delivery_outbox%ROWTYPE;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_row FROM srk_private.srk_push_delivery_outbox
    WHERE id=p_outbox_id FOR UPDATE;
  IF NOT FOUND OR v_row.delivery_status IN ('delivered','dead')
     OR v_row.attempt_count IS DISTINCT FROM p_attempt_count
     OR v_row.delivery_status <> 'processing' THEN
    RETURN false;
  END IF;
  IF p_success THEN
    UPDATE srk_private.srk_push_delivery_outbox
      SET delivery_status='delivered',delivered_at=clock_timestamp(),
          locked_until=NULL,last_error=NULL,updated_at=clock_timestamp()
      WHERE id=p_outbox_id AND attempt_count=p_attempt_count AND delivery_status='processing';
  ELSIF v_row.attempt_count>=8 THEN
    UPDATE srk_private.srk_push_delivery_outbox
      SET delivery_status='dead',locked_until=NULL,
          last_error=left(coalesce(p_error,'Push delivery failed'),500),updated_at=clock_timestamp()
      WHERE id=p_outbox_id AND attempt_count=p_attempt_count AND delivery_status='processing';
  ELSE
    UPDATE srk_private.srk_push_delivery_outbox
      SET delivery_status='pending',locked_until=NULL,
          next_attempt_at=clock_timestamp()+make_interval(secs=>least(3600,30*(2^least(v_row.attempt_count,7))::integer)),
          last_error=left(coalesce(p_error,'Push delivery failed'),500),updated_at=clock_timestamp()
      WHERE id=p_outbox_id AND attempt_count=p_attempt_count AND delivery_status='processing';
  END IF;
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text) TO service_role;

DROP FUNCTION IF EXISTS public.srk_finish_push_subscription_delivery(uuid,boolean,text);
CREATE FUNCTION public.srk_finish_push_subscription_delivery(
  p_delivery_id uuid,p_attempt_count integer,p_success boolean,p_error text DEFAULT NULL
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','srk_private','pg_temp'
AS $function$
DECLARE v_row srk_private.srk_push_subscription_deliveries%ROWTYPE;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_row FROM srk_private.srk_push_subscription_deliveries
    WHERE id=p_delivery_id FOR UPDATE;
  IF NOT FOUND OR v_row.delivery_status IN ('delivered','dead')
     OR v_row.attempt_count IS DISTINCT FROM p_attempt_count
     OR v_row.delivery_status <> 'processing' THEN
    RETURN false;
  END IF;
  IF p_success THEN
    UPDATE srk_private.srk_push_subscription_deliveries
      SET delivery_status='delivered',delivered_at=clock_timestamp(),
          locked_until=NULL,last_error=NULL,updated_at=clock_timestamp()
      WHERE id=p_delivery_id AND attempt_count=p_attempt_count AND delivery_status='processing';
  ELSIF v_row.attempt_count>=5 THEN
    UPDATE srk_private.srk_push_subscription_deliveries
      SET delivery_status='dead',locked_until=NULL,
          last_error=left(coalesce(p_error,'Push delivery failed'),500),updated_at=clock_timestamp()
      WHERE id=p_delivery_id AND attempt_count=p_attempt_count AND delivery_status='processing';
  ELSE
    UPDATE srk_private.srk_push_subscription_deliveries
      SET delivery_status='pending',locked_until=NULL,
          next_attempt_at=clock_timestamp()+make_interval(secs=>least(1800,30*(2^least(v_row.attempt_count,6))::integer)),
          last_error=left(coalesce(p_error,'Push delivery failed'),500),updated_at=clock_timestamp()
      WHERE id=p_delivery_id AND attempt_count=p_attempt_count AND delivery_status='processing';
  END IF;
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text) TO service_role;
