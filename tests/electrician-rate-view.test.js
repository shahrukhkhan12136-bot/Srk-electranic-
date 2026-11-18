const test = require("node:test");
const assert = require("node:assert/strict");
const { buildElectricianRateList, deriveElectricianPaymentStage, buildElectricianJobAccounting } = require("../lib/electrician-rate-view");
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

test("rate list uses direct 85 percent half-up results for SQL tie cases", () => {
  const result = buildElectricianRateList({
    rates: { electrical_assistant: 10, skilled_electrician: 30, expert_electrician: 50, premium_electrical_specialist: 70 },
    approvedCategoryKeys: ["electrical_assistant", "skilled_electrician", "expert_electrician", "premium_electrical_specialist"],
    rateVersionId: "tie-v1", effectiveAt: "2026-11-18T00:00:00Z"
  });
  assert.deepEqual(result.items.map(item => item.electrician_rate_paise), [9, 26, 43, 60]);
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
    razorpay_order_id: "order_123",
    customer_labour_gross_paise: 50000, company_share_paise: 7500, electrician_earning_paise: 42500
  });
  assert.equal("accounting" in result, false);
  assert.equal("electrician_payable_paise" in result, false);
});

test("completed unpaid job exposes only electrician 85 percent", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b2", booking_status: "completed", payment_status: "unpaid",
    electrician_earning_paise: 76415,
    customer_labour_gross_paise: 89900, company_share_paise: 13485
  });
  assert.equal(result.electrician_payable_paise, 76415);
  assert.equal("accounting" in result, false);
  assert.equal("customer_labour_gross_paise" in result, false);
  assert.equal("company_share_paise" in result, false);
});

test("checkout started derives from a persisted Razorpay order and exposes 100/85/15", () => {
  assert.equal(deriveElectricianPaymentStage({
    booking_status: "completed", payment_status: "pending", razorpay_order_id: "order_123"
  }), "checkout_started");
  const result = buildElectricianJobAccounting({
    booking_id: "b3", booking_status: "completed", payment_status: "pending",
    razorpay_order_id: "order_123", customer_labour_gross_paise: 100000,
    electrician_earning_paise: 85000, company_share_paise: 15000
  });
  assert.deepEqual(result.accounting, {
    customer_labour_gross_paise: 100000,
    electrician_earning_paise: 85000,
    company_share_paise: 15000
  });
});

test("verified payment derives from persisted provider evidence and keeps payout separate", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b4", booking_status: "completed", payment_status: "paid",
    payment_verified_at: "2026-11-18T02:00:00Z", razorpay_payment_id: "pay_123",
    customer_labour_gross_paise: 100000, electrician_earning_paise: 85000,
    company_share_paise: 15000, customer_amount_received_paise: 103000,
    payout_reconciliation_status: "reconciled", payout_status: "pending", payout_amount_paise: 81250
  });
  assert.equal(result.accounting.customer_amount_received_paise, 103000);
  assert.equal(result.accounting.electrician_earning_paise, 85000);
  assert.deepEqual(result.electrician_payout, {
    reconciliation_status: "reconciled", reconciled: true,
    payout_status: "pending", payout_amount_paise: 81250
  });
});

test("manual payment requires server-confirmed matching evidence flag", () => {
  assert.equal(deriveElectricianPaymentStage({
    booking_status: "completed", payment_status: "paid",
    payment_verified_at: "2026-11-18T02:00:00Z", manualPaymentEvidence: true
  }), "payment_verified");
  assert.equal(deriveElectricianPaymentStage({
    booking_status: "completed", payment_status: "paid",
    payment_verified_at: "2026-11-18T02:00:00Z", manualPaymentEvidence: false
  }), "completed_unpaid");
});

test("browser-supplied paymentStage is ignored", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b5", booking_status: "completed", payment_status: "unpaid",
    paymentStage: "payment_verified", customer_labour_gross_paise: 100000,
    electrician_earning_paise: 85000, company_share_paise: 15000
  });
  assert.equal("accounting" in result, false);
  assert.equal("customer_labour_gross_paise" in result, false);
  assert.equal(result.electrician_payable_paise, 85000);
});

test("completed status alone never reveals gross or company share", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b6", booking_status: "completed", payment_status: "pending",
    customer_labour_gross_paise: 100000, electrician_earning_paise: 85000,
    company_share_paise: 15000
  });
  assert.equal("accounting" in result, false);
  assert.equal("customer_labour_gross_paise" in result, false);
});

test("rejects mismatched 100 percent split", () => {
  assert.throws(() => buildElectricianJobAccounting({
    booking_id: "b7", booking_status: "completed", payment_status: "pending",
    razorpay_order_id: "order_123", customer_labour_gross_paise: 100000,
    electrician_earning_paise: 85000, company_share_paise: 14000
  }), /must equal/);
});

test("verified stage requires a positive actual customer receipt", () => {
  assert.throws(() => buildElectricianJobAccounting({
    booking_id: "b8", booking_status: "completed", payment_status: "paid",
    payment_verified_at: "2026-11-18T02:00:00Z", razorpay_payment_id: "pay_123",
    customer_labour_gross_paise: 100000, electrician_earning_paise: 85000,
    company_share_paise: 15000, customer_amount_received_paise: 0
  }), /must be positive/);
});


test("verified customer payment with missing payout ledger is not reported as reconciled", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b9", booking_status: "completed", payment_status: "paid",
    payment_verified_at: "2026-11-18T02:00:00Z", razorpay_payment_id: "pay_999",
    customer_labour_gross_paise: null, electrician_earning_paise: null,
    company_share_paise: 15000, customer_amount_received_paise: 100000,
    payout_reconciliation_status: "missing", payout_status: null, payout_amount_paise: null
  });
  assert.equal(result.accounting.customer_amount_received_paise, 100000);
  assert.deepEqual(result.electrician_payout, {
    reconciliation_status: "missing", reconciled: false,
    payout_status: "not_recorded", payout_amount_paise: null
  });
});

test("verified customer payment with a mismatched payout ledger does not expose payout amount as reconciled", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b10", booking_status: "completed", payment_status: "paid",
    payment_verified_at: "2026-11-18T02:00:00Z", razorpay_payment_id: "pay_100",
    customer_labour_gross_paise: 100000, electrician_earning_paise: null,
    company_share_paise: 15000, customer_amount_received_paise: 100000,
    payout_reconciliation_status: "mismatch", payout_status: "pending", payout_amount_paise: 85000
  });
  assert.equal(result.electrician_payout.reconciled, false);
  assert.equal(result.electrician_payout.payout_amount_paise, null);
});


test("reconciled payout separately includes immutable materials without changing labour commission", () => {
  const result = buildElectricianJobAccounting({
    booking_id: "b11", booking_status: "completed", payment_status: "paid",
    payment_verified_at: "2026-11-18T02:00:00Z", razorpay_payment_id: "pay_111",
    customer_labour_gross_paise: 100000, materials_amount_paise: 10000,
    electrician_earning_paise: 95000, company_share_paise: 15000,
    customer_amount_received_paise: 110000, payout_reconciliation_status: "reconciled",
    payout_status: "pending", payout_amount_paise: 95000
  });
  assert.equal(result.accounting.electrician_earning_paise, 95000);
  assert.equal(result.accounting.materials_amount_paise, 10000);
  assert.equal(result.accounting.customer_labour_gross_paise + result.accounting.materials_amount_paise,
    result.accounting.electrician_earning_paise + result.accounting.company_share_paise);
});
