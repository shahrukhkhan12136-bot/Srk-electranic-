-- Claim, reconcile, and safely retry per-generation AI Gateway costs.
-- This migration is source-only until explicitly applied to the hosted database.
BEGIN;

ALTER TABLE public.srk_ai_generation_cost_jobs
  ADD COLUMN IF NOT EXISTS locked_until timestamptz,
  ADD COLUMN IF NOT EXISTS last_error text,
  ADD COLUMN IF NOT EXISTS generation_created_at timestamptz;

ALTER TABLE public.srk_ai_generation_cost_jobs
  DROP CONSTRAINT IF EXISTS srk_ai_generation_cost_jobs_generation_id_safe_check;
ALTER TABLE public.srk_ai_generation_cost_jobs
  ADD CONSTRAINT srk_ai_generation_cost_jobs_generation_id_safe_check
    CHECK (generation_id IS NULL OR generation_id ~ '^gen_[A-Za-z0-9._:-]{1,195}$');

ALTER TABLE public.srk_ai_generation_cost_jobs
  DROP CONSTRAINT IF EXISTS srk_ai_generation_cost_jobs_status_check;
ALTER TABLE public.srk_ai_generation_cost_jobs
  DROP CONSTRAINT IF EXISTS srk_ai_generation_cost_values_check;

ALTER TABLE public.srk_ai_generation_cost_jobs
  ADD CONSTRAINT srk_ai_generation_cost_jobs_status_check
    CHECK (status IN ('pending','processing','unavailable','reported')),
  ADD CONSTRAINT srk_ai_generation_cost_values_check CHECK (
    (status IN ('pending','processing')
      AND generation_id IS NOT NULL AND cost_usd IS NULL AND generation_created_at IS NULL)
    OR (status='unavailable' AND cost_usd IS NULL)
    OR (status='reported' AND generation_id IS NOT NULL
      AND cost_usd IS NOT NULL AND cost_usd >= 0 AND generation_created_at IS NOT NULL)
  );

CREATE OR REPLACE FUNCTION public.srk_claim_ai_generation_cost_jobs(p_limit integer DEFAULT 5)
RETURNS TABLE(attempt_id uuid,generation_id text,model_key text,attempt_count integer)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path='pg_catalog','public','pg_temp'
AS $function$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;

  UPDATE public.srk_ai_generation_cost_jobs j
  SET status='unavailable',locked_until=NULL,next_attempt_at=NULL,
      last_error='Reconciliation lease expired after maximum attempts',
      updated_at=clock_timestamp()
  WHERE j.status='processing' AND j.attempt_count>=20
    AND (j.locked_until IS NULL OR j.locked_until<=clock_timestamp());

  RETURN QUERY
  WITH picked AS (
    SELECT j.attempt_id
    FROM public.srk_ai_generation_cost_jobs j
    WHERE j.attempt_count<20 AND (
      (j.status='pending' AND coalesce(j.next_attempt_at,'-infinity'::timestamptz)<=clock_timestamp())
      OR (j.status='processing' AND (j.locked_until IS NULL OR j.locked_until<=clock_timestamp()))
    )
    ORDER BY coalesce(j.next_attempt_at,j.created_at),j.created_at,j.attempt_id
    FOR UPDATE SKIP LOCKED
    LIMIT greatest(1,least(coalesce(p_limit,5),20))
  ), claimed AS (
    UPDATE public.srk_ai_generation_cost_jobs j
    SET status='processing',attempt_count=j.attempt_count+1,
        locked_until=clock_timestamp()+interval '2 minutes',
        last_checked_at=clock_timestamp(),updated_at=clock_timestamp()
    FROM picked p WHERE p.attempt_id=j.attempt_id
    RETURNING j.attempt_id,j.generation_id,j.model_key,j.attempt_count
  )
  SELECT c.attempt_id,c.generation_id,c.model_key,c.attempt_count FROM claimed c;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_finish_ai_generation_cost_job(
  p_attempt_id uuid,
  p_attempt_count integer,
  p_success boolean,
  p_cost_usd numeric DEFAULT NULL,
  p_cost_source text DEFAULT NULL,
  p_generation_created_at timestamptz DEFAULT NULL,
  p_error text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path='pg_catalog','public','pg_temp'
AS $function$
DECLARE v_job public.srk_ai_generation_cost_jobs%ROWTYPE;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_attempt_id IS NULL OR p_attempt_count IS NULL OR p_success IS NULL THEN
    RAISE EXCEPTION 'AI_INVALID_COST_JOB_FINISH' USING ERRCODE='22023';
  END IF;
  IF p_success AND (p_cost_usd IS NULL OR p_cost_usd<0 OR
      p_cost_source IS DISTINCT FROM 'vercel_ai_gateway_generation_api' OR
      p_generation_created_at IS NULL) THEN
    RAISE EXCEPTION 'AI_INVALID_REPORTED_COST' USING ERRCODE='22023';
  END IF;
  IF NOT p_success AND (p_cost_usd IS NOT NULL OR p_generation_created_at IS NOT NULL) THEN
    RAISE EXCEPTION 'AI_FAILED_COST_MUST_BE_NULL' USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_job
  FROM public.srk_ai_generation_cost_jobs
  WHERE attempt_id=p_attempt_id FOR UPDATE;

  IF NOT FOUND OR v_job.status<>'processing'
     OR v_job.attempt_count IS DISTINCT FROM p_attempt_count
     OR v_job.locked_until IS NULL OR v_job.locked_until<=clock_timestamp() THEN
    RETURN false;
  END IF;

  IF p_success THEN
    UPDATE public.srk_ai_generation_cost_jobs
    SET status='reported',cost_usd=p_cost_usd,cost_source=p_cost_source,
        generation_created_at=p_generation_created_at,locked_until=NULL,
        next_attempt_at=NULL,last_error=NULL,last_checked_at=clock_timestamp(),
        updated_at=clock_timestamp()
    WHERE attempt_id=p_attempt_id;
  ELSIF v_job.attempt_count>=20 THEN
    UPDATE public.srk_ai_generation_cost_jobs
    SET status='unavailable',locked_until=NULL,next_attempt_at=NULL,
        last_error=left(coalesce(p_error,'Gateway generation cost unavailable'),500),
        last_checked_at=clock_timestamp(),updated_at=clock_timestamp()
    WHERE attempt_id=p_attempt_id;
  ELSE
    UPDATE public.srk_ai_generation_cost_jobs
    SET status='pending',locked_until=NULL,
        next_attempt_at=clock_timestamp()+make_interval(
          secs=>least(3600,30*(2^least(v_job.attempt_count-1,7))::integer)),
        last_error=left(coalesce(p_error,'Gateway generation cost not ready'),500),
        last_checked_at=clock_timestamp(),updated_at=clock_timestamp()
    WHERE attempt_id=p_attempt_id;
  END IF;
  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_claim_ai_generation_cost_jobs(integer)
  FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_finish_ai_generation_cost_job(uuid,integer,boolean,numeric,text,timestamptz,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_claim_ai_generation_cost_jobs(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_finish_ai_generation_cost_job(uuid,integer,boolean,numeric,text,timestamptz,text)
  TO service_role;

COMMIT;
