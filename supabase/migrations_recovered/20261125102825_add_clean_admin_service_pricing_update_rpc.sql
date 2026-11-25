create or replace function public.srk_admin_update_service_pricing_rate(
  p_pricing_rule_id uuid,
  p_pricing_unit text,
  p_technician_rate numeric,
  p_helper_rate numeric,
  p_base_hp numeric,
  p_base_hp_price numeric,
  p_hp_step_amount numeric,
  p_timer_enabled boolean,
  p_pricing_note text,
  p_hp_tiers jsonb,
  p_change_reason text
)
returns uuid
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $function$
begin
  if auth.uid() is null or not public.srk_has_admin_permission('catalog.manage') then
    raise exception 'Catalog management permission required' using errcode='42501';
  end if;
  return public.srk_admin_version_service_pricing_rule(
    p_pricing_rule_id,p_pricing_unit,p_technician_rate,p_helper_rate,
    p_base_hp,p_base_hp_price,p_hp_step_amount,p_timer_enabled,
    false,false,p_pricing_note,p_hp_tiers,p_change_reason
  );
end
$function$;
revoke all on function public.srk_admin_update_service_pricing_rate(uuid,text,numeric,numeric,numeric,numeric,numeric,boolean,text,jsonb,text) from public,anon;
grant execute on function public.srk_admin_update_service_pricing_rate(uuid,text,numeric,numeric,numeric,numeric,numeric,boolean,text,jsonb,text) to authenticated;