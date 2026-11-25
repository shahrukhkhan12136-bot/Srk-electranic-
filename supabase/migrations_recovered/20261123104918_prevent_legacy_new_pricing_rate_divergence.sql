
create or replace function public.srk_admin_update_service_rate(
 p_rate_id uuid,
 p_technician_hourly_rate numeric,
 p_helper_hourly_rate numeric,
 p_change_reason text
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_old public.srk_service_rates%rowtype;
 v_new_id uuid;
 v_changed_at timestamptz := clock_timestamp();
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not public.srk_has_admin_permission('catalog.manage') then
  raise exception 'Catalog management permission required';
 end if;
 if p_rate_id is null then raise exception 'Rate ID is required'; end if;
 if p_technician_hourly_rate is null or p_technician_hourly_rate <= 0 then
  raise exception 'Technician hourly rate must be positive';
 end if;
 if p_helper_hourly_rate is not null and p_helper_hourly_rate <= 0 then
  raise exception 'Helper hourly rate must be positive when supplied';
 end if;
 if length(btrim(coalesce(p_change_reason,''))) < 10 then
  raise exception 'Rate change reason must be at least 10 characters';
 end if;

 select * into v_old from public.srk_service_rates
 where id=p_rate_id and effective_to is null and rate_status='approved'
 for update;
 if not found then
  raise exception 'Current approved legacy rate not found; drafts and retired rates cannot be changed here';
 end if;

 if exists (
  select 1 from public.srk_service_pricing_rules r
  where r.category_id=v_old.category_id
    and r.service_type_id=v_old.service_type_id
    and r.effective_from<=v_changed_at
    and (r.effective_to is null or r.effective_to>v_changed_at)
 ) then
  raise exception 'This service uses the versioned pricing rules. Update it through srk_admin_version_service_pricing_rule instead of the legacy hourly-rate manager';
 end if;

 update public.srk_service_rates
 set effective_to=v_changed_at,
     change_reason=concat_ws('; ',nullif(change_reason,''),'Superseded by admin rate adjustment')
 where id=v_old.id;

 insert into public.srk_service_rates(
  category_id,service_type_id,skill_level_id,technician_hourly_rate,
  helper_hourly_rate,rate_status,effective_from,created_by,change_reason
 ) values (
  v_old.category_id,v_old.service_type_id,v_old.skill_level_id,
  p_technician_hourly_rate,p_helper_hourly_rate,'approved',v_changed_at,
  auth.uid(),btrim(p_change_reason)
 ) returning id into v_new_id;

 return jsonb_build_object(
  'success',true,'previous_rate_id',v_old.id,'new_rate_id',v_new_id,
  'technician_hourly_rate',p_technician_hourly_rate,
  'helper_hourly_rate',p_helper_hourly_rate,'effective_from',v_changed_at
 );
end
$function$;
revoke all on function public.srk_admin_update_service_rate(uuid,numeric,numeric,text) from public,anon;
grant execute on function public.srk_admin_update_service_rate(uuid,numeric,numeric,text) to authenticated;
comment on function public.srk_admin_update_service_rate(uuid,numeric,numeric,text)
is 'Legacy hourly-rate versioning only for services without a current srk_service_pricing_rules row; prevents divergence from versioned pricing rules.';
