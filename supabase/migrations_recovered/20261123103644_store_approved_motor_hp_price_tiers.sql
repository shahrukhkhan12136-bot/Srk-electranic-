
create table if not exists public.srk_service_pricing_hp_tiers (
 id uuid primary key default gen_random_uuid(),
 pricing_rule_id uuid not null references public.srk_service_pricing_rules(id) on delete restrict,
 motor_hp numeric(8,2) not null check (motor_hp >= 0.5),
 fixed_price numeric(12,2) not null check (fixed_price > 0),
 created_at timestamptz not null default clock_timestamp(),
 created_by uuid,
 unique(pricing_rule_id,motor_hp)
);
create index if not exists srk_pricing_hp_tiers_rule_hp_idx
 on public.srk_service_pricing_hp_tiers(pricing_rule_id,motor_hp);
alter table public.srk_service_pricing_hp_tiers enable row level security;
revoke all on public.srk_service_pricing_hp_tiers from public,anon,authenticated;
insert into public.srk_service_pricing_hp_tiers(pricing_rule_id,motor_hp,fixed_price)
select r.id,t.motor_hp,t.fixed_price
from public.srk_service_pricing_rules r
cross join (values (0.5::numeric,500::numeric),(1.0::numeric,600::numeric),
                   (1.5::numeric,650::numeric),(2.0::numeric,700::numeric)) t(motor_hp,fixed_price)
where r.pricing_unit='motor_hp' and r.effective_to is null
on conflict(pricing_rule_id,motor_hp) do update set fixed_price=excluded.fixed_price;
