
alter table public.service_bookings
  add column if not exists amount_paid numeric(12,2);

alter table public.service_bookings
  add constraint service_bookings_amount_paid_nonnegative
  check (amount_paid is null or amount_paid >= 0);

create or replace function public.srk_calculate_booking_commission()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public, pg_temp
as $$
begin
  if new.amount_paid is not null and new.amount_paid < 0 then
    raise exception 'amount_paid cannot be negative';
  end if;
  if new.commission_rate is null or new.commission_rate < 0 or new.commission_rate > 100 then
    raise exception 'commission_rate must be between 0 and 100';
  end if;

  if new.status = 'completed' and new.payment_status = 'paid' and new.amount_paid is not null then
    new.commission_amount := round(new.amount_paid * new.commission_rate / 100, 2);
  else
    new.commission_amount := null;
  end if;
  return new;
end;
$$;

drop trigger if exists srk_calculate_booking_commission on public.service_bookings;
create trigger srk_calculate_booking_commission
before insert or update of status, payment_status, amount_paid, commission_rate
on public.service_bookings
for each row execute function public.srk_calculate_booking_commission();

create table if not exists public.service_booking_status_history (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete cascade,
  old_status text,
  new_status text not null,
  note text,
  changed_by uuid,
  changed_at timestamptz not null default now()
);

create index if not exists service_booking_status_history_booking_idx
  on public.service_booking_status_history (booking_id, changed_at desc);

alter table public.service_booking_status_history enable row level security;

drop policy if exists srk_admin_read_service_booking_history on public.service_booking_status_history;
create policy srk_admin_read_service_booking_history
on public.service_booking_status_history
for select to authenticated
using ((select public.is_srk_admin()));

drop policy if exists service_role_manage_service_booking_history on public.service_booking_status_history;
create policy service_role_manage_service_booking_history
on public.service_booking_status_history
for all to service_role
using (true) with check (true);

grant select on public.service_booking_status_history to authenticated;
grant all on public.service_booking_status_history to service_role;

create or replace function public.srk_log_service_booking_status()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.service_booking_status_history
      (booking_id, old_status, new_status, note, changed_by)
    values
      (new.id, null, new.status, 'Booking created', auth.uid());
  elsif new.status is distinct from old.status then
    insert into public.service_booking_status_history
      (booking_id, old_status, new_status, note, changed_by)
    values
      (new.id, old.status, new.status, 'Booking status updated', auth.uid());
  end if;
  return new;
end;
$$;

revoke all on function public.srk_log_service_booking_status() from public, anon, authenticated;
drop trigger if exists srk_log_service_booking_status on public.service_bookings;
create trigger srk_log_service_booking_status
after insert or update of status on public.service_bookings
for each row execute function public.srk_log_service_booking_status();
