const test = require("node:test");
const assert = require("node:assert/strict");
const { resolvePublishedRateVersion, createBookingRateSnapshot } = require("../lib/booking-rate-snapshot");
const { INITIAL_RATES_PAISE } = require("../lib/commercial-rate-policy");

const versions = [
  { version_id: "v1", status: "published", effective_at: "2026-11-01T00:00:00Z", rates: INITIAL_RATES_PAISE },
  { version_id: "v2-future", status: "published", effective_at: "2026-11-20T00:00:00Z", rates: { ...INITIAL_RATES_PAISE, skilled_electrician: 139900 } },
  { version_id: "draft", status: "draft", effective_at: "2026-11-10T00:00:00Z", rates: { ...INITIAL_RATES_PAISE, skilled_electrician: 129900 } }
];

test("resolver selects the latest effective published version, not future or draft", () => {
  assert.deepEqual(resolvePublishedRateVersion({
    versions, rateTier: "skilled_electrician", now: "2026-11-18T12:00:00Z"
  }), {
    rate_version_id: "v1", effective_at: "2026-11-01T00:00:00Z", rate_tier: "skilled_electrician", rate_8h_paise: 119900
  });
});

test("booking snapshot stores the resolved rate and prorated labour amount", () => {
  const resolved = resolvePublishedRateVersion({ versions, rateTier: "skilled_electrician", now: "2026-11-21T00:00:00Z" });
  const snapshot = createBookingRateSnapshot({ resolvedRate: resolved, durationHours: 4 });
  assert.equal(snapshot.rate_version_id, "v2-future");
  assert.equal(snapshot.rate_8h_paise, 139900);
  assert.equal(snapshot.labour_amount_paise, 69950);
  assert.equal(snapshot.duration_hours, 4);
  assert.equal(Object.isFrozen(snapshot), true);
});

test("resolver returns null when no published version is effective", () => {
  assert.equal(resolvePublishedRateVersion({
    versions, rateTier: "electrical_assistant", now: "2026-10-01T00:00:00Z"
  }), null);
});

test("resolver rejects ambiguous published versions with the same effective time", () => {
  assert.throws(() => resolvePublishedRateVersion({
    versions: [versions[0], { ...versions[0], version_id: "duplicate" }],
    rateTier: "electrical_assistant", now: "2026-11-18T12:00:00Z"
  }), /ambiguous_published_rate_versions/);
});

test("snapshot rejects invalid resolved rate context", () => {
  assert.throws(() => createBookingRateSnapshot({ resolvedRate: null, durationHours: 8 }));
});

test("snapshot rejects an unknown rate tier", () => {
  assert.throws(() => createBookingRateSnapshot({
    resolvedRate: { rate_version_id: "v1", effective_at: "2026-11-01T00:00:00Z", rate_tier: "unapproved", rate_8h_paise: 119900 },
    durationHours: 8
  }), /resolved_published_rate_required/);
});
