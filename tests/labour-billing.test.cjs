"use strict";

const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const {
  RATE_CARD_VERSION,
  RATE_CARD,
  MINUTES_PER_8_HOURS,
  calculateLabourPaise,
  calculateBillableMinutesFromElapsedSeconds,
  calculateEstimatePaise
} = require("../lib/labour-billing.js");

test("publishes a versioned customer gross labour rate card in integer paise", () => {
  assert.equal(RATE_CARD_VERSION, "SRK-CUSTOMER-LABOUR-2026-11-13-V1");
  assert.deepEqual(Object.values(RATE_CARD).map(x => x.rate8hPaise), [89900, 119900, 159900, 199900]);
  assert.equal(MINUTES_PER_8_HOURS, 480);
});

test("calculates one-hour and eight-hour estimates exactly", () => {
  assert.equal(calculateEstimatePaise("electrical_assistant", 1), 11238);
  assert.equal(calculateEstimatePaise("electrical_assistant", 8), 89900);
  assert.equal(calculateEstimatePaise("skilled_electrician", 8), 119900);
});

test("calculates actual 77 billable minutes from the approved rate", () => {
  assert.equal(calculateLabourPaise(89900, 77), 14421);
});

test("applies half-up rounding when the fraction is exactly half a paisa", () => {
  assert.equal(calculateLabourPaise(1, 240), 1);
});

test("rounds down when the fractional part is below half a paisa", () => {
  assert.equal(calculateLabourPaise(1, 239), 0);
});

test("rounds up when the fractional part is above half a paisa", () => {
  assert.equal(calculateLabourPaise(1, 241), 1);
});

test("does not cap billable minutes at eight hours", () => {
  assert.equal(calculateLabourPaise(89900, 960), 179800);
  assert.equal(calculateLabourPaise(89900, 1500), 280938);
});

test("zero billable minutes produces zero labour", () => {
  assert.equal(calculateLabourPaise(89900, 0), 0);
});

test("rejects invalid rate and minute values", () => {
  for (const value of [0, -1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => calculateLabourPaise(value, 1), TypeError);
  }
  for (const value of [-1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => calculateLabourPaise(89900, value), TypeError);
  }
});

test("rejects unknown categories and expected durations outside 1-8 hours", () => {
  assert.throws(() => calculateEstimatePaise("unknown", 1), /unknown/);
  for (const hours of [0, 9, 1.5, NaN]) {
    assert.throws(() => calculateEstimatePaise("electrical_assistant", hours), /expectedHours/);
  }
});

test("rejects amounts outside the safe integer range", () => {
  assert.throws(() => calculateLabourPaise(Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER), RangeError);
});

test("rounds any partial elapsed minute up to the next billable minute", () => {
  assert.equal(calculateBillableMinutesFromElapsedSeconds(0), 0);
  assert.equal(calculateBillableMinutesFromElapsedSeconds(1), 1);
  assert.equal(calculateBillableMinutesFromElapsedSeconds(599), 10);
  assert.equal(calculateBillableMinutesFromElapsedSeconds(600), 10);
  assert.equal(calculateBillableMinutesFromElapsedSeconds(620), 11);
  assert.equal(calculateBillableMinutesFromElapsedSeconds(86401), 1441);
});

test("rejects invalid elapsed seconds", () => {
  for (const value of [-1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => calculateBillableMinutesFromElapsedSeconds(value), TypeError);
  }
});


test("finance reporting migration exposes separate new Platform Fee and legacy commission fields", () => {
  const migrationPath = path.join(__dirname, "../supabase/migrations/20261114050000_correct_legacy_and_platform_fee_reporting.sql");
  const migration = fs.readFileSync(migrationPath, "utf8");
  assert.match(migration, /platform_fee_amount numeric/);
  assert.match(migration, /legacy_commission_amount numeric/);
  assert.match(migration, /'total_platform_fee',t\.platform_fee/);
  assert.match(migration, /'total_legacy_commission',t\.legacy_commission/);
  assert.match(migration, /AS legacy_commission/);
});

test("electrician earnings UI renders Platform Fee and historical commission independently", () => {
  const html = fs.readFileSync(path.join(__dirname, "../electrician.html"), "utf8");
  assert.match(html, /Number\(x\.platform_fee_amount\|\|0\)/);
  assert.match(html, /Number\(x\.legacy_commission_amount\|\|0\)/);
  assert.match(html, /पुरानी कमीशन/);
});


test("accepted electrician keeps customer contact during pending work-start approval", () => {
  const migration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261114050000_correct_legacy_and_platform_fee_reporting.sql"), "utf8");
  assert.match(migration, /awaiting_work_start_approval/);
  assert.match(migration, /THEN b\.phone ELSE NULL END/);
  assert.match(migration, /b\.assigned_electrician_id=p\.id/);
});
