"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migrationPath = path.join(__dirname, "..", "supabase", "migrations", "20261118230000_admin_ai_handoff_queue_read_rpc.sql");
const migration = fs.readFileSync(migrationPath, "utf8");

test("AI handoff queue read is Main Admin-only and bounded", () => {
  assert.match(migration, /auth\.uid\(\)\s+IS NULL OR NOT public\.is_srk_admin\(\)/i);
  assert.match(migration, /p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100/i);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_admin_list_ai_handoff_queue\(integer\)\s+TO authenticated/i);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.srk_admin_list_ai_handoff_queue\(integer\)\s+FROM PUBLIC, anon/i);
  assert.match(migration, /SET search_path = ''/i);
  assert.match(migration, /SECURITY DEFINER/i);
});

test("AI handoff queue read returns only active queue metadata in deterministic priority order", () => {
  assert.match(migration, /JOIN public\.srk_ai_conversations c ON c\.id=q\.conversation_id/i);
  assert.match(migration, /WHERE q\.status IN \('queued','assigned'\)/i);
  assert.match(migration, /WHEN 'high' THEN 0 WHEN 'normal' THEN 1 ELSE 2 END/i);
  assert.match(migration, /q\.created_at ASC,\s*q\.id ASC/i);
  assert.doesNotMatch(migration, /INSERT INTO|UPDATE public\.srk_ai_handoff_queue|DELETE FROM|send_email|send_sms|webhook/i);
});
