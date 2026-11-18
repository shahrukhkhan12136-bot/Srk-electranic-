-- DRAFT ONLY. Behavioral tests for private AI RPCs.
-- Run only after the schema and RPC drafts in a disposable local PostgreSQL database.
BEGIN;
SET LOCAL search_path TO public, extensions;
SELECT plan(32);

-- Minimal Auth fixtures. No hosted project or real user data is used.
INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
 ('10000000-0000-4000-8000-000000000001','authenticated','authenticated','ai-rpc-owner@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('10000000-0000-4000-8000-000000000002','authenticated','authenticated','ai-rpc-other@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now());

INSERT INTO public.srk_ai_conversations(id,owner_user_id,actor_type,module_key,status)
VALUES ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','customer','customer_support','open');

-- Trusted-server claim for the positive behavior tests.
SELECT set_config('request.jwt.claim.role','service_role',true);

-- Idempotency: first claim, in-flight duplicate, hash conflict, completed replay,
-- and expired lease reclaim.
SELECT is(
 private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000001',repeat('a',64),90)->>'status',
 'processing','first idempotency request enters processing'
);
SELECT is(
 private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000001',repeat('a',64),90)->>'status',
 'processing','same request during active lease is processing'
);
SELECT is(
 private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000001',repeat('b',64),90)->>'status',
 'conflict','same key with different request hash conflicts'
);
UPDATE public.srk_ai_idempotency
SET state='completed',response_status=200,response_body='{"ok":true}'::jsonb,lease_expires_at=NULL
WHERE owner_user_id='10000000-0000-4000-8000-000000000001'
  AND endpoint_key='assistant' AND idempotency_key='idem-key-00000001';
SELECT is(
 private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000001',repeat('a',64),90)->>'status',
 'replay','completed request replays'
);
SELECT is(
 private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000002',repeat('c',64),90)->>'status',
 'processing','new idempotency key enters processing'
);
UPDATE public.srk_ai_idempotency
SET lease_expires_at=now()-interval '1 second'
WHERE owner_user_id='10000000-0000-4000-8000-000000000001'
  AND endpoint_key='assistant' AND idempotency_key='idem-key-00000002';
SELECT is(
 private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000002',repeat('c',64),90)->>'status',
 'claimed','expired processing lease can be reclaimed'
);
SELECT throws_ok(
 $$SELECT private.ai_claim_idempotency(NULL,'assistant','idem-key-00000003',repeat('d',64),90)$$,
 '22023',NULL,'null owner is rejected'
);

-- Message append: owner validation, monotonic sequence, and closed conversation.
SELECT is(
 (private.ai_append_message('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','user','hello')->>'sequence_no')::bigint,
 1::bigint,'first message gets sequence 1'
);
SELECT is(
 (private.ai_append_message('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','assistant','hello back')->>'sequence_no')::bigint,
 2::bigint,'second message gets sequence 2'
);
SELECT is(
 (SELECT count(*)::integer FROM public.srk_ai_messages WHERE conversation_id='20000000-0000-4000-8000-000000000001'),
 2,'both messages persisted'
);
SELECT throws_ok(
 $$SELECT private.ai_append_message('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','user','wrong owner')$$,
 'P0002',NULL,'different owner cannot append to conversation'
);
SELECT throws_ok(
 $$SELECT private.ai_append_message('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','invalid','bad sender')$$,
 '22023',NULL,'invalid sender is rejected'
);
UPDATE public.srk_ai_conversations SET status='closed',closed_at=now()
WHERE id='20000000-0000-4000-8000-000000000001';
SELECT throws_ok(
 $$SELECT private.ai_append_message('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','user','closed')$$,
 'P0002',NULL,'closed conversation rejects new messages'
);

