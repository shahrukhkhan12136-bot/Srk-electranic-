const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customerContact = fs.readFileSync(path.join(root, 'supabase/migrations/20261109103143_move_customer_call_contact_lookup_to_private.sql'), 'utf8');
const electricianOffers = fs.readFileSync(path.join(root, 'supabase/migrations/20261114370000_electrician_offer_details_immediate_booking_fields.sql'), 'utf8');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');

test('customer sees electrician contact only after an electrician is assigned, and keeps it after completion/cancellation', () => {
  assert.match(customerContact, /b\.assigned_electrician_id is not null/);
  assert.doesNotMatch(customerContact, /b\.status in \('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress'\)/);
  assert.match(booking, /☎ इलेक्ट्रिशियन को कॉल करें/);
  assert.doesNotMatch(booking, /काम पूरा हो चुका है। इलेक्ट्रिशियन का मोबाइल नंबर अब प्रदर्शित नहीं होगा।/);
});

test('electrician receives customer contact only when that electrician owns the assignment', () => {
  assert.match(electricianOffers, /b\.assigned_electrician_id=p\.id/);
  assert.match(electricianOffers, /'assigned'.*'completed','cancelled'/s);
  assert.match(electricianOffers, /THEN b[.]phone\s+ELSE NULL END/);
});
