BEGIN;
SELECT plan(14);

SELECT has_table('public','srk_ai_usd_inr_reference_rates',
  'private FBIL USD/INR reference-rate snapshot table exists');
SELECT has_column('public','srk_ai_usd_inr_reference_rates','rate_date',
  'each official FX snapshot is keyed by its publication date');
SELECT has_column('public','srk_ai_usd_inr_reference_rates','usd_inr_rate',
  'FX snapshot stores the exact USD/INR rate');
SELECT has_column('public','srk_ai_usd_inr_reference_rates','published_at',
  'FX snapshot preserves when FBIL published the rate');
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
  position('fbil\.org\.in' in lower(pg_get_functiondef(
    'public.srk_ai_record_fbil_usd_inr_rate(date,numeric,text,timestamp with time zone,timestamp with time zone)'::regprocedure)))>0,
  'FX ingestion accepts only the official FBIL domain');
SELECT ok(
  position('published_at<=j.generation_created_at' in pg_get_functiondef(
    'public.srk_apply_ai_generation_cost_fx(integer)'::regprocedure))>0
  AND position('round(j.cost_usd*p.usd_inr_rate,10)' in pg_get_functiondef(
    'public.srk_apply_ai_generation_cost_fx(integer)'::regprocedure))>0,
  'INR conversion uses the latest rate published by generation time and stores precise conversion');

SELECT * FROM finish();
ROLLBACK;
