const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const customer = fs.readFileSync('apps/customer_app/lib/main.dart', 'utf8');
const electrician = fs.readFileSync('apps/electrician_app/lib/main.dart', 'utf8');
const sosMigration = fs.readFileSync('supabase/migrations/20261115260000_sos_admin_support_alerts.sql', 'utf8');

test('Customer mobile app exposes SOS only during one active booking and calls the server-owned SOS RPC', () => {
  assert.match(customer, /status == 'in_progress'[\s\S]*_bookings\.where\(\(b\) => b\['status'\] == 'in_progress'\)\.length == 1/);
  assert.match(customer, /srk_create_sos_alert/);
  assert.match(customer, /SMS\/Police को स्वतः कॉल या संदेश नहीं जाएगा/);
});

test('Technician mobile app exposes SOS only during one active booking and calls the server-owned SOS RPC', () => {
  assert.match(electrician, /activeBookingCount = bookingDetails\.where\(\(b\) => b\['booking_status'\] == 'in_progress'\)\.length/);
  assert.match(electrician, /srk_create_sos_alert/);
  assert.match(electrician, /SMS\/Police को स्वतः कॉल या संदेश नहीं जाएगा/);
});

test('SOS backend derives active booking and actor identity from the authenticated session', () => {
  assert.match(sosMigration, /v_uid uuid:=auth\.uid\(\)/);
  assert.match(sosMigration, /SOS_REQUIRES_ONE_ACTIVE_BOOKING/);
  assert.match(sosMigration, /actor_user_id,actor_role,actor_name,actor_phone/);
});
