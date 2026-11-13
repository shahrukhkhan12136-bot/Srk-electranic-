BEGIN;
SELECT plan(6);

SELECT has_column('public','service_bookings','selected_category','canonical customer-selected category column exists');
SELECT has_column('public','service_bookings','selected_duration_hours','customer-selected duration column exists');

SELECT ok(
  (SELECT is_nullable='YES' FROM information_schema.columns
   WHERE table_schema='public' AND table_name='service_bookings' AND column_name='selected_category'),
  'legacy bookings remain nullable and are not backfilled by inference'
);
SELECT ok(
  (SELECT is_nullable='YES' FROM information_schema.columns
   WHERE table_schema='public' AND table_name='service_bookings' AND column_name='selected_duration_hours'),
  'legacy duration remains nullable'
);
SELECT ok(
  EXISTS (SELECT 1 FROM pg_constraint
          WHERE conrelid='public.service_bookings'::regclass
            AND conname='service_bookings_selected_category_valid'),
  'category allowlist constraint exists'
);
SELECT ok(
  EXISTS (SELECT 1 FROM pg_constraint
          WHERE conrelid='public.service_bookings'::regclass
            AND conname='service_bookings_selected_duration_hours_valid')
  AND EXISTS (SELECT 1 FROM pg_constraint
          WHERE conrelid='public.service_bookings'::regclass
            AND conname='service_bookings_category_duration_pair'),
  'duration range and paired-null legacy constraints exist'
);

SELECT * FROM finish();
ROLLBACK;
