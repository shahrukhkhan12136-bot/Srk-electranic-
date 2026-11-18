-- DRAFT ONLY. Run after schema + RPC drafts in disposable local PostgreSQL.
BEGIN;
SET LOCAL search_path TO public, extensions;
SELECT plan(9);
SELECT ok(to_regprocedure('private.ai_claim_idempotency(uuid,text,text,text,integer)') IS NOT NULL,'idempotency claim RPC exists');
SELECT ok(to_regprocedure('private.ai_append_message(uuid,uuid,text,text)') IS NOT NULL,'append message RPC exists');
SELECT ok(to_regprocedure('private.ai_append_audit_event(uuid,text,text,text,text,uuid,uuid,uuid,jsonb)') IS NOT NULL,'append audit RPC exists');
SELECT ok(NOT has_schema_privilege('anon','private','USAGE'),'anon cannot use private schema');
SELECT ok(NOT has_schema_privilege('authenticated','private','USAGE'),'authenticated cannot use private schema');
SELECT ok(has_schema_privilege('service_role','private','USAGE'),'service role can use private schema');
SELECT ok(has_function_privilege('service_role','private.ai_claim_idempotency(uuid,text,text,text,integer)','EXECUTE'),'service role can claim idempotency');
SELECT ok(NOT has_function_privilege('anon','private.ai_claim_idempotency(uuid,text,text,text,integer)','EXECUTE'),'anon cannot claim idempotency');
SELECT ok(NOT has_function_privilege('authenticated','private.ai_append_message(uuid,uuid,text,text)','EXECUTE'),'authenticated cannot append messages');
SELECT * FROM finish();
ROLLBACK;
