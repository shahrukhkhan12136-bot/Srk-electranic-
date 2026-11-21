BEGIN;
SELECT plan(9);

SELECT has_constraint('public','service_bookings','service_bookings_assignment_status_requires_electrician',
  'canonical Master category is accepted for assigned work without a legacy electrician profile');
SELECT has_trigger('public','service_bookings','srk_guard_master_booking_status_transition',
  'Master booking status and commercial snapshots are guarded');
SELECT has_trigger('public','srk_technician_dispatch_requests','srk_promote_fully_assigned_master_booking',
  'dispatch completion promotes the same booking row to Assigned');
SELECT has_function('public','srk_guard_master_booking_status_transition',ARRAY[]::text[]);
SELECT has_function('public','srk_promote_fully_assigned_master_booking',ARRAY[]::text[]);
SELECT ok(
  has_column('public','service_bookings','srk_service_category_code')
  AND has_column('public','service_bookings','srk_service_skill_code')
  AND has_column('public','service_bookings','srk_service_code'),
  'Master booking canonical category, skill and service are present'
);
SELECT ok(
  has_column('public','srk_technician_dispatch_requests','required_technician_count')
  AND has_column('public','srk_technician_dispatch_requests','assigned_technician_count'),
  'dispatch request tracks requested and accepted Technician count'
);
SELECT ok(
  position('MASTER_BOOKING_SERVICE_AND_RATE_SNAPSHOTS_ARE_IMMUTABLE' in pg_get_functiondef(
    'public.srk_guard_master_booking_status_transition()'::regprocedure
  ))>0,
  'Master service and rate snapshots cannot be changed after booking creation'
);
SELECT ok(
  position('NEW.assigned_technician_count < NEW.required_technician_count' in pg_get_functiondef(
    'public.srk_promote_fully_assigned_master_booking()'::regprocedure
  ))>0,
  'booking is promoted only after every requested Technician has accepted'
);

SELECT * FROM finish();
ROLLBACK;
