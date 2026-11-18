"use strict";

const { calculateElectricianNetPaise } = require("./electrician-net-rate");

// Presentation DTO builders only; the production API must still enforce auth,
// ownership and approved-category filtering before calling these helpers.
function buildElectricianRateList({ rates, approvedCategoryKeys, categoryLabels, rateVersionId, effectiveAt }) {
  if (!rates || typeof rates !== "object" || !Array.isArray(approvedCategoryKeys) ||
      typeof rateVersionId !== "string" || !rateVersionId ||
      typeof effectiveAt !== "string" || !Number.isFinite(Date.parse(effectiveAt))) {
    throw new TypeError("invalid_electrician_rate_list_context");
  }
  const items = approvedCategoryKeys.map((key) => {
    if (!Object.prototype.hasOwnProperty.call(rates, key)) {
      throw new RangeError("approved_category_rate_missing");
    }
    return {
      category_key: key,
      category_name: categoryLabels?.[key] || key,
      duration_hours: 8,
      electrician_rate_paise: calculateElectricianNetPaise(rates[key])
    };
  });
  return { currency: "INR", rate_version_id: rateVersionId, effective_at: effectiveAt, items };
}

function buildElectricianJobAccounting(booking) {
  if (!booking || typeof booking !== "object") throw new TypeError("booking_required");
  const base = { booking_id: booking.booking_id, booking_status: booking.booking_status, payment_status: booking.payment_status };
  if (booking.booking_status !== "completed") return base;
  return {
    ...base,
    accounting: {
      customer_amount_received_paise: booking.customer_amount_received_paise ?? 0,
      company_share_paise: booking.company_share_paise ?? 0,
      electrician_payable_paise: booking.electrician_payable_paise ?? 0,
      payout_status: booking.payout_status ?? "not_recorded"
    }
  };
}

module.exports = { buildElectricianRateList, buildElectricianJobAccounting };
