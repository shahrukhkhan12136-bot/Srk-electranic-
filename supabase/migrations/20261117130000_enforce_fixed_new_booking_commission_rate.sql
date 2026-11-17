-- Fix the company commission at 15% for every newly-created booking.
-- Historical booking commission snapshots remain unchanged and immutable.
-- This does not rewrite/backfill any existing service_bookings rows.

create or replace function public.srk_enforce_new_booking_commission_rate()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    -- Ignore any client/service-role supplied percentage for new bookings.
    new.commission_rate := 15.00;
    return new;
  end if;

  -- Preserve each historical booking's stored commission snapshot.
  if new.commission_rate is distinct from old.commission_rate then
    raise exception 'BOOKING_COMMISSION_RATE_IS_IMMUTABLE';
  end if;

  return new;
end;
$$;

revoke all on function public.srk_enforce_new_booking_commission_rate() from public, anon, authenticated;

drop trigger if exists aa_srk_enforce_new_booking_commission_rate on public.service_bookings;
create trigger aa_srk_enforce_new_booking_commission_rate
before insert or update of commission_rate on public.service_bookings
for each row
execute function public.srk_enforce_new_booking_commission_rate();

comment on function public.srk_enforce_new_booking_commission_rate() is
  'Forces exactly 15 percent on new bookings and preserves existing booking commission snapshots against edits.';

