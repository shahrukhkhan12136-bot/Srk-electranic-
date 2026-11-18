"use strict";

const { calculateElectricianNetPaise } = require("./electrician-net-rate");

function buildElectricianRateList({ rates, approvedCategoryKeys, categoryLabels, rateVersionId, effectiveAt }) {
  if (!rates || typeof rates !== "object" || !Array.isArray(approvedCategoryKeys) ||
      typeof rateVersionId !== "string" || !rateVersionId ||
      typeof effectiveAt !== "string" || !Number.isFinite(Date.parse(effectiveAt))) {
    throw new TypeError("invalid_electrician_rate_list_context");
  }
  const items = approvedCategoryKeys.map((key) => {
    if (!Object.prototype.hasOwnProperty.call(rates, key)) throw new RangeError("approved_category_rate_missing");
    return {
      category_key: key,
      category_name: categoryLabels?.[key] || key,
      duration_hours: 8,
      electrician_rate_paise: calculateElectricianNetPaise(rates[key])
    };
  });
  return { currency: "INR", rate_version_id: rateVersionId, effective_at: effectiveAt, items };
}

/**
 * Presentation-only DTO. paymentStage MUST be derived server-side from trusted
 * persisted booking/checkout/payment evidence; never accept a browser stage.
 * Payout is reported independently from customer payment and earnings.
 */
function buildElectricianJobAccounting(booking) {
  if (!booking || typeof booking !== "object") throw new TypeError("booking_required");
  const base = {
    booking_id: booking.booking_id,
    booking_status: booking.booking_status,
    payment_status: booking.payment_status
  };
  if (booking.booking_status !== "completed") return base;

  const stage = booking.paymentStage;
  const net = booking.electrician_earning_paise;
  if (stage === "completed_unpaid") {
    if (!Number.isSafeInteger(net) || net <= 0) return base;
    return { ...base, electrician_payable_paise: net, currency: "INR" };
  }
  if (stage !== "checkout_started" && stage !== "payment_verified") return base;

  const gross = booking.customer_labour_gross_paise;
  const company = booking.company_share_paise;
  if (!Number.isSafeInteger(gross) || gross <= 0 ||
      !Number.isSafeInteger(net) || net <= 0 ||
      !Number.isSafeInteger(company) || company < 0 || gross !== net + company) {
    throw new RangeError("customer labour gross must equal electrician net plus company share");
  }

  const accounting = stage === "payment_verified"
    ? {
        customer_amount_received_paise: booking.customer_amount_received_paise,
        customer_labour_gross_paise: gross,
        electrician_earning_paise: net,
        company_share_paise: company
      }
    : {
        customer_labour_gross_paise: gross,
        electrician_earning_paise: net,
        company_share_paise: company
      };

  if (stage === "payment_verified" &&
      (!Number.isSafeInteger(booking.customer_amount_received_paise) ||
       booking.customer_amount_received_paise <= 0)) {
    throw new TypeError("verified customer amount must be positive paise");
  }

  return {
    ...base,
    currency: "INR",
    accounting,
    ...(stage === "payment_verified" ? {
      electrician_payout: {
        payout_status: booking.payout_status || "not_recorded",
        payout_amount_paise: Number.isSafeInteger(booking.payout_amount_paise) ? booking.payout_amount_paise : null
      }
    } : {})
  };
}

module.exports = { buildElectricianRateList, buildElectricianJobAccounting };
