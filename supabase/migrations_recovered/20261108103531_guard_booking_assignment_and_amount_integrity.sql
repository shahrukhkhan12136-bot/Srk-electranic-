ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_quoted_amount_range
  CHECK (quoted_amount IS NULL OR (quoted_amount >= 0 AND quoted_amount <= 10000000)),
  ADD CONSTRAINT service_bookings_amount_paid_range
  CHECK (amount_paid IS NULL OR (amount_paid >= 0 AND amount_paid <= 10000000)),
  ADD CONSTRAINT service_bookings_assignment_status_requires_electrician
  CHECK (status NOT IN ('assigned','in_progress','completed') OR assigned_electrician_id IS NOT NULL);