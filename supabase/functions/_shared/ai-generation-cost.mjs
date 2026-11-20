function numberToPlainDecimal(value) {
  const source = String(value);
  if (!/[eE]/.test(source)) return source;
  const [mantissa, exponentText] = source.toLowerCase().split("e");
  const exponent = Number(exponentText);
  const negative = mantissa.startsWith("-");
  const unsigned = negative ? mantissa.slice(1) : mantissa;
  const dot = unsigned.indexOf(".");
  const decimalPosition = (dot === -1 ? unsigned.length : dot) + exponent;
  const digits = unsigned.replace(".", "");
  const expanded = decimalPosition <= 0
    ? "0." + "0".repeat(-decimalPosition) + digits
    : decimalPosition >= digits.length
      ? digits + "0".repeat(decimalPosition - digits.length)
      : digits.slice(0, decimalPosition) + "." + digits.slice(decimalPosition);
  return (negative ? "-" : "") + expanded;
}

export function extractReportedUsd(payload, expectedGenerationId) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return null;
  const data = payload.data && typeof payload.data === "object" && !Array.isArray(payload.data)
    ? payload.data : payload;
  if (typeof data.id !== "string" || data.id !== expectedGenerationId) return null;
  const raw = data.total_cost ?? data.totalCost;
  if (typeof raw !== "number" && typeof raw !== "string") return null;
  if (typeof raw === "number" && (!Number.isFinite(raw) || raw < 0)) return null;
  // Expand scientific notation without rounding. If the Gateway supplies
  // more than 10 decimal places, reject it rather than silently round a
  // small positive charge down to zero.
  const normalized = typeof raw === "number" ? numberToPlainDecimal(raw) : raw;
  if (!/^(?:0|[1-9]\d{0,9})(?:\.\d{1,10})?$/.test(normalized)) return null;
  return normalized;
}

export function extractGenerationCreatedAt(payload, expectedGenerationId) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return null;
  const data = payload.data && typeof payload.data === "object" && !Array.isArray(payload.data)
    ? payload.data : payload;
  if (typeof data.id !== "string" || data.id !== expectedGenerationId) return null;
  const raw = data.created_at ?? data.createdAt;
  if (typeof raw !== "string" || raw.length > 64) return null;
  const timestamp = Date.parse(raw);
  if (!Number.isFinite(timestamp)) return null;
  return new Date(timestamp).toISOString();
}
