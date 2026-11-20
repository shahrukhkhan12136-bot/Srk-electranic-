BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(9);

SELECT has_table('srk_private','srk_ai_handoff_subscription_deliveries',
  'AI handoff per-device delivery ledger exists');
SELECT has_column('srk_private','srk_ai_handoff_subscription_deliveries','subscription_id',
  'ledger tracks each push subscription separately');
SELECT has_column('srk_private','srk_ai_handoff_subscription_deliveries','attempt_count',
  'per-device retries are bounded and counted');
SELECT has_function('public','srk_claim_ai_handoff_subscription_deliveries',
  ARRAY['uuid','uuid','integer'],'service worker can claim per-device deliveries');
SELECT has_function('public','srk_finish_ai_handoff_subscription_delivery',
  ARRAY['uuid','integer','boolean','text'],'service worker can finish a fenced device attempt');
SELECT has_function('public','srk_is_ai_handoff_subscription_delivery_complete',
  ARRAY['uuid'],'service worker can check completion');
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE oid='srk_private.srk_ai_handoff_subscription_deliveries'::regclass),
  'private per-device ledger has RLS enabled'
);
SELECT ok(
  NOT has_table_privilege('authenticated',
    'srk_private.srk_ai_handoff_subscription_deliveries','SELECT'),
  'authenticated users cannot read private per-device delivery records'
);
SELECT ok(
  NOT has_function_privilege('authenticated',
    'public.srk_claim_ai_handoff_subscription_deliveries(uuid,uuid,integer)','EXECUTE')
  AND NOT has_function_privilege('anon',
    'public.srk_finish_ai_handoff_subscription_delivery(uuid,integer,boolean,text)','EXECUTE'),
  'anonymous and authenticated users cannot operate the delivery worker RPCs'
);

SELECT * FROM finish();
ROLLBACK;
