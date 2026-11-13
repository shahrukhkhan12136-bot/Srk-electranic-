const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const html = fs.readFileSync(path.join(__dirname, "..", "booking.html"), "utf8");

test("Customer Payments tab has a separate private refund request history panel", () => {
  assert.match(html, /id="customerRefundHistoryPanel"/);
  assert.match(html, /id="customerRefundHistoryRefresh"/);
  assert.match(html, /id="customerRefundHistory"/);
});

test("Customer refund history reads only the authenticated customer's refund-list RPC", () => {
  assert.match(html, /customerSb\\.rpc\\('srk_customer_list_my_booking_refund_requests',\\{p_limit:25,p_offset:requestedOffset\\}\\)/);
  assert.match(html, /async function loadCustomerRefundHistory(reset=true)/);
});

test("Customer refund history auto-refreshes after login and when Payments tab opens", () => {
  assert.match(html, /await loadCustomerRefundHistory\(\)/);
  assert.match(html, /if\(name==='Payments'\)\{loadCustomerPaymentHistory\(true\);loadCustomerRefundHistory\(\);\}/);
});

test("Customer-visible refund statuses explain Admin review and reconciliation", () => {
  assert.match(html, /in_review:'Admin समीक्षा में'/);
  assert.match(html, /unknown:'Admin जाँच आवश्यक'/);
  assert.match(html, /processing:'रिफंड प्रोसेस हो रहा है'/);
});
