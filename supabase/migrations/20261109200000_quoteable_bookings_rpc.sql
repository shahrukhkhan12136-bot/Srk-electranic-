-- Helper RPC for assigned electricians to find bookings eligible for a quote.
create or replace function public.srk_get_my_quoteable_bookings()
returns table(booking_id uuid,service_type text,booking_status text,quoted_amount numeric,customer_name text,created_at timestamptz)
language plpgsql stable security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare v_uid uuid:=auth.uid(); v_profile_id uuid;
begin
 if v_uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select id into v_profile_id from public.electrician_profiles
 where (user_id=v_uid or auth_user_id=v_uid) and verification_status='approved' and active=true;
 if v_profile_id is null then raise exception 'Approved active electrician profile required' using errcode='42501'; end if;
 return query
 select b.id,b.service_type,b.status,b.quoted_amount,b.customer_name,b.created_at
 from public.service_bookings b
 where b.assigned_electrician_id=v_profile_id and b.status in ('assigned','in_progress')
 order by b.created_at desc limit 100;
end;
$function$;
revoke all on function public.srk_get_my_quoteable_bookings() from public,anon;
grant execute on function public.srk_get_my_quoteable_bookings() to authenticated;
