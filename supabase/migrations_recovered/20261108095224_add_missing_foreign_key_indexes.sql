create index if not exists booking_status_history_booking_id_idx on public.booking_status_history (booking_id);
create index if not exists bookings_electrician_id_idx on public.bookings (electrician_id);
create index if not exists bookings_service_id_idx on public.bookings (service_id);