-- Audit: append works, metadata persists, malformed event and oversized metadata fail.
UPDATE public.srk_ai_conversations SET status='open',closed_at=NULL
WHERE id='20000000-0000-4000-8000-000000000001';
SELECT ok(
 private.ai_append_audit_event('10000000-0000-4000-8000-000000000001','customer','customer_support','message_persisted','success','20000000-0000-4000-8000-000000000001',NULL,'30000000-0000-4000-8000-000000000001','{"source":"test"}'::jsonb) IS NOT NULL,
 'valid audit event receives an id'
);
SELECT is(
 (SELECT count(*)::integer FROM public.srk_ai_audit_events WHERE correlation_id='30000000-0000-4000-8000-000000000001'),
 1,'audit event persisted'
);
SELECT throws_ok(
 $$SELECT private.ai_append_audit_event(NULL,'customer','customer_support','not_allowed','success',NULL,NULL,NULL,'{}'::jsonb)$$,
 '22023',NULL,'invalid audit event type is rejected'
);
SELECT throws_ok(
 $$SELECT private.ai_append_audit_event(NULL,'customer','customer_support','message_persisted','success',NULL,NULL,NULL,pg_catalog.jsonb_build_object('payload',pg_catalog.repeat('x',9000)))$$,
 '22023',NULL,'oversized audit metadata is rejected'
);
SELECT ok(
 (SELECT prosecdef FROM pg_proc WHERE oid='private.ai_claim_idempotency(uuid,text,text,text,integer)'::regprocedure)
 AND (SELECT EXISTS (SELECT 1 FROM pg_catalog.unnest(proconfig) AS cfg WHERE cfg LIKE 'search_path=%') FROM pg_proc WHERE oid='private.ai_claim_idempotency(uuid,text,text,text,integer)'::regprocedure),
 'idempotency RPC is SECURITY DEFINER with empty search_path'
);

-- A caller without the trusted service-role claim is rejected by function logic.
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT throws_ok(
 $$SELECT private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000004',repeat('e',64),90)$$,
 '42501',NULL,'non-service role claim cannot claim idempotency'
);
SELECT throws_ok(
 $$SELECT private.ai_append_message('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','user','not trusted')$$,
 '42501',NULL,'non-service role claim cannot append messages'
);
SELECT throws_ok(
 $$SELECT private.ai_append_audit_event(NULL,'system','system','safety_block','denied')$$,
 '42501',NULL,'non-service role claim cannot append audit'
);


-- Atomic completion: assistant message and cached response commit together.
SELECT is(
 private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000003',repeat('f',64),90)->>'status',
 'processing','completion fixture obtains a live claim'
);
SELECT is(
 private.ai_complete_idempotency(
  '10000000-0000-4000-8000-000000000001','assistant','idem-key-00000003',200,
  '{"ok":true,"answer":"saved"}'::jsonb,
  '20000000-0000-4000-8000-000000000001','atomic assistant reply'
 )->>'status',
 'completed','completion RPC marks request completed'
);
SELECT is(
 (SELECT response_status FROM public.srk_ai_idempotency
  WHERE idempotency_key='idem-key-00000003' AND endpoint_key='assistant'),
 200,'completion stores response status'
);
SELECT is(
 (SELECT response_body->>'answer' FROM public.srk_ai_idempotency
  WHERE idempotency_key='idem-key-00000003' AND endpoint_key='assistant'),
 'saved','completion stores replay response body'
);
SELECT is(
 (SELECT count(*)::integer FROM public.srk_ai_messages
  WHERE conversation_id='20000000-0000-4000-8000-000000000001'
    AND sender_type='assistant' AND body='atomic assistant reply'),
 1,'completion persists assistant message'
);
SELECT is(
 private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000003',repeat('f',64),90)->>'status',
 'replay','completed request replays stored result'
);

-- If message persistence fails, completion must roll back and keep the claim processing.
SELECT is(
 private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000004',repeat('1',64),90)->>'status',
 'processing','atomic rollback fixture obtains a live claim'
);
UPDATE public.srk_ai_conversations SET status='closed',closed_at=now()
WHERE id='20000000-0000-4000-8000-000000000001';
SELECT throws_ok(
 $SELECT private.ai_complete_idempotency(
  '10000000-0000-4000-8000-000000000001','assistant','idem-key-00000004',200,
  '{"ok":true}'::jsonb,'20000000-0000-4000-8000-000000000001','must rollback'
 )$,
 'P0002',NULL,'failed assistant message insert aborts completion'
);
SELECT is(
 (SELECT state FROM public.srk_ai_idempotency
  WHERE idempotency_key='idem-key-00000004' AND endpoint_key='assistant'),
 'processing','failed completion leaves idempotency claim uncompleted'
);
UPDATE public.srk_ai_conversations SET status='open',closed_at=NULL
WHERE id='20000000-0000-4000-8000-000000000001';
SELECT is(
 private.ai_claim_idempotency('10000000-0000-4000-8000-000000000001','assistant','idem-key-00000005',repeat('2',64),90)->>'status',
 'processing','invalid completion fixture obtains a live claim'
);
SELECT throws_ok(
 $SELECT private.ai_complete_idempotency(
  '10000000-0000-4000-8000-000000000001','assistant','idem-key-00000005',99,
  '{"ok":true}'::jsonb
 )$,
 '22023',NULL,'invalid response status is rejected'
);
\nSELECT * FROM finish();
ROLLBACK;
