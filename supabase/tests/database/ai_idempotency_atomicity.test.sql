BEGIN;
SELECT plan(40);
INSERT INTO auth.users (id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
VALUES
 ('00000000-0000-4000-8000-000000000101','authenticated','authenticated','ai-owner@example.test','',transaction_timestamp(),transaction_timestamp(),transaction_timestamp()),
 ('00000000-0000-4000-8000-000000000102','authenticated','authenticated','ai-other@example.test','',transaction_timestamp(),transaction_timestamp(),transaction_timestamp());
CREATE TEMP TABLE ai_test_context (
 actor_one uuid NOT NULL, actor_two uuid NOT NULL, conversation_one uuid, conversation_two uuid,
 key_one uuid NOT NULL, key_two uuid NOT NULL, key_three uuid NOT NULL, key_four uuid NOT NULL,
 digest_one bytea NOT NULL, response_message_id uuid
);
INSERT INTO ai_test_context VALUES (
 '00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000102',
 NULL,NULL,'00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000202',
 '00000000-0000-4000-8000-000000000203','00000000-0000-4000-8000-000000000204',
 decode(repeat('a',64),'hex'),NULL
);
SET LOCAL request.jwt.claim.role='service_role';
SELECT ok(
 has_function_privilege('service_role','public.srk_ai_reserve_idempotency(uuid,uuid,bytea)','EXECUTE')
 AND has_function_privilege('service_role','public.srk_ai_complete_idempotency(uuid,uuid,bytea,bigint,uuid,text,integer)','EXECUTE')
 AND NOT has_function_privilege('anon','public.srk_ai_reserve_idempotency(uuid,uuid,bytea)','EXECUTE')
 AND NOT has_function_privilege('authenticated','public.srk_ai_complete_idempotency(uuid,uuid,bytea,bigint,uuid,text,integer)','EXECUTE'),
 'idempotency RPCs are service-role-only');
SELECT ok(
 (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_ai_idempotency'::regclass)
 AND NOT has_table_privilege('anon','public.srk_ai_idempotency','SELECT')
 AND NOT has_table_privilege('authenticated','public.srk_ai_idempotency','SELECT'),
 'idempotency storage is RLS enabled and inaccessible to browser roles');
SELECT ok(
 (SELECT prosecdef AND proconfig @> ARRAY['search_path=""']::text[] FROM pg_proc
  WHERE oid='public.srk_ai_complete_idempotency(uuid,uuid,bytea,bigint,uuid,text,integer)'::regprocedure),
 'atomic completion is SECURITY DEFINER with an empty search_path');
SELECT ok(
 position('FOR UPDATE' in upper(pg_get_functiondef('public.srk_ai_complete_idempotency(uuid,uuid,bytea,bigint,uuid,text,integer)'::regprocedure)))>0
 AND position('response_message_id' in pg_get_functiondef('public.srk_ai_reserve_idempotency(uuid,uuid,bytea)'::regprocedure))>0,
 'completion locks the idempotency claim and replay stores the exact message ID');
SELECT ok(
 position('p_final_status IS DISTINCT FROM ''failed''' in pg_get_functiondef('public.srk_ai_finalize_idempotency(uuid,uuid,bytea,bigint,text,integer,uuid)'::regprocedure))>0
 AND position('p_sender_kind <> ''user''' in pg_get_functiondef('public.srk_ai_append_message(uuid,uuid,text,text)'::regprocedure))>0,
 'legacy finalize cannot complete and legacy append accepts user messages only');
UPDATE ai_test_context
SET conversation_one=(public.srk_ai_create_conversation(actor_one,'customer_support')->>'conversation_id')::uuid,
 conversation_two=(public.srk_ai_create_conversation(actor_one,'booking_assistant')->>'conversation_id')::uuid;

SELECT ok(
 has_function_privilege('service_role','public.srk_ai_reserve_request_capacity(uuid,text)','EXECUTE')
 AND NOT has_function_privilege('anon','public.srk_ai_reserve_request_capacity(uuid,text)','EXECUTE')
 AND NOT has_function_privilege('authenticated','public.srk_ai_reserve_request_capacity(uuid,text)','EXECUTE'),
 'AI request capacity RPC is service-role-only');
SELECT ok(
 (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_ai_request_limits'::regclass)
 AND NOT has_table_privilege('anon','public.srk_ai_request_limits','SELECT')
 AND NOT has_table_privilege('authenticated','public.srk_ai_request_limits','SELECT'),
 'AI request counters are private and RLS enabled');
SELECT is(
 (public.srk_ai_reserve_request_capacity((SELECT actor_one FROM ai_test_context),'customer_support')->>'state'),
 'allowed','first request receives capacity');
SELECT public.srk_ai_reserve_request_capacity((SELECT actor_one FROM ai_test_context),'customer_support')
FROM generate_series(1,9);
SELECT is(
 (public.srk_ai_reserve_request_capacity((SELECT actor_one FROM ai_test_context),'customer_support')->>'scope'),
 'window','eleventh request in ten minutes is throttled');
UPDATE public.srk_ai_request_limits SET requests_today=100
WHERE actor_user_id=(SELECT actor_one FROM ai_test_context) AND module_key='customer_support';
SELECT is(
 (public.srk_ai_reserve_request_capacity((SELECT actor_one FROM ai_test_context),'customer_support')->>'scope'),
 'daily','daily request ceiling is enforced');
SELECT is(
 (public.srk_ai_reserve_request_capacity((SELECT actor_one FROM ai_test_context),'booking_assistant')->>'state'),
 'allowed','limits are isolated per assistant module');

SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_one,digest_one)->>'state'),'reserved',
 'first request reserves one five-minute processing lease') FROM ai_test_context;
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_one,digest_one)->>'state'),'processing',
 'duplicate while lease is live does not start a second worker') FROM ai_test_context;
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_one,decode(repeat('b',64),'hex'))->>'state'),'conflict',
 'same actor/key with a different digest conflicts') FROM ai_test_context;
