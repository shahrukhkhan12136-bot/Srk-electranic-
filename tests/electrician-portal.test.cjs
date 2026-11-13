const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const html = fs.readFileSync('electrician.html', 'utf8');

test('electrician verification state is rendered as text, never stored HTML', () => {
  assert.match(html, /stateEl\\.textContent/);
  assert.match(html, /stateEl\\.className=p\\.active\\?'good':'bad'/);
  assert.doesNotMatch(html, /getElementById\\('state'\\)\\.innerHTML/);
});

test('electrician portal keeps customer contact data behind assigned-offer response fields', () => {
  assert.match(html, /ग्राहक का विवरण काम आपको असाइन होने के बाद दिखेगा/);
  assert.match(html, /o\\.customer_name\\?/);
  assert.match(html, /o\\.customer_phone\\?/);
});

test('electrician portal exposes server-authoritative work start, completion, bill and cash confirmation RPCs', () => {
  for (const rpc of ['srk_electrician_request_work_start','srk_electrician_request_work_completion','srk_electrician_get_labour_bill','srk_electrician_confirm_cash_payment']) {
    assert.ok(html.includes(rpc), 'missing RPC marker: ' + rpc);
  }
});

test('electrician earnings and wallet displays use read RPCs and do not expose payout mutation controls', () => {
  assert.match(html, /srk_get_my_earnings/);
  assert.match(html, /srk_get_my_wallet_summary/);
  assert.match(html, /बैंक खाता जोड़ना और निकासी अभी बंद है/);
  assert.doesNotMatch(html, /srk_electrician_request_payout|srk_electrician_add_bank_account/);
});
