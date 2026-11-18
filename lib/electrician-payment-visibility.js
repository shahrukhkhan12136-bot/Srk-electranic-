"use strict";

const STATES = Object.freeze({
  OFFER: "offered",
  IN_PROGRESS: "in_progress",
  COMPLETED_UNPAID: "completed_unpaid",
  CHECKOUT_STARTED: "checkout_started",
  PAID: "paid"
});

function positivePaise(value, field) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new TypeError(field + " must be a positive safe integer in paise");
  }
  return value;
}

function buildElectricianOfferDto(input) {
  if (!input || typeof input.bookingId !== "string" || !input.bookingId ||
      typeof input.categoryKey !== "string" || !input.categoryKey ||
      !Number.isInteger(input.durationHours) || input.durationHours < 1 || input.durationHours > 8) {
    throw new TypeError("valid booking, category and duration are required");
  }
  return Object.freeze({
    booking_id: input.bookingId,
    booking_status: STATES.OFFER,
    category_key: input.categoryKey,
    duration_hours: input.durationHours,
    electrician_offer_paise: positivePaise(input.electricianNetPaise, "electricianNetPaise"),
    currency: "INR",
    rate_version_id: input.rateVersionId
  });
}

/**
 * paymentStage MUST be derived by a trusted server after checking persisted
 * checkout/payment records. Never pass a browser-supplied stage here.
 */
function buildElectricianAccountingDto(input) {
  if (!input || typeof input.bookingId !== "string" || !input.bookingId) {
    throw new TypeError("bookingId is required");
  }
  const net = positivePaise(input.electricianNetPaise, "electricianNetPaise");
  if (input.paymentStage === STATES.COMPLETED_UNPAID) {
    return Object.freeze({
      booking_id: input.bookingId,
      booking_status: "completed",
      payment_status: "unpaid",
      electrician_payable_paise: net,
      currency: "INR"
    });
  }
  if (input.paymentStage === STATES.CHECKOUT_STARTED || input.paymentStage === STATES.PAID) {
    const gross = positivePaise(input.customerGrossPaise, "customerGrossPaise");
    const company = positivePaise(input.companySharePaise, "companySharePaise");
    if (gross !== net + company) {
      throw new RangeError("customer gross must equal electrician net plus company share");
    }
    const accounting = input.paymentStage === STATES.PAID
      ? {
          customer_amount_received_paise: positivePaise(input.customerAmountReceivedPaise, "customerAmountReceivedPaise"),
          electrician_earning_paise: net,
          company_share_paise: company
        }
      : {
          customer_payment_due_paise: gross,
          electrician_earning_paise: net,
          company_share_paise: company
        };
    return Object.freeze({
      booking_id: input.bookingId,
      booking_status: "completed",
      payment_status: input.paymentStage === STATES.PAID ? "paid" : "pending",
      currency: "INR",
      accounting: Object.freeze(accounting),
      ...(input.paymentStage === STATES.PAID ? {
        electrician_payout: Object.freeze({
          payout_status: input.payoutStatus || "pending",
          payout_amount_paise: net
        })
      } : {})
    });
  }
  throw new Error("accounting is not available in this payment stage");
}

module.exports = { STATES, buildElectricianOfferDto, buildElectricianAccountingDto };
