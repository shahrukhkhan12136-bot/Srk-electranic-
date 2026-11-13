-- Canonical customer-selected work category and booked duration.
-- Legacy bookings remain NULL and are never inferred from free-form service_type.
ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS selected_category text,
  ADD COLUMN IF NOT EXISTS selected_duration_hours smallint;

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_selected_category_valid
  CHECK (
    selected_category IS NULL OR selected_category IN (
      'home_wiring',
      'electrical_repair',
      'light_fan_fitting',
      'home_repair',
      'other'
    )
  );

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_selected_duration_hours_valid
  CHECK (
    selected_duration_hours IS NULL OR selected_duration_hours BETWEEN 1 AND 8
  );

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_category_duration_pair
  CHECK ((selected_category IS NULL) = (selected_duration_hours IS NULL));

COMMENT ON COLUMN public.service_bookings.selected_category IS
  'Canonical customer-selected work category. NULL means legacy/unclassified; never infer from service_type.';
COMMENT ON COLUMN public.service_bookings.selected_duration_hours IS
  'Customer-booked duration estimate in whole hours (1–8). Actual billing uses server-recorded elapsed time.';
