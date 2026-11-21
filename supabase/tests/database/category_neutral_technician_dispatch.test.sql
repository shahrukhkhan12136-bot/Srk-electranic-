BEGIN;
SELECT plan(20);

SELECT has_table('public','srk_technician_presence','Technician presence and GPS state exists');
SELECT has_table('public','srk_technician_dispatch_requests','category-neutral dispatch requests exist');
SELECT has_table('public','srk_technician_dispatch_offers','sequential Technician offers exist');
SELECT has_table('public','srk_technician_dispatch_events','dispatch audit history exists');
SELECT has_column('public','srk_technician_presence','last_location_at','GPS freshness is recorded');
SELECT has_index('public','srk_technician_dispatch_offers','srk_technician_dispatch_one_live_offer_per_booking_uidx',
  'only one live offer can exist per booking');
SELECT has_index('public','srk_technician_dispatch_offers','srk_technician_dispatch_offers_expiry_idx',
  'expired live offers can be located efficiently');
SELECT has_index('public','srk_technician_dispatch_offers','srk_technician_dispatch_one_live_offer_per_technician_uidx',
  'a Technician cannot receive two simultaneous live offers');
SELECT has_trigger('public','srk_technician_dispatch_events','srk_technician_dispatch_events_append_only',
  'dispatch history cannot be rewritten');
SELECT has_trigger('public','service_bookings','srk_release_technician_presence_after_booking_terminal',
  'terminal booking releases active Technician presence');

SELECT ok(has_function('public','srk_technician_set_presence',ARRAY['boolean','double precision','double precision']),
  'Technician can set online state and GPS');
SELECT ok(has_function('public','srk_dispatch_create_for_booking',ARRAY['uuid','text','text','smallint','smallint']),
  'trusted backend can create a category-specific dispatch request');
SELECT ok(has_function('public','srk_dispatch_issue_next_offer',ARRAY['uuid']),
  'trusted worker can issue the next sequential offer');
SELECT ok(has_function('public','srk_dispatch_process_pending_queue',ARRAY[]::text[]),
  'existing worker can process pending category-neutral dispatches');
SELECT ok(has_function('public','srk_technician_respond_to_dispatch_offer',ARRAY['uuid','text']),
  'Technician can accept or decline their own offer');
SELECT ok(has_function('public','srk_technician_get_my_dispatch_offers',ARRAY[]::text[]),
  'Technician can read only their own offer inbox');

SELECT ok(
  has_function_privilege('authenticated',
    'public.srk_technician_set_presence(boolean,double precision,double precision)','EXECUTE')
  AND NOT has_function_privilege('anon',
    'public.srk_technician_set_presence(boolean,double precision,double precision)','EXECUTE'),
  'presence RPC is authenticated-only'
);
SELECT ok(
  has_function_privilege('service_role',
    'public.srk_dispatch_create_for_booking(uuid,text,text,smallint,smallint)','EXECUTE')
  AND NOT has_function_privilege('authenticated',
    'public.srk_dispatch_create_for_booking(uuid,text,text,smallint,smallint)','EXECUTE'),
  'dispatch creation is restricted to the trusted backend'
);
SELECT ok(
  position('last_location_at' in pg_get_functiondef(
    'public.srk_dispatch_issue_next_offer(uuid)'::regprocedure))>0
  AND position('30' in pg_get_functiondef(
    'public.srk_dispatch_issue_next_offer(uuid)'::regprocedure))>0,
  'dispatch uses fresh GPS and the 30 km radius'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_technician_dispatch_offers'::regclass),
  'dispatch offer table has RLS enabled'
);

SELECT * FROM finish();
ROLLBACK;
