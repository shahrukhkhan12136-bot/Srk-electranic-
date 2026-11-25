
create or replace function public.srk_customer_list_cancellation_fees()
returns setof public.srk_booking_cancellation_fees
language sql
stable
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
 select f.* from public.srk_booking_cancellation_fees f
 where f.customer_user_id=auth.uid()
 order by f.created_at desc
$function$;
revoke all on function public.srk_customer_list_cancellation_fees() from public,anon;
grant execute on function public.srk_customer_list_cancellation_fees() to authenticated;
