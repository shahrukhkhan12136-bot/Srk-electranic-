-- Durable, retryable push delivery outbox and least-privilege subscription grants.
-- Apply only after the feature-branch schema is reviewed in an isolated environment.

ALTER TABLE public.srk_push_subscriptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_push_subscriptions FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.srk_push_subscriptions TO authenticated;
DROP POLICY IF EXISTS srk_push_subscriptions_select_own ON public.srk_push_subscriptions;
DROP POLICY IF EXISTS srk_push_subscriptions_insert_own ON public.srk_push_subscriptions;
DROP POLICY IF EXISTS srk_push_subscriptions_update_own ON public.srk_push_subscriptions;
DROP POLICY IF EXISTS srk_push_subscriptions_delete_own ON public.srk_push_subscriptions;
CREATE POLICY srk_push_subscriptions_select_own ON public.srk_push_subscriptions
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));
CREATE POLICY srk_push_subscriptions_insert_own ON public.srk_push_subscriptions
  FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY srk_push_subscriptions_update_own ON public.srk_push_subscriptions
  FOR UPDATE TO authenticated USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY srk_push_subscriptions_delete_own ON public.srk_push_subscriptions
  FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()));

CREATE TABLE IF NOT EXISTS srk_private.srk_push_delivery_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id uuid NOT NULL UNIQUE REFERENCES public.job_offers(id) ON DELETE CASCADE,
  payload jsonb NOT NULL,
  delivery_status text NOT NULL DEFAULT 'pending'
    CHECK (delivery_status IN ('pending','processing','delivered','dead')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  locked_until timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  delivered_at timestamptz
);
REVOKE ALL ON TABLE srk_private.srk_push_delivery_outbox FROM PUBLIC, anon, authenticated;
CREATE INDEX IF NOT EXISTS srk_push_delivery_outbox_due_idx
  ON srk_private.srk_push_delivery_outbox(next_attempt_at, created_at)
  WHERE delivery_status IN ('pending','processing');

CREATE OR REPLACE FUNCTION private.srk_enqueue_job_offer_push()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','srk_private','pg_temp'
AS $function$
BEGIN
  IF NEW.status = 'offered' THEN
    INSERT INTO srk_private.srk_push_delivery_outbox(offer_id,payload)
    VALUES (NEW.id, jsonb_build_object(
      'type','INSERT','schema','public','table','job_offers',
      'record',jsonb_build_object('id',NEW.id,'booking_id',NEW.booking_id,
        'electrician_id',NEW.electrician_id,'status',NEW.status,'expires_at',NEW.expires_at),
      'old_record',null
    ))
    ON CONFLICT (offer_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.srk_enqueue_job_offer_push() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS trg_srk_enqueue_job_offer_push ON public.job_offers;
CREATE TRIGGER trg_srk_enqueue_job_offer_push
  AFTER INSERT ON public.job_offers
  FOR EACH ROW EXECUTE FUNCTION private.srk_enqueue_job_offer_push();

CREATE OR REPLACE FUNCTION public.srk_claim_push_delivery_outbox(p_limit integer DEFAULT 20)
RETURNS TABLE(outbox_id uuid, payload jsonb, attempt_count integer)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','srk_private','pg_temp'
AS $function$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  WITH picked AS (
    SELECT o.id FROM srk_private.srk_push_delivery_outbox o
    WHERE o.attempt_count < 8
      AND o.next_attempt_at <= clock_timestamp()
      AND (o.delivery_status='pending'
        OR (o.delivery_status='processing' AND o.locked_until < clock_timestamp()))
    ORDER BY o.created_at
    FOR UPDATE SKIP LOCKED
    LIMIT greatest(1,least(coalesce(p_limit,20),50))
  )
  UPDATE srk_private.srk_push_delivery_outbox o
    SET delivery_status='processing', attempt_count=o.attempt_count+1,
        locked_until=clock_timestamp()+interval '2 minutes',
        updated_at=clock_timestamp()
  FROM picked WHERE o.id=picked.id
  RETURNING o.id,o.payload,o.attempt_count;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_claim_push_delivery_outbox(integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_claim_push_delivery_outbox(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.srk_finish_push_delivery_outbox(
  p_outbox_id uuid, p_success boolean, p_error text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','srk_private','pg_temp'
AS $function$
DECLARE v_row srk_private.srk_push_delivery_outbox%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_row FROM srk_private.srk_push_delivery_outbox
    WHERE id=p_outbox_id FOR UPDATE;
  IF NOT FOUND OR v_row.delivery_status IN ('delivered','dead') THEN RETURN; END IF;
  IF p_success THEN
    UPDATE srk_private.srk_push_delivery_outbox
      SET delivery_status='delivered',delivered_at=clock_timestamp(),
          locked_until=NULL,last_error=NULL,updated_at=clock_timestamp()
      WHERE id=p_outbox_id;
  ELSIF v_row.attempt_count >= 8 THEN
    UPDATE srk_private.srk_push_delivery_outbox
      SET delivery_status='dead',locked_until=NULL,
          last_error=left(coalesce(p_error,'Push delivery failed'),500),
          updated_at=clock_timestamp()
      WHERE id=p_outbox_id;
  ELSE
    UPDATE srk_private.srk_push_delivery_outbox
      SET delivery_status='pending',locked_until=NULL,
          next_attempt_at=clock_timestamp() + make_interval(secs => least(3600,30 * (2 ^ least(v_row.attempt_count,7))::integer)),
          last_error=left(coalesce(p_error,'Push delivery failed'),500),
          updated_at=clock_timestamp()
      WHERE id=p_outbox_id;
  END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_finish_push_delivery_outbox(uuid,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_finish_push_delivery_outbox(uuid,boolean,text) TO service_role;
