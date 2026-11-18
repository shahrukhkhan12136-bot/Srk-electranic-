"use strict";

// Labour-only split helper. Inputs and outputs are integer paise.
// Payout accounting follows the existing rounded 15% commission exactly.
// Rate-list display is a separate direct 85% calculation; do not apply both
// calculations sequentially to the same amount.
const PLATFORM_COMMISSION_BPS = 1500;
const ELECTRICIAN_RATE_LIST_BPS = 8500;
const BASIS_POINTS = 10000;

function calculateElectricianNetPaise(customerLabourPaise) {
  if (!Number.isSafeInteger(customerLabourPaise) || customerLabourPaise <= 0) {
    throw new TypeError("customerLabourPaise_must_be_positive_integer");
  }
  const gross = BigInt(customerLabourPaise);
  const commission = (gross * BigInt(PLATFORM_COMMISSION_BPS) + BigInt(BASIS_POINTS / 2)) / BigInt(BASIS_POINTS);
  const net = Number(gross - commission);
  if (!Number.isSafeInteger(net) || net <= 0 || net > customerLabourPaise) {
    throw new RangeError("electrician_net_out_of_range");
  }
  return net;
}

function calculateElectricianRateListPaise(customerLabourPaise) {
  if (!Number.isSafeInteger(customerLabourPaise) || customerLabourPaise <= 0) {
    throw new TypeError("customerLabourPaise_must_be_positive_integer");
  }
  const gross = BigInt(customerLabourPaise);
  const net = Number((gross * BigInt(ELECTRICIAN_RATE_LIST_BPS) + BigInt(BASIS_POINTS / 2)) / BigInt(BASIS_POINTS));
  if (!Number.isSafeInteger(net) || net <= 0 || net > customerLabourPaise) {
    throw new RangeError("electrician_rate_list_out_of_range");
  }
  return net;
}

function calculateInternalResidualPaise(customerLabourPaise) {
  const net = calculateElectricianNetPaise(customerLabourPaise);
  return customerLabourPaise - net;
}

module.exports = { PLATFORM_COMMISSION_BPS, ELECTRICIAN_RATE_LIST_BPS, calculateElectricianNetPaise, calculateElectricianRateListPaise, calculateInternalResidualPaise };
