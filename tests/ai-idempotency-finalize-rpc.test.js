"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const migration = fs.readFileSync(path.join(__dirname,"..","supabase","migrations","20261118200000_ai_idempotency_finalize_rpc.sql"),"utf8");

test("AI idempotency completion and failure RPCs are service-role-only and validate bounded inputs",()=>{
 assert.match(migration,/auth\.role\(\)\s+IS DISTINCT FROM\s+'service_role'/i);
 assert.match(migration,/octet_length\(p_request_sha256\)\s*<>\s*32/i);
 assert.match(migration,/p_lease_version\s*<\s*1/i);
 assert.match(migration,/p_response_code\s+NOT BETWEEN 100 AND 599/i);
 assert.match(migration,/GRANT EXECUTE ON FUNCTION public\.srk_ai_complete_idempotency\(uuid,uuid,bytea,bigint,uuid,text,integer\)\s+TO service_role/i);
 assert.match(migration,/REVOKE ALL ON FUNCTION public\.srk_ai_complete_idempotency\(uuid,uuid,bytea,bigint,uuid,text,integer\)\s+FROM PUBLIC,anon,authenticated/i);
 assert.match(migration,/p_final_status IS DISTINCT FROM 'failed'/i);
});

test("AI completion locks the claim before conversation and atomically stores the exact assistant response",()=>{
 const lock=migration.indexOf("FROM public.srk_ai_idempotency");
 const conversation=migration.indexOf("FROM public.srk_ai_conversations",lock);
 assert.ok(lock>=0 && conversation>lock,"idempotency row is locked before conversation");
 assert.match(migration,/processing_lease_expires_at\s*<=\s*v_now/i);
 assert.match(migration,/lease_version\s*<>\s*p_lease_version/i);
 assert.match(migration,/v_conversation_status\s*<>\s*'open'/i);
 assert.match(migration,/INSERT INTO public\.srk_ai_messages[\s\S]*?'assistant'/i);
 assert.match(migration,/response_message_id\s*=\s*v_message_id/i);
 assert.match(migration,/retention_expires_at\s*=\s*v_now\s*\+\s*interval '7 days'/i);
});

test("AI exact replay verifies the original assistant message and owner without latest-message fallback",()=>{
 assert.match(migration,/m\.id\s*=\s*v_claim\.response_message_id/i);
 assert.match(migration,/m\.conversation_id\s*=\s*v_claim\.conversation_id/i);
 assert.match(migration,/m\.sender_kind\s*=\s*'assistant'/i);
 assert.match(migration,/c\.owner_user_id\s*=\s*p_actor_user_id/i);
 assert.match(migration,/'response_message_id',\s*v_message_id/i);
 assert.doesNotMatch(migration,/ORDER BY[\s\S]{0,100}sequence_no[\s\S]{0,100}LIMIT 1/i);
});
