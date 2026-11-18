const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migration = fs.readFileSync(
  path.join(__dirname, "../supabase/migrations/20261118110000_unify_electrician_rate_rounding.sql"),
  "utf8"
);
const ui = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");

test("versioned electrician rate list uses the canonical rounded 15 percent commission", () => {
  assert.match(migration, /electrician_rate_paise',\(i\.customer_rate_paise - floor\(\(i\.customer_rate_paise::numeric\*1500\/10000\)\+0\.5\)::bigint\)/);
});

test("offer RPC uses the same canonical net formula as the rate list", () => {
  assert.match(migration, /b\.estimated_labour_paise - floor\(\(b\.estimated_labour_paise::numeric\*1500\/10000\)\+0\.5\)::bigint/);
  assert.doesNotMatch(migration, /estimated_labour_paise::numeric\*8500/);
});

test("electrician app renders only the backend-calculated offer amount", () => {
  assert.match(ui, /o\.electrician_offer_paise/);
  assert.doesNotMatch(ui, /o\.estimated_labour_paise/);
});

test("half-paise ties reconcile to the existing payout commission rule", () => {
  const roundHalfUp = (gross) => Math.floor((gross * 1500 / 10000) + 0.5);
  for (const [gross, expectedNet] of [[10, 8], [30, 25], [50, 42], [70, 59], [100000, 85000]]) {
    assert.equal(gross - roundHalfUp(gross), expectedNet);
  }
});

test("electrician rate list rejects malformed, non-positive, or non-8-hour server amounts before rendering", () => {
  assert.match(ui, /!Number\.isSafeInteger\(item\.electrician_rate_paise\)/);
  assert.match(ui, /item\.electrician_rate_paise<=0/);
  assert.match(ui, /item\.duration_hours!==8/);
  assert.match(ui, /typeof rateList\.rate_version_id!=='string'/);
  assert.match(ui, /rateList\.items\.some\(item=>/);
});
