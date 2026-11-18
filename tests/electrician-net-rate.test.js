const test = require("node:test");
const assert = require("node:assert/strict");
const { calculateElectricianNetPaise, calculateInternalResidualPaise } = require("../lib/electrician-net-rate");

test("1000 rupees gross labour yields 850 net and 150 internal residual", () => {
  assert.equal(calculateElectricianNetPaise(100000), 85000);
  assert.equal(calculateInternalResidualPaise(100000), 15000);
});

test("899 rupees gross labour yields rounded net paise", () => {
  assert.equal(calculateElectricianNetPaise(89900), 76415);
  assert.equal(calculateInternalResidualPaise(89900), 13485);
});

test("rejects zero, negative, fractional and unsafe amounts", () => {
  for (const value of [0, -1, 1.5, Number.MAX_SAFE_INTEGER]) {
    assert.throws(() => calculateElectricianNetPaise(value));
  }
});
