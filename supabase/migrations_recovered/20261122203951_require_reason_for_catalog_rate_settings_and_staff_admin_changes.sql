
alter table public.srk_admin_staff_members add column if not exists admin_note text;
alter table public.srk_system_settings add column if not exists admin_note text;
alter table public.srk_service_types add column if not exists admin_note text;
alter table public.srk_service_skills add column if not exists admin_note text;
alter table public.srk_booking_receipts add column if not exists admin_note text;

create or replace function public.srk_admin_set_offer_timeout(p_seconds integer,p_reason text)
returns boolean language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if p_seconds is null or p_seconds not between 30 and 3600 then raise exception 'Offer timeout must be 30 to 3600 seconds'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Reason must be at least 10 characters'; end if;
  insert into public.srk_system_settings(setting_key,setting_value,updated_by,updated_at,admin_note)
  values('offer_timeout_seconds',to_jsonb(p_seconds),auth.uid(),clock_timestamp(),p_reason)
  on conflict(setting_key) do update set setting_value=excluded.setting_value,updated_by=excluded.updated_by,
    updated_at=excluded.updated_at,admin_note=excluded.admin_note;
  return true;
end $$;
revoke all on function public.srk_admin_set_offer_timeout(integer) from public,anon,authenticated;
revoke all on function public.srk_admin_set_offer_timeout(integer,text) from public,anon;
grant execute on function public.srk_admin_set_offer_timeout(integer,text) to authenticated;

create or replace function public.srk_admin_set_staff_role(p_user_id uuid,p_role_code text,p_active boolean,p_reason text)
returns public.srk_admin_staff_members
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_role uuid; v_member public.srk_admin_staff_members%rowtype;
begin
  if not exists(select 1 from public.srk_admin_users where user_id=auth.uid()) then raise exception 'Super Admin permission required'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Reason must be at least 10 characters'; end if;
  select id into v_role from public.srk_admin_roles where role_code=p_role_code and is_active;
  if v_role is null then raise exception 'Admin role not found or inactive'; end if;
  insert into public.srk_admin_staff_members(user_id,role_id,is_active,invited_by,admin_note)
  values(p_user_id,v_role,p_active,auth.uid(),p_reason)
  on conflict(user_id) do update set role_id=excluded.role_id,is_active=excluded.is_active,
    updated_at=clock_timestamp(),admin_note=excluded.admin_note
  returning * into v_member;
  return v_member;
end $$;
revoke all on function public.srk_admin_set_staff_role(uuid,text,boolean) from public,anon,authenticated;
revoke all on function public.srk_admin_set_staff_role(uuid,text,boolean,text) from public,anon;
grant execute on function public.srk_admin_set_staff_role(uuid,text,boolean,text) to authenticated;

create or replace function public.srk_admin_add_service_type(
 p_category_id uuid,p_service_code text,p_service_name text,p_sort_order integer,p_reason text
) returns public.srk_service_types
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_service_types%rowtype;
begin
  if not public.srk_has_admin_permission('catalog.manage') then raise exception 'Catalog management permission required'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Reason must be at least 10 characters'; end if;
  if p_service_code !~ '^[a-z][a-z0-9_]{1,59}$' or length(btrim(p_service_name)) not between 2 and 120 then raise exception 'Invalid service code or name'; end if;
  insert into public.srk_service_types(category_id,service_code,service_name,sort_order,is_active,admin_note)
  values(p_category_id,p_service_code,btrim(p_service_name),coalesce(p_sort_order,0),true,p_reason)
  returning * into v;
  return v;
end $$;
revoke all on function public.srk_admin_add_service_type(uuid,text,text,integer) from public,anon,authenticated;
revoke all on function public.srk_admin_add_service_type(uuid,text,text,integer,text) from public,anon;
grant execute on function public.srk_admin_add_service_type(uuid,text,text,integer,text) to authenticated;

create or replace function public.srk_admin_add_service_skill(
 p_service_type_id uuid,p_skill_code text,p_skill_name text,p_sort_order integer,p_reason text
) returns public.srk_service_skills
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_service_skills%rowtype;
begin
  if not public.srk_has_admin_permission('catalog.manage') then raise exception 'Catalog management permission required'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Reason must be at least 10 characters'; end if;
  if p_skill_code !~ '^[a-z][a-z0-9_]{1,79}$' or length(btrim(p_skill_name)) not between 2 and 150 then raise exception 'Invalid skill code or name'; end if;
  insert into public.srk_service_skills(service_type_id,skill_code,skill_name,sort_order,is_active,admin_note)
  values(p_service_type_id,p_skill_code,btrim(p_skill_name),coalesce(p_sort_order,0),true,p_reason)
  returning * into v;
  return v;
