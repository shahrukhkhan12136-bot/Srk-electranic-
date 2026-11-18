"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migrationPath = path.join(__dirname, "..", "supabase", "migrations", "20261118210000_ai_message_append_rpc.sql");
const migration = fs.readFileSync(migrationPath, "utf8");

test("AI message append RPC is service-role-only and validates sender/body", () => {
  assert.match(migration, /auth\.role\(\)\s+IS DISTINCT FROM\s+'service_role'/i);
  assert.match(migration, /p_sender_kind NOT IN \('user','assistant'\)/i);
  assert.match(migration, /p_body IS NULL OR length\(btrim\(p_body\)\) NOT BETWEEN 1 AND 4000/i);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_ai_append_message\(uuid,uuid,text,text\)\s+TO service_role/i);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.srk_ai_append_message\(uuid,uuid,text,text\)\s+FROM PUBLIC, anon, authenticated/i);
});

test("AI message append locks and verifies the conversation owner and open state", () => {
  assert.match(migration, /WHERE conversation\.id = p_conversation_id\s+FOR UPDATE/i);
  assert.match(migration, /v_owner_user_id <> p_actor_user_id/i);
  assert.match(migration, /v_status <> 'open'/i);
  for (const state of ["not_found", "access_denied", "conversation_not_open", "appended"]) {
    assert.ok(migration.includes("'state','" + state + "'"), "missing state " + state);
  }
});

test("AI message append derives sender identity and stores only user/assistant messages", () => {
  assert.match(migration, /CASE WHEN p_sender_kind = 'user' THEN p_actor_user_id ELSE NULL END/i);
  assert.match(migration, /INSERT INTO public\.srk_ai_messages/i);
  assert.match(migration, /UPDATE public\.srk_ai_conversations\s+SET updated_at = clock_timestamp\(\)/i);
  assert.doesNotMatch(migration, /provider_api_key|service_role_key|authorization_header/i);
});
