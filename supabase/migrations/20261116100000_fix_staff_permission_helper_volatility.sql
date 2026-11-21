-- PostgreSQL row-locking permission checks must be VOLATILE.
-- The Staff permission helper takes FOR SHARE locks to serialize authorization
-- with suspension and session revocation. STABLE functions cannot execute
-- SELECT ... FOR SHARE/UPDATE in PostgreSQL.
create or replace function public.srk_has_admin_permission(p_permission_key text)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_session_id uuid;
begin
  if v_uid is null or p_permission_key is null or length(p_permission_key) > 120 then
    return false;
  end if;

  -- Main Admin remains a separate, full-control identity class.
  if public.is_srk_admin() then
    return true;
  end if;

  if coalesce(auth.jwt() ->> 'session_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  v_session_id := (auth.jwt() ->> 'session_id')::uuid;

  -- Hold registry and tracked-session locks through the caller transaction.
  perform 1 from public.srk_admin_staff s
   where s.user_id = v_uid and s.status = 'active'
   for share;
  if not found then
    return false;
  end if;

  perform 1 from public.srk_admin_staff_sessions tracked
   where tracked.auth_session_id = v_session_id
     and tracked.staff_user_id = v_uid
     and tracked.revoked_at is null
   for share;
  if not found then
    return false;
  end if;

  return exists (
    select 1
      from public.srk_admin_staff s
      join public.srk_admin_role_permissions rp on rp.role_key = s.role_key
      join public.srk_admin_permissions p on p.permission_key = rp.permission_key
     where s.user_id = v_uid
       and s.status = 'active'
       and p.permission_key = p_permission_key
       and exists (
         select 1 from auth.sessions auth_s
          where auth_s.id = v_session_id and auth_s.user_id = v_uid
       )
  );
end;
$function$;

revoke all on function public.srk_has_admin_permission(text) from public, anon;
grant execute on function public.srk_has_admin_permission(text) to authenticated;

comment on function public.srk_has_admin_permission(text) is
  'VOLATILE because Staff authorization locks the active registry and exact live Auth session rows with FOR SHARE.';
