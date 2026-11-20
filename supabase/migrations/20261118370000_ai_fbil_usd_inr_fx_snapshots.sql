-- Store verified FBIL USD/INR reference rates and reconcile Gateway USD costs to INR.
-- No rate is hardcoded and no live source is fetched by this migration.
BEGIN;

CREATE TABLE IF NOT EXISTS public.srk_ai_usd_inr_reference_rates (
  rate_date date PRIMARY KEY,
  usd_inr_rate numeric(18,8) NOT NULL CHECK (usd_inr_rate>0 AND usd_inr_rate<=1000),
  source_key text NOT NULL CHECK (source_key='fbil_usd_inr_reference_rate'),
  source_url text NOT NULL CHECK (
    length(source_url)<=2048 AND
    source_url ~* '^https://(www\.)?fbil\.org\.in(/|#|\?|$)'
  ),
  published_at timestamptz NOT NULL,
  retrieved_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT srk_ai_fx_rate_date_matches_publication CHECK (
    rate_date=(published_at AT TIME ZONE 'Asia/Kolkata')::date
  ),
  CONSTRAINT srk_ai_fx_retrieval_after_publication CHECK (
    retrieved_at>=published_at
  )
);

ALTER TABLE public.srk_ai_usd_inr_reference_rates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_ai_usd_inr_reference_rates FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.srk_reject_ai_fx_rate_mutation()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=''
AS $function$
BEGIN
  RAISE EXCEPTION 'AI_FX_REFERENCE_RATES_ARE_APPEND_ONLY' USING ERRCODE='55000';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_reject_ai_fx_rate_mutation() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER srk_ai_fx_reference_rates_append_only
  BEFORE UPDATE OR DELETE ON public.srk_ai_usd_inr_reference_rates
  FOR EACH ROW EXECUTE FUNCTION public.srk_reject_ai_fx_rate_mutation();

