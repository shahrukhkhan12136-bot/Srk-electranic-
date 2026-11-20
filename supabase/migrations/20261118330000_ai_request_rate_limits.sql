-- Atomic per-user AI request throttling and daily spend guardrail foundation.
-- Counts only newly reserved idempotent requests; provider retries/replays do not consume another slot.

BEGIN;

CREATE TABLE IF NOT EXISTS public.srk_ai_request_limits (
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  module_key text NOT NULL CHECK (module_key IN ('customer_support','booking_assistant','electrician_assistant')),
  window_started_at timestamptz NOT NULL,
  requests_in_window bigint NOT NULL CHECK (requests_in_window >= 0),
  daily_window_started_at timestamptz NOT NULL,
  requests_today bigint NOT NULL CHECK (requests_today >= 0),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY(actor_user_id,module_key)
);
ALTER TABLE public.srk_ai_request_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_ai_request_limits FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE public.srk_ai_request_limits TO service_role;

CREATE OR REPLACE FUNCTION public.srk_ai_reserve_request_capacity(
  p_actor_user_id uuid,
  p_module_key text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_now timestamptz := clock_timestamp();
  v_row public.srk_ai_request_limits%ROWTYPE;
  v_retry integer;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_actor_user_id IS NULL OR p_module_key NOT IN ('customer_support','booking_assistant','electrician_assistant') THEN
    RAISE EXCEPTION 'AI_INVALID_RATE_LIMIT_ARGUMENT' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.srk_ai_request_limits(
    actor_user_id,module_key,window_started_at,requests_in_window,
    daily_window_started_at,requests_today,updated_at
  ) VALUES (p_actor_user_id,p_module_key,v_now,1,date_trunc('day',v_now),1,v_now)
  ON CONFLICT(actor_user_id,module_key) DO UPDATE SET
    window_started_at=CASE WHEN public.srk_ai_request_limits.window_started_at <= v_now-interval '10 minutes' THEN v_now ELSE public.srk_ai_request_limits.window_started_at END,
    requests_in_window=CASE WHEN public.srk_ai_request_limits.window_started_at <= v_now-interval '10 minutes' THEN 1 ELSE LEAST(public.srk_ai_request_limits.requests_in_window+1,2147483647) END,
    daily_window_started_at=CASE WHEN public.srk_ai_request_limits.daily_window_started_at < date_trunc('day',v_now) THEN date_trunc('day',v_now) ELSE public.srk_ai_request_limits.daily_window_started_at END,
    requests_today=CASE WHEN public.srk_ai_request_limits.daily_window_started_at < date_trunc('day',v_now) THEN 1 ELSE LEAST(public.srk_ai_request_limits.requests_today+1,2147483647) END,
    updated_at=v_now
  RETURNING * INTO v_row;

  IF v_row.requests_today>100 THEN
    v_retry=GREATEST(1,CEIL(EXTRACT(EPOCH FROM (date_trunc('day',v_now)+interval '1 day'-v_now)))::integer);
    RETURN jsonb_build_object('state','rate_limited','scope','daily','retry_after_seconds',v_retry);
  END IF;
  IF v_row.requests_in_window>10 THEN
    v_retry=GREATEST(1,CEIL(EXTRACT(EPOCH FROM (v_row.window_started_at+interval '10 minutes'-v_now)))::integer);
    RETURN jsonb_build_object('state','rate_limited','scope','window','retry_after_seconds',v_retry);
  END IF;
  RETURN jsonb_build_object('state','allowed','remaining_window',10-v_row.requests_in_window,'remaining_today',100-v_row.requests_today);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_ai_reserve_request_capacity(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_reserve_request_capacity(uuid,text) TO service_role;

COMMIT;
