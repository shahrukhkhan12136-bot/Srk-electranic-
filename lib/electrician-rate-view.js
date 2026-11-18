"use strict";

const { calculateElectricianRateListPaise } = require("./electrician-net-rate");

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
      electrician_rate_paise: calculateElectricianRateListPaise(rates[key])
    };
  });
  return { currency: "INR", rate_version_id: rateVersionId, effective_at: effectiveAt, items };
}

/**
 * The input must be a server-fetched persisted booking row. In particular,
 * manualPaymentEvidence must come from a matching verified manual-payment row,
 * never from a browser field. No client-supplied paymentStage is consumed.
 */
function deriveElectricianPaymentStage(booking) {
  if (!booking || booking.booking_status !== "completed") return "in_progress";
  if (booking.payment_status === "refunded") return "refunded";
  const verifiedAt = typeof booking.payment_verified_at === "string" && Number.isFinite(Date.parse(booking.payment_verified_at));
  const hasProviderEvidence = typeof booking.razorpay_payment_id === "string" && booking.razorpay_payment_id.length > 0;
  if (booking.payment_status === "paid" && verifiedAt &&
      (hasProviderEvidence || booking.manualPaymentEvidence === true)) return "payment_verified";
  if (booking.payment_status === "pending" &&
      typeof booking.razorpay_order_id === "string" && booking.razorpay_order_id.length > 0) return "checkout_started";
  return "completed_unpaid";
}

function buildElectricianJobAccounting(booking) {
  if (!booking || typeof booking !== "object") throw new TypeError("booking_required");
  const base = {
    booking_id: booking.booking_id,
    booking_status: booking.booking_status,
    payment_status: booking.payment_status
  };
  if (booking.booking_status !== "completed") return base;

  const stage = deriveElectricianPaymentStage(booking);
  const net = booking.electrician_earning_paise;
  if (stage === "completed_unpaid") {
    if (!Number.isSafeInteger(net) || net <= 0) return base;
    return { ...base, electrician_payable_paise: net, currency: "INR" };
  }
  if (stage !== "checkout_started" && stage !== "payment_verified") return base;

  const gross = booking.customer_labour_gross_paise;
  const company = booking.company_share_paise;
  const materials = stage === "payment_verified" ? (booking.materials_amount_paise || 0) : 0;
  const payoutReconciled = stage === "payment_verified" &&
    booking.payout_reconciliation_status === "reconciled";
  if ((stage !== "payment_verified" || payoutReconciled) &&
      (!Number.isSafeInteger(company) || company < 0)) {
    throw new RangeError("company share must be non-negative integer paise when reconciled");
  }
  if (company !== null && company !== undefined &&
      (!Number.isSafeInteger(company) || company < 0)) {
    throw new RangeError("company share must be non-negative integer paise when supplied");
  }
  const visibleCompany = Number.isSafeInteger(company) ? company : null;
  if (stage === "checkout_started") {
    if (!Number.isSafeInteger(gross) || gross <= 0 ||
        !Number.isSafeInteger(net) || net <= 0 || gross !== net + company) {
      throw new RangeError("checkout labour gross must equal electrician net plus company share");
    }
  } else if (payoutReconciled) {
    if (!Number.isSafeInteger(gross) || gross <= 0 ||
        !Number.isSafeInteger(net) || net <= 0 || !Number.isSafeInteger(materials) || materials < 0 || gross + materials !== net + company) {
      throw new RangeError("reconciled payout must equal immutable labour plus materials less company share");
    }
  } else if (gross !== null && gross !== undefined &&
      (!Number.isSafeInteger(gross) || gross <= 0)) {
    throw new RangeError("customer labour gross must be positive integer paise when supplied");
  }

  const accounting = stage === "payment_verified"
    ? {
        customer_amount_received_paise: booking.customer_amount_received_paise,
        customer_labour_gross_paise: Number.isSafeInteger(gross) ? gross : null,
        materials_amount_paise: Number.isSafeInteger(materials) ? materials : null,
        electrician_earning_paise: payoutReconciled ? net : null,
        company_share_paise: visibleCompany
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
        reconciliation_status: booking.payout_reconciliation_status || "not_checked",
        reconciled: booking.payout_reconciliation_status === "reconciled",
        payout_status: booking.payout_status || "not_recorded",
        payout_amount_paise: booking.payout_reconciliation_status === "reconciled" &&
          Number.isSafeInteger(booking.payout_amount_paise) ? booking.payout_amount_paise : null
      }
    } : {})
  };
}

module.exports = { buildElectricianRateList, deriveElectricianPaymentStage, buildElectricianJobAccounting };
