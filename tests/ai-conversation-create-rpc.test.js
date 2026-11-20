"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migrationPath = path.join(__dirname, "..", "supabase", "migrations", "20261118260000_ai_conversation_create_rpc.sql");
const migration = fs.readFileSync(migrationPath, "utf8");

test("AI conversation creation RPC is service-role-only and validates its actor and module", () => {
  assert.match(migration, /auth\\.role\\(\\)\\s+IS DISTINCT FROM\\s+'service_role'/i);
  assert.match(migration, /p_actor_user_id IS NULL OR p_module_key IS NULL/i);
  assert.match(migration, /'customer_support','booking_assistant','electrician_assistant'/i);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\\.srk_ai_create_conversation\\(uuid,text\\)\\s+FROM PUBLIC, anon, authenticated/i);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\\.srk_ai_create_conversation\\(uuid,text\\)\\s+TO service_role/i);
});

test("AI conversation creation writes the conversation and audit event in one transaction", () => {
  assert.match(migration, /INSERT INTO public\\.srk_ai_conversations \\(owner_user_id, module_key\\)/i);
  assert.match(migration, /INSERT INTO public\\.srk_ai_audit_events\\s*\\(\\s*conversation_id, actor_user_id, module_key, action_key, outcome\\s*\\)\\s*VALUES\\s*\\(\\s*v_conversation_id, p_actor_user_id, p_module_key,\\s*'conversation_created', 'accepted'\\s*\\)/i);
  assert.match(migration, /RETURN jsonb_build_object\\(\\s*'state','created',\\s*'conversation_id',v_conversation_id\\s*\\)/i);
  assert.match(migration, /BEGIN;[\\s\\S]*COMMIT;/i);
  assert.doesNotMatch(migration, /prompt_body|message_body|provider_api_key/i);
});
