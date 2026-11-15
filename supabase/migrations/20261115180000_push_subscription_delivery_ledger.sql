-- Per-subscription idempotent delivery state. This is at-least-once at the
-- transport boundary (a provider timeout can be ambiguous), but successful
-- subscriptions are never intentionally resent on an outbox retry.

CREATE TABLE IF NOT EXISTS srk_private.srk_push_subscription_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outbox_id uuid NOT NULL REFERENCES srk_private.srk_push_delivery_outbox(id) ON DELETE CASCADE,
  subscription_id uuid NOT NULL REFERENCES public.srk_push_subscriptions(id) ON DELETE CASCADE,
  delivery_status text NOT NULL DEFAULT 'pending'
    CHECK (delivery_status IN ('pending','processing','delivered','dead')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  locked_until timestamptz,
  last_error text,
  delivered_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(outbox_id,subscription_id)
);
REVOKE ALL ON TABLE srk_private.srk_push_subscription_deliveries FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS srk_push_subscription_deliveries_due_idx
  ON srk_private.srk_push_subscription_deliveries(outbox_id,next_attempt_at)
  WHERE delivery_status IN ('pending','processing');

CREATE OR REPLACE FUNCTION public.srk_claim_push_subscription_deliveries(
  p_outbox_id uuid, p_user_id uuid, p_limit integer DEFAULT 50
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','srk_private','pg_temp'
AS $function$
DECLARE v_targets jsonb; v_complete boolean;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  IF p_outbox_id IS NULL OR p_user_id IS NULL THEN
    RAISE EXCEPTION 'Outbox and user IDs required' USING ERRCODE='22023';
  END IF;

  INSERT INTO srk_private.srk_push_subscription_deliveries(outbox_id,subscription_id)
  SELECT p_outbox_id,s.id FROM public.srk_push_subscriptions s
  WHERE s.user_id=p_user_id
  ON CONFLICT(outbox_id,subscription_id) DO NOTHING;

  WITH picked AS (
    SELECT d.id FROM srk_private.srk_push_subscription_deliveries d
    WHERE d.outbox_id=p_outbox_id AND d.attempt_count<5
      AND d.next_attempt_at<=clock_timestamp()
      AND (d.delivery_status='pending'
        OR (d.delivery_status='processing' AND d.locked_until<clock_timestamp()))
    ORDER BY d.updated_at
    FOR UPDATE SKIP LOCKED
    LIMIT greatest(1,least(coalesce(p_limit,50),100))
  ), claimed AS (
    UPDATE srk_private.srk_push_subscription_deliveries d
      SET delivery_status='processing',attempt_count=d.attempt_count+1,
          locked_until=clock_timestamp()+interval '2 minutes',
          updated_at=clock_timestamp()
    FROM picked WHERE d.id=picked.id
    RETURNING d.id,d.subscription_id,d.attempt_count
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'delivery_id',c.id,'subscription_id',s.id,'endpoint',s.endpoint,
      'p256dh',s.p256dh,'auth',s.auth,'attempt_count',c.attempt_count
    )),'[]'::jsonb)
  INTO v_targets
  FROM claimed c JOIN public.srk_push_subscriptions s ON s.id=c.subscription_id;

  SELECT NOT EXISTS(
    SELECT 1 FROM srk_private.srk_push_subscription_deliveries d
    WHERE d.outbox_id=p_outbox_id AND d.delivery_status IN ('pending','processing')
  ) INTO v_complete;
  RETURN jsonb_build_object('targets',v_targets,'complete',v_complete);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_claim_push_subscription_deliveries(uuid,uuid,integer)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_claim_push_subscription_deliveries(uuid,uuid,integer)
  TO service_role;

CREATE OR REPLACE FUNCTION public.srk_finish_push_subscription_delivery(
  p_delivery_id uuid,p_success boolean,p_error text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','srk_private','pg_temp'
AS $function$
DECLARE v_row srk_private.srk_push_subscription_deliveries%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_row FROM srk_private.srk_push_subscription_deliveries
    WHERE id=p_delivery_id FOR UPDATE;
  IF NOT FOUND OR v_row.delivery_status IN ('delivered','dead') THEN RETURN; END IF;
  IF p_success THEN
    UPDATE srk_private.srk_push_subscription_deliveries
      SET delivery_status='delivered',delivered_at=clock_timestamp(),
          locked_until=NULL,last_error=NULL,updated_at=clock_timestamp()
      WHERE id=p_delivery_id;
  ELSIF v_row.attempt_count>=5 THEN
    UPDATE srk_private.srk_push_subscription_deliveries
      SET delivery_status='dead',locked_until=NULL,
          last_error=left(coalesce(p_error,'Push delivery failed'),500),
          updated_at=clock_timestamp()
      WHERE id=p_delivery_id;
  ELSE
    UPDATE srk_private.srk_push_subscription_deliveries
      SET delivery_status='pending',locked_until=NULL,
          next_attempt_at=clock_timestamp()+make_interval(secs=>least(1800,30*(2^least(v_row.attempt_count,6))::integer)),
          last_error=left(coalesce(p_error,'Push delivery failed'),500),
          updated_at=clock_timestamp()
      WHERE id=p_delivery_id;
  END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_finish_push_subscription_delivery(uuid,boolean,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_finish_push_subscription_delivery(uuid,boolean,text)
  TO service_role;