end $$;
revoke all on function public.srk_admin_add_service_skill(uuid,text,text,integer) from public,anon,authenticated;
revoke all on function public.srk_admin_add_service_skill(uuid,text,text,integer,text) from public,anon;
grant execute on function public.srk_admin_add_service_skill(uuid,text,text,integer,text) to authenticated;

create or replace function public.srk_admin_publish_service_rate(
 p_category_id uuid,p_service_type_id uuid,p_skill_level_id uuid,
 p_technician_hourly_rate numeric,p_helper_hourly_rate numeric,p_reason text
) returns public.srk_service_rates
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_service_rates%rowtype;
begin
  if not public.srk_has_admin_permission('catalog.manage') then raise exception 'Catalog management permission required'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Rate change reason must be at least 10 characters'; end if;
  if p_technician_hourly_rate is null or p_technician_hourly_rate<0 or p_helper_hourly_rate is null or p_helper_hourly_rate<0 then raise exception 'Both hourly rates must be non-negative'; end if;
  if not exists(select 1 from public.srk_skill_levels l where l.id=p_skill_level_id and l.category_id=p_category_id) then raise exception 'Skill level/category mismatch'; end if;
  if p_service_type_id is not null and not exists(select 1 from public.srk_service_types s where s.id=p_service_type_id and s.category_id=p_category_id) then raise exception 'Service type/category mismatch'; end if;
  update public.srk_service_rates set effective_to=clock_timestamp(),rate_status='retired'
  where category_id=p_category_id and service_type_id is not distinct from p_service_type_id
    and skill_level_id=p_skill_level_id and rate_status='approved' and effective_to is null;
  insert into public.srk_service_rates(category_id,service_type_id,skill_level_id,technician_hourly_rate,
    helper_hourly_rate,rate_status,created_by,change_reason)
  values(p_category_id,p_service_type_id,p_skill_level_id,p_technician_hourly_rate,p_helper_hourly_rate,'approved',auth.uid(),p_reason)
  returning * into v;
  return v;
end $$;
revoke all on function public.srk_admin_publish_service_rate(uuid,uuid,uuid,numeric,numeric) from public,anon,authenticated;
revoke all on function public.srk_admin_publish_service_rate(uuid,uuid,uuid,numeric,numeric,text) from public,anon;
grant execute on function public.srk_admin_publish_service_rate(uuid,uuid,uuid,numeric,numeric,text) to authenticated;

create or replace function public.srk_admin_attach_booking_receipt(p_bill_id uuid,p_storage_path text,p_file_name text,p_reason text)
returns public.srk_booking_receipts
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking uuid; v public.srk_booking_receipts%rowtype;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if length(coalesce(p_reason,''))<10 then raise exception 'Reason must be at least 10 characters'; end if;
  if p_storage_path like '/%' or p_storage_path like '%..%' then raise exception 'Invalid receipt path'; end if;
  select booking_id into v_booking from public.srk_booking_final_bills where id=p_bill_id and status in ('issued','approved');
  if not found then raise exception 'Issued final bill not found'; end if;
  insert into public.srk_booking_receipts(bill_id,booking_id,storage_path,file_name,generated_by,admin_note)
  values(p_bill_id,v_booking,p_storage_path,p_file_name,auth.uid(),p_reason)
  on conflict(bill_id) do update set storage_path=excluded.storage_path,file_name=excluded.file_name,
    generated_at=clock_timestamp(),generated_by=auth.uid(),admin_note=excluded.admin_note
  returning * into v;
  return v;
end $$;
revoke all on function public.srk_admin_attach_booking_receipt(uuid,text,text) from public,anon,authenticated;
revoke all on function public.srk_admin_attach_booking_receipt(uuid,text,text,text) from public,anon;
grant execute on function public.srk_admin_attach_booking_receipt(uuid,text,text,text) to authenticated;

drop trigger if exists srk_audit_system_settings_admin on public.srk_system_settings;
create trigger srk_audit_system_settings_admin after insert or update or delete on public.srk_system_settings
for each row execute function public.srk_log_admin_entity_change('system_setting');
