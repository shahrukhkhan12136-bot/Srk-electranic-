-- Permanent customer-facing order numbers for every SRK ELECTRONIC booking.
-- Feature branch only. Do not apply to TEST or Production without owner approval.
begin;

create sequence if not exists public.srk_order_number_seq
  as bigint
  start with 1
  increment by 1
  minvalue 1
  no cycle;

alter table public.service_bookings
  add column if not exists order_number text;

-- Give legacy bookings stable, unique numbers before enforcing NOT NULL.
with numbered as (
  select id,
         'SRK-ORD-' || lpad(nextval('public.srk_order_number_seq')::text, 6, '0') as number
  from public.service_bookings
  where order_number is null
  order by id
)
update public.service_bookings b
set order_number = numbered.number
from numbered
where b.id = numbered.id;

alter table public.service_bookings
  alter column order_number
  set default ('SRK-ORD-' || lpad(nextval('public.srk_order_number_seq')::text, 6, '0'));

alter table public.service_bookings
  alter column order_number set not null;

create unique index if not exists service_bookings_order_number_uidx
  on public.service_bookings(order_number);

-- Keep order numbers immutable after assignment.
create or replace function public.srk_guard_booking_order_number()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.order_number is distinct from old.order_number then
    raise exception 'BOOKING_ORDER_NUMBER_IMMUTABLE' using errcode='55000';
  end if;
  return new;
end
$function$;

drop trigger if exists z_srk_guard_booking_order_number on public.service_bookings;
create trigger z_srk_guard_booking_order_number
before update of order_number on public.service_bookings
for each row execute function public.srk_guard_booking_order_number();

revoke all on function public.srk_guard_booking_order_number() from public, anon, authenticated;

commit;
