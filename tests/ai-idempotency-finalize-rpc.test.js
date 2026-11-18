"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migrationPath = path.join(__dirname, "..", "supabase", "migrations", "20261118200000_ai_idempotency_finalize_rpc.sql");
const migration = fs.readFileSync(migrationPath, "utf8");

test("AI idempotency finalization is service-role-only and validates final result inputs", () => {
  assert.match(migration, /auth\.role\(\)\s+IS DISTINCT FROM\s+'service_role'/i);
  assert.match(migration, /octet_length\(p_request_sha256\)\s*<>\s*32/i);
  assert.match(migration, /p_final_status NOT IN \('completed','failed'\)/i);
  assert.match(migration, /p_response_code NOT BETWEEN 100 AND 599/i);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_ai_finalize_idempotency\(uuid,uuid,bytea,text,integer,uuid\)\s+TO service_role/i);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.srk_ai_finalize_idempotency\(uuid,uuid,bytea,text,integer,uuid\)\s+FROM PUBLIC, anon, authenticated/i);
});

test("AI idempotency finalization only transitions a matching processing claim", () => {
  assert.match(migration, /claim\.request_sha256 = p_request_sha256/i);
  assert.match(migration, /claim\.status = 'processing'/i);
  assert.match(migration, /SET status = p_final_status[\s\S]*completed_at = clock_timestamp\(\)/i);
});

test("AI idempotency finalization checks conversation ownership and handles retries safely", () => {
  assert.match(migration, /conversation\.owner_user_id = p_actor_user_id/i);
  for (const state of ["finalized", "already_finalized", "conflict", "not_found", "not_processing"]) {
    assert.ok(migration.includes("'state','" + state + "'"), "missing state " + state);
  }
  assert.match(migration, /IS NOT DISTINCT FROM p_conversation_id/i);
  assert.doesNotMatch(migration, /response_body|message_body|prompt_body/i);
});
