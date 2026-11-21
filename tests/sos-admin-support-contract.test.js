const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261115260000_sos_admin_support_alerts.sql'), 'utf8');
const pgTap = fs.readFileSync(path.join(root, 'supabase/tests/database/sos_admin_support_alerts.test.sql'), 'utf8');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');

test('Customer and Electrician clients send only the approved reason to the SOS RPC', () => {
  assert.match(booking, /rpc\('srk_create_sos_alert',\{p_reason:reason\}\)/);
  assert.match(electrician, /rpc\('srk_create_sos_alert',\{p_reason:reason\}\)/);
  assert.doesNotMatch(booking, /srk_create_sos_alert'\s*,\s*\{[^}]*booking_id/);
  assert.doesNotMatch(electrician, /srk_create_sos_alert'\s*,\s*\{[^}]*booking_id/);
});

test('SOS creation derives one active booking and actor from authenticated server-side identity', () => {
  assert.match(migration, /v_uid uuid:=auth\.uid\(\)/);
  assert.match(migration, /customer_user_id=v_uid/);
  assert.match(migration, /ep\.user_id=v_uid or ep\.auth_user_id=v_uid/);
  assert.match(migration, /SOS_ACTIVE_BOOKING_AMBIGUOUS/);
  assert.match(migration, /SOS_REQUIRES_ONE_ACTIVE_BOOKING/);
  assert.match(migration, /status='in_progress'/);
  assert.match(migration, /selected_category is not null/);
});


test('SOS contact snapshots respect schema bounds and tolerate malformed phone values', () => {
  assert.ok(migration.includes("v_actor_name:=left(coalesce(nullif(btrim(v_booking.customer_name),''),'Customer'),120)"));
  assert.ok(migration.includes("v_actor_name:=left(coalesce(nullif(btrim(v_profile.display_name),''),'Electrician'),120)"));
  assert.ok(migration.includes("length(btrim(coalesce(v_booking.phone,''))) between 5 and 30"));
  assert.ok(migration.includes("length(btrim(coalesce(v_profile.phone,''))) between 5 and 30"));
  assert.ok(migration.includes("then btrim(v_booking.phone) else 'Unavailable' end"));
  assert.ok(migration.includes("then btrim(v_profile.phone) else 'Unavailable' end"));
});

test('SOS cases and event history are private and append-only', () => {
  assert.match(migration, /alter table public\.srk_sos_alerts enable row level security/i);
  assert.match(migration, /revoke all on public\.srk_sos_alerts from public,anon,authenticated/i);
  assert.match(migration, /revoke all on public\.srk_sos_alert_events from public,anon,authenticated/i);
  assert.match(migration, /SOS_EVENT_HISTORY_IS_APPEND_ONLY/);
  assert.match(migration, /before update or delete on public\.srk_sos_alert_events/i);
  assert.match(migration, /before truncate on public\.srk_sos_alert_events/i);
});

test('Support Staff receive explicit SOS read and acknowledgement permissions', () => {
  assert.match(migration, /support\.sos\.read/);
  assert.match(migration, /support\.sos\.acknowledge/);
  assert.match(migration, /srk_has_admin_permission\('support\.sos\.read'\)/);
  assert.match(migration, /srk_has_admin_permission\('support\.sos\.acknowledge'\)/);
});

test('Admin and Support portal displays SOS queue, delivery limits and acknowledgement history', () => {
  assert.match(admin, /srk_admin_list_sos_alerts/);
  assert.match(admin, /srk_admin_acknowledge_sos_alert/);
  assert.match(admin, /srk_admin_list_sos_alert_events/);
  assert.match(admin, /SMS\/Push provider अभी configured नहीं है/);
  assert.match(admin, /ऐप पुलिस\/112 को स्वतः सूचना नहीं भेजता/);
  assert.match(admin, /मैंने SOS केस स्वीकार किया/);
});

test('SOS does not claim SMS, Push or location delivery without configuration and consent', () => {
  assert.match(migration, /sms_delivery_status text not null default 'not_configured'/);
  assert.match(migration, /push_delivery_status text not null default 'not_configured'/);
  assert.match(migration, /location_status text not null default 'not_shared'/);
  assert.match(migration, /'sms_delivery_status','not_configured'/);
  assert.match(migration, /'push_delivery_status','not_configured'/);
});

test('SOS pgTAP plan count matches its assertion count', () => {
  const plan = Number(pgTap.match(/select plan\((\d+)\)/)?.[1]);
  const assertions = (pgTap.match(/\bselect (?:ok|has_table|has_function)\(/g) || []).length;
  assert.equal(assertions, plan);
});
