"use strict";

// Labour-only split helper. Inputs and outputs are integer paise.
// Match the existing 15% payout-ledger commission exactly. Electrician net is
// the gross less that one rounded commission; never subtract a second 15%.
const PLATFORM_COMMISSION_BPS = 1500;
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

function calculateInternalResidualPaise(customerLabourPaise) {
  const net = calculateElectricianNetPaise(customerLabourPaise);
  return customerLabourPaise - net;
}

module.exports = { PLATFORM_COMMISSION_BPS, calculateElectricianNetPaise, calculateInternalResidualPaise };
