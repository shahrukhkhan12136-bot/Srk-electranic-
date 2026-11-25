
alter table public.srk_booking_worker_events drop constraint if exists srk_booking_worker_event_type_valid;
alter table public.srk_booking_worker_events add constraint srk_booking_worker_event_type_valid
 check (event_type = any (array[
 'offered','accepted','rejected','assigned','working','paused','completed','released','cancelled','timed_out',
 'cancellation_fault_reviewed','released_due_to_suspension'
 ]::text[]));
alter function public.srk_verify_worker_identity_qr(text) volatile;
