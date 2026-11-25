
drop policy if exists srk_worker_application_self on public.srk_worker_applications;
create policy srk_worker_application_self
on public.srk_worker_applications for select to authenticated
using (user_id=auth.uid() or public.is_srk_admin());

create or replace function public.srk_admin_list_worker_applications_masked(p_limit integer default 100)
returns table(
 application_id uuid,worker_type text,full_name text,masked_phone text,
 category_id uuid,state text,district text,experience_years integer,
 status text,submitted_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
begin
 if auth.uid() is null or not public.srk_has_admin_permission('workers.verify') then
   raise exception 'Worker verification permission required' using errcode='42501';
 end if;
 return query
 select a.id,a.worker_type,a.full_name,
   case when a.phone is null then null else '******'||right(a.phone,4) end,
   a.category_id,a.state,a.district,a.experience_years,a.status,a.created_at
 from public.srk_worker_applications a
 order by a.created_at desc limit greatest(1,least(coalesce(p_limit,100),500));
end
$function$;
revoke all on function public.srk_admin_list_worker_applications_masked(integer) from public,anon;
grant execute on function public.srk_admin_list_worker_applications_masked(integer) to authenticated;
