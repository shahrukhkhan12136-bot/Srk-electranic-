
alter table public.service_bookings
  alter column payment_method set default 'Unselected';

comment on column public.service_bookings.payment_method is
'Customer-selected payment method after final bill; new bookings default to Unselected. Legacy rows retain their stored value.';
