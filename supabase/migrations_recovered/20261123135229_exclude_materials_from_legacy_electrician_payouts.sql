
create or replace function public.srk_exclude_materials_from_legacy_electrician_payout()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  new.materials_amount := 0;
  if new.gross_service_amount is not null and new.platform_commission is not null then
    new.electrician_payable := round(new.gross_service_amount - new.platform_commission, 2);
  end if;
  return new;
end; $$;

drop trigger if exists srk_exclude_materials_legacy_payout_guard on public.srk_electrician_payouts;
create trigger srk_exclude_materials_legacy_payout_guard
before insert or update of materials_amount, gross_service_amount, platform_commission, electrician_payable
on public.srk_electrician_payouts for each row
execute function public.srk_exclude_materials_from_legacy_electrician_payout();

comment on column public.srk_electrician_payouts.materials_amount is
'Legacy compatibility field. New payout records force this value to zero; materials are outside SRK ELECTRONIC payments and payouts.';