CREATE OR REPLACE FUNCTION public.srk_ai_record_fbil_usd_inr_rate(
  p_rate_date date,
  p_usd_inr_rate numeric,
  p_source_url text,
  p_published_at timestamptz,
  p_retrieved_at timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path='pg_catalog','public','pg_temp'
AS $function$
DECLARE v_existing public.srk_ai_usd_inr_reference_rates%ROWTYPE;
DECLARE v_inserted integer;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_rate_date IS NULL OR p_rate_date>(clock_timestamp() AT TIME ZONE 'Asia/Kolkata')::date
     OR p_usd_inr_rate IS NULL OR p_usd_inr_rate<=0 OR p_usd_inr_rate>1000
     OR p_source_url IS NULL OR length(p_source_url)>2048
     OR p_source_url !~* '^https://(www\.)?fbil\.org\.in(/|#|\?|$)'
     OR p_published_at IS NULL OR p_retrieved_at IS NULL
     OR (p_published_at AT TIME ZONE 'Asia/Kolkata')::date IS DISTINCT FROM p_rate_date
     OR p_retrieved_at<p_published_at
     OR p_retrieved_at>clock_timestamp()+interval '5 minutes' THEN
    RAISE EXCEPTION 'AI_INVALID_FBIL_FX_RATE' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.srk_ai_usd_inr_reference_rates(
    rate_date,usd_inr_rate,source_key,source_url,published_at,retrieved_at
  ) VALUES (
    p_rate_date,p_usd_inr_rate,'fbil_usd_inr_reference_rate',
    p_source_url,p_published_at,p_retrieved_at
  ) ON CONFLICT (rate_date) DO NOTHING;
  GET DIAGNOSTICS v_inserted=ROW_COUNT;

  IF v_inserted=1 THEN
    RETURN jsonb_build_object('state','recorded');
  END IF;

  SELECT * INTO v_existing FROM public.srk_ai_usd_inr_reference_rates
  WHERE rate_date=p_rate_date;
  IF v_existing.usd_inr_rate=p_usd_inr_rate
     AND v_existing.source_url=p_source_url
     AND v_existing.published_at=p_published_at THEN
    RETURN jsonb_build_object('state','already_recorded');
  END IF;
  RETURN jsonb_build_object('state','conflict');
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_ai_record_fbil_usd_inr_rate(date,numeric,text,timestamptz,timestamptz)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_record_fbil_usd_inr_rate(date,numeric,text,timestamptz,timestamptz)
  TO service_role;

ALTER TABLE public.srk_ai_generation_cost_jobs
  ADD COLUMN IF NOT EXISTS fx_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS cost_inr numeric(24,10),
  ADD COLUMN IF NOT EXISTS fx_rate_date date,
  ADD COLUMN IF NOT EXISTS usd_inr_rate numeric(18,8),
  ADD COLUMN IF NOT EXISTS fx_source_url text,
  ADD COLUMN IF NOT EXISTS fx_retrieved_at timestamptz;

UPDATE public.srk_ai_generation_cost_jobs
SET fx_status='unavailable'
WHERE status='unavailable' AND fx_status='pending';

ALTER TABLE public.srk_ai_generation_cost_jobs
  ADD CONSTRAINT srk_ai_generation_cost_jobs_fx_status_check
    CHECK (fx_status IN ('pending','reported','unavailable')),
  ADD CONSTRAINT srk_ai_generation_cost_jobs_fx_values_check CHECK (
    (fx_status='pending' AND cost_inr IS NULL AND fx_rate_date IS NULL
      AND usd_inr_rate IS NULL AND fx_source_url IS NULL AND fx_retrieved_at IS NULL)
    OR (fx_status='reported' AND status='reported' AND cost_inr IS NOT NULL
      AND cost_inr>=0 AND fx_rate_date IS NOT NULL AND usd_inr_rate IS NOT NULL
      AND usd_inr_rate>0 AND fx_source_url IS NOT NULL AND fx_retrieved_at IS NOT NULL)
    OR (fx_status='unavailable' AND cost_inr IS NULL AND fx_rate_date IS NULL
      AND usd_inr_rate IS NULL AND fx_source_url IS NULL AND fx_retrieved_at IS NULL)
  );

CREATE INDEX IF NOT EXISTS srk_ai_generation_cost_fx_pending_idx
  ON public.srk_ai_generation_cost_jobs(generation_created_at,attempt_id)
  WHERE status='reported' AND fx_status='pending';

CREATE OR REPLACE FUNCTION public.srk_apply_ai_generation_cost_fx(p_limit integer DEFAULT 20)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path='pg_catalog','public','pg_temp'
AS $function$
DECLARE v_count integer;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;

  WITH picked AS (
    SELECT j.attempt_id,r.rate_date,r.usd_inr_rate,r.source_url,r.retrieved_at
    FROM public.srk_ai_generation_cost_jobs j
    JOIN LATERAL (
      SELECT fx.rate_date,fx.usd_inr_rate,fx.source_url,fx.retrieved_at
      FROM public.srk_ai_usd_inr_reference_rates fx
      WHERE fx.published_at<=j.generation_created_at
      ORDER BY fx.published_at DESC,fx.rate_date DESC
      LIMIT 1
    ) r ON true
    WHERE j.status='reported' AND j.fx_status='pending'
      AND j.generation_created_at IS NOT NULL
    ORDER BY j.generation_created_at,j.attempt_id
    FOR UPDATE OF j SKIP LOCKED
    LIMIT greatest(1,least(coalesce(p_limit,20),100))
  ), updated AS (
    UPDATE public.srk_ai_generation_cost_jobs j
    SET fx_status='reported',
        cost_inr=round(j.cost_usd*p.usd_inr_rate,10),
        fx_rate_date=p.rate_date,usd_inr_rate=p.usd_inr_rate,
        fx_source_url=p.source_url,fx_retrieved_at=p.retrieved_at,
        updated_at=clock_timestamp()
    FROM picked p
    WHERE p.attempt_id=j.attempt_id AND j.fx_status='pending'
    RETURNING j.attempt_id
  )
  SELECT count(*)::integer INTO v_count FROM updated;
  RETURN coalesce(v_count,0);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_apply_ai_generation_cost_fx(integer)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_apply_ai_generation_cost_fx(integer)
  TO service_role;

COMMIT;
