create or replace function public.srk_admin_set_company_commission_rate(
  p_rate numeric,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_old numeric(5,2);
  v_new numeric(5,2);
  v_old_worker numeric(5,2);
  v_new_worker numeric(5,2);
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin confirmation required to change revenue split' using errcode='42501';
  end if;
  if p_rate is null or p_rate<0 or p_rate>100 or p_rate<>round(p_rate,2) then
    raise exception 'Company percentage must be between 0 and 100 with up to 2 decimal places';
  end if;
  if length(btrim(coalesce(p_reason,'')))<10 then
    raise exception 'Reason must be at least 10 characters';
  end if;
  select coalesce((setting_value #>> '{}')::numeric,15.00)
    into v_old from public.srk_system_settings
    where setting_key='company_commission_rate' for update;
  v_old:=coalesce(v_old,15.00);
  v_new:=p_rate::numeric(5,2);
  v_old_worker:=100.00-v_old;
  v_new_worker:=100.00-v_new;
  insert into public.srk_system_settings(setting_key,setting_value,updated_by,updated_at,admin_note)
  values('company_commission_rate',to_jsonb(v_new),auth.uid(),clock_timestamp(),btrim(p_reason))
  on conflict(setting_key) do update set setting_value=excluded.setting_value,
    updated_by=excluded.updated_by,updated_at=excluded.updated_at,admin_note=excluded.admin_note;
  insert into public.srk_system_settings(setting_key,setting_value,updated_by,updated_at,admin_note)
  values('worker_share_rate',to_jsonb(v_new_worker),auth.uid(),clock_timestamp(),btrim(p_reason))
  on conflict(setting_key) do update set setting_value=excluded.setting_value,
    updated_by=excluded.updated_by,updated_at=excluded.updated_at,admin_note=excluded.admin_note;
  return jsonb_build_object(
    'success',true,'previous_company_rate',v_old,'current_company_rate',v_new,
    'previous_worker_rate',v_old_worker,'current_worker_rate',v_new_worker,
    'effective_for','new bookings only'
  );
end
$function$;

create or replace function public.srk_admin_get_revenue_split()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
declare v_company numeric(5,2);
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin confirmation required' using errcode='42501';
  end if;
  select coalesce((setting_value #>> '{}')::numeric,15.00)
    into v_company from public.srk_system_settings
    where setting_key='company_commission_rate';
  v_company:=coalesce(v_company,15.00);
  return jsonb_build_object('company_rate',v_company,'worker_rate',100.00-v_company);
end
$function$;

create or replace function public.srk_admin_update_revenue_split(
  p_company_rate numeric,p_worker_rate numeric,p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin confirmation required' using errcode='42501';
  end if;
  if p_company_rate is null or p_worker_rate is null
    or p_company_rate<0 or p_company_rate>100
    or p_worker_rate<0 or p_worker_rate>100
    or p_company_rate<>round(p_company_rate,2)
    or p_worker_rate<>round(p_worker_rate,2)
    or round(p_company_rate+p_worker_rate,2)<>100 then
    raise exception 'Company and worker percentages must total exactly 100';
  end if;
  if length(btrim(coalesce(p_reason,'')))<10 then
    raise exception 'Change reason must contain at least 10 non-space characters';
  end if;
  v_result:=public.srk_admin_set_company_commission_rate(p_company_rate,p_reason);
  return v_result||jsonb_build_object(
    'company_rate',p_company_rate,'worker_rate',p_worker_rate,
    'effective_for','new bookings only'
  );
end
$function$;
revoke all on function public.srk_admin_set_company_commission_rate(numeric,text) from public,anon;
grant execute on function public.srk_admin_set_company_commission_rate(numeric,text) to authenticated;
revoke all on function public.srk_admin_get_revenue_split() from public,anon;
grant execute on function public.srk_admin_get_revenue_split() to authenticated;
revoke all on function public.srk_admin_update_revenue_split(numeric,numeric,text) from public,anon;
grant execute on function public.srk_admin_update_revenue_split(numeric,numeric,text) to authenticated;