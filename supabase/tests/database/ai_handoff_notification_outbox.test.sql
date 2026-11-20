BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(14);

SELECT has_table('srk_private','srk_ai_handoff_notification_outbox',
  'private AI handoff notification outbox exists');
SELECT has_column('srk_private','srk_ai_handoff_notification_outbox','handoff_id',
  'outbox is linked to the handoff queue');
SELECT has_column('srk_private','srk_ai_handoff_notification_outbox','attempt_count',
  'outbox tracks bounded retries');
SELECT has_function('public','srk_claim_ai_handoff_notification_outbox',
  ARRAY['integer'],'claim RPC exists');
SELECT has_function('public','srk_finish_ai_handoff_notification_outbox',
  ARRAY['uuid','integer','boolean','text'],'finish RPC exists');
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid='srk_private.srk_ai_handoff_notification_outbox'::regclass),
  'private outbox has RLS enabled'
);
SELECT ok(
  NOT has_table_privilege('authenticated','srk_private.srk_ai_handoff_notification_outbox','SELECT'),
  'authenticated users cannot read private notification outbox'
);
SELECT ok(
  NOT has_function_privilege('authenticated',
    'public.srk_claim_ai_handoff_notification_outbox(integer)','EXECUTE'),
  'authenticated users cannot claim notification events'
);
SELECT ok(
  NOT has_function_privilege('anon',
    'public.srk_finish_ai_handoff_notification_outbox(uuid,integer,boolean,text)','EXECUTE'),
  'anonymous users cannot finish notification events'
);
SELECT ok(
  EXISTS (SELECT 1 FROM pg_trigger
    WHERE tgname='trg_srk_enqueue_ai_handoff_notification'
      AND tgrelid='public.srk_ai_handoff_queue'::regclass
      AND NOT tgisinternal),
  'handoff insertion is connected to durable notification enqueue'
);

SELECT ok(
  position('v_row.locked_until' in pg_get_functiondef(
    'public.srk_finish_ai_handoff_notification_outbox(uuid,integer,boolean,text)'::regprocedure
  )) > 0,
  'outbox completion rejects stale or expired worker leases'
);

SELECT ok(
  position('s.status=''active''' in pg_get_functiondef(
    'public.srk_claim_ai_handoff_notification_outbox(integer)'::regprocedure
  )) > 0,
  'notification recipients must be active Staff members'
);
SELECT ok(
  position('ARRAY[q.assigned_to]' in pg_get_functiondef(
    'public.srk_claim_ai_handoff_notification_outbox(integer)'::regprocedure
  )) > 0,
  'assigned handoffs notify only their assigned Staff member'
);
SELECT ok(
  position('Handoff is no longer active' in pg_get_functiondef(
    'public.srk_claim_ai_handoff_notification_outbox(integer)'::regprocedure
  )) > 0,
  'resolved handoffs are suppressed instead of notified'
);

SELECT * FROM finish();
ROLLBACK;
