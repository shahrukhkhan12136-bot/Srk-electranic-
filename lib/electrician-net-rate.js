"use strict";

// Labour-only split helper. Inputs and outputs are integer paise.
// This does not define or replace the separate historical platform commission.
const ELECTRICIAN_NET_BPS = 8500;
const BASIS_POINTS = 10000;

function calculateElectricianNetPaise(customerLabourPaise) {
  if (!Number.isSafeInteger(customerLabourPaise) || customerLabourPaise <= 0) {
    throw new TypeError("customerLabourPaise_must_be_positive_integer");
  }
  const net = Math.floor((customerLabourPaise * ELECTRICIAN_NET_BPS + BASIS_POINTS / 2) / BASIS_POINTS);
  if (!Number.isSafeInteger(net) || net <= 0 || net > customerLabourPaise) {
    throw new RangeError("electrician_net_out_of_range");
  }
  return net;
}

function calculateInternalResidualPaise(customerLabourPaise) {
  const net = calculateElectricianNetPaise(customerLabourPaise);
  return customerLabourPaise - net;
}

module.exports = { ELECTRICIAN_NET_BPS, calculateElectricianNetPaise, calculateInternalResidualPaise };
