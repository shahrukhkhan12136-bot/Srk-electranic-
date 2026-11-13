"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  RATE_CARD_VERSION,
  RATE_CARD,
  MINUTES_PER_8_HOURS,
  calculateLabourPaise,
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
