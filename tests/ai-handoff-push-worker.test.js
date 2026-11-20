const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (name) => fs.readFileSync(path.join(root, name), "utf8");

test("AI handoff push scheduler is disabled unless explicitly enabled", () => {
  const source = read("netlify/functions/deliver-ai-handoff-notifications.js");
  assert.match(source, /AI_HANDOFF_PUSH_ENABLED !== "true"/);
  assert.match(source, /disabled: true/);
  assert.match(source, /x-srk-ai-handoff-push-secret/);
});

test("AI handoff push sender requires enable flag and a private worker secret", () => {
  const source = read("supabase/functions/ai-handoff-push/index.ts");
  assert.match(source, /AI_HANDOFF_PUSH_ENABLED.*=== "true"/);
  assert.match(source, /x-srk-ai-handoff-push-secret/);
  assert.match(source, /srk_claim_ai_handoff_notification_outbox/);
  assert.match(source, /srk_claim_ai_handoff_subscription_deliveries/);
});

test("AI handoff push payload contains only a minimal staff alert", () => {
  const source = read("supabase/functions/ai-handoff-push/index.ts");
  assert.match(source, /type: "ai_handoff"/);
  assert.match(source, /handoffId: event\.handoff_id/);
  assert.doesNotMatch(source, /select\(["'][^"']*(?:summary|body|phone|customer)[^"']*["']\)/i);
});

test("AI handoff device delivery uses its isolated, service-role-only ledger", () => {
  const migration = read("supabase/migrations/20261118290000_ai_handoff_push_subscription_ledger.sql");
  assert.match(migration, /REFERENCES srk_private\.srk_ai_handoff_notification_outbox/);
  assert.match(migration, /ENABLE ROW LEVEL SECURITY/);
  assert.match(migration, /FROM PUBLIC,anon,authenticated/);
  assert.match(migration, /locked_until/);
});
