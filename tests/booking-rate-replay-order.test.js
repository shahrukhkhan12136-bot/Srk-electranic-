"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "..", "create-booking.js"), "utf8");

test("idempotent booking replay is resolved before requiring the current published catalogue", () => {
  const existingLookup = source.indexOf("const existingRows = await findByRequestKey()");
  const replayResponse = source.indexOf("replayed: true", existingLookup);
  const catalogueLookup = source.indexOf("rpc/srk_get_current_customer_rate_catalogue");
  assert.ok(existingLookup >= 0, "existing idempotency key lookup exists");
  assert.ok(replayResponse > existingLookup, "saved booking replay response follows lookup");
  assert.ok(catalogueLookup > replayResponse, "new-rate catalogue is loaded only after replay path");
});

test("replayed booking returns its persisted amount and catalogue version, not newly calculated values", () => {
  const replayStart = source.indexOf("if (existing) {");
  const replayEnd = source.indexOf("\n    }\n    // The service-role server", replayStart);
  assert.ok(replayStart >= 0 && replayEnd > replayStart, "existing booking replay block exists");
  const replay = source.slice(replayStart, replayEnd);
  assert.match(replay, /existing\.estimated_labour_paise/);
  assert.match(replay, /existing\.estimate_rate_card_version/);
  assert.match(replay, /loadReplayDetails\(existing\)/);
  assert.doesNotMatch(replay, /rateCard\[selected_rate_tier\]/);
});

test("new booking still requires the server-loaded published catalogue", () => {
  const catalogueLookup = source.indexOf("rpc/srk_get_current_customer_rate_catalogue");
  const insert = source.indexOf('supabase("service_bookings", {', catalogueLookup);
  assert.ok(catalogueLookup >= 0 && insert > catalogueLookup);
  assert.match(source.slice(catalogueLookup, insert), /Number\.isSafeInteger\(rateCard\[selected_rate_tier\]\)/);
  assert.match(source.slice(catalogueLookup, insert), /estimate_rate_card_version: rateCardVersion/);
});

test("saved booking replay treats offer and historical-rate metadata as best-effort", () => {
  const helperStart = source.indexOf("async function loadReplayDetails(booking)");
  const helperEnd = source.indexOf("\nasync function checkPublicRateLimit", helperStart);
  assert.ok(helperStart >= 0 && helperEnd > helperStart, "replay metadata helper exists");
  const helper = source.slice(helperStart, helperEnd);
  assert.match(helper, /catch \(error\)/);
  assert.match(helper, /offersCreated = null/);
  assert.match(helper, /rate8hPaise = null/);
  assert.match(helper, /return \{ offersCreated, matchLevel, rate8hPaise \}/);
  assert.match(source, /loadReplayDetails\(raced\)/);
});


test("unique-key race replay also returns the persisted booking snapshot", () => {
  const raceStart = source.indexOf("const racedRows = await findByRequestKey()");
  const raceEnd = source.indexOf("\n    }\n    const booking =", raceStart);
  assert.ok(raceStart >= 0 && raceEnd > raceStart, "unique-key race replay block exists");
  const replay = source.slice(raceStart, raceEnd);
  assert.match(replay, /raced\.estimated_labour_paise/);
  assert.match(replay, /raced\.estimate_rate_card_version/);
  assert.match(replay, /loadReplayDetails\(raced\)/);
  assert.doesNotMatch(replay, /rateCard\[selected_rate_tier\]/);
});

test("new booking persists server-derived estimate and catalogue version as the immutable snapshot inputs", () => {
  const catalogueLookup = source.indexOf("rpc/srk_get_current_customer_rate_catalogue");
  const insertStart = source.indexOf('inserted = await supabase("service_bookings"', catalogueLookup);
  const insertEnd = source.indexOf("\n      });", insertStart);
  assert.ok(catalogueLookup >= 0 && insertStart > catalogueLookup && insertEnd > insertStart);
  const insert = source.slice(insertStart, insertEnd);
  assert.match(insert, /estimated_labour_paise:\s*estimatedLabourPaise/);
  assert.match(insert, /estimate_rate_card_version:\s*rateCardVersion/);
  assert.match(insert, /selected_rate_tier/);
  assert.match(insert, /selected_duration_hours/);
});
