create or replace function srk_private.admin_list_district_rate_history(
  p_district_lgd_code text,p_limit integer default 200
) returns table(
  created_at timestamptz,state_name text,district_name text,target_type text,target_id uuid,
  admin_user_id uuid,admin_name text,admin_email text,old_values jsonb,new_values jsonb,reason text
)
language plpgsql stable security definer
set search_path=pg_catalog,public,auth,srk_private
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  if not exists(select 1 from public.srk_india_districts where district_lgd_code=p_district_lgd_code) then
    raise exception 'District not found';
  end if;
  return query
  select a.created_at,d.state_name,d.district_name,a.target_type,a.target_id,
    a.admin_user_id,
    coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name','Main Admin'),
    u.email,a.old_values,a.new_values,a.reason
  from srk_private.admin_district_rate_audit_log a
  join public.srk_india_districts d on d.district_lgd_code=a.district_lgd_code
  left join auth.users u on u.id=a.admin_user_id
  where a.district_lgd_code=p_district_lgd_code
  order by a.created_at desc
  limit greatest(1,least(coalesce(p_limit,200),500));
end;
$function$;

revoke all on function srk_private.admin_list_district_rate_history(text,integer) from public,anon;
grant execute on function srk_private.admin_list_district_rate_history(text,integer) to authenticated;

create or replace function public.srk_admin_list_district_rate_history(p_district_lgd_code text,p_limit integer default 200)
returns table(
  created_at timestamptz,state_name text,district_name text,target_type text,target_id uuid,
  admin_user_id uuid,admin_name text,admin_email text,old_values jsonb,new_values jsonb,reason text
)
language sql stable security invoker set search_path=pg_catalog,public
as $function$ select * from srk_private.admin_list_district_rate_history(p_district_lgd_code,p_limit); $function$;

revoke all on function public.srk_admin_list_district_rate_history(text,integer) from public,anon;
grant execute on function public.srk_admin_list_district_rate_history(text,integer) to authenticated;
