
-- Structured pricing inputs and immutable booking-time pricing rule reference.
alter table public.service_bookings
  add column if not exists pricing_unit_snapshot text,
  add column if not exists pricing_quantity numeric(12,3),
  add column if not exists motor_hp numeric(8,2),
  add column if not exists pricing_rule_id uuid references public.srk_service_pricing_rules(id) on delete restrict;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='service_bookings_pricing_unit_snapshot_valid') then
    alter table public.service_bookings add constraint service_bookings_pricing_unit_snapshot_valid
      check (pricing_unit_snapshot is null or pricing_unit_snapshot in ('hour','per_item','motor_hp'));
  end if;
  if not exists (select 1 from pg_constraint where conname='service_bookings_pricing_quantity_positive') then
    alter table public.service_bookings add constraint service_bookings_pricing_quantity_positive
      check (pricing_quantity is null or pricing_quantity > 0);
  end if;
  if not exists (select 1 from pg_constraint where conname='service_bookings_motor_hp_positive') then
    alter table public.service_bookings add constraint service_bookings_motor_hp_positive
      check (motor_hp is null or motor_hp >= 0.5);
  end if;
end $$;

create or replace function public.srk_set_final_bill_item_total()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.line_total := round(new.quantity * new.unit_price, 2);
  return new;
end;
$$;

drop trigger if exists srk_final_bill_item_total_trg on public.srk_booking_final_bill_items;
create trigger srk_final_bill_item_total_trg
before insert or update of quantity, unit_price
on public.srk_booking_final_bill_items
for each row execute function public.srk_set_final_bill_item_total();

create or replace function public.srk_set_final_bill_total()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.total_amount := round(new.service_amount + new.materials_amount - new.discount_amount + new.tax_amount, 2);
  return new;
end;
$$;

drop trigger if exists srk_final_bill_total_trg on public.srk_booking_final_bills;
create trigger srk_final_bill_total_trg
before insert or update of service_amount, materials_amount, discount_amount, tax_amount
on public.srk_booking_final_bills
for each row execute function public.srk_set_final_bill_total();

-- Internal trigger helpers must not be callable by API roles.
revoke all on function public.srk_set_final_bill_item_total() from public, anon, authenticated;
revoke all on function public.srk_set_final_bill_total() from public, anon, authenticated;

create index if not exists service_bookings_pricing_rule_idx
  on public.service_bookings(pricing_rule_id)
  where pricing_rule_id is not null;
