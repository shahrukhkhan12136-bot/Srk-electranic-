"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migrationPath = path.join(__dirname, "..", "supabase", "migrations", "20261118260000_ai_conversation_create_rpc.sql");
const migration = fs.readFileSync(migrationPath, "utf8");

test("AI conversation creation RPC is service-role-only and validates its actor and module", () => {
  assert.ok(migration.includes("auth.role() IS DISTINCT FROM 'service_role'"));
  assert.ok(migration.includes("p_actor_user_id IS NULL OR p_module_key IS NULL"));
  for (const moduleKey of ["customer_support", "booking_assistant", "electrician_assistant"]) {
    assert.ok(migration.includes("'" + moduleKey + "'"), "missing module " + moduleKey);
  }
  assert.ok(migration.includes("REVOKE ALL ON FUNCTION public.srk_ai_create_conversation(uuid,text)"));
  assert.ok(migration.includes("GRANT EXECUTE ON FUNCTION public.srk_ai_create_conversation(uuid,text)"));
});

test("AI conversation creation writes the conversation and audit event in one transaction", () => {
  assert.ok(migration.includes("INSERT INTO public.srk_ai_conversations (owner_user_id, module_key)"));
  assert.ok(migration.includes("'conversation_created', 'accepted'"));
  assert.ok(migration.includes("v_conversation_id, p_actor_user_id, p_module_key"));
  assert.ok(migration.includes("'state','created'"));
  assert.ok(migration.includes("'conversation_id',v_conversation_id"));
  assert.match(migration, /BEGIN;[\s\S]*COMMIT;/i);
  assert.doesNotMatch(migration, /prompt_body|message_body|provider_api_key/i);
});
