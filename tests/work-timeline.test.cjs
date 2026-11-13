"use strict";
const test=require("node:test");
const fs=require("node:fs");
const path=require("node:path");
const assert=require("node:assert/strict");
const root=path.resolve(__dirname,"..");
const migration=fs.readFileSync(path.join(root,"supabase/migrations/20261114070000_customer_safe_idempotent_booking_timeline.sql"),"utf8");
const booking=fs.readFileSync(path.join(root,"booking.html"),"utf8");
const rpc=migration.slice(migration.indexOf("CREATE OR REPLACE FUNCTION public.srk_customer_get_my_booking_work_timeline()"));

test("timeline events carry explicit actor role and unique idempotency key",()=>{
 for(const value of ["ADD COLUMN IF NOT EXISTS actor_role text","ADD COLUMN IF NOT EXISTS idempotency_key text","CREATE UNIQUE INDEX IF NOT EXISTS srk_booking_work_events_idempotency_key_uidx","ON CONFLICT (idempotency_key) DO NOTHING"]) assert.ok(migration.includes(value),value);
});
test("historical events are marked unknown and not given invented event timestamps",()=>{
 assert.ok(migration.includes("SET actor_role='unknown'"));
 assert.ok(migration.includes("legacy-event:'||id::text"));
 assert.ok(!migration.includes("generate_series"));
});
test("actor roles are derived from authenticated ownership and Admin authorization",()=>{
 for(const value of ["NEW.customer_user_id=v_actor THEN 'customer'","ep.user_id=v_actor OR ep.auth_user_id=v_actor","public.is_srk_admin() THEN 'admin'"]) assert.ok(migration.includes(value),value);
});
test("customer timeline RPC is authenticated and filters strictly by booking ownership",()=>{
 for(const value of ["CREATE OR REPLACE FUNCTION public.srk_customer_get_my_booking_work_timeline()","IF auth.uid() IS NULL THEN","JOIN public.service_bookings b ON b.id=e.booking_id","WHERE b.customer_user_id=auth.uid()","REVOKE ALL ON FUNCTION public.srk_customer_get_my_booking_work_timeline() FROM PUBLIC, anon","GRANT EXECUTE ON FUNCTION public.srk_customer_get_my_booking_work_timeline() TO authenticated"]) assert.ok(migration.includes(value),value);
 assert.ok(!rpc.includes("actor_id uuid"));
});
test("customer timeline returns ordered safe event fields without private details",()=>{
 for(const value of ["event_type text","actor_role text","old_status text","new_status text","occurred_at timestamptz","ORDER BY e.booking_id,e.occurred_at,e.id"]) assert.ok(rpc.includes(value),value);
 assert.ok(!rpc.includes("e.details"));
});
test("customer booking page uses safe timeline RPC and real event timestamps",()=>{
 for(const value of ["rpc('srk_customer_get_my_booking_work_timeline')","customerBookingEventLabels","customerBookingTimeText(event.occurred_at)","customerEsc(customerBookingEventText(event.event_type))"]) assert.ok(booking.includes(value),value);
 assert.ok(!booking.includes("rpc('srk_get_customer_booking_timeline')"));
});
test("timeline UI labels only known observed event types and preserves no-history message",()=>{
 for(const value of ["booking_created","work_start_requested","work_start_approved","work_completion_requested","work_completion_rejected","work_completion_disputed","work_completion_customer_approved","work_completion_admin_approved","इस बुकिंग का अलग स्थिति इतिहास अभी उपलब्ध नहीं है"]) assert.ok(booking.includes(value),value);
});
