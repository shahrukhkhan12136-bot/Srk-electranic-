BEGIN;
SET LOCAL search_path TO public, extensions;
SELECT plan(20);

SELECT has_table('public','srk_rate_catalogue_drafts',
  'private rate catalogue draft table exists');

SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_rate_catalogue_drafts'::regclass),
  'draft table has row-level security enabled'
);

SELECT ok(
  NOT has_table_privilege('anon','public.srk_rate_catalogue_drafts','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_rate_catalogue_drafts','SELECT')
  AND NOT has_table_privilege('anon','public.srk_rate_catalogue_drafts','INSERT')
  AND NOT has_table_privilege('authenticated','public.srk_rate_catalogue_drafts','INSERT')
  AND NOT has_table_privilege('anon','public.srk_rate_catalogue_drafts','UPDATE')
  AND NOT has_table_privilege('authenticated','public.srk_rate_catalogue_drafts','UPDATE')
  AND NOT has_table_privilege('anon','public.srk_rate_catalogue_drafts','DELETE')
  AND NOT has_table_privilege('authenticated','public.srk_rate_catalogue_drafts','DELETE'),
  'browser roles have no direct draft table access'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid='public.srk_rate_catalogue_drafts'::regclass
      AND tgname='srk_rate_catalogue_draft_guard' AND NOT tgisinternal
  ),
  'published draft mutation guard trigger exists'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid='public.srk_rate_catalogue_drafts'::regclass
      AND tgname='srk_rate_catalogue_draft_guard' AND NOT tgisinternal
      AND (tgtype & 2)=2 AND (tgtype & 16)=16 AND (tgtype & 8)=8
  ),
  'draft guard runs before both UPDATE and DELETE'
);

SELECT ok(
  (SELECT p.prosecdef AND p.proconfig @> ARRAY['search_path=""']
   FROM pg_proc p
   WHERE p.oid='public.srk_guard_rate_catalogue_draft_mutation()'::regprocedure),
  'draft guard is SECURITY DEFINER with an empty search_path'
);

SELECT ok(
  NOT has_function_privilege('anon','public.srk_guard_rate_catalogue_draft_mutation()','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_guard_rate_catalogue_draft_mutation()','EXECUTE'),
  'client roles cannot execute the trigger function directly'
);

SELECT ok(
  to_regprocedure('public.srk_admin_save_rate_catalogue_draft(jsonb,timestamptz,text,uuid)') IS NOT NULL,
  'draft save RPC exists'
);

SELECT ok(
  (SELECT p.prosecdef AND p.proconfig @> ARRAY['search_path=""']
   FROM pg_proc p
   WHERE p.oid='public.srk_admin_save_rate_catalogue_draft(jsonb,timestamptz,text,uuid)'::regprocedure),
  'draft save RPC is SECURITY DEFINER with an empty search_path'
);

SELECT ok(
  NOT has_function_privilege('anon','public.srk_admin_save_rate_catalogue_draft(jsonb,timestamptz,text,uuid)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_save_rate_catalogue_draft(jsonb,timestamptz,text,uuid)','EXECUTE'),
  'only authenticated callers can reach the Main Admin-checked save RPC'
);

SELECT ok(
  (SELECT p.prosecdef AND p.provolatile='s'
      AND p.proconfig @> ARRAY['search_path=""']
   FROM pg_proc p
   WHERE p.oid='public.srk_admin_list_rate_catalogue_drafts(integer)'::regprocedure),
  'draft queue RPC is stable SECURITY DEFINER with an empty search_path'
);

SELECT ok(
  position('INVALID_PAGE_LIMIT' IN pg_get_functiondef(
    'public.srk_admin_list_rate_catalogue_drafts(integer)'::regprocedure))>0,
  'draft queue RPC enforces bounded page sizes'
);

SELECT ok(
  to_regprocedure('public.srk_admin_publish_rate_catalogue_draft(uuid,uuid)') IS NOT NULL,
  'draft publish RPC exists'
);

SELECT ok(
  (SELECT p.prosecdef AND p.proconfig @> ARRAY['search_path=""']
   FROM pg_proc p
   WHERE p.oid='public.srk_admin_publish_rate_catalogue_draft(uuid,uuid)'::regprocedure)
  AND NOT has_function_privilege('anon','public.srk_admin_publish_rate_catalogue_draft(uuid,uuid)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_publish_rate_catalogue_draft(uuid,uuid)','EXECUTE'),
  'publish RPC is hardened and available only through authenticated Main Admin checks'
);

SELECT ok(
  position('srk_admin_publish_rate_catalogue(' IN pg_get_functiondef(
    'public.srk_admin_publish_rate_catalogue_draft(uuid,uuid)'::regprocedure))>0
  AND position('p_expected_current_version_id' IN pg_get_functiondef(
    'public.srk_admin_publish_rate_catalogue_draft(uuid,uuid)'::regprocedure))>0,
  'draft publishing delegates to the version-checked catalogue publisher'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid='public.srk_rate_catalogue_drafts'::regclass
      AND contype='c'
      AND position('published_rate_version_id' IN pg_get_constraintdef(oid))>0
  ),
  'published status requires a linked immutable rate version'
);

SELECT ok(
  position('p_rates->>v_key IS NULL' IN pg_get_functiondef(
    'public.srk_admin_save_rate_catalogue_draft(jsonb,timestamptz,text,uuid)'::regprocedure))>0,
  'draft save rejects null tier amounts before integer-paise validation'
);

SELECT ok(
  position('EXACTLY_FOUR_RATE_TIERS_REQUIRED' IN pg_get_functiondef(
    'public.srk_admin_save_rate_catalogue_draft(jsonb,timestamptz,text,uuid)'::regprocedure))>0
  AND position('RATE_MUST_BE_INTEGER_PAISE' IN pg_get_functiondef(
    'public.srk_admin_save_rate_catalogue_draft(jsonb,timestamptz,text,uuid)'::regprocedure))>0,
  'draft save validates the four-tier integer-paise contract'
);


SELECT ok(
  pg_get_functiondef('public.srk_get_my_electrician_rate_list()'::regprocedure)
    ~ 'i[.]customer_rate_paise::numeric[*]1500/10000'
  AND pg_get_functiondef('public.srk_get_my_electrician_rate_list()'::regprocedure)
    ~ 'i[.]customer_rate_paise-floor',
  'electrician rate list uses the canonical commission-first 15% half-up net formula'
);

SELECT ok(
  pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure)
    ~ 'b[.]estimated_labour_paise::numeric[*]1500/10000'
  AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure)
    ~ 'b[.]estimated_labour_paise-floor',
  'job offer net amount uses the same canonical commission-first formula'
);

SELECT * FROM finish();
ROLLBACK;
