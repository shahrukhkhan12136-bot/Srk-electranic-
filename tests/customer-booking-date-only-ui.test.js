const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const html = fs.readFileSync(path.join(__dirname, "..", "index.html"), "utf8");
const bookingFormStart = html.indexOf('<form id="booking"');
assert.notEqual(bookingFormStart, -1, "customer booking form must exist");
const bookingFormEnd = html.indexOf("</form>", bookingFormStart);
assert.notEqual(bookingFormEnd, -1, "customer booking form must close");
const bookingForm = html.slice(bookingFormStart, bookingFormEnd);

test("customer booking form exposes a required date-only selector", () => {
  assert.match(bookingForm, /<input\b(?=[^>]*\bid="date")(?=[^>]*\btype="date")(?=[^>]*\brequired\b)[^>]*>/i);
  assert.doesNotMatch(bookingForm, /<input\b[^>]*\btype="time"/i);
  assert.doesNotMatch(bookingForm, /\bid="time"/i);
  assert.doesNotMatch(bookingForm, /time[- ]slot|समय चुनें|समय स्लॉट/i);
});

test("customer booking request and WhatsApp message use date without a selected clock time", () => {
  const submitStart = html.indexOf("document.getElementById('booking').addEventListener('submit'");
  assert.notEqual(submitStart, -1, "customer booking submit handler must exist");
  const submitEnd = html.indexOf("document.getElementById('payNow').addEventListener", submitStart);
  assert.notEqual(submitEnd, -1, "booking submit handler boundary must exist");
  const submitHandler = html.slice(submitStart, submitEnd);
  assert.match(submitHandler, /तारीख: \$\{value\('date'\)\}/);
  assert.match(submitHandler, /preferred_date:\s*value\('date'\)/);
  assert.doesNotMatch(submitHandler, /preferred_time\s*:/);
  assert.doesNotMatch(submitHandler, /value\(['"]time['"]\)/);
});

test("historical booking time remains visible when an older record has one", () => {
  assert.match(html, /preferred_date,preferred_time/);
  assert.match(html, /row\.preferred_date\s*\|\|\s*''\)\s*\+\s*' '\s*\+\s*customerEsc\(row\.preferred_time\s*\|\|\s*''\)/);
});
