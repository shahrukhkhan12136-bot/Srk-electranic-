"use strict";

// Supplemental documentation guard only. These assertions do NOT exercise PostgreSQL
// transactions, concurrency, RLS, grants, or RPC behavior. GPT-2 must run the real
// non-production database test matrix in docs/ai-idempotency-db-test-plan.md.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const contractPath = path.join(__dirname, "..", "docs", "ai-gateway-idempotency-contract.md");
const planPath = path.join(__dirname, "..", "docs", "ai-idempotency-db-test-plan.md");
const contract = fs.readFileSync(contractPath, "utf8");
const plan = fs.readFileSync(planPath, "utf8");

test("AI idempotency handoff documents fail-closed exact response replay", () => {
  assert.match(contract, /response_message_id/);
  assert.match(contract, /sender_kind = 'assistant'/);
  assert.match(contract, /Never fall back to the latest message/i);
  assert.match(contract, /fail-closed integrity error/i);
});

test("AI idempotency handoff documents atomic completion and fixed lock order", () => {
  assert.match(contract, /srk_ai_complete_idempotency/);
  assert.match(contract, /Idempotency Row → Conversation Row/);
  assert.match(contract, /same database transaction/i);
  assert.match(contract, /entire transaction/i);
});

test("AI idempotency handoff documents separate lease and retention windows", () => {
  assert.match(contract, /Processing lease:\*\* 5 minutes/);
  assert.match(contract, /Completed replay retention:\*\* 7 days/);
  assert.match(contract, /Failed record retention:\*\* 7 days/);
  assert.match(contract, /must not be reset or reclaimed/i);
});

test("AI idempotency handoff documents legacy RPC restrictions and security gates", () => {
  assert.match(contract, /finalize.*failed.*only/i);
  assert.match(contract, /cannot insert `assistant` messages/i);
  assert.match(contract, /RLS/i);
  assert.match(contract, /GRANT/i);
  assert.match(contract, /search_path/i);
});

test("AI idempotency database test plan requires real PostgreSQL transaction and concurrency tests", () => {
  assert.match(plan, /independent PostgreSQL sessions/i);
  assert.match(plan, /Transaction rollback/i);
  assert.match(plan, /Migration replay\/rollback/i);
  assert.match(plan, /NOT EXECUTED/);
  assert.match(plan, /Static repository tests may supplement but cannot replace/i);
});

test("AI idempotency handoff defines deterministic failed-key retry semantics", () => {
  assert.match(contract, /same actor\/key\/digest returns a stable failure result/i);
  assert.match(contract, /different digest returns a conflict/i);
  assert.match(contract, /failed record is never silently converted to success/i);
});

test("AI idempotency handoff defines inclusive retention expiry and strict cleanup", () => {
  assert.match(contract, /retention_expires_at >= transaction_timestamp\(\)/);
  assert.match(contract, /retention_expires_at < transaction_timestamp\(\)/);
  assert.match(plan, /exactly at `retention_expires_at`/);
});

test("AI idempotency handoff defines same-conversation concurrency and closed replay", () => {
  assert.match(contract, /Different idempotency keys targeting the same conversation/);
  assert.match(contract, /serialize at the conversation lock/);
  assert.match(contract, /later transition of that conversation to `closed` does \*\*not\*\* invalidate replay/);
  assert.match(plan, /Replay after conversation closure/);
  assert.match(plan, /Different keys, same conversation/);
});

test("AI idempotency handoff defines expired-lease fencing", () => {
  assert.match(contract, /lease_version/);
  assert.match(contract, /old worker's token no longer matches/);
  assert.match(plan, /old worker cannot complete/);
});
