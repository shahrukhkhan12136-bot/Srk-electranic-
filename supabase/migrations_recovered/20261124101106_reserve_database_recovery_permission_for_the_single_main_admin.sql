ALTER TABLE public.srk_admin_role_permissions
 ADD CONSTRAINT srk_admin_role_permissions_no_staff_recovery
 CHECK (permission_code<>'system.recovery');

UPDATE public.srk_admin_permissions
SET description='Manage staff directory and HR profile information; role and permission changes remain Main Admin only'
WHERE permission_code='staff.manage';

CREATE OR REPLACE FUNCTION public.srk_admin_set_role_permission(
 p_role_code text,p_permission_code text,p_granted boolean,p_reason text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_role_id uuid;
 v_exists boolean;
 v_reason text:=nullif(btrim(coalesce(p_reason,'')),'');
begin
 if auth.uid() is null or not exists(select 1 from public.srk_admin_users where user_id=auth.uid()) then
  raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_role_code is null or length(btrim(p_role_code)) not between 2 and 80
  or p_permission_code is null or length(btrim(p_permission_code)) not between 3 and 100
  or p_granted is null then
  raise exception 'Valid role, permission and grant/revoke action are required' using errcode='22023';
 end if;
 if v_reason is null or length(v_reason)<10 then
  raise exception 'Reason must be at least 10 non-space characters' using errcode='22023';
 end if;
 if btrim(p_permission_code)='system.recovery' then
  raise exception 'Database recovery permission is reserved exclusively for the single Main Admin';
 end if;
 select id into v_role_id from public.srk_admin_roles
 where role_code=btrim(p_role_code) and is_active;
 if v_role_id is null then raise exception 'Active staff role not found'; end if;
 if not exists(select 1 from public.srk_admin_permissions where permission_code=btrim(p_permission_code)) then
  raise exception 'Permission code not found';
 end if;
 select exists(select 1 from public.srk_admin_role_permissions
  where role_id=v_role_id and permission_code=btrim(p_permission_code)) into v_exists;
 if p_granted then
  insert into public.srk_admin_role_permissions(role_id,permission_code,change_reason,updated_by,updated_at)
  values(v_role_id,btrim(p_permission_code),v_reason,auth.uid(),clock_timestamp())
  on conflict(role_id,permission_code) do update
  set change_reason=excluded.change_reason,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
 else
  if not v_exists then raise exception 'This role does not currently have that permission'; end if;
  update public.srk_admin_role_permissions
  set change_reason=v_reason,updated_by=auth.uid(),updated_at=clock_timestamp()
  where role_id=v_role_id and permission_code=btrim(p_permission_code);
  delete from public.srk_admin_role_permissions
  where role_id=v_role_id and permission_code=btrim(p_permission_code);
 end if;
 return jsonb_build_object('success',true,'role_code',btrim(p_role_code),
  'permission_code',btrim(p_permission_code),'granted',p_granted,'reason',v_reason);
end
$function$;