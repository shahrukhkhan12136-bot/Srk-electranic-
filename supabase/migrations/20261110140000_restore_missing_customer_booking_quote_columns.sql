-- Restore fields selected by the customer mobile app booking history query.
-- Additive and nullable: existing bookings and quote workflow remain unchanged.
alter table public.service_bookings
  add column if not exists customer_suggested_amount numeric(12,2),
  add column if not exists electrician_quote_kind text;

comment on column public.service_bookings.customer_suggested_amount is
  'Optional amount suggested by the customer for the service booking.';
comment on column public.service_bookings.electrician_quote_kind is
  'Optional quote classification supplied by the electrician.';

notify pgrst, 'reload schema';
