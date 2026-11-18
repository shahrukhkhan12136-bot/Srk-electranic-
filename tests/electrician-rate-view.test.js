const test = require("node:test");
const assert = require("node:assert/strict");
const { buildElectricianRateList, buildElectricianJobAccounting } = require("../lib/electrician-rate-view");
const { INITIAL_RATES_PAISE } = require("../lib/commercial-rate-policy");

test("electrician rate list contains only their approved categories and 85 percent amounts", () => {
  const result = buildElectricianRateList({
    rates: INITIAL_RATES_PAISE,
    approvedCategoryKeys: ["skilled_electrician"],
    categoryLabels: { skilled_electrician: "Skilled Electrician" },
    rateVersionId: "rate-v7",
    effectiveAt: "2026-11-18T00:00:00Z"
  });
  assert.deepEqual(result.items, [{
    category_key: "skilled_electrician",
    category_name: "Skilled Electrician",
    duration_hours: 8,
    electrician_rate_paise: 101915
  }]);
  assert.equal("customer_rate_paise" in result.items[0], false);
  assert.equal(result.items.length, 1);
});

test("rate list rejects an approved category without a source rate", () => {
  assert.throws(() => buildElectricianRateList({
    rates: INITIAL_RATES_PAISE, approvedCategoryKeys: ["unknown"],
    rateVersionId: "v1", effectiveAt: "2026-11-18T00:00:00Z"
  }));
});

test("unfinished job DTO does not include financial accounting", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b1", booking_status: "in_progress", payment_status: "pending",
    customer_amount_received_paise: 50000, company_share_paise: 7500, electrician_payable_paise: 42500
  });
  assert.equal("accounting" in result, false);
});

test("completed job DTO exposes only its own recorded accounting snapshot", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b2", booking_status: "completed", payment_status: "paid",
    customer_amount_received_paise: 89900, company_share_paise: 13485,
    electrician_payable_paise: 76415, payout_status: "pending"
  });
  assert.deepEqual(result.accounting, {
    customer_amount_received_paise: 89900,
    company_share_paise: 13485,
    electrician_payable_paise: 76415,
    payout_status: "pending"
  });
});