WITH result AS (
 SELECT public.srk_ai_complete_idempotency(actor_one,key_one,digest_one,1,conversation_one,
  'First assistant answer',200) AS payload FROM ai_test_context
)
SELECT is(result.payload->>'state','completed','valid completion atomically stores the assistant answer') FROM result;
UPDATE ai_test_context
SET response_message_id=(SELECT i.response_message_id::uuid FROM public.srk_ai_idempotency i
 WHERE i.actor_user_id=ai_test_context.actor_one AND i.idempotency_key=ai_test_context.key_one);
SELECT ok((SELECT i.response_message_id IS NOT NULL AND i.status='completed'
 AND i.retention_expires_at=i.completed_at+interval '7 days'
 FROM public.srk_ai_idempotency i JOIN ai_test_context c
 ON c.actor_one=i.actor_user_id AND c.key_one=i.idempotency_key),
 'completion stores exact response reference and seven-day retention');
SELECT is((public.srk_ai_append_message(actor_one,conversation_one,'user','A later user message')->>'state'),
 'appended','a later user message can be appended to the open conversation') FROM ai_test_context;
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_one,digest_one)->>'response_message_id')::uuid,
 response_message_id,'replay returns the exact original response ID, not the latest thread message') FROM ai_test_context;
SELECT is((SELECT m.body FROM public.srk_ai_messages m JOIN ai_test_context c ON m.id=c.response_message_id),
 'First assistant answer','the replay reference resolves to the original assistant body');
UPDATE public.srk_ai_conversations SET status='closed',closed_at=transaction_timestamp()
WHERE id=(SELECT conversation_one FROM ai_test_context);
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_one,digest_one)->>'state'),'replay',
 'completed exact replay remains available after conversation closure') FROM ai_test_context;
SELECT is((public.srk_ai_reserve_idempotency(actor_two,key_one,digest_one)->>'state'),'reserved',
 'another actor receives an independent actor-scoped reservation') FROM ai_test_context;
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_two,digest_one)->>'state'),'reserved',
 'a separate key receives its own processing lease') FROM ai_test_context;
UPDATE public.srk_ai_idempotency SET processing_lease_expires_at=transaction_timestamp()
WHERE actor_user_id=(SELECT actor_one FROM ai_test_context)
 AND idempotency_key=(SELECT key_two FROM ai_test_context);
WITH reclaimed AS (
 SELECT public.srk_ai_reserve_idempotency(actor_one,key_two,digest_one) AS payload FROM ai_test_context
)
SELECT is(reclaimed.payload->>'lease_version','2','expired lease is reclaimed with an incremented fencing version')
FROM reclaimed;
SELECT is((public.srk_ai_complete_idempotency(actor_one,key_two,digest_one,1,conversation_two,'Stale answer',200)->>'state'),
 'stale_lease','old worker cannot complete after lease reclamation') FROM ai_test_context;
SELECT is((SELECT count(*)::integer FROM public.srk_ai_messages
 WHERE conversation_id=(SELECT conversation_two FROM ai_test_context) AND sender_kind='assistant'),
 0,'stale worker created no assistant message');
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_three,digest_one)->>'state'),'reserved',
 'failure test request reserves successfully') FROM ai_test_context;
