
create or replace function public.srk_admin_list_no_show_reports(p_limit integer default 100)
returns setof public.srk_booking_no_show_reports
language plpgsql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
begin
 if auth.uid() is null or not public.srk_has_admin_permission('support.manage') then
   raise exception 'Support permission required' using errcode='42501';
 end if;
 return query select r.* from public.srk_booking_no_show_reports r
 order by r.reported_at desc limit greatest(1,least(coalesce(p_limit,100),500));
end
$function$;
revoke all on function public.srk_admin_list_no_show_reports(integer) from public,anon;
grant execute on function public.srk_admin_list_no_show_reports(integer) to authenticated;

create or replace function public.srk_customer_list_my_no_show_reports()
returns setof public.srk_booking_no_show_reports
language sql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
 select r.* from public.srk_booking_no_show_reports r
 where r.reported_by=auth.uid()
 order by r.reported_at desc
$function$;
revoke all on function public.srk_customer_list_my_no_show_reports() from public,anon;
grant execute on function public.srk_customer_list_my_no_show_reports() to authenticated;
