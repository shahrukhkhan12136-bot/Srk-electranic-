CREATE UNIQUE INDEX IF NOT EXISTS srk_admin_users_singleton_only
ON public.srk_admin_users ((true));

CREATE OR REPLACE FUNCTION public.srk_admin_set_staff_role(
 p_user_id uuid,p_role_code text,p_active boolean,p_reason text
) RETURNS public.srk_admin_staff_members
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_role uuid;
 v_member public.srk_admin_staff_members%rowtype;
 v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');
begin
 if auth.uid() is null or not exists(
  select 1 from public.srk_admin_users where user_id=auth.uid()
 ) then
  raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_user_id is null or p_active is null or p_role_code is null
  or length(btrim(p_role_code)) not between 2 and 80 then
  raise exception 'Valid user, role and active status are required' using errcode='22023';
 end if;
 if v_reason is null or length(v_reason)<10 then
  raise exception 'Reason must be at least 10 non-space characters' using errcode='22023';
 end if;
 if exists(select 1 from public.srk_admin_users where user_id=p_user_id) then
  raise exception 'The Main Admin cannot also be assigned a Staff role';
 end if;
 if not exists(select 1 from auth.users where id=p_user_id) then
  raise exception 'Staff Auth user does not exist';
 end if;
 select id into v_role from public.srk_admin_roles
 where role_code=btrim(p_role_code) and is_active;
 if v_role is null then raise exception 'Admin role not found or inactive'; end if;
 insert into public.srk_admin_staff_members(
  user_id,role_id,is_active,invited_by,admin_note
 ) values(p_user_id,v_role,p_active,auth.uid(),v_reason)
 on conflict(user_id) do update
 set role_id=excluded.role_id,is_active=excluded.is_active,
  updated_at=clock_timestamp(),admin_note=excluded.admin_note
 returning * into v_member;
 return v_member;
end
$function$;