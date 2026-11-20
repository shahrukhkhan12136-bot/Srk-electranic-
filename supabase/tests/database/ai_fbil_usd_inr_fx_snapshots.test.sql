BEGIN;
SELECT plan(27);

SELECT has_table('public','srk_ai_usd_inr_reference_rates',
  'private FBIL USD/INR reference-rate snapshot table exists');
SELECT has_column('public','srk_ai_usd_inr_reference_rates','rate_date',
  'each official FX snapshot is keyed by its publication date');
SELECT has_column('public','srk_ai_usd_inr_reference_rates','usd_inr_rate',
  'FX snapshot stores the exact USD/INR rate');
SELECT has_column('public','srk_ai_usd_inr_reference_rates','published_at',
  'FX snapshot preserves when FBIL published the rate');
SELECT has_column('public','srk_ai_generation_cost_jobs','generation_created_at',
  'Gateway generation timestamp is retained for rate-date selection');
SELECT has_column('public','srk_ai_generation_cost_jobs','cost_inr',
  'reported USD costs have a dedicated INR conversion field');
SELECT has_function('public','srk_ai_record_fbil_usd_inr_rate',
  ARRAY['date','numeric','text','timestamp with time zone','timestamp with time zone'],
  'trusted server can record a verified FBIL rate');
SELECT has_function('public','srk_apply_ai_generation_cost_fx',
  ARRAY['integer'],'server can convert reported Gateway USD costs to INR');
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE oid='public.srk_ai_usd_inr_reference_rates'::regclass)
  AND NOT has_table_privilege('anon','public.srk_ai_usd_inr_reference_rates','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_ai_usd_inr_reference_rates','SELECT')
  AND NOT has_table_privilege('service_role','public.srk_ai_usd_inr_reference_rates','SELECT'),
  'FX snapshots are RLS-enabled and inaccessible through direct table reads');
SELECT ok(
  has_function_privilege('service_role',
    'public.srk_ai_record_fbil_usd_inr_rate(date,numeric,text,timestamp with time zone,timestamp with time zone)','EXECUTE')
  AND has_function_privilege('service_role',
    'public.srk_apply_ai_generation_cost_fx(integer)','EXECUTE')
  AND NOT has_function_privilege('anon',
    'public.srk_ai_record_fbil_usd_inr_rate(date,numeric,text,timestamp with time zone,timestamp with time zone)','EXECUTE')
  AND NOT has_function_privilege('authenticated',
    'public.srk_apply_ai_generation_cost_fx(integer)','EXECUTE'),
  'FX ingestion and conversion RPCs are service-role-only');
SELECT ok(
  EXISTS (SELECT 1 FROM pg_trigger
    WHERE tgrelid='public.srk_ai_usd_inr_reference_rates'::regclass
      AND tgname='srk_ai_fx_reference_rates_append_only' AND NOT tgisinternal),
  'FX reference snapshots have an append-only mutation guard');
SELECT ok(
  EXISTS (SELECT 1 FROM pg_trigger
    WHERE tgrelid='public.srk_ai_generation_cost_jobs'::regclass
      AND tgname='srk_ai_generation_fx_status_sync' AND NOT tgisinternal),
  'unavailable USD cost jobs are marked FX-unavailable automatically');
SELECT ok(
  position('fbil\.org\.in' in lower(pg_get_functiondef(
    'public.srk_ai_record_fbil_usd_inr_rate(date,numeric,text,timestamp with time zone,timestamp with time zone)'::regprocedure)))>0,
  'FX ingestion accepts only the official FBIL domain');
SELECT ok(
  position('published_at<=j.generation_created_at' in pg_get_functiondef(
    'public.srk_apply_ai_generation_cost_fx(integer)'::regprocedure))>0
  AND position('round(j.cost_usd*p.usd_inr_rate,10)' in pg_get_functiondef(
    'public.srk_apply_ai_generation_cost_fx(integer)'::regprocedure))>0,
  'INR conversion uses the latest rate published by generation time and stores precise conversion');


