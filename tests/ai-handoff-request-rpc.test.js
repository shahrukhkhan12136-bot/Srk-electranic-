"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migrationPath = path.join(__dirname, "..", "supabase", "migrations", "20261118220000_ai_handoff_request_rpc.sql");
const migration = fs.readFileSync(migrationPath, "utf8");

test("AI handoff request RPC is service-role-only and validates request fields", () => {
  assert.match(migration, /auth\.role\(\)\s+IS DISTINCT FROM\s+'service_role'/i);
  assert.match(migration, /p_reason_code NOT IN/i);
  assert.match(migration, /p_urgency NOT IN \('low','normal','high'\)/i);
  assert.match(migration, /p_summary IS NULL OR length\(btrim\(p_summary\)\) NOT BETWEEN 1 AND 1000/i);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_ai_request_handoff\(uuid,uuid,text,text,text\)\s+TO service_role/i);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.srk_ai_request_handoff\(uuid,uuid,text,text,text\)\s+FROM PUBLIC, anon, authenticated/i);
});

test("AI handoff locks and verifies conversation ownership and is idempotent for queued handoffs", () => {
  assert.match(migration, /WHERE conversation\.id = p_conversation_id\s+FOR UPDATE/i);
  assert.match(migration, /v_owner_user_id <> p_actor_user_id/i);
  assert.match(migration, /v_status = 'handoff_requested'/i);
  assert.match(migration, /queue\.status IN \('queued','assigned'\)/i);
  for (const state of ["not_found", "access_denied", "already_queued", "handoff_unavailable", "conversation_not_open", "queued"]) {
    assert.ok(migration.includes("'state','" + state + "'"), "missing state " + state);
  }
});

test("AI handoff queue insertion and conversation status transition share one transaction", () => {
  assert.match(migration, /INSERT INTO public\.srk_ai_handoff_queue/i);
  assert.match(migration, /UPDATE public\.srk_ai_conversations\s+SET status = 'handoff_requested'/i);
  assert.match(migration, /BEGIN;[\s\S]*COMMIT;/i);
  assert.doesNotMatch(migration, /send_email|send_sms|webhook|provider_api_key/i);
});
