const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const availability = fs.readFileSync(path.join(root, 'supabase/migrations/20261114310000_electrician_self_availability.sql'), 'utf8');
const location = fs.readFileSync(path.join(root, 'supabase/migrations/20261114320000_booking_scoped_live_electrician_location.sql'), 'utf8');
const relocation = fs.readFileSync(path.join(root, 'supabase/migrations/20261114220000_admin_approved_electrician_relocation.sql'), 'utf8');
const dispatchRecheck = fs.readFileSync(path.join(root, 'supabase/migrations/20261114230000_recheck_electrician_current_area_before_offer.sql'), 'utf8');

test('availability changes require the linked authenticated active approved electrician', () => {
  assert.match(availability, /auth\.uid\(\)/);
  assert.match(availability, /WHERE user_id=v_uid AND auth_user_id=v_uid/);
  assert.match(availability, /v_profile\.active IS DISTINCT FROM true/);
  assert.match(availability, /v_profile\.verification_status<>'approved'/);
  assert.match(availability, /GRANT EXECUTE ON FUNCTION public\.srk_electrician_set_availability\(boolean\) TO authenticated/);
});

test('turning availability off closes only unaccepted offers and advances their queues', () => {
  assert.match(availability, /WHERE electrician_id=v_profile\.id AND status='offered'/);
  assert.match(availability, /PERFORM private\.srk_dispatch_next_booking_offer\(v_booking_id\)/);
  assert.match(availability, /available_for_work=p_available/);
});

test('live location is private and scoped to the electrician assigned to the travelling booking', () => {
  assert.match(location, /REVOKE ALL ON TABLE public\.srk_booking_live_locations FROM PUBLIC, anon, authenticated/);
  assert.match(location, /WHERE user_id=v_uid AND auth_user_id=v_uid AND active=true/);
  assert.match(location, /assigned_electrician_id=v_profile\.id[\s\S]*?status='assigned'/);
  assert.match(location, /p_accuracy_meters NOT BETWEEN 0 AND 150/);
  assert.match(location, /stopped_at IS NULL/);
});

test('customer live-location reads require ownership, assignment, travel status and a fresh update', () => {
  const start = location.indexOf('CREATE OR REPLACE FUNCTION public.srk_customer_get_live_electrician_location');
  const end = location.indexOf('$function$;', start);
  assert.ok(start >= 0 && end > start);
  const body = location.slice(start, end);
  assert.match(body, /b\.customer_user_id=v_uid/);
  assert.match(body, /b\.assigned_electrician_id IS NOT NULL AND b\.status='assigned'/);
  assert.match(body, /v_row\.updated_at < clock_timestamp\(\)-interval '90 seconds'/);
  assert.match(body, /'location_unavailable_or_stale'/);
  assert.match(location, /REVOKE ALL ON FUNCTION public\.srk_customer_get_live_electrician_location\(uuid\) FROM PUBLIC,anon/);
});

test('booking stage or assigned electrician changes clear active coordinates', () => {
  assert.match(location, /CREATE OR REPLACE FUNCTION public\.srk_stop_live_location_on_booking_transition/);
  assert.match(location, /NEW\.status IS DISTINCT FROM OLD\.status/);
  assert.match(location, /NEW\.assigned_electrician_id IS DISTINCT FROM OLD\.assigned_electrician_id/);
  assert.match(location, /SET is_active=false,latitude=NULL,longitude=NULL,accuracy_meters=NULL/);
});

test('relocation requests are private and only Admin approval changes the active operating area', () => {
  assert.match(relocation, /REVOKE ALL ON TABLE srk_private\.srk_electrician_area_change_requests FROM PUBLIC,anon,authenticated/);
  assert.match(relocation, /WHERE user_id=v_uid AND auth_user_id=v_uid FOR UPDATE/);
  const start = relocation.indexOf('CREATE OR REPLACE FUNCTION public.srk_admin_review_electrician_area_request');
  const body = relocation.slice(start);
  assert.match(body, /public\.is_srk_admin\(\)/);
  assert.match(body, /IF p_decision='approved' THEN[\s\S]*?UPDATE public\.electrician_profiles SET state=/);
  assert.match(body, /location_lat=NULL,location_lng=NULL/);
});

test('offer dispatch rechecks the electrician current operating area after a queued snapshot', () => {
  assert.match(dispatchRecheck, /lower\(trim\(e\.state\)\)=lower\(trim\(v_booking\.state\)\)/);
  assert.match(dispatchRecheck, /lower\(trim\(e\.district\)\)=lower\(trim\(v_booking\.district\)\)/);
  assert.match(dispatchRecheck, /v_electrician\.pincode=v_booking\.pincode/);
  assert.match(dispatchRecheck, /Recompute match label and distance from the electrician's CURRENT area\/location/);
});
