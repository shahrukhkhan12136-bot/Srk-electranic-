create or replace function public.srk_admin_list_policy_documents(p_limit integer default 100)
returns setof public.srk_policy_documents
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  return query
  select d.*
  from public.srk_policy_documents d
  order by d.audience_role,d.policy_type,d.language_code,d.effective_at desc
  limit greatest(1,least(coalesce(p_limit,100),300));
end
$function$;
revoke all on function public.srk_admin_list_policy_documents(integer) from public,anon;
grant execute on function public.srk_admin_list_policy_documents(integer) to authenticated;
