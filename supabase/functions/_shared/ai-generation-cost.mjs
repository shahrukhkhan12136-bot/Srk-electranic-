export function extractReportedUsd(payload, expectedGenerationId) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return null;
  const data = payload.data && typeof payload.data === "object" && !Array.isArray(payload.data)
    ? payload.data : payload;
  if (typeof data.id === "string" && data.id !== expectedGenerationId) return null;
  const raw = data.total_cost ?? data.totalCost;
  if (typeof raw !== "number" && typeof raw !== "string") return null;
  if (typeof raw === "number" && (!Number.isFinite(raw) || raw < 0)) return null;
  const normalized = typeof raw === "number"
    ? raw.toFixed(10).replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "")
    : raw;
  if (!/^(?:0|[1-9]\d{0,9})(?:\.\d{1,10})?$/.test(normalized)) return null;
  return normalized;
}
