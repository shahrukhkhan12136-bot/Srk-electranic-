ALTER TABLE public.service_bookings
 ADD CONSTRAINT service_bookings_per_item_quantity_limit
 CHECK (
  pricing_unit_snapshot IS DISTINCT FROM 'per_item'
  OR pricing_quantity BETWEEN 1 AND 100
 );