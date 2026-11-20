-- Private, append-only token usage ledger for AI provider attempts.
-- Stores operational metadata and token counts only; never prompts or completions.

BEGIN;

CREATE TABLE IF NOT EXISTS public.srk_ai_usage_events (
  attempt_id uuid PRIMARY KEY,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  conversation_id uuid NOT NULL REFERENCES public.srk_ai_conversations(id) ON DELETE RESTRICT,
  request_id uuid NOT NULL,
  module_key text NOT NULL CHECK (module_key IN (
    'customer_support','booking_assistant','electrician_assistant'
  )),
  provider_key text NOT NULL CHECK (provider_key='vercel_ai_gateway'),
  model_key text NOT NULL CHECK (length(btrim(model_key)) BETWEEN 1 AND 160),
  usage_status text NOT NULL CHECK (usage_status IN ('reported','unavailable')),
  prompt_tokens integer,
  completion_tokens integer,
  total_tokens integer,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT srk_ai_usage_token_values_check CHECK (
    (usage_status='reported'
      AND prompt_tokens BETWEEN 0 AND 10000000
      AND completion_tokens BETWEEN 0 AND 10000000
      AND total_tokens BETWEEN 0 AND 20000000
      AND total_tokens >= prompt_tokens
      AND total_tokens >= completion_tokens)
    OR
    (usage_status='unavailable'
      AND prompt_tokens IS NULL
      AND completion_tokens IS NULL
      AND total_tokens IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS srk_ai_usage_actor_created_idx
  ON public.srk_ai_usage_events(actor_user_id,created_at DESC);
CREATE INDEX IF NOT EXISTS srk_ai_usage_model_created_idx
  ON public.srk_ai_usage_events(model_key,created_at DESC);

ALTER TABLE public.srk_ai_usage_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_ai_usage_events FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.srk_ai_record_usage_event(
  p_attempt_id uuid,
  p_actor_user_id uuid,
  p_conversation_id uuid,
  p_request_id uuid,
  p_provider_key text,
  p_model_key text,
  p_usage_available boolean,
  p_prompt_tokens integer DEFAULT NULL,
  p_completion_tokens integer DEFAULT NULL,
  p_total_tokens integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_module_key text;
  v_owner_user_id uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'AI_SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_attempt_id IS NULL OR p_actor_user_id IS NULL OR p_conversation_id IS NULL OR
     p_request_id IS NULL OR p_provider_key IS DISTINCT FROM 'vercel_ai_gateway' OR
     p_model_key IS NULL OR length(btrim(p_model_key)) NOT BETWEEN 1 AND 160 OR
     p_usage_available IS NULL THEN
    RAISE EXCEPTION 'AI_INVALID_USAGE_EVENT' USING ERRCODE='22023';
  END IF;

  SELECT c.owner_user_id,c.module_key INTO v_owner_user_id,v_module_key
  FROM public.srk_ai_conversations c
  WHERE c.id=p_conversation_id;
  IF NOT FOUND OR v_owner_user_id<>p_actor_user_id THEN
    RETURN jsonb_build_object('state','access_denied');
  END IF;

  IF p_usage_available THEN
    IF p_prompt_tokens IS NULL OR p_completion_tokens IS NULL OR p_total_tokens IS NULL OR
       p_prompt_tokens NOT BETWEEN 0 AND 10000000 OR
       p_completion_tokens NOT BETWEEN 0 AND 10000000 OR
       p_total_tokens NOT BETWEEN 0 AND 20000000 OR
       p_total_tokens<p_prompt_tokens OR p_total_tokens<p_completion_tokens THEN
      RAISE EXCEPTION 'AI_INVALID_USAGE_COUNTS' USING ERRCODE='22023';
    END IF;
  ELSIF p_prompt_tokens IS NOT NULL OR p_completion_tokens IS NOT NULL OR p_total_tokens IS NOT NULL THEN
    RAISE EXCEPTION 'AI_INVALID_MISSING_USAGE_COUNTS' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.srk_ai_usage_events(
    attempt_id,actor_user_id,conversation_id,request_id,module_key,
    provider_key,model_key,usage_status,prompt_tokens,completion_tokens,total_tokens
  ) VALUES (
    p_attempt_id,p_actor_user_id,p_conversation_id,p_request_id,v_module_key,
    p_provider_key,p_model_key,CASE WHEN p_usage_available THEN 'reported' ELSE 'unavailable' END,
    p_prompt_tokens,p_completion_tokens,p_total_tokens
  ) ON CONFLICT (attempt_id) DO NOTHING;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('state','recorded');
  END IF;
  RETURN jsonb_build_object('state','recorded');
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_reject_ai_usage_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
BEGIN
  RAISE EXCEPTION 'AI_USAGE_EVENTS_ARE_APPEND_ONLY' USING ERRCODE='55000';
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_reject_ai_usage_mutation() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER srk_ai_usage_events_append_only
  BEFORE UPDATE OR DELETE ON public.srk_ai_usage_events
  FOR EACH ROW EXECUTE FUNCTION public.srk_reject_ai_usage_mutation();

REVOKE ALL ON FUNCTION public.srk_ai_record_usage_event(uuid,uuid,uuid,uuid,text,text,boolean,integer,integer,integer)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_ai_record_usage_event(uuid,uuid,uuid,uuid,text,text,boolean,integer,integer,integer)
  TO service_role;

COMMIT;
