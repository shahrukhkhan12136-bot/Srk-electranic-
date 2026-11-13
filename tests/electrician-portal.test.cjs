const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const html = fs.readFileSync('electrician.html', 'utf8');

test('electrician verification state is rendered as text, never stored HTML', () => {
  assert.ok(html.includes("stateEl.textContent="));
  assert.ok(html.includes("stateEl.className=p.active?'good':'bad'"));
  assert.ok(!html.includes("getElementById('state').innerHTML"));
});

test('electrician portal keeps customer contact data behind assigned-offer response fields', () => {
  assert.ok(html.includes('ग्राहक का विवरण काम आपको असाइन होने के बाद दिखेगा'));
  assert.ok(html.includes('o.customer_name?'));
  assert.ok(html.includes('o.customer_phone?'));
});

test('electrician portal exposes server-authoritative work start, completion, bill and cash confirmation RPCs', () => {
  for (const rpc of ['srk_electrician_request_work_start','srk_electrician_request_work_completion','srk_electrician_get_labour_bill','srk_electrician_confirm_cash_payment']) {
    assert.ok(html.includes(rpc), 'missing RPC marker: ' + rpc);
  }
});

test('electrician earnings and wallet displays use read RPCs and do not expose payout mutation controls', () => {
  assert.ok(html.includes('srk_get_my_earnings'));
  assert.ok(html.includes('srk_get_my_wallet_summary'));
  assert.ok(html.includes('बैंक खाता जोड़ना और निकासी अभी बंद है'));
  assert.ok(!html.includes('srk_electrician_request_payout'));
  assert.ok(!html.includes('srk_electrician_add_bank_account'));
});

test('electrician dashboard exposes the six approved sections in order with accessible tab panels', () => {
  const nav = html.match(/<nav class="partner-menu"[\\s\\S]*?<\\/nav>/)?.[0] || '';
  const names = [...nav.matchAll(/data-partner-menu="([^"]+)"/g)].map(m => m[1]);
  assert.deepEqual(names, ['Home','Offers','Work','Earnings','Profile','Support']);
  assert.equal((nav.match(/role="tab"/g)||[]).length, 6);
  for (const key of ['Home','Offers','Work','Earnings','Profile','Support']) {
    assert.equal((html.match(new RegExp('id="partnerPanel'+key+'"','g'))||[]).length, 1);
  }
  assert.ok(html.includes("function activatePartnerMenu(name,focus=false)"));
  assert.ok(html.includes("event.key==='ArrowRight'"));
  assert.ok(html.includes("event.key==='ArrowLeft'"));
});

test('electrician offers and accepted work are rendered into separate menu panels without duplicate records', () => {
  assert.ok(html.includes("const offerRows=rows.filter(o=>o.offer_status==='offered')"));
  assert.ok(html.includes("const workRows=rows.filter(o=>o.offer_status==='accepted'||"));
  assert.ok(html.includes("offerRows.map(o=>renderElectricianJob(o,p))"));
  assert.ok(html.includes("workRows.map(o=>renderElectricianJob(o,p))"));
  assert.ok(html.includes('id="newOffers"'));
  assert.ok(html.includes('id="myWork"'));
});

test('electrician support panel does not call customer-only support APIs or claim unavailable tools are live', () => {
  assert.ok(html.includes('इलेक्ट्रिशियन सहायता टिकट और संदेश सुविधा अभी उपलब्ध नहीं है।'));
  assert.ok(html.includes('इलेक्ट्रिशियन-विशिष्ट ticket, message, attachment और RLS अधिकार'));
  assert.ok(!html.includes('srk_customer_send_booking_complaint_message'));
});
