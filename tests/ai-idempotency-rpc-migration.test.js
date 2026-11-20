"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const migrationPath = path.join(__dirname, "..", "supabase", "migrations", "20261118190000_ai_idempotency_reservation_rpc.sql");
const migration = fs.readFileSync(migrationPath, "utf8");
const digest = createHash("sha256").update("request").digest();

test("AI idempotency reservation RPC is service-role-only and validates SHA-256 digest length", () => {
  assert.match(migration, /auth\.role\(\)\s+IS DISTINCT FROM\s+'service_role'/i);
  assert.match(migration, /octet_length\(p_request_sha256\)\s*<>\s*32/i);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.srk_ai_reserve_idempotency\(uuid,uuid,bytea\)\s+FROM PUBLIC, anon, authenticated/i);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_ai_reserve_idempotency\(uuid,uuid,bytea\)\s+TO service_role/i);
  assert.equal(digest.length, 32);
});

test("AI idempotency reservation uses actor-scoped uniqueness and atomically reclaims any expired lease", () => {
  assert.match(migration, /ON CONFLICT \(actor_user_id, idempotency_key\) DO UPDATE/i);
  assert.match(migration, /WHERE current_row\.expires_at <= clock_timestamp\(\)/i);
  assert.doesNotMatch(migration, /current_row\.status\s*<>\s*'processing'/i);
  assert.match(migration, /FOR UPDATE/i);
  assert.match(migration, /request_sha256 <> p_request_sha256/i);
  assert.match(migration, /interval '24 hours'/i);
});

test("AI idempotency reservation distinguishes reserved, conflict, replay, processing and failed states", () => {
  for (const state of ["reserved", "conflict", "replay", "processing", "failed"]) {
    assert.ok(migration.includes("'state','" + state + "'"), "missing state " + state);
  }
  assert.match(migration, /response_code.*conversation_id/s);
});

test("AI idempotency reservation never stores a raw request or response body", () => {
  assert.doesNotMatch(migration, /p_request_body|p_prompt|response_body|message_body/i);
  assert.match(migration, /request_sha256/);
});
