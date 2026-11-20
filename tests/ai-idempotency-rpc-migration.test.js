"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const migration = fs.readFileSync(path.join(__dirname,"..","supabase","migrations","20261118190000_ai_idempotency_reservation_rpc.sql"),"utf8");
const digest = createHash("sha256").update("request").digest();

test("AI reservation RPC is service-role-only and validates SHA-256 digest length",()=>{
 assert.match(migration,/auth\.role\(\)\s+IS DISTINCT FROM\s+'service_role'/i);
 assert.match(migration,/octet_length\(p_request_sha256\)\s*<>\s*32/i);
 assert.match(migration,/REVOKE ALL ON FUNCTION public\.srk_ai_reserve_idempotency\(uuid,uuid,bytea\)\s+FROM PUBLIC, anon, authenticated/i);
 assert.match(migration,/GRANT EXECUTE ON FUNCTION public\.srk_ai_reserve_idempotency\(uuid,uuid,bytea\)\s+TO service_role/i);
 assert.equal(digest.length,32);
});

test("AI reservation uses actor-scoped uniqueness and fences expired processing leases by digest",()=>{
 assert.match(migration,/ON CONFLICT \(actor_user_id,idempotency_key\) DO NOTHING/i);
 assert.match(migration,/processing_lease_expires_at\s*<=\s*v_now/i);
 assert.match(migration,/v_existing\.request_sha256\s*<>\s*p_request_sha256/i);
 assert.match(migration,/lease_version\s*=\s*lease_version\s*\+\s*1/i);
 assert.match(migration,/interval '5 minutes'/i);
 assert.match(migration,/v_existing\.status='processing'/i);
 assert.doesNotMatch(migration,/expires_at\s*<=\s*clock_timestamp\(\)/i);
});

test("AI reservation replays exact completed response and retains completed/failed keys for seven days",()=>{
 assert.match(migration,/v_existing\.status='completed' AND v_existing\.retention_expires_at>=v_now/i);
 assert.match(migration,/v_existing\.status='failed' AND v_existing\.retention_expires_at>=v_now/i);
 assert.match(migration,/m\.id=v_existing\.response_message_id/i);
 assert.match(migration,/m\.sender_kind='assistant'/i);
 assert.match(migration,/'response_message_id',v_message_id/i);
 assert.match(migration,/'state','failed'/i);
});

test("AI reservation stores only a request digest and exact response reference, never request or response bodies",()=>{
 assert.doesNotMatch(migration,/p_request_body|p_prompt|p_response_body|response_body|message_body/i);
 assert.match(migration,/request_sha256/);
 assert.match(migration,/response_message_id/);
});
