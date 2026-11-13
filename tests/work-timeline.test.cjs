"use strict";
const test=require("node:test");
const fs=require("node:fs");
const path=require("node:path");
const assert=require("node:assert/strict");
const root=path.resolve(__dirname,"..");
const migration=fs.readFileSync(path.join(root,"supabase/migrations/20261114070000_customer_safe_idempotent_booking_timeline.sql"),"utf8");
const booking=fs.readFileSync(path.join(root,"booking.html"),"utf8");

test("timeline events carry an explicit actor role and unique idempotency key",()=>{
 assert.match(migration,/ADD COLUMN IF NOT EXISTS actor_role text/);
 assert.match(migration,/ADD COLUMN IF NOT EXISTS idempotency_key text/);
 assert.match(migration,/CREATE UNIQUE INDEX IF NOT EXISTS srk_booking_work_events_idempotency_key_uidx/);
 assert.match(migration,/ON CONFLICT \\(idempotency_key\\) DO NOTHING/);
});
test("historical events are marked unknown rather than fabricating actors or times",()=>{
 assert.match(migration,/SET actor_role='unknown'[\\s\\S]*WHERE actor_role IS NULL/);
 assert.match(migration,/legacy-event:'\\|\\|id::text/);
});
test("actor roles are derived from authenticated ownership and Admin authorization",()=>{
 assert.match(migration,/NEW\\.customer_user_id=v_actor THEN 'customer'/);
 assert.match(migration,/ep\\.user_id=v_actor OR ep\\.auth_user_id=v_actor/);
 assert.match(migration,/public\\.is_srk_admin\\(\\) THEN 'admin'/);
});
test("customer timeline RPC is authenticated and filters strictly by booking ownership",()=>{
 assert.match(migration,/CREATE OR REPLACE FUNCTION public\\.srk_customer_get_my_booking_work_timeline\\(\\)/);
 assert.match(migration,/JOIN public\\.service_bookings b ON b\\.id=e\\.booking_id[\\s\\S]*WHERE b\\.customer_user_id=auth\\.uid\\(\\)/);
 assert.match(migration,/REVOKE ALL ON FUNCTION public\\.srk_customer_get_my_booking_work_timeline\\(\\) FROM PUBLIC, anon/);
 assert.match(migration,/GRANT EXECUTE ON FUNCTION public\\.srk_customer_get_my_booking_work_timeline\\(\\) TO authenticated/);
 assert.doesNotMatch(migration,/RETURNS TABLE\\([\\s\\S]*actor_id uuid/);
});
test("customer timeline returns ordered safe event fields without private details",()=>{
 assert.match(migration,/event_type text,[\\s\\S]*actor_role text,[\\s\\S]*old_status text,[\\s\\S]*new_status text,[\\s\\S]*occurred_at timestamptz/);
 assert.match(migration,/ORDER BY e\\.booking_id,e\\.occurred_at,e\\.id/);
 assert.doesNotMatch(migration,/RETURN QUERY[\\s\\S]*SELECT[\\s\\S]*e\\.details/);
});
test("customer booking page uses safe timeline RPC and real event timestamps",()=>{
 assert.match(booking,/rpc\\('srk_customer_get_my_booking_work_timeline'\\)/);
 assert.match(booking,/customerBookingEventLabels/);
 assert.match(booking,/customerBookingTimeText\\(event\\.occurred_at\\)/);
 assert.match(booking,/customerEsc\\(customerBookingEventText\\(event\\.event_type\\)\\)/);
 assert.doesNotMatch(booking,/rpc\\('srk_get_customer_booking_timeline'\\)/);
});
test("timeline UI labels only known observed event types",()=>{
 for(const key of ["booking_created","work_start_requested","work_start_approved","work_completion_requested","work_completion_rejected","work_completion_disputed","work_completion_customer_approved","work_completion_admin_approved"]) assert.ok(booking.includes(key));
 assert.match(booking,/इस बुकिंग का अलग स्थिति इतिहास अभी उपलब्ध नहीं है/);
});
