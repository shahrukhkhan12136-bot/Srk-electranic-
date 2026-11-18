"use strict";

const { RATE_TIERS, validateRateCatalogue, calculateLabourPaise } = require("./commercial-rate-policy");

// Pure contract helper. The trusted server must load versions from its protected
// source and pass them here; never accept a client-supplied catalogue as authority.
function resolvePublishedRateVersion({ versions, rateTier, now = new Date().toISOString() }) {
  if (!Array.isArray(versions) || !RATE_TIERS.includes(rateTier) ||
      !Number.isFinite(Date.parse(now))) {
    throw new TypeError("invalid_rate_resolution_context");
  }
  const eligible = versions.filter((version) =>
    version && version.status === "published" &&
    typeof version.version_id === "string" && version.version_id.length > 0 &&
    typeof version.effective_at === "string" && Number.isFinite(Date.parse(version.effective_at)) &&
    Date.parse(version.effective_at) <= Date.parse(now) &&
    validateRateCatalogue(version.rates).valid
  );
  eligible.sort((a, b) => Date.parse(b.effective_at) - Date.parse(a.effective_at));
  if (!eligible.length) return null;
  if (eligible.length > 1 && Date.parse(eligible[0].effective_at) === Date.parse(eligible[1].effective_at)) {
    throw new Error("ambiguous_published_rate_versions");
  }
  const selected = eligible[0];
  return Object.freeze({
    rate_version_id: selected.version_id,
    effective_at: selected.effective_at,
    rate_tier: rateTier,
    rate_8h_paise: selected.rates[rateTier]
  });
}

// Persist this exact snapshot with a new booking. Later catalogue changes must
// not recalculate or mutate this booking's agreed labour amount.
function createBookingRateSnapshot({ resolvedRate, durationHours }) {
  if (!resolvedRate || typeof resolvedRate.rate_version_id !== "string" ||
      !resolvedRate.rate_version_id || !RATE_TIERS.includes(resolvedRate.rate_tier) ||
      typeof resolvedRate.effective_at !== "string" ||
      !Number.isFinite(Date.parse(resolvedRate.effective_at))) {
    throw new TypeError("resolved_published_rate_required");
  }
  const labourPaise = calculateLabourPaise(resolvedRate.rate_8h_paise, durationHours);
  return Object.freeze({
    rate_version_id: resolvedRate.rate_version_id,
    rate_effective_at: resolvedRate.effective_at,
    rate_tier: resolvedRate.rate_tier,
    duration_hours: durationHours,
    rate_8h_paise: resolvedRate.rate_8h_paise,
    labour_amount_paise: labourPaise,
    currency: "INR"
  });
}

module.exports = { resolvePublishedRateVersion, createBookingRateSnapshot };
