const test = require("node:test");
const assert = require("node:assert/strict");
const { calculateElectricianNetPaise, calculateElectricianRateListPaise, calculateInternalResidualPaise } = require("../lib/electrician-net-rate");
const { INITIAL_RATES_PAISE } = require("../lib/commercial-rate-policy");

test("1000 rupees gross labour yields 850 net and 150 internal residual", () => {
  assert.equal(calculateElectricianNetPaise(100000), 85000);
  assert.equal(calculateInternalResidualPaise(100000), 15000);
});

test("899 rupees gross labour yields rounded net paise", () => {
  assert.equal(calculateElectricianNetPaise(89900), 76415);
  assert.equal(calculateInternalResidualPaise(89900), 13485);
});

test("rounding follows the existing rounded 15 percent commission and always reconciles to gross", () => {
  const grossPaise = 10;
  const netPaise = calculateElectricianNetPaise(grossPaise);
  const companyPaise = calculateInternalResidualPaise(grossPaise);
  assert.equal(netPaise, 8);
  assert.equal(companyPaise, 2);
  assert.equal(netPaise + companyPaise, grossPaise);
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
  for (const value of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => calculateElectricianNetPaise(value));
  }
});

test("rate-list amount is calculated directly as 85 percent with integer-paise half-up rounding", () => {
  assert.equal(calculateElectricianRateListPaise(100000), 85000);
  assert.equal(calculateElectricianRateListPaise(89900), 76415);
  assert.equal(calculateElectricianRateListPaise(99900), 84915);
});

test("direct 85 percent rate-list calculation rounds exact half-paise ties upward", () => {
  assert.equal(calculateElectricianRateListPaise(10), 9);  // 8.5 paise
  assert.equal(calculateElectricianRateListPaise(30), 26); // 25.5 paise
  assert.equal(calculateElectricianRateListPaise(50), 43); // 42.5 paise
  assert.equal(calculateElectricianRateListPaise(70), 60); // 59.5 paise
});

test("rate-list 85 percent is not passed through a second 15 percent deduction", () => {
  const displayed = calculateElectricianRateListPaise(100000);
  assert.equal(displayed, 85000);
  assert.notEqual(displayed, calculateElectricianNetPaise(displayed));
});

test("rate-list helper rejects invalid integer-paise amounts", () => {
  for (const value of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => calculateElectricianRateListPaise(value));
  }
});
