"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migrationPath = path.join(
  __dirname,
  "..",
  "supabase",
  "migrations",
  "20261118160000_private_ai_conversation_persistence.sql"
);
const sql = fs.readFileSync(migrationPath, "utf8");

test("AI persistence creates separate private conversation, message, idempotency, handoff and audit records", () => {
  for (const table of [
    "srk_ai_conversations",
    "srk_ai_messages",
    "srk_ai_idempotency",
    "srk_ai_handoff_queue",
    "srk_ai_audit_events"
  ]) {
    assert.match(sql, new RegExp("CREATE TABLE IF NOT EXISTS public\\." + table + "\\b", "i"));
  }
  assert.match(sql, /REFERENCES public\.srk_ai_conversations\(id\)/);
  assert.doesNotMatch(sql, /srk_booking_complaint_messages|srk_electrician_support_messages/);
});

test("all AI persistence tables deny direct client access and grant database access only to service_role", () => {
  for (const table of [
    "srk_ai_conversations",
    "srk_ai_messages",
    "srk_ai_idempotency",
    "srk_ai_handoff_queue",
    "srk_ai_audit_events"
  ]) {
    assert.match(sql, new RegExp("ALTER TABLE public\\." + table + " ENABLE ROW LEVEL SECURITY", "i"));
    assert.match(sql, new RegExp("REVOKE ALL ON TABLE public\\." + table + " FROM PUBLIC,anon,authenticated", "i"));
    assert.match(sql, new RegExp("GRANT ALL ON TABLE public\\." + table + " TO service_role", "i"));
  }
});

test("idempotency is scoped to authenticated actor and stores a digest rather than request content", () => {
  assert.match(sql, /UNIQUE\s*\(actor_user_id\s*,\s*idempotency_key\)/i);
  assert.match(sql, /request_sha256 bytea NOT NULL CHECK \(octet_length\(request_sha256\)=32\)/i);
  assert.doesNotMatch(sql, /request_body|prompt_text|provider_payload/i);
});

test("AI audit schema contains metadata fields only and rejects updates and deletes", () => {
  const auditStart = sql.indexOf("CREATE TABLE IF NOT EXISTS public.srk_ai_audit_events");
  const auditEnd = sql.indexOf(");", auditStart);
  assert.ok(auditStart >= 0 && auditEnd > auditStart);
  const audit = sql.slice(auditStart, auditEnd);
  assert.match(audit, /module_key/);
  assert.match(audit, /action_key/);
  assert.match(audit, /outcome/);
  assert.doesNotMatch(audit, /body|prompt|token|payload|error_message/i);
  assert.match(sql, /BEFORE UPDATE OR DELETE ON public\.srk_ai_audit_events/i);
  assert.match(sql, /AI_AUDIT_EVENTS_ARE_APPEND_ONLY/);
});

test("AI persistence migration does not enable assistant routes or deploy a provider integration", () => {
  assert.match(sql, /SOURCE ONLY/i);
  assert.doesNotMatch(sql, /CREATE EXTENSION|net\.http_post|ALTER ROLE|CREATE POLICY/i);
});
