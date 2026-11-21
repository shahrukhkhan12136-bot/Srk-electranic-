-- Read-only operational health summary for the scheduled push worker.
-- No payloads, subscription endpoints, user IDs or private error strings are exposed.
DO $preflight$
BEGIN
  IF to_regclass('srk_private.srk_push_delivery_outbox') IS NULL
     OR to_regclass('srk_private.srk_push_subscription_deliveries') IS NULL THEN
    RAISE EXCEPTION 'Push health prerequisite missing: outbox and subscription ledger migrations';
  END IF;
END;
$preflight$;

CREATE OR REPLACE FUNCTION public.srk_get_push_delivery_health()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','srk_private','pg_temp'
AS $function$
DECLARE
  v_outbox jsonb;
  v_devices jsonb;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;

  SELECT jsonb_build_object(
    'pending', count(*) FILTER (WHERE delivery_status='pending'),
    'processing', count(*) FILTER (WHERE delivery_status='processing'),
    'delivered', count(*) FILTER (WHERE delivery_status='delivered'),
    'dead', count(*) FILTER (WHERE delivery_status='dead'),
    'oldest_pending_at', min(created_at) FILTER (WHERE delivery_status='pending')
  ) INTO v_outbox
  FROM srk_private.srk_push_delivery_outbox;

  SELECT jsonb_build_object(
    'pending', count(*) FILTER (WHERE delivery_status='pending'),
    'processing', count(*) FILTER (WHERE delivery_status='processing'),
    'delivered', count(*) FILTER (WHERE delivery_status='delivered'),
    'dead', count(*) FILTER (WHERE delivery_status='dead'),
    'oldest_pending_at', min(updated_at) FILTER (WHERE delivery_status='pending')
  ) INTO v_devices
  FROM srk_private.srk_push_subscription_deliveries;

  RETURN jsonb_build_object('outbox',v_outbox,'devices',v_devices,'generated_at',clock_timestamp());
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_get_push_delivery_health() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_get_push_delivery_health() TO service_role;

-- Explicit operator recovery: requeue one identified dead outbox item only.
-- Already-delivered device rows remain delivered and are not resent.
CREATE OR REPLACE FUNCTION public.srk_retry_push_delivery_dead_letter(p_outbox_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','srk_private','pg_temp'
AS $function$
DECLARE
  v_status text;
  v_devices integer := 0;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  IF p_outbox_id IS NULL THEN
    RAISE EXCEPTION 'Outbox ID required' USING ERRCODE='22023';
  END IF;

  SELECT delivery_status INTO v_status
  FROM srk_private.srk_push_delivery_outbox
  WHERE id=p_outbox_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Outbox item not found' USING ERRCODE='P0002';
  END IF;
  IF v_status <> 'dead' THEN
    RAISE EXCEPTION 'Only dead outbox items can be manually recovered' USING ERRCODE='22023';
  END IF;

  UPDATE srk_private.srk_push_subscription_deliveries
    SET delivery_status='pending',attempt_count=0,next_attempt_at=clock_timestamp(),
        locked_until=NULL,last_error=NULL,updated_at=clock_timestamp()
    WHERE outbox_id=p_outbox_id AND delivery_status='dead';
  GET DIAGNOSTICS v_devices = ROW_COUNT;

  UPDATE srk_private.srk_push_delivery_outbox
    SET delivery_status='pending',attempt_count=0,next_attempt_at=clock_timestamp(),
        locked_until=NULL,last_error=NULL,updated_at=clock_timestamp()
    WHERE id=p_outbox_id;

  RETURN jsonb_build_object('requeued',true,'outbox_id',p_outbox_id,'device_rows_requeued',v_devices);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_retry_push_delivery_dead_letter(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_retry_push_delivery_dead_letter(uuid) TO service_role;
