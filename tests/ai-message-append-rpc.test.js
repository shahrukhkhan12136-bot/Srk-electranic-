"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const migration = fs.readFileSync(path.join(__dirname,"..","supabase","migrations","20261118210000_ai_message_append_rpc.sql"),"utf8");

test("AI message append RPC is service-role-only, user-only, and validates body",()=>{
 assert.match(migration,/auth\.role\(\)\s+IS DISTINCT FROM\s+'service_role'/i);
 assert.match(migration,/p_sender_kind\s*<>\s*'user'/i);
 assert.match(migration,/p_body IS NULL OR length\(btrim\(p_body\)\) NOT BETWEEN 1 AND 4000/i);
 assert.match(migration,/GRANT EXECUTE ON FUNCTION public\.srk_ai_append_message\(uuid,uuid,text,text\)\s+TO service_role/i);
 assert.match(migration,/REVOKE ALL ON FUNCTION public\.srk_ai_append_message\(uuid,uuid,text,text\)\s+FROM PUBLIC, anon, authenticated/i);
});

test("AI user-message append locks and verifies the conversation owner and open state",()=>{
 assert.match(migration,/WHERE conversation\.id = p_conversation_id\s+FOR UPDATE/i);
 assert.match(migration,/v_owner_user_id <> p_actor_user_id/i);
 assert.match(migration,/v_status <> 'open'/i);
 for(const state of ["not_found","access_denied","conversation_not_open","appended"])
  assert.ok(migration.includes("'state','"+state+"'"),"missing state "+state);
});

test("AI append derives the sender identity from the actor and cannot insert assistant messages",()=>{
 assert.match(migration,/v_sender_user_id\s*:=\s*p_actor_user_id/i);
 assert.match(migration,/INSERT INTO public\.srk_ai_messages/i);
 assert.match(migration,/UPDATE public\.srk_ai_conversations\s+SET updated_at = clock_timestamp\(\)/i);
 assert.doesNotMatch(migration,/CASE WHEN p_sender_kind/i);
 assert.doesNotMatch(migration,/provider_api_key|service_role_key|authorization_header/i);
});

test("recorded user messages append a metadata-only audit event using the conversation module",()=>{
 assert.match(migration,/SELECT conversation\.owner_user_id, conversation\.module_key, conversation\.status/i);
 assert.match(migration,/INSERT INTO public\.srk_ai_audit_events\s*\([\s\S]*?'message_recorded', 'completed'/i);
 assert.match(migration,/UPDATE public\.srk_ai_conversations[\s\S]*?INSERT INTO public\.srk_ai_audit_events/i);
});
