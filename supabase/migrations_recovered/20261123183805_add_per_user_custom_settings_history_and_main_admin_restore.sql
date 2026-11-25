
create table if not exists public.srk_user_custom_settings (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null,
 account_role text not null check (account_role in ('customer','technician','helper')),
 setting_key text not null,
 setting_value jsonb not null,
 changed_by uuid not null,
 change_reason text not null,
 updated_at timestamptz not null default now(),
 unique(user_id,account_role,setting_key)
);
create table if not exists public.srk_user_custom_setting_history (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null,
 account_role text not null check (account_role in ('customer','technician','helper')),
 setting_key text not null,
 old_value jsonb,
 new_value jsonb not null,
 changed_by uuid not null,
 change_reason text not null,
 changed_at timestamptz not null default now()
);
create index if not exists srk_user_custom_settings_user_idx
 on public.srk_user_custom_settings(user_id,account_role);
create index if not exists srk_user_custom_setting_history_user_idx
 on public.srk_user_custom_setting_history(user_id,changed_at desc);
alter table public.srk_user_custom_settings enable row level security;
alter table public.srk_user_custom_setting_history enable row level security;
revoke all privileges on table public.srk_user_custom_settings,public.srk_user_custom_setting_history from anon,authenticated;

create or replace function public.srk_admin_set_user_custom_setting(
 p_user_id uuid,p_account_role text,p_setting_key text,p_setting_value jsonb,p_reason text
)
returns public.srk_user_custom_settings
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_old jsonb; v_row public.srk_user_custom_settings%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_user_id is null or p_account_role not in ('customer','technician','helper')
    or p_setting_key is null or length(btrim(p_setting_key)) not between 2 and 80
    or p_setting_value is null or length(btrim(coalesce(p_reason,'')))<10 then
   raise exception 'User, role, setting, value and reason are required' using errcode='22023';
 end if;
 if p_account_role='customer' and not exists(select 1 from public.srk_customer_profiles where user_id=p_user_id) then
   raise exception 'Customer account not found';
 elsif p_account_role in ('technician','helper') and not exists(
   select 1 from public.srk_worker_profiles where user_id=p_user_id and worker_type=p_account_role
 ) then
   raise exception 'Worker account role does not match';
 end if;
 select setting_value into v_old from public.srk_user_custom_settings
 where user_id=p_user_id and account_role=p_account_role and setting_key=p_setting_key
 for update;
 insert into public.srk_user_custom_setting_history(
   user_id,account_role,setting_key,old_value,new_value,changed_by,change_reason
 ) values(p_user_id,p_account_role,p_setting_key,v_old,p_setting_value,auth.uid(),btrim(p_reason));
 insert into public.srk_user_custom_settings(
   user_id,account_role,setting_key,setting_value,changed_by,change_reason,updated_at
 ) values(p_user_id,p_account_role,p_setting_key,p_setting_value,auth.uid(),btrim(p_reason),clock_timestamp())
 on conflict(user_id,account_role,setting_key) do update
 set setting_value=excluded.setting_value,changed_by=excluded.changed_by,
     change_reason=excluded.change_reason,updated_at=excluded.updated_at
 returning * into v_row;
 return v_row;
end
$function$;
revoke all on function public.srk_admin_set_user_custom_setting(uuid,text,text,jsonb,text) from public,anon;
grant execute on function public.srk_admin_set_user_custom_setting(uuid,text,text,jsonb,text) to authenticated;

create or replace function public.srk_user_get_my_custom_settings()
returns setof public.srk_user_custom_settings
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_role text;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then v_role:='customer';
 else select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid() limit 1;
 end if;
 if v_role is null then raise exception 'Account role not found'; end if;
 return query select s.* from public.srk_user_custom_settings s
 where s.user_id=auth.uid() and s.account_role=v_role order by s.setting_key;
end
$function$;
revoke all on function public.srk_user_get_my_custom_settings() from public,anon;
grant execute on function public.srk_user_get_my_custom_settings() to authenticated;

create or replace function public.srk_admin_restore_system_setting(
 p_history_id uuid,p_confirm boolean,p_reason text
)
returns public.srk_system_settings
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_history public.srk_system_setting_history%rowtype; v_setting public.srk_system_settings%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_history_id is null or p_confirm is distinct from true or length(btrim(coalesce(p_reason,'')))<10 then
   raise exception 'Explicit confirmation and a reason of at least 10 characters are required';
 end if;
 select * into v_history from public.srk_system_setting_history where id=p_history_id for update;
 if not found then raise exception 'Setting history record not found'; end if;
 update public.srk_system_settings
 set setting_value=v_history.old_value,admin_note='RESTORE: '||btrim(p_reason),
     updated_by=auth.uid(),updated_at=clock_timestamp()
 where setting_key=v_history.setting_key returning * into v_setting;
 if not found then raise exception 'Current system setting not found'; end if;
 return v_setting;
end
$function$;
revoke all on function public.srk_admin_restore_system_setting(uuid,boolean,text) from public,anon;
grant execute on function public.srk_admin_restore_system_setting(uuid,boolean,text) to authenticated;
