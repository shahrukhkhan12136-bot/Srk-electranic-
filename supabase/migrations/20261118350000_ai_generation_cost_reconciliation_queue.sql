-- Queue Gateway generation IDs for asynchronous, auditable cost reconciliation.
-- No provider calls are made by this migration or by the queue RPC.
BEGIN;

CREATE TABLE IF NOT EXISTS public.srk_ai_generation_cost_jobs (
  attempt_id uuid PRIMARY KEY REFERENCES public.srk_ai_usage_events(attempt_id) ON DELETE RESTRICT,
  generation_id text,
  provider_key text NOT NULL CHECK (provider_key='vercel_ai_gateway'),
  model_key text NOT NULL CHECK (length(btrim(model_key)) BETWEEN 1 AND 160),
  status text NOT NULL CHECK (status IN ('pending','unavailable')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count BETWEEN 0 AND 20),
  next_attempt_at timestamptz,
  last_checked_at timestamptz,
  cost_usd numeric(20,10),
  cost_source text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT srk_ai_generation_cost_values_check CHECK (
    (status='pending' AND generation_id IS NOT NULL AND cost_usd IS NULL)
    OR (status='unavailable' AND generation_id IS NULL AND cost_usd IS NULL)
    OR (status='reported' AND generation_id IS NOT NULL AND cost_usd >= 0)
  ),
  CONSTRAINT srk_ai_generation_id_safe_check CHECK (
    generation_id IS NULL OR generation_id ~ '^[A-Za-z0-9._:-]{1,200}$'
  )
);

CREATE INDEX IF NOT EXISTS srk_ai_generation_cost_due_idx
  ON public.srk_ai_generation_cost_jobs(next_attempt_at,created_at)
  WHERE status='pending';

ALTER TABLE public.srk_ai_generation_cost_jobs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_ai_generation_cost_jobs FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.srk_ai_queue_generation_cost_job(
  p_attempt_id uuid,
  p_generation_id text,
  p_provider_key text,
  p_model_key text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=''
AS $function$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_attempt_id IS NULL OR p_provider_key IS DISTINCT FROM 'vercel_ai_gateway' OR
     p_model_key IS NULL OR length(btrim(p_model_key)) NOT BETWEEN 1 AND 160 OR
     (p_generation_id IS NOT NULL AND p_generation_id !~ '^[A-Za-z0-9._:-]{1,200}$') THEN
    RAISE EXCEPTION 'AI_INVALID_GENERATION_COST_JOB' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.srk_ai_usage_events e WHERE e.attempt_id=p_attempt_id) THEN
    RETURN jsonb_build_object('state','usage_event_missing');
  END IF;
  INSERT INTO public.srk_ai_generation_cost_jobs(
    attempt_id,generation_id,provider_key,model_key,status,next_attempt_at
  ) VALUES (
    p_attempt_id,p_generation_id,p_provider_key,p_model_key,
    CASE WHEN p_generation_id IS NULL THEN 'unavailable' ELSE 'pending' END,
    CASE WHEN p_generation_id IS NULL THEN NULL ELSE clock_timestamp() END
  ) ON CONFLICT (attempt_id) DO NOTHING;
  RETURN jsonb_build_object('state','queued');
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_ai_queue_generation_cost_job(uuid,text,text,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_queue_generation_cost_job(uuid,text,text,text)
  TO service_role;

COMMIT;
