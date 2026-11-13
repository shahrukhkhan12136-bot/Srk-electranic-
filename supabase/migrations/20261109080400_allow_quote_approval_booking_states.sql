-- Allow inspection and quote-approval workflow states; require assigned electrician for every post-assignment state.
alter table public.service_bookings drop constraint if exists service_bookings_status_check;
alter table public.service_bookings add constraint service_bookings_status_check
 check (status = any(array['new','confirmed','assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed','cancelled']::text[]));
alter table public.service_bookings drop constraint if exists service_bookings_assignment_status_requires_electrician;
alter table public.service_bookings add constraint service_bookings_assignment_status_requires_electrician
 check ((status <> all(array['assigned','inspection','awaiting_quote_approval','quote_approved','quote_rejected','in_progress','completed']::text[])) or assigned_electrician_id is not null);