SELECT is((public.srk_ai_finalize_idempotency(actor_one,key_three,digest_one,1,'failed',503,conversation_two)->>'state'),
 'failed','legacy finalizer records only a stable failed result') FROM ai_test_context;
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_three,digest_one)->>'state'),'failed',
 'same digest during failure retention returns stable failure') FROM ai_test_context;
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_three,decode(repeat('c',64),'hex'))->>'state'),'conflict',
 'different digest during failure retention conflicts') FROM ai_test_context;
UPDATE public.srk_ai_idempotency SET retention_expires_at=transaction_timestamp()
WHERE actor_user_id=(SELECT actor_one FROM ai_test_context)
 AND idempotency_key=(SELECT key_three FROM ai_test_context);
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_three,digest_one)->>'state'),'failed',
 'failure remains protected exactly at the retention boundary') FROM ai_test_context;
UPDATE public.srk_ai_idempotency SET retention_expires_at=transaction_timestamp()-interval '1 microsecond'
WHERE actor_user_id=(SELECT actor_one FROM ai_test_context)
 AND idempotency_key=(SELECT key_three FROM ai_test_context);
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_three,decode(repeat('d',64),'hex'))->>'state'),'reserved',
 'failure key can be reused strictly after retention expiry') FROM ai_test_context;
UPDATE public.srk_ai_idempotency SET retention_expires_at=transaction_timestamp()
WHERE actor_user_id=(SELECT actor_one FROM ai_test_context)
 AND idempotency_key=(SELECT key_one FROM ai_test_context);
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_one,digest_one)->>'state'),'replay',
 'completed response remains replayable exactly at the seven-day retention boundary') FROM ai_test_context;
UPDATE public.srk_ai_idempotency SET retention_expires_at=transaction_timestamp()-interval '1 microsecond'
WHERE actor_user_id=(SELECT actor_one FROM ai_test_context)
 AND idempotency_key=(SELECT key_one FROM ai_test_context);
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_one,decode(repeat('e',64),'hex'))->>'state'),'reserved',
 'completed key can be reused only strictly after retention expiry') FROM ai_test_context;
SELECT is((public.srk_ai_reserve_idempotency(actor_one,key_four,digest_one)->>'state'),'reserved',
 'rollback test request reserves successfully') FROM ai_test_context;
CREATE OR REPLACE FUNCTION public.srk_test_fail_ai_audit_insert()
RETURNS trigger LANGUAGE plpgsql AS $test$
BEGIN
 RAISE EXCEPTION 'AI_TEST_FORCED_AUDIT_FAILURE' USING ERRCODE='P0001';
END;
$test$;
CREATE TRIGGER srk_test_fail_ai_audit_insert
BEFORE INSERT ON public.srk_ai_audit_events
FOR EACH ROW EXECUTE FUNCTION public.srk_test_fail_ai_audit_insert();
SELECT throws_ok(
 $q$SELECT public.srk_ai_complete_idempotency(
  (SELECT actor_one FROM ai_test_context),(SELECT key_four FROM ai_test_context),
  (SELECT digest_one FROM ai_test_context),1,(SELECT conversation_two FROM ai_test_context),
  'Rollback answer',200)$q$,
 'P0001','AI_TEST_FORCED_AUDIT_FAILURE',
 'forced audit failure aborts the completion transaction');
DROP TRIGGER srk_test_fail_ai_audit_insert ON public.srk_ai_audit_events;
DROP FUNCTION public.srk_test_fail_ai_audit_insert();
SELECT is((SELECT i.status FROM public.srk_ai_idempotency i JOIN ai_test_context c
 ON i.actor_user_id=c.actor_one AND i.idempotency_key=c.key_four),
 'processing','failed transaction leaves the idempotency claim processing');
SELECT is((SELECT count(*)::integer FROM public.srk_ai_messages
 WHERE conversation_id=(SELECT conversation_two FROM ai_test_context) AND sender_kind='assistant'),
 0,'failed transaction rolls back the inserted assistant message');
SELECT is((public.srk_ai_complete_idempotency(actor_one,key_four,digest_one,1,conversation_two,
 'Committed answer',200)->>'state'),'completed',
 'same claim can complete successfully after rollback') FROM ai_test_context;
SELECT throws_ok(
 $$SELECT public.srk_ai_finalize_idempotency((SELECT actor_one FROM ai_test_context),
 (SELECT key_four FROM ai_test_context),(SELECT digest_one FROM ai_test_context),1,'completed',200,NULL)$$,
 '22023','AI_INVALID_IDEMPOTENCY_FAILURE','legacy finalizer rejects completed status');
SELECT throws_ok(
 $$SELECT public.srk_ai_append_message((SELECT actor_one FROM ai_test_context),
 (SELECT conversation_two FROM ai_test_context),'assistant','Bypass')$$,
 '22023','AI_INVALID_MESSAGE','legacy append rejects assistant messages');
SELECT * FROM finish();
ROLLBACK;
