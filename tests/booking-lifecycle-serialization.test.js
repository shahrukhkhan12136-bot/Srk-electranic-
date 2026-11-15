const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const customer = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const timerSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114240000_server_authoritative_customer_approved_work_timer.sql'), 'utf8');
const startFixSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114260000_fix_work_start_rpc_and_append_only_event_history.sql'), 'utf8');
const multiProfileBillSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261115145900_fix_multi_profile_electrician_labour_bill_access.sql'), 'utf8');

function handler(source, name) {
  const start = source.indexOf('async function ' + name + '(');
  assert.ok(start >= 0, name + ' handler exists');
  const tail = source.slice(start + 1);
  const next = tail.search(/\n(?:async )?function\s+[A-Za-z0-9_$]+\s*\(/);
  return source.slice(start, next < 0 ? source.length : start + 1 + next);
}

test('electrician start and completion requests are serialized per booking', () => {
  assert.match(electrician, /const electricianLifecycleBusy=new Set\(\)/);
  for (const [name, rpc] of [
    ['electricianRequestWorkStart', 'srk_electrician_request_work_start'],
    ['electricianRequestWorkCompletion', 'srk_electrician_request_work_completion']
  ]) {
    const fn = handler(electrician, name);
    assert.match(fn, /electricianLifecycleBusy\.has\(bookingId\)/);
    assert.match(fn, /electricianLifecycleBusy\.add\(bookingId\)/);
    assert.match(fn, new RegExp(rpc));
    assert.match(fn, /finally\{electricianLifecycleBusy\.delete\(bookingId\);\}/);
  }
});

test('customer start approval is validated and serialized per booking', () => {
  assert.match(customer, /const customerLifecycleBusy=new Set\(\)/);
  const fn = handler(customer, 'customerRespondWorkStart');
  assert.match(fn, /!\['approved','rejected'\]\.includes\(response\)/);
  assert.match(fn, /customerLifecycleBusy\.has\(bookingId\)/);
  assert.match(fn, /customerLifecycleBusy\.add\(bookingId\)/);
  assert.match(fn, /srk_customer_respond_work_start/);
  assert.match(fn, /finally\{customerLifecycleBusy\.delete\(bookingId\);\}/);
});

test('customer completion response allows only approve, reject or dispute and requires dispute reason', () => {
  const fn = handler(customer, 'customerRespondWorkCompletion');
  assert.match(fn, /!\['approved','rejected','disputed'\]\.includes\(response\)/);
  assert.match(fn, /note\.length<20\|\|note\.length>1000/);
  assert.match(fn, /srk_customer_respond_work_completion/);
  assert.match(fn, /customerLifecycleBusy\.has\(bookingId\)/);
  assert.match(fn, /finally[\s\S]*?customerLifecycleBusy\.delete\(bookingId\)/);
});

test('customer and electrician timers are display-only projections of server timestamps and elapsed seconds', () => {
  assert.match(customer, /work_timer_elapsed_seconds,work_started_at,work_timer_running/);
  assert.match(customer, /Date\.parse\(el\.dataset\.started\)/);
  assert.match(electrician, /data-running=.*work_timer_running/);
  assert.match(electrician, /Date\.parse\(el\.dataset\.started\)/);
  assert.match(electrician, /srk_electrician_get_labour_bill/);
  assert.doesNotMatch(customer + electrician, /\.update\(\{[^}]*work_timer_(?:running|elapsed_seconds)/);
});

test('electrician offer response is restricted to accepted/declined and rejects duplicate in-flight response', () => {
  const fn = handler(electrician, 'respond');
  assert.match(fn, /!\['accepted','declined'\]\.includes\(response\)/);
  assert.match(fn, /electricianOfferResponseBusy\.has\(id\)/);
  assert.match(fn, /electricianOfferResponseBusy\.add\(id\)/);
  assert.match(fn, /srk_respond_to_offer/);
  assert.match(fn, /data\?\.success!==true/);
  assert.match(fn, /finally[\s\S]*?electricianOfferResponseBusy\.delete\(id\)/);
});

test('booking lifecycle UI distinguishes pending start, running work, completion review and dispute', () => {
  assert.match(electrician, /booking_status==='awaiting_work_start_approval'/);
  assert.match(electrician, /booking_status==='in_progress'/);
  assert.match(electrician, /completion_approval_status==='pending'/);
  assert.match(electrician, /completion_approval_status==='disputed'/);
  assert.match(customer, /work_start_approval_status/);
  assert.match(customer, /completion_approval_status/);
  assert.match(customer, /completion_approval_status==='pending'/);
});


function sqlFunction(source, name) {
  const start = source.indexOf('CREATE OR REPLACE FUNCTION public.' + name + '(');
  assert.ok(start >= 0, name + ' SQL function exists');
  const end = source.indexOf('$function$;', start);
  assert.ok(end > start, name + ' SQL function body ends');
  return source.slice(start, end + '$function$;'.length);
}

test('server work-start request and customer approval lock the booking and use server clock', () => {
  const request = sqlFunction(timerSql, 'srk_electrician_request_work_start');
  const approval = sqlFunction(startFixSql, 'srk_customer_respond_work_start');
  assert.match(request, /assigned_electrician_id=v_profile FOR UPDATE/);
  assert.match(request, /work_start_requested_at=clock_timestamp\(\)/);
  assert.match(request, /work_timer_running=false/);
  assert.match(approval, /customer_user_id=auth\.uid\(\)[\s\S]*?FOR UPDATE/);
  assert.match(approval, /work_started_at=clock_timestamp\(\)/);
  assert.match(approval, /work_timer_running=true/);
  assert.match(approval, /work_start_approval_status='rejected'/);
});

test('server completion freezes elapsed time and customer rejection resumes from server time', () => {
  const request = sqlFunction(timerSql, 'srk_electrician_request_work_completion');
  const response = sqlFunction(timerSql, 'srk_customer_respond_work_completion');
  assert.match(request, /assigned_electrician_id=v_profile FOR UPDATE/);
  assert.match(request, /clock_timestamp\(\)-b\.work_started_at/);
  assert.match(request, /work_timer_running=false/);
  assert.match(request, /completion_approval_status='pending'/);
  assert.match(response, /customer_user_id=auth\.uid\(\)[\s\S]*?FOR UPDATE/);
  assert.match(response, /IF p_response='approved' THEN/);
  assert.match(response, /INSERT INTO public\.srk_booking_labour_bills/);
  assert.match(response, /ELSIF p_response='rejected' THEN[\s\S]*?work_started_at=clock_timestamp\(\),work_timer_running=true/);
  assert.match(response, /ELSE[\s\S]*?srk_booking_complaints[\s\S]*?completion_approval_status='disputed'[\s\S]*?work_timer_running=false/);
});

test('offer acceptance verifies assigned electrician and locks offer plus booking before assignment', () => {
  const fn = sqlFunction(timerSql, 'srk_respond_to_offer');
  assert.match(fn, /e\.user_id=auth\.uid\(\) AND e\.auth_user_id=auth\.uid\(\)/);
  assert.match(fn, /e\.verification_status='approved' AND e\.active=true/);
  assert.match(fn, /FOR UPDATE OF o/);
  assert.match(fn, /FROM public\.service_bookings WHERE id=v_booking_id FOR UPDATE/);
  assert.match(fn, /status='accepted'/);
  assert.match(fn, /assigned_electrician_id=v_electrician_id,status='assigned'/);
  assert.match(fn, /v_expires_at<=clock_timestamp\(\)/);
});

test('base work-start migration has no undeclared dispute-note references', () => {
  const approval = sqlFunction(timerSql, 'srk_customer_respond_work_start');
  assert.match(approval, /p_response NOT IN \('approved','rejected'\)/);
  assert.doesNotMatch(approval, /\bp_note\b|\bv_note\b/);
});


test('completion RPC comment documents the full three-argument signature', () => {
  assert.match(timerSql, /CREATE OR REPLACE FUNCTION public\.srk_customer_respond_work_completion\(p_booking_id uuid,p_response text,p_note text DEFAULT NULL\)/);
  assert.match(timerSql, /COMMENT ON FUNCTION public\.srk_customer_respond_work_completion\(uuid,text,text\) IS/);
  assert.doesNotMatch(timerSql, /COMMENT ON FUNCTION public\.srk_customer_respond_work_completion\(uuid,text\) IS/);
});

test('electrician labour bill access recognizes any profile owned by the authenticated user', () => {
  const fn = sqlFunction(multiProfileBillSql, 'srk_electrician_get_labour_bill');
  assert.match(fn, /bill\.booking_id=p_booking_id/);
  assert.match(fn, /EXISTS\s*\([\s\S]*?profile\.id=bill\.electrician_profile_id/);
  assert.match(fn, /profile\.user_id=auth\.uid\(\) OR profile\.auth_user_id=auth\.uid\(\)/);
  assert.doesNotMatch(fn, /ORDER BY profile\.created_at DESC LIMIT 1/);
  assert.match(multiProfileBillSql, /REVOKE ALL ON FUNCTION public\.srk_electrician_get_labour_bill\(uuid\) FROM PUBLIC,anon/);
  assert.match(multiProfileBillSql, /GRANT EXECUTE ON FUNCTION public\.srk_electrician_get_labour_bill\(uuid\) TO authenticated/);
});

test('customer work lifecycle SECURITY DEFINER RPCs retain the private authorization schema in search_path', () => {
  assert.ok(startFixSql.includes("alter function public.srk_customer_respond_work_start(uuid,text)"));
  assert.ok(startFixSql.includes("alter function public.srk_customer_respond_work_completion(uuid,text,text)"));
  assert.ok((startFixSql.match(/set search_path = 'pg_catalog, public, auth, srk_private, pg_temp'/g) || []).length >= 2);
});
