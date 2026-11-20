BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(7);

SELECT has_column('srk_private','srk_ai_handoff_notification_outbox','assignment_revision',
  'notification outbox records assignment revision separately');

SELECT ok(
  EXISTS (SELECT 1 FROM pg_constraint
    WHERE conrelid='srk_private.srk_ai_handoff_notification_outbox'::regclass
      AND conname='srk_ai_handoff_notification_outbox_handoff_revision_key'
      AND contype='u'),
  'each handoff assignment revision has its own unique outbox event'
);

SELECT ok(
  EXISTS (SELECT 1 FROM pg_trigger
    WHERE tgname='trg_srk_enqueue_ai_handoff_assignment_notification'
      AND tgrelid='public.srk_ai_handoff_queue'::regclass
      AND NOT tgisinternal),
  'assignment and reassignment updates enqueue a separate notification event'
);

SELECT ok(
  position('OLD.assigned_to IS DISTINCT FROM NEW.assigned_to' in
    pg_get_functiondef('private.srk_enqueue_ai_handoff_assignment_notification()'::regprocedure)) > 0
  AND position('max(o.assignment_revision)' in
    pg_get_functiondef('private.srk_enqueue_ai_handoff_assignment_notification()'::regprocedure)) > 0,
  'new assignment recipients receive a monotonically increasing event revision'
);

SELECT ok(
  position('NEW.status=''assigned''' in
    pg_get_functiondef('private.srk_enqueue_ai_handoff_assignment_notification()'::regprocedure)) > 0,
  'only active assignment transitions create assignment alerts'
);

SELECT ok(
  position('ON CONFLICT (handoff_id,assignment_revision) DO NOTHING' in
    pg_get_functiondef('private.srk_enqueue_ai_handoff_notification()'::regprocedure)) > 0,
  'initial queued alert remains idempotent at revision zero'
);

SELECT ok(
  NOT has_function_privilege('authenticated',
    'private.srk_enqueue_ai_handoff_assignment_notification()','EXECUTE')
  AND NOT has_function_privilege('anon',
    'private.srk_enqueue_ai_handoff_assignment_notification()','EXECUTE'),
  'notification trigger function is not callable by client roles'
);

SELECT * FROM finish();
ROLLBACK;
