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
