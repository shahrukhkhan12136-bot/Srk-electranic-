-- Draft and scheduled workflow for the immutable Rate Catalogue.
-- Source-only migration. Never apply to a hosted/live database without explicit approval.
BEGIN;
CREATE TABLE IF NOT EXISTS public.srk_rate_catalogue_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rates jsonb NOT NULL CHECK (jsonb_typeof(rates)='object'),
  effective_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','scheduled','published')),
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 5 AND 500),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  updated_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  published_rate_version_id uuid REFERENCES public.srk_rate_catalogue_versions(id) ON DELETE RESTRICT,
  CHECK ((status='published' AND published_rate_version_id IS NOT NULL)
      OR (status<>'published' AND published_rate_version_id IS NULL))
);
CREATE INDEX IF NOT EXISTS srk_rate_catalogue_drafts_admin_queue_idx
  ON public.srk_rate_catalogue_drafts(status,effective_at,updated_at DESC);
ALTER TABLE public.srk_rate_catalogue_drafts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_rate_catalogue_drafts FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.srk_guard_rate_catalogue_draft_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
BEGIN
  IF TG_OP='DELETE' AND OLD.status='published' THEN
    RAISE EXCEPTION 'PUBLISHED_RATE_DRAFT_IS_IMMUTABLE' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND OLD.status='published' THEN
    RAISE EXCEPTION 'PUBLISHED_RATE_DRAFT_IS_IMMUTABLE' USING ERRCODE='42501';
  END IF;
  RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END;
$fn$;
REVOKE ALL ON FUNCTION public.srk_guard_rate_catalogue_draft_mutation() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_rate_catalogue_draft_guard ON public.srk_rate_catalogue_drafts;
CREATE TRIGGER srk_rate_catalogue_draft_guard
BEFORE UPDATE OR DELETE ON public.srk_rate_catalogue_drafts
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_rate_catalogue_draft_mutation();
CREATE OR REPLACE FUNCTION public.srk_admin_save_rate_catalogue_draft(
  p_rates jsonb, p_effective_at timestamptz, p_reason text, p_draft_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE
  v_actor uuid:=auth.uid();
  v_id uuid:=coalesce(p_draft_id,gen_random_uuid());
  v_keys text[];
  v_key text;
  v_amount bigint;
  v_status text;
BEGIN
  IF v_actor IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'MAIN_ADMIN_ONLY' USING ERRCODE='42501';
  END IF;
  IF p_effective_at IS NULL OR p_effective_at<now()-interval '1 minute'
     OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500
     OR jsonb_typeof(p_rates)<>'object' THEN
    RAISE EXCEPTION 'INVALID_DRAFT_INPUT' USING ERRCODE='22023';
  END IF;
  SELECT array_agg(key ORDER BY key) INTO v_keys FROM jsonb_object_keys(p_rates) AS x(key);
  IF v_keys IS DISTINCT FROM ARRAY[
    'electrical_assistant','expert_electrician','premium_electrical_specialist','skilled_electrician'
  ]::text[] THEN RAISE EXCEPTION 'EXACTLY_FOUR_RATE_TIERS_REQUIRED'; END IF;
  FOREACH v_key IN ARRAY v_keys LOOP
    IF p_rates->>v_key IS NULL OR (p_rates->>v_key) !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'RATE_MUST_BE_INTEGER_PAISE: %',v_key;
    END IF;
    v_amount:=(p_rates->>v_key)::bigint;
    IF v_amount<1 OR v_amount>9000000000000000 THEN
      RAISE EXCEPTION 'RATE_OUT_OF_RANGE: %',v_key;
    END IF;
  END LOOP;
  v_status:=CASE WHEN p_effective_at>now() THEN 'scheduled' ELSE 'draft' END;
  IF p_draft_id IS NULL THEN
    INSERT INTO public.srk_rate_catalogue_drafts(id,rates,effective_at,status,reason,created_by,updated_by)
    VALUES(v_id,p_rates,p_effective_at,v_status,btrim(p_reason),v_actor,v_actor);
  ELSE
    UPDATE public.srk_rate_catalogue_drafts
       SET rates=p_rates,effective_at=p_effective_at,status=v_status,reason=btrim(p_reason),
           updated_by=v_actor,updated_at=now()
     WHERE id=v_id AND status IN ('draft','scheduled');
    IF NOT FOUND THEN RAISE EXCEPTION 'EDITABLE_RATE_DRAFT_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  END IF;
  RETURN jsonb_build_object('success',true,'draft_id',v_id,'status',v_status,'effective_at',p_effective_at);
END;
$fn$;
CREATE OR REPLACE FUNCTION public.srk_admin_list_rate_catalogue_drafts(p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'MAIN_ADMIN_ONLY' USING ERRCODE='42501';
  END IF;
  IF p_limit IS NULL OR p_limit<1 OR p_limit>100 THEN
    RAISE EXCEPTION 'INVALID_PAGE_LIMIT' USING ERRCODE='22023';
  END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.updated_at DESC),'[]'::jsonb)
    INTO v_result
  FROM (
    SELECT id,rates,effective_at,status,reason,created_at,updated_at,created_by,updated_by
    FROM public.srk_rate_catalogue_drafts
    WHERE status IN ('draft','scheduled')
    ORDER BY updated_at DESC,id
    LIMIT p_limit
  ) q;
  RETURN v_result;
END;
$fn$;
CREATE OR REPLACE FUNCTION public.srk_admin_publish_rate_catalogue_draft(
  p_draft_id uuid, p_expected_current_version_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE v_draft public.srk_rate_catalogue_drafts%rowtype; v_result jsonb; v_version uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'MAIN_ADMIN_ONLY' USING ERRCODE='42501';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('srk-rate-catalogue-publish',0));
  SELECT * INTO v_draft FROM public.srk_rate_catalogue_drafts
   WHERE id=p_draft_id AND status IN ('draft','scheduled') FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PUBLISHABLE_RATE_DRAFT_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  v_result:=public.srk_admin_publish_rate_catalogue(
    v_draft.rates,v_draft.effective_at,p_expected_current_version_id,v_draft.reason
  );
  v_version:=(v_result->>'rate_version_id')::uuid;
  UPDATE public.srk_rate_catalogue_drafts
     SET status='published',published_rate_version_id=v_version,updated_by=auth.uid(),updated_at=now()
   WHERE id=p_draft_id;
  RETURN jsonb_build_object('success',true,'draft_id',p_draft_id,
    'status','published','rate_version_id',v_version,'effective_at',v_draft.effective_at);
END;
$fn$;
REVOKE ALL ON FUNCTION public.srk_admin_save_rate_catalogue_draft(jsonb,timestamptz,text,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_admin_list_rate_catalogue_drafts(integer) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_admin_publish_rate_catalogue_draft(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_save_rate_catalogue_draft(jsonb,timestamptz,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_rate_catalogue_drafts(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_admin_publish_rate_catalogue_draft(uuid,uuid) TO authenticated;
COMMIT;
