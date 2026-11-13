"use strict";

// Labour-only customer rate card. Amounts are integer paise; never use floating point.
const RATE_CARD_VERSION = "SRK-CUSTOMER-LABOUR-2026-11-13-V1";
const RATE_CARD = Object.freeze({
  electrical_assistant: Object.freeze({ label: "Electrical Assistant", rate8hPaise: 89900 }),
  skilled_electrician: Object.freeze({ label: "Skilled Electrician", rate8hPaise: 119900 }),
  expert_electrician: Object.freeze({ label: "Expert Electrician", rate8hPaise: 159900 }),
  premium_electrical_specialist: Object.freeze({ label: "Premium Electrical Specialist", rate8hPaise: 199900 })
});
const MINUTES_PER_8_HOURS = 480;

/**
 * Calculate customer gross labour in integer paise using exact rational arithmetic.
 * Rounding: nearest paisa, ties rounded up (half-up).
 * This helper does not authorize a booking or determine an electrician's eligibility.
 */
function calculateLabourPaise(rate8hPaise, billableMinutes) {
  if (!Number.isSafeInteger(rate8hPaise) || rate8hPaise <= 0) {
    throw new TypeError("rate8hPaise must be a positive safe integer");
  }
  if (!Number.isSafeInteger(billableMinutes) || billableMinutes < 0) {
    throw new TypeError("billableMinutes must be a non-negative safe integer");
  }

  const numerator = BigInt(rate8hPaise) * BigInt(billableMinutes);
  const denominator = BigInt(MINUTES_PER_8_HOURS);
  let rounded = numerator / denominator;
  const remainder = numerator % denominator;
  if (remainder * 2n >= denominator) rounded += 1n;

  if (rounded > BigInt(Number.MAX_SAFE_INTEGER)) {
    throw new RangeError("calculated labour amount exceeds safe integer range");
  }
  return Number(rounded);
}

function calculateEstimatePaise(category, expectedHours) {
  const rate = RATE_CARD[category];
  if (!rate) throw new TypeError("unknown customer labour category");
  if (!Number.isSafeInteger(expectedHours) || expectedHours < 1 || expectedHours > 8) {
    throw new TypeError("expectedHours must be an integer from 1 to 8");
  }
  return calculateLabourPaise(rate.rate8hPaise, expectedHours * 60);
}

module.exports = {
  RATE_CARD_VERSION,
  RATE_CARD,
  MINUTES_PER_8_HOURS,
  calculateLabourPaise,
  calculateEstimatePaise
};
