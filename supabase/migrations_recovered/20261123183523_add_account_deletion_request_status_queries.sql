
create or replace function public.srk_get_my_account_deletion_requests()
returns setof public.srk_account_deletion_requests
language sql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
 select r.* from public.srk_account_deletion_requests r
 where r.user_id=auth.uid()
 order by r.requested_at desc
$function$;
revoke all on function public.srk_get_my_account_deletion_requests() from public,anon;
grant execute on function public.srk_get_my_account_deletion_requests() to authenticated;

create or replace function public.srk_admin_list_account_deletion_requests(p_limit integer default 100)
returns setof public.srk_account_deletion_requests
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 return query select r.* from public.srk_account_deletion_requests r
 order by r.requested_at desc limit greatest(1,least(coalesce(p_limit,100),500));
end
$function$;
revoke all on function public.srk_admin_list_account_deletion_requests(integer) from public,anon;
grant execute on function public.srk_admin_list_account_deletion_requests(integer) to authenticated;
