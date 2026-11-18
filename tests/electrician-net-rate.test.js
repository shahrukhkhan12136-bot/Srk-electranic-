const test = require("node:test");
const assert = require("node:assert/strict");
const { calculateElectricianNetPaise, calculateInternalResidualPaise } = require("../lib/electrician-net-rate");
const { INITIAL_RATES_PAISE } = require("../lib/commercial-rate-policy");

test("1000 rupees gross labour yields 850 net and 150 internal residual", () => {
  assert.equal(calculateElectricianNetPaise(100000), 85000);
  assert.equal(calculateInternalResidualPaise(100000), 15000);
});

test("899 rupees gross labour yields rounded net paise", () => {
  assert.equal(calculateElectricianNetPaise(89900), 76415);
  assert.equal(calculateInternalResidualPaise(89900), 13485);
});

test("all four 8-hour category rates derive the expected electrician 85 percent", () => {
  assert.deepEqual(
    Object.fromEntries(Object.entries(INITIAL_RATES_PAISE).map(([tier, gross]) => [tier, calculateElectricianNetPaise(gross)])),
    {
      electrical_assistant: 76415,
      skilled_electrician: 101915,
      expert_electrician: 135915,
      premium_electrical_specialist: 169915
    }
  );
});

test("Admin rate edits automatically derive the new 85 percent amount", () => {
  assert.equal(calculateElectricianNetPaise(99900), 84915);
  assert.equal(calculateElectricianNetPaise(149900), 127415);
});

test("rejects zero, negative, fractional and unsafe amounts", () => {
  for (const value of [0, -1, 1.5, Number.MAX_SAFE_INTEGER]) {
    assert.throws(() => calculateElectricianNetPaise(value));
  }
});
