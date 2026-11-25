
alter table public.srk_service_pricing_rules
  add constraint srk_pricing_rates_positive
  check (
    (technician_rate is null or technician_rate > 0)
    and (helper_rate is null or helper_rate > 0)
    and (base_hp is null or base_hp > 0)
    and (base_hp_price is null or base_hp_price > 0)
    and (hp_step_amount is null or hp_step_amount > 0)
  ) not valid;

alter table public.srk_service_pricing_rules
  add constraint srk_pricing_effective_window_valid
  check (effective_to is null or effective_to > effective_from) not valid;

alter table public.srk_service_pricing_rules
  add constraint srk_pricing_timer_matches_unit
  check (
    (pricing_unit = 'hour' and timer_enabled = true)
    or (pricing_unit in ('per_item','motor_hp') and timer_enabled = false)
  ) not valid;

alter table public.srk_service_pricing_rules
  validate constraint srk_pricing_rates_positive;
alter table public.srk_service_pricing_rules
  validate constraint srk_pricing_effective_window_valid;
alter table public.srk_service_pricing_rules
  validate constraint srk_pricing_timer_matches_unit;
