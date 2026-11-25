
create or replace function public.srk_exclude_materials_from_new_bookings()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  new.materials_amount := 0;
  if new.service_charge is not null then new.quoted_amount := new.service_charge; end if;
  return new;
end; $$;

drop trigger if exists srk_exclude_materials_booking_guard on public.service_bookings;
create trigger srk_exclude_materials_booking_guard
before insert or update of materials_amount, service_charge, quoted_amount
on public.service_bookings for each row
execute function public.srk_exclude_materials_from_new_bookings();

create or replace function public.srk_exclude_materials_from_new_final_bills()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin new.materials_amount := 0; return new; end; $$;

drop trigger if exists srk_exclude_materials_final_bill_guard on public.srk_booking_final_bills;
create trigger srk_exclude_materials_final_bill_guard
before insert or update of materials_amount
on public.srk_booking_final_bills for each row
execute function public.srk_exclude_materials_from_new_final_bills();

create or replace function public.srk_reject_material_bill_items()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if lower(coalesce(new.item_type,'')) = 'material' then
    raise exception 'Material is excluded from SRK ELECTRONIC booking bills';
  end if;
  return new;
end; $$;

drop trigger if exists srk_reject_material_bill_items_guard on public.srk_booking_final_bill_items;
create trigger srk_reject_material_bill_items_guard
before insert or update of item_type
on public.srk_booking_final_bill_items for each row
execute function public.srk_reject_material_bill_items();

update public.srk_service_pricing_rules
set materials_charged_separately = false
where materials_charged_separately is distinct from false;

comment on column public.service_bookings.materials_amount is
'Legacy compatibility field. New SRK ELECTRONIC bookings force this value to zero; materials are outside booking and payment accounting.';
comment on column public.srk_booking_final_bills.materials_amount is
'Legacy compatibility field. New final bills force this value to zero; materials are not billable through SRK ELECTRONIC.';
