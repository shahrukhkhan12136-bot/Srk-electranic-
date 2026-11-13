const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync('electrician.html', 'utf8');


test('electrician profile lookup errors render safely into an existing status element', () => {
  assert.ok(html.includes("stateEl.textContent='प्रोफाइल जानकारी अभी लोड नहीं हुई। कृपया Refresh करें।'"));
  assert.ok(!html.includes("getElementById('jobs')"));
});


test('profile panel shows only an internal partner reference and honestly discloses missing document workflow', () => {
  assert.ok(html.includes('id="partnerReferenceId"'));
  assert.ok(html.includes("आंतरिक पार्टनर संदर्भ ID: '+String(p.id||'उपलब्ध नहीं')"));
  assert.ok(html.includes('यह UUID केवल आंतरिक पार्टनर संदर्भ है'));
  assert.ok(html.includes('पहचान और दस्तावेज़ सत्यापन'));
  assert.ok(!html.includes('सरकारी पहचान-पत्र जारी'));
});

test('electrician KYC upload uses private bucket, strict MIME/size checks and server registration RPC', () => {
  assert.ok(html.includes("sb.storage.from('srk-electrician-verification').upload(path,file,{upsert:false,contentType:file.type})"));
  assert.ok(html.includes("file.size>5242880"));
  assert.ok(html.includes("srk_electrician_submit_verification_document"));
  assert.ok(html.includes("srk_electrician_list_my_verification_documents"));
  assert.ok(html.includes("crypto.randomUUID()"));
  assert.ok(html.includes("await sb.storage.from('srk-electrician-verification').remove([path])"));
  assert.ok(html.includes('दस्तावेज़ की वैधता/expiry अभी सिस्टम में track नहीं होती'));
});

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
  const navStart = html.indexOf('<nav class="partner-menu"');
  const navEnd = html.indexOf('</nav>', navStart);
  const nav = navStart >= 0 && navEnd >= 0 ? html.slice(navStart, navEnd + 6) : '';
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


test('electrician work history is read through a dedicated assigned-profile-scoped RPC', () => {
  assert.ok(html.includes('srk_electrician_get_my_booking_work_timeline'));
  assert.ok(html.includes('कार्य इतिहास देखें'));
  assert.ok(html.includes('function loadElectricianTimeline(bookingId)'));
  assert.ok(html.includes("row.booking_id===bookingId"));
  assert.ok(html.includes('row.occurred_at'));
  assert.ok(html.includes('ELECTRICIAN_EVENT_LABELS'));
  assert.ok(!html.includes('row.actor_id'));
  assert.ok(!html.includes('row.details'));
});

test('electrician inline JavaScript parses after navigation and work-panel changes', () => {
  const start = html.lastIndexOf('<script>');
  const end = html.lastIndexOf('</script>');
  assert.ok(start >= 0 && end > start);
  assert.doesNotThrow(() => new vm.Script(html.slice(start + 8, end)));
});

test('historical offer-detail migrations never reveal assigned customer contact after a terminal or unapproved state', () => {
  const early = fs.readFileSync('supabase/migrations/20261109002000_expose_assigned_booking_map_pin.sql', 'utf8');
  const quote = fs.readFileSync('supabase/migrations/20261109075837_electrician_inspection_quotes_and_service_only_commission.sql', 'utf8');
  const allowed = "('assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed')";
  for (const [name, sql] of [['map-pin migration', early], ['quote-workflow migration', quote]]) {
    assert.ok(sql.toLowerCase().includes('b.status in ' + allowed), name + ' must gate customer contact fields by active assigned-work state');
    assert.ok(!/CASE WHEN b\.assigned_electrician_id\s*=\s*p\.id THEN/i.test(sql), name + ' must not expose contacts based on assignment alone');
  }
});

test('wallet SECURITY DEFINER RPCs pin search_path to trusted schemas', () => {
  const wallet = fs.readFileSync('supabase/migrations/20261109010000_create_secure_wallet_ledger_foundation.sql', 'utf8');
  assert.equal((wallet.match(/set search_path = pg_catalog, public, auth, pg_temp/gi)||[]).length, 2);
  assert.ok(!/set search_path = public, pg_temp/i.test(wallet));
});