INSERT INTO auth.users (id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
VALUES ('00000000-0000-4000-8000-000000000501','authenticated','authenticated',
  'ai-fx-owner@example.test','',transaction_timestamp(),transaction_timestamp(),transaction_timestamp());

CREATE TEMP TABLE ai_fx_context (
  actor_user_id uuid NOT NULL,
  conversation_id uuid,
  attempt_id uuid NOT NULL,
  request_id uuid NOT NULL
);
INSERT INTO ai_fx_context VALUES (
  '00000000-0000-4000-8000-000000000501',NULL,
  '00000000-0000-4000-8000-000000000502',
  '00000000-0000-4000-8000-000000000503'
);
SET LOCAL request.jwt.claim.role='service_role';

UPDATE ai_fx_context
SET conversation_id=(public.srk_ai_create_conversation(actor_user_id,'customer_support')->>'conversation_id')::uuid;
SELECT is((SELECT conversation_id IS NOT NULL FROM ai_fx_context),true,
  'test actor can create a conversation for the cost ledger');
SELECT is((public.srk_ai_record_usage_event(
  (SELECT attempt_id FROM ai_fx_context),(SELECT actor_user_id FROM ai_fx_context),
  (SELECT conversation_id FROM ai_fx_context),(SELECT request_id FROM ai_fx_context),
  'vercel_ai_gateway','provider/test',true,12,8,20)->>'state'),
  'recorded','usage metadata is recorded before generation cost is queued');
SELECT is((public.srk_ai_queue_generation_cost_job(
  (SELECT attempt_id FROM ai_fx_context),'gen_test_fx_001',
  'vercel_ai_gateway','provider/test')->>'state'),
  'queued','generation cost job is queued idempotently');

CREATE TEMP TABLE ai_fx_claim AS
SELECT * FROM public.srk_claim_ai_generation_cost_jobs(5);
SELECT is((SELECT attempt_count FROM ai_fx_claim WHERE attempt_id=(SELECT attempt_id FROM ai_fx_context)),
  1,'worker claim increments the fenced attempt count');
SELECT ok(public.srk_finish_ai_generation_cost_job(
  (SELECT attempt_id FROM ai_fx_context),
  (SELECT attempt_count FROM ai_fx_claim WHERE attempt_id=(SELECT attempt_id FROM ai_fx_context)),
  true,0.0123,'vercel_ai_gateway_generation_api',
  '2025-01-02T08:00:00Z'::timestamptz,NULL),
  'worker records exact USD cost and Gateway generation timestamp');

SELECT is((public.srk_ai_record_fbil_usd_inr_rate(
  '2025-01-02',90.1234,'https://www.fbil.org.in/#/home',
  '2025-01-02T07:30:00Z'::timestamptz,
  '2025-01-02T07:35:00Z'::timestamptz)->>'state'),
  'recorded','verified FBIL rate snapshot is stored with its source and timestamps');
SELECT is(public.srk_apply_ai_generation_cost_fx(20),1,
  'reported USD cost is converted using the FBIL rate published before generation');
SELECT is((SELECT cost_inr FROM public.srk_ai_generation_cost_jobs
  WHERE attempt_id=(SELECT attempt_id FROM ai_fx_context)),
  1.10851782::numeric,'INR cost is calculated with the stored exact USD cost and FBIL rate');
SELECT is((SELECT fx_rate_date FROM public.srk_ai_generation_cost_jobs
  WHERE attempt_id=(SELECT attempt_id FROM ai_fx_context)),
  '2025-01-02'::date,'converted cost retains the exact FBIL rate date');
SELECT is(public.srk_apply_ai_generation_cost_fx(20),0,
  'a converted generation is not converted a second time');
SELECT is((public.srk_ai_record_fbil_usd_inr_rate(
  '2025-01-02',90.1234,'https://www.fbil.org.in/#/home',
  '2025-01-02T07:30:00Z'::timestamptz,
  '2025-01-02T07:35:00Z'::timestamptz)->>'state'),
  'already_recorded','replaying the identical daily rate is idempotent');
SELECT is((public.srk_ai_record_fbil_usd_inr_rate(
  '2025-01-02',91.1234,'https://www.fbil.org.in/#/home',
  '2025-01-02T07:30:00Z'::timestamptz,
  '2025-01-02T07:35:00Z'::timestamptz)->>'state'),
  'conflict','a different rate cannot overwrite an append-only daily snapshot');
SELECT throws_ok(
  $SELECT public.srk_ai_record_fbil_usd_inr_rate(
    '2025-01-03',90,'https://evil.example/rate',
    '2025-01-03T07:30:00Z'::timestamptz,
    '2025-01-03T07:35:00Z'::timestamptz)$,
  '22023','AI_INVALID_FBIL_FX_RATE',
  'FX ingestion rejects a non-FBIL source URL');

SELECT * FROM finish();
ROLLBACK;
