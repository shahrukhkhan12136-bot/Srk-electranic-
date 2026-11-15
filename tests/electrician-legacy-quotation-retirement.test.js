const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const retirement = fs.readFileSync(path.join(root, 'supabase/migrations/20261115220000_retire_live_legacy_quotation_rpcs.sql'), 'utf8');

test('electrician portal contains no legacy inspection or quotation UI/data fallback', () => {
  for (const legacy of [
    'quoted_amount', 'quote_status', 'quote_note', 'service_charge',
    'materials_amount', 'awaiting_quote_approval', 'quote_approved',
    'quote_rejected', 'submitQuote', 'inspection'
  ]) {
    assert.equal(electrician.includes(legacy), false, 'legacy quotation reference remains: ' + legacy);
  }
  assert.match(electrician, /estimated_labour_paise/);
  assert.match(electrician, /श्रम अनुमान उपलब्ध नहीं/);
});

test('backend retirement disables legacy quote/status RPCs without deleting historical booking data', () => {
  for (const rpc of [
    'srk_submit_booking_quote(uuid,numeric,numeric,text)',
    'srk_customer_respond_booking_quote(uuid,text)',
    'srk_update_booking_work_status(uuid,text)'
  ]) {
    assert.ok(retirement.includes('REVOKE ALL ON FUNCTION public.' + rpc));
    assert.ok(retirement.includes('DROP FUNCTION IF EXISTS public.' + rpc));
  }
  assert.match(retirement, /DROP FUNCTION IF EXISTS public\.srk_get_my_offer_details\(\)/);
  assert.match(retirement, /offer_expires_at timestamptz/);
  assert.match(retirement, /estimated_labour_paise bigint/);
  assert.match(retirement, /work_timer_running boolean/);
  assert.doesNotMatch(retirement, /quoted_amount numeric|service_charge numeric|materials_amount numeric|quote_status text|quote_note text/);
  assert.match(retirement, /Historical booking\/payment records remain preserved/);
});
