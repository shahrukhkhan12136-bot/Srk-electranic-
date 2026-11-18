const test = require("node:test");
const assert = require("node:assert/strict");
const { INITIAL_RATES_PAISE, validateRateCatalogue, calculateLabourPaise } = require("../lib/commercial-rate-policy");

test("accepts the four initial commercial tiers", () => {
  assert.deepEqual(validateRateCatalogue(INITIAL_RATES_PAISE), { valid: true });
});

test("allows an independent rate reduction such as 899 to 599 rupees", () => {
  const rates = { ...INITIAL_RATES_PAISE, electrical_assistant: 59900 };
  assert.deepEqual(validateRateCatalogue(rates), { valid: true });
});

test("allows rate increases without a percentage cap", () => {
  const rates = { ...INITIAL_RATES_PAISE, electrical_assistant: 999999999 };
  assert.deepEqual(validateRateCatalogue(rates), { valid: true });
});

test("rejects zero, negative, fractional, unsafe, missing and unknown tier values", () => {
  for (const invalid of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1, null, "59900"]) {
    assert.equal(validateRateCatalogue({ ...INITIAL_RATES_PAISE, electrical_assistant: invalid }).valid, false);
  }
  const { premium_electrical_specialist, ...missing } = INITIAL_RATES_PAISE;
  assert.equal(validateRateCatalogue(missing).valid, false);
  assert.equal(validateRateCatalogue({ ...INITIAL_RATES_PAISE, unknown: 1 }).valid, false);
});

test("calculates a duration estimate using integer paise", () => {
  assert.equal(calculateLabourPaise(89900, 8), 89900);
  assert.equal(calculateLabourPaise(89900, 4), 44950);
  assert.throws(() => calculateLabourPaise(0, 8), TypeError);
  assert.throws(() => calculateLabourPaise(89900, 0), RangeError);
});
