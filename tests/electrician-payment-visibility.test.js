"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { STATES, buildElectricianOfferDto, buildElectricianAccountingDto } = require("../lib/electrician-payment-visibility");

test("offer exposes only electrician net", () => {
  const dto = buildElectricianOfferDto({
    bookingId: "b1", categoryKey: "skilled_electrician", durationHours: 8,
    electricianNetPaise: 85000, rateVersionId: "v1"
  });
  assert.equal(dto.electrician_offer_paise, 85000);
  assert.equal("customer_gross_paise" in dto, false);
  assert.equal("company_share_paise" in dto, false);
});

test("completed unpaid exposes net only", () => {
  const dto = buildElectricianAccountingDto({
    bookingId: "b1", paymentStage: STATES.COMPLETED_UNPAID, electricianNetPaise: 85000
  });
  assert.equal(dto.electrician_payable_paise, 85000);
  assert.equal("accounting" in dto, false);
});

test("checkout started exposes complete breakdown", () => {
  const dto = buildElectricianAccountingDto({
    bookingId: "b1", paymentStage: STATES.CHECKOUT_STARTED,
    electricianNetPaise: 85000, customerGrossPaise: 100000, companySharePaise: 15000
  });
  assert.deepEqual(dto.accounting, {
    customer_payment_due_paise: 100000,
    electrician_earning_paise: 85000,
    company_share_paise: 15000
  });
});

test("paid response separates receipt and payout", () => {
  const dto = buildElectricianAccountingDto({
    bookingId: "b1", paymentStage: STATES.PAID,
    electricianNetPaise: 85000, customerGrossPaise: 100000,
    companySharePaise: 15000, customerAmountReceivedPaise: 100000,
    payoutStatus: "pending"
  });
  assert.equal(dto.accounting.customer_amount_received_paise, 100000);
  assert.equal(dto.electrician_payout.payout_amount_paise, 85000);
  assert.equal(dto.electrician_payout.payout_status, "pending");
});

test("rejects mismatched gross/net/company accounting", () => {
  assert.throws(() => buildElectricianAccountingDto({
    bookingId: "b1", paymentStage: STATES.CHECKOUT_STARTED,
    electricianNetPaise: 85000, customerGrossPaise: 100000, companySharePaise: 14000
  }), /must equal/);
});

test("does not return accounting before checkout and rejects unknown stage", () => {
  assert.throws(() => buildElectricianAccountingDto({
    bookingId: "b1", paymentStage: STATES.OFFER, electricianNetPaise: 85000
  }), /not available/);
});

test("rejects invalid money values", () => {
  assert.throws(() => buildElectricianOfferDto({
    bookingId: "b1", categoryKey: "skilled_electrician", durationHours: 8,
    electricianNetPaise: 0, rateVersionId: "v1"
  }), /positive safe integer/);
});
