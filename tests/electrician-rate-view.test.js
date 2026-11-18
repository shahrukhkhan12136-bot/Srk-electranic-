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
    paymentStage: "checkout_started",
    customer_labour_gross_paise: 50000, company_share_paise: 7500, electrician_earning_paise: 42500
  });
  assert.equal("accounting" in result, false);
  assert.equal("electrician_payable_paise" in result, false);
});

test("completed unpaid job exposes only electrician 85 percent", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b2", booking_status: "completed", payment_status: "unpaid",
    paymentStage: "completed_unpaid", electrician_earning_paise: 76415,
    customer_labour_gross_paise: 89900, company_share_paise: 13485
  });
  assert.equal(result.electrician_payable_paise, 76415);
  assert.equal("accounting" in result, false);
  assert.equal("customer_labour_gross_paise" in result, false);
  assert.equal("company_share_paise" in result, false);
});

test("checkout started exposes 100 percent split only after trusted stage is supplied", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b3", booking_status: "completed", payment_status: "pending",
    paymentStage: "checkout_started", customer_labour_gross_paise: 100000,
    electrician_earning_paise: 85000, company_share_paise: 15000
  });
  assert.deepEqual(result.accounting, {
    customer_labour_gross_paise: 100000,
    electrician_earning_paise: 85000,
    company_share_paise: 15000
  });
});

test("verified payment exposes actual receipt and keeps payout ledger separate", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b4", booking_status: "completed", payment_status: "paid",
    paymentStage: "payment_verified", customer_labour_gross_paise: 100000,
    electrician_earning_paise: 85000, company_share_paise: 15000,
    customer_amount_received_paise: 103000,
    payout_status: "pending", payout_amount_paise: 81250
  });
  assert.equal(result.accounting.customer_amount_received_paise, 103000);
  assert.equal(result.accounting.electrician_earning_paise, 85000);
  assert.deepEqual(result.electrician_payout, { payout_status: "pending", payout_amount_paise: 81250 });
});

test("completed status alone never reveals gross or company share", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b5", booking_status: "completed", payment_status: "pending",
    customer_labour_gross_paise: 100000, electrician_earning_paise: 85000,
    company_share_paise: 15000
  });
  assert.equal("accounting" in result, false);
  assert.equal("customer_labour_gross_paise" in result, false);
});

test("rejects mismatched 100 percent split", () => {
  assert.throws(() => buildElectricianJobAccounting({
    booking_id: "b6", booking_status: "completed", payment_status: "pending",
    paymentStage: "checkout_started", customer_labour_gross_paise: 100000,
    electrician_earning_paise: 85000, company_share_paise: 14000
  }), /must equal/);
});

test("verified stage requires a positive actual customer receipt", () => {
  assert.throws(() => buildElectricianJobAccounting({
    booking_id: "b7", booking_status: "completed", payment_status: "paid",
    paymentStage: "payment_verified", customer_labour_gross_paise: 100000,
    electrician_earning_paise: 85000, company_share_paise: 15000,
    customer_amount_received_paise: 0
  }), /must be positive/);
});
