"use strict";

const RATE_TIERS = Object.freeze([
  "electrical_assistant",
  "skilled_electrician",
  "expert_electrician",
  "premium_electrical_specialist"
]);

const INITIAL_RATES_PAISE = Object.freeze({
  electrical_assistant: 89900,
  skilled_electrician: 119900,
  expert_electrician: 159900,
  premium_electrical_specialist: 199900
});

function validateRateCatalogue(rates) {
  if (!rates || typeof rates !== "object" || Array.isArray(rates)) {
    return { valid: false, error: "rates_must_be_object" };
  }
  const keys = Object.keys(rates).sort();
  const expected = [...RATE_TIERS].sort();
  if (keys.length !== expected.length || keys.some((key, index) => key !== expected[index])) {
    return { valid: false, error: "exactly_four_known_tiers_required" };
  }
  for (const tier of RATE_TIERS) {
    const amount = rates[tier];
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      return { valid: false, error: "rate_must_be_positive_integer_paise", tier };
    }
  }
  return { valid: true };
}

function calculateLabourPaise(rate8hPaise, durationHours) {
  if (!Number.isSafeInteger(rate8hPaise) || rate8hPaise <= 0) {
    throw new TypeError("rate8hPaise_must_be_positive_integer");
  }
  if (!Number.isInteger(durationHours) || durationHours < 1 || durationHours > 8) {
    throw new RangeError("durationHours_must_be_between_1_and_8");
  }
  return Math.floor((rate8hPaise * durationHours) / 8 + 0.5);
}

module.exports = { RATE_TIERS, INITIAL_RATES_PAISE, validateRateCatalogue, calculateLabourPaise };
