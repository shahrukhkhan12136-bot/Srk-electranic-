
create or replace function public.srk_admin_list_audit_events(p_limit integer default 100)
returns table(
 id uuid, entity_type text, entity_id uuid, booking_id uuid, action text,
 actor_user_id uuid, actor_role text, changed_fields text[],
 before_data jsonb, after_data jsonb, created_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
begin
 if auth.uid() is null or not public.srk_has_admin_permission('audit.read') then
  raise exception 'Audit permission required' using errcode='42501';
 end if;
 return query
 select e.id,e.entity_type,e.entity_id,e.booking_id,e.action,e.actor_user_id,
        e.actor_role,e.changed_fields,e.before_data,e.after_data,e.created_at
 from public.srk_admin_audit_events e
 order by e.created_at desc
 limit greatest(1,least(coalesce(p_limit,100),200));
end;
$function$;

revoke all on function public.srk_admin_list_audit_events(integer) from public,anon;
grant execute on function public.srk_admin_list_audit_events(integer) to authenticated;
