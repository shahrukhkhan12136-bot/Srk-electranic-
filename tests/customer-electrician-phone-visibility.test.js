const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const offerDetails = fs.readFileSync(path.join(root, 'supabase/migrations/20261114370000_electrician_offer_details_immediate_booking_fields.sql'), 'utf8');
const customerContacts = fs.readFileSync(path.join(root, 'supabase/migrations/20261109103143_move_customer_call_contact_lookup_to_private.sql'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');

test('electrician personal customer details are returned only for the assigned electrician', () => {
  for (const field of ['b.customer_name', 'b.phone', 'b.address', 'b.location_lat', 'b.location_lng']) {
    const escaped = field.replace('.', '\\\\.');
    const pattern = new RegExp('CASE\\\\s+WHEN b\\\\.assigned_electrician_id=p\\\\.id\\\\s+AND b\\\\.status IN\\\\s*\\\\([\\\\s\\\\S]*?\\\\)\\\\s+THEN ' + escaped + ' ELSE NULL END', 'i');
    assert.match(offerDetails, pattern, 'personal field must be assignment-gated: ' + field);
  }
  assert.match(offerDetails, /AND p\\.verification_status='approved'[\\s\\S]*AND p\\.active=true/i);
  assert.match(electrician, /o\\.customer_name\\?/);
  assert.match(electrician, /ग्राहक का विवरण काम आपको असाइन होने के बाद दिखेगा/);
});

test('customer direct-call lookup is authenticated and scoped to the booking owner', () => {
  assert.match(customerContacts, /if v_uid is null then[\\s\\S]*raise exception 'Authentication required'/i);
  assert.match(customerContacts, /where b\\.customer_user_id = v_uid[\\s\\S]*and b\\.assigned_electrician_id is not null/i);
  assert.match(customerContacts, /revoke all on function public\\.srk_get_customer_call_contacts\\(\\) from public, anon/i);
  assert.match(customerContacts, /grant execute on function public\\.srk_get_customer_call_contacts\\(\\) to authenticated/i);
  assert.match(booking, /customerSb\\.rpc\\('srk_get_customer_call_contacts'\\)/);
  assert.doesNotMatch(booking, /\\.select\\([^\\n]*\\bphone\\b[^\\n]*\\)\\s*\\.eq\\('customer_user_id'/i);
});